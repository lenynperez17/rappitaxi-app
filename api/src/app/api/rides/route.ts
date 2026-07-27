/**
 * POST /api/rides
 *   Auth: Bearer <access_token>
 *   Body: {
 *     pickup: { lat, lng, address },
 *     destination: { lat, lng, address },
 *     vehicleType, paymentMethod,
 *     proposedFare?, negotiable?, distanceMeters?, durationSeconds?
 *   }
 *   Passenger crea solicitud de viaje. Inserta en rides con status='requested'.
 *   Retorna el ride creado con su id.
 *
 * GET /api/rides?role=passenger|driver&status=&page=1&pageSize=20
 *   Lista viajes del user autenticado según rol. Ordenar por created_at DESC.
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { query, maybeOne } from '@/lib/db'
import { findNearbyOnlineDrivers, notifyRideOffer } from '@/lib/notify-drivers'

export const runtime = 'nodejs'

const ALLOWED_STATUSES = [
  'requested', 'searching', 'accepted', 'on_way', 'arrived',
  'in_progress', 'completed', 'cancelled', 'no_drivers',
]
const ALLOWED_VEHICLE_TYPES = ['taxi', 'moto', 'moto_taxi', 'car', 'van', 'truck', 'bicycle']
const ALLOWED_PAYMENT_METHODS = ['cash', 'mercadopago', 'wallet', 'yape', 'plin', 'card']

interface RideRow {
  id: string
  passenger_id: string | null
  driver_id: string | null
  status: string
  pickup_address: string | null
  pickup_lat: string | null
  pickup_lng: string | null
  destination_address: string | null
  destination_lat: string | null
  destination_lng: string | null
  distance_meters: number | null
  duration_seconds: number | null
  estimated_fare: string | null
  final_fare: string | null
  payment_method: string | null
  vehicle_type: string | null
  passenger_rating: string | null
  driver_rating: string | null
  cancelled_by: string | null
  cancelled_reason: string | null
  created_at: Date
  accepted_at: Date | null
  started_at: Date | null
  completed_at: Date | null
  metadata: Record<string, unknown> | null
}

function serializeRide(r: RideRow) {
  return {
    id: r.id,
    passengerId: r.passenger_id,
    driverId: r.driver_id,
    status: r.status,
    pickup: {
      address: r.pickup_address,
      lat: r.pickup_lat !== null ? Number(r.pickup_lat) : null,
      lng: r.pickup_lng !== null ? Number(r.pickup_lng) : null,
    },
    destination: {
      address: r.destination_address,
      lat: r.destination_lat !== null ? Number(r.destination_lat) : null,
      lng: r.destination_lng !== null ? Number(r.destination_lng) : null,
    },
    distanceMeters: r.distance_meters,
    durationSeconds: r.duration_seconds,
    estimatedFare: r.estimated_fare !== null ? Number(r.estimated_fare) : null,
    finalFare: r.final_fare !== null ? Number(r.final_fare) : null,
    paymentMethod: r.payment_method,
    vehicleType: r.vehicle_type,
    passengerRating: r.passenger_rating !== null ? Number(r.passenger_rating) : null,
    driverRating: r.driver_rating !== null ? Number(r.driver_rating) : null,
    cancelledBy: r.cancelled_by,
    cancelledReason: r.cancelled_reason,
    createdAt: r.created_at,
    acceptedAt: r.accepted_at,
    startedAt: r.started_at,
    completedAt: r.completed_at,
    metadata: r.metadata,
    // Ronda 244 BUG FIX: `negotiable` y `proposedFare` viven dentro de
    // metadata (JSONB), pero el cliente los lee del ROOT:
    //   final negotiable = ride['negotiable'] == true || ride['isNegotiable'] == true;
    //   if (!negotiable && status != 'accepted') continue;   // ← descartaba el ride
    // Como ride['negotiable'] era null, TODO ride negociable se filtraba del
    // listado del pasajero y sus ofertas nunca se mostraban ("le mandé la
    // oferta y no llega"). Los exponemos también en el root para que el
    // cliente actual funcione sin necesidad de actualizar la app.
    negotiable: (r.metadata as Record<string, unknown> | null)?.negotiable === true,
    // Ronda 247: ganancia neta y comisión reales del viaje. Las pantallas del
    // conductor las inventaban con un 12% fijo mientras el backend cobra 20%.
    driverEarning:
      (r.metadata as Record<string, unknown> | null)?.driverEarning !== undefined
        ? Number((r.metadata as Record<string, unknown>).driverEarning)
        : null,
    commissionAmount:
      (r.metadata as Record<string, unknown> | null)?.commissionAmount !== undefined
        ? Number((r.metadata as Record<string, unknown>).commissionAmount)
        : null,
    commissionRate:
      (r.metadata as Record<string, unknown> | null)?.commissionRate !== undefined
        ? Number((r.metadata as Record<string, unknown>).commissionRate)
        : null,
    proposedFare:
      (r.metadata as Record<string, unknown> | null)?.proposedFare !== undefined
        ? Number((r.metadata as Record<string, unknown>).proposedFare)
        : null,
  }
}

// ============================================================================
// POST — Passenger crea viaje
// ============================================================================
interface PointInput {
  lat?: number
  lng?: number
  address?: string
}

export async function POST(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  let body: {
    pickup?: PointInput
    destination?: PointInput
    vehicleType?: string
    paymentMethod?: string
    proposedFare?: number
    negotiable?: boolean
    distanceMeters?: number
    durationSeconds?: number
  } = {}
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ success: false, error: 'bad_json' }, { status: 400 })
  }

  const pickup = body.pickup
  const destination = body.destination
  const vehicleType = body.vehicleType?.trim()
  const paymentMethod = body.paymentMethod?.trim()

  // Ronda 79: validar rango lat/lng además de tipo. Sin esto, coords absurdas
  // (999, -4000) llegaban a Postgres y contaminaban Haversine + crasheaban
  // Google Maps client + envenenaban analytics.
  // Ronda 260: además del rango planetario, se exige que el punto caiga
  // dentro de PERÚ. Última línea de defensa: si el geocodificador vuelve a
  // fallar, el viaje no se crea con basura. En producción se guardaron tres
  // viajes con el destino en AUSTRIA (lat 46.78, lng 15.57) porque Photon
  // devolvió un resultado europeo — pasaban esta validación sin problema al
  // ser coordenadas "válidas" en el sentido geométrico. El mapa salía todo
  // azul, la distancia quedaba nula y la app del conductor se cerraba.
  // Perú: lat -18.4..0.0, lng -81.4..-68.6 (con margen).
  const inPeru = (lat: number, lng: number): boolean =>
    lat >= -19 && lat <= 0.5 && lng >= -82 && lng <= -68
  const isValidCoord = (lat: unknown, lng: unknown): boolean =>
    typeof lat === 'number' && typeof lng === 'number' &&
    Number.isFinite(lat) && Number.isFinite(lng) &&
    lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180 &&
    inPeru(lat, lng)
  if (!pickup || !isValidCoord(pickup.lat, pickup.lng)) {
    return NextResponse.json(
      { success: false, error: 'invalid_pickup', message: 'El punto de recogida debe estar dentro de Perú' },
      { status: 400 },
    )
  }
  if (!destination || !isValidCoord(destination.lat, destination.lng)) {
    return NextResponse.json(
      { success: false, error: 'invalid_destination', message: 'El destino debe estar dentro de Perú' },
      { status: 400 },
    )
  }
  if (!vehicleType || !ALLOWED_VEHICLE_TYPES.includes(vehicleType)) {
    return NextResponse.json(
      { success: false, error: 'invalid_vehicle_type', message: `vehicleType debe ser uno de: ${ALLOWED_VEHICLE_TYPES.join(', ')}` },
      { status: 400 },
    )
  }
  if (!paymentMethod || !ALLOWED_PAYMENT_METHODS.includes(paymentMethod)) {
    return NextResponse.json(
      { success: false, error: 'invalid_payment_method', message: `paymentMethod debe ser uno de: ${ALLOWED_PAYMENT_METHODS.join(', ')}` },
      { status: 400 },
    )
  }

  // Cap absoluto en proposedFare para prevenir fat-finger / driver malicioso
  // que proponga estimated_fare inflado. Taxi urbano Perú realista: max S/ 500.
  // Combinado con FINAL_FARE_MAX_MULTIPLIER=1.5 en complete → max S/ 750 total.
  const PROPOSED_FARE_ABS_CAP = 500
  const rawProposed = typeof body.proposedFare === 'number' ? body.proposedFare : null
  if (rawProposed !== null && rawProposed > PROPOSED_FARE_ABS_CAP) {
    return NextResponse.json(
      { success: false, error: 'fare_too_high',
        message: `El precio propuesto no puede exceder S/ ${PROPOSED_FARE_ABS_CAP}.` },
      { status: 400 },
    )
  }
  const proposedFare = rawProposed !== null && rawProposed > 0 ? rawProposed : null
  const negotiable = body.negotiable === true
  // Caps sanos para prevenir envenenamiento de analytics con valores absurdos
  // (distance 9e15, duration 1e9). Taxi urbano Perú: <500km, <8h.
  const MAX_DISTANCE_M = 500_000  // 500 km
  const MAX_DURATION_S = 8 * 3600  // 8 horas
  const distanceMeters = typeof body.distanceMeters === 'number' && body.distanceMeters >= 0 && body.distanceMeters <= MAX_DISTANCE_M
    ? Math.round(body.distanceMeters)
    : null
  const durationSeconds = typeof body.durationSeconds === 'number' && body.durationSeconds >= 0 && body.durationSeconds <= MAX_DURATION_S
    ? Math.round(body.durationSeconds)
    : null

  const metadata: Record<string, unknown> = { negotiable }
  if (proposedFare !== null) metadata.proposedFare = proposedFare

  try {
    const ride = await maybeOne<RideRow>(
      `INSERT INTO rides
         (passenger_id, status,
          pickup_address, pickup_lat, pickup_lng,
          destination_address, destination_lat, destination_lng,
          distance_meters, duration_seconds,
          estimated_fare, payment_method, vehicle_type, metadata)
       VALUES ($1, 'requested',
               $2, $3, $4,
               $5, $6, $7,
               $8, $9,
               $10, $11, $12, $13)
       RETURNING *`,
      [
        auth.userId,
        pickup.address ?? null, pickup.lat, pickup.lng,
        destination.address ?? null, destination.lat, destination.lng,
        distanceMeters, durationSeconds,
        proposedFare, paymentMethod, vehicleType,
        JSON.stringify(metadata),
      ],
    )
    if (!ride) {
      return NextResponse.json({ success: false, error: 'insert_failed' }, { status: 500 })
    }

    // Auditoría del cambio de estado
    await query(
      `INSERT INTO auth_events (user_id, event_type, provider, metadata)
       VALUES ($1, 'ride_created', 'app', $2)`,
      [auth.userId, JSON.stringify({ rideId: ride.id, vehicleType, paymentMethod })],
    )

    // Ronda 208 CRÍTICO: fan-out FCM a drivers cercanos. Antes: solo el SSE
    // stream avisaba, así que drivers con la app en background NUNCA se
    // enteraban del ride → 90s de espera → pasajero cancela → churn.
    // notifyRideOffer inserta notifications + envía push FCM real. Fire &
    // forget: si FCM falla no rompe la respuesta al pasajero.
    try {
      const nearby = await findNearbyOnlineDrivers(pickup.lat!, pickup.lng!, 5, vehicleType)
      if (nearby.length > 0) {
        // Nombre del passenger para el push (opcional).
        const paxName = await maybeOne<{ name: string | null }>(
          `SELECT COALESCE(display_name, full_name) AS name FROM users WHERE id = $1`,
          [auth.userId],
        )
        void notifyRideOffer(nearby, {
          rideId: ride.id,
          pickupAddress: ride.pickup_address,
          destinationAddress: ride.destination_address,
          pickupLat: Number(ride.pickup_lat ?? 0),
          pickupLng: Number(ride.pickup_lng ?? 0),
          destinationLat: Number(ride.destination_lat ?? 0),
          destinationLng: Number(ride.destination_lng ?? 0),
          estimatedFare: proposedFare,
          passengerName: paxName?.name ?? null,
          passengerPhone: null,
          vehicleType,
          paymentMethod,
        })
      }
    } catch (fanoutErr) {
      console.warn('[rides POST] FCM fanout falló (best-effort):', fanoutErr)
    }

    return NextResponse.json({ success: true, ride: serializeRide(ride) }, { status: 201 })
  } catch (err) {
    console.error('[rides POST] error:', err)
    return NextResponse.json({ success: false, error: 'internal_error' }, { status: 500 })
  }
}

// ============================================================================
// GET — Listar viajes del user autenticado
// ============================================================================
export async function GET(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  const { searchParams } = new URL(req.url)
  const role = searchParams.get('role') ?? 'passenger'
  const status = searchParams.get('status')
  // Ronda 136: Number("abc") = NaN, Math.max(1, NaN) = NaN → offset NaN →
  // `LIMIT NaN OFFSET NaN` en SQL string-interpolado tira syntax error 500.
  // Usar Number.isFinite antes de aplicar bounds.
  const rawPage = Number(searchParams.get('page') ?? '1')
  const rawPageSize = Number(searchParams.get('pageSize') ?? '20')
  const page = Number.isFinite(rawPage) ? Math.max(1, Math.floor(rawPage)) : 1
  const pageSize = Number.isFinite(rawPageSize)
    ? Math.min(100, Math.max(1, Math.floor(rawPageSize)))
    : 20
  const offset = (page - 1) * pageSize

  if (role !== 'passenger' && role !== 'driver') {
    return NextResponse.json(
      { success: false, error: 'invalid_role', message: "role debe ser 'passenger' o 'driver'" },
      { status: 400 },
    )
  }

  const where: string[] = []
  const params: unknown[] = []

  params.push(auth.userId)
  if (role === 'passenger') {
    where.push(`passenger_id = $${params.length}`)
  } else {
    where.push(`driver_id = $${params.length}`)
  }

  if (status) {
    if (!ALLOWED_STATUSES.includes(status)) {
      return NextResponse.json(
        { success: false, error: 'invalid_status', message: `status debe ser uno de: ${ALLOWED_STATUSES.join(', ')}` },
        { status: 400 },
      )
    }
    params.push(status)
    where.push(`status = $${params.length}`)
  }

  const whereSql = `WHERE ${where.join(' AND ')}`
  const rows = await query<RideRow & { total: string }>(
    `SELECT *, COUNT(*) OVER() AS total
       FROM rides
       ${whereSql}
       ORDER BY created_at DESC
       LIMIT ${pageSize} OFFSET ${offset}`,
    params,
  )

  const total = rows.length ? Number(rows[0].total) : 0
  return NextResponse.json({
    success: true,
    rides: rows.map(serializeRide),
    page,
    pageSize,
    total,
    totalPages: Math.ceil(total / pageSize),
  })
}
