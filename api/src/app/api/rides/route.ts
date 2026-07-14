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

  if (!pickup || typeof pickup.lat !== 'number' || typeof pickup.lng !== 'number') {
    return NextResponse.json(
      { success: false, error: 'invalid_pickup', message: 'pickup.lat y pickup.lng son obligatorios' },
      { status: 400 },
    )
  }
  if (!destination || typeof destination.lat !== 'number' || typeof destination.lng !== 'number') {
    return NextResponse.json(
      { success: false, error: 'invalid_destination', message: 'destination.lat y destination.lng son obligatorios' },
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
  const page = Math.max(1, Number(searchParams.get('page') ?? '1'))
  const pageSize = Math.min(100, Math.max(1, Number(searchParams.get('pageSize') ?? '20')))
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
