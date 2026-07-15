/**
 * GET  /api/admin/trips?status=&passengerId=&driverId=&search=&fromDate=&toDate=
 * POST /api/admin/trips — crea un viaje manualmente desde el admin.
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAdmin } from '@/lib/admin-middleware'
import { query, maybeOne, tx } from '@/lib/db'
import { findNearbyOnlineDrivers, notifyRideOffer } from '@/lib/notify-drivers'

export const runtime = 'nodejs'

interface RideRow {
  id: string
  passenger_id: string | null
  driver_id: string | null
  status: string
  pickup_address: string | null
  destination_address: string | null
  distance_meters: number | null
  duration_seconds: number | null
  estimated_fare: string | null
  final_fare: string | null
  payment_method: string | null
  vehicle_type: string | null
  passenger_rating: string | null
  driver_rating: string | null
  created_at: Date
  accepted_at: Date | null
  completed_at: Date | null
  cancelled_by: string | null
  cancelled_reason: string | null
  passenger_name: string | null
  passenger_phone: string | null
  driver_name: string | null
  driver_phone: string | null
  total: string
}

export async function GET(req: NextRequest) {
  const auth = await requireAdmin(req)
  if (!auth.ok) return auth.response

  const { searchParams } = new URL(req.url)
  const status = searchParams.get('status')
  const passengerId = searchParams.get('passengerId')
  const driverId = searchParams.get('driverId')
  const search = (searchParams.get('search') ?? '').trim().toLowerCase()
  const fromDate = searchParams.get('fromDate')
  const toDate = searchParams.get('toDate')
  // Ronda 27 Bug#1: Number('abc')=NaN, Math.max(1, NaN)=NaN → LIMIT NaN
  // → Postgres syntax error → 500. Guardar con isFinite antes de propagar.
  const pageRaw = Number(searchParams.get('page') ?? '1')
  const page = Number.isFinite(pageRaw) ? Math.max(1, pageRaw) : 1
  const pageSizeRaw = Number(searchParams.get('pageSize') ?? '50')
  const pageSize = Number.isFinite(pageSizeRaw) ? Math.min(200, Math.max(1, pageSizeRaw)) : 50
  const offset = (page - 1) * pageSize

  const where: string[] = []
  const params: unknown[] = []

  if (status) { params.push(status); where.push(`r.status = $${params.length}`) }
  if (passengerId) { params.push(passengerId); where.push(`r.passenger_id = $${params.length}`) }
  if (driverId) { params.push(driverId); where.push(`r.driver_id = $${params.length}`) }
  if (fromDate) { params.push(fromDate); where.push(`r.created_at >= $${params.length}`) }
  if (toDate) { params.push(toDate); where.push(`r.created_at <= $${params.length}`) }
  if (search) {
    params.push(`%${search}%`)
    where.push(`(LOWER(r.pickup_address) LIKE $${params.length} OR LOWER(r.destination_address) LIKE $${params.length})`)
  }

  const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : ''
  const rows = await query<RideRow>(
    `SELECT r.*, p.full_name AS passenger_name, p.phone AS passenger_phone,
            d.full_name AS driver_name, d.phone AS driver_phone,
            COUNT(*) OVER() AS total
       FROM rides r
       LEFT JOIN users p ON p.id = r.passenger_id
       LEFT JOIN users d ON d.id = r.driver_id
       ${whereSql}
       ORDER BY r.created_at DESC
       LIMIT ${pageSize} OFFSET ${offset}`,
    params,
  )

  const total = rows.length ? Number(rows[0].total) : 0
  return NextResponse.json({
    success: true,
    trips: rows.map((r) => ({
      id: r.id,
      passengerId: r.passenger_id,
      driverId: r.driver_id,
      passengerName: r.passenger_name,
      passengerPhone: r.passenger_phone,
      driverName: r.driver_name,
      driverPhone: r.driver_phone,
      status: r.status,
      pickupAddress: r.pickup_address,
      destinationAddress: r.destination_address,
      distanceMeters: r.distance_meters,
      durationSeconds: r.duration_seconds,
      estimatedFare: r.estimated_fare ? Number(r.estimated_fare) : null,
      finalFare: r.final_fare ? Number(r.final_fare) : null,
      paymentMethod: r.payment_method,
      vehicleType: r.vehicle_type,
      passengerRating: r.passenger_rating ? Number(r.passenger_rating) : null,
      driverRating: r.driver_rating ? Number(r.driver_rating) : null,
      cancelledBy: r.cancelled_by,
      cancelledReason: r.cancelled_reason,
      createdAt: r.created_at,
      acceptedAt: r.accepted_at,
      completedAt: r.completed_at,
    })),
    page, pageSize, total, totalPages: Math.ceil(total / pageSize),
  })
}

/**
 * POST /api/admin/trips — crea un viaje manualmente.
 * Body: {
 *   passengerId, driverId?, pickupAddress, pickupLat, pickupLng,
 *   destinationAddress, destinationLat, destinationLng,
 *   estimatedFare?, vehicleType?, paymentMethod?, status?
 * }
 */
export async function POST(req: NextRequest) {
  const auth = await requireAdmin(req)
  if (!auth.ok) return auth.response

  let body: {
    passengerId?: string
    driverId?: string | null
    pickupAddress?: string
    pickupLat?: number
    pickupLng?: number
    destinationAddress?: string
    destinationLat?: number
    destinationLng?: number
    estimatedFare?: number
    vehicleType?: string
    paymentMethod?: string
    status?: string
  } = {}
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ success: false, error: 'bad_json' }, { status: 400 })
  }

  if (!body.passengerId) {
    return NextResponse.json({ success: false, error: 'passenger_id_required' }, { status: 400 })
  }
  if (!body.pickupAddress || !body.destinationAddress) {
    return NextResponse.json({ success: false, error: 'addresses_required' }, { status: 400 })
  }
  const inRange = (lat: number, lng: number) =>
    lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180
  if (typeof body.pickupLat !== 'number' || typeof body.pickupLng !== 'number'
      || !inRange(body.pickupLat, body.pickupLng)) {
    return NextResponse.json({ success: false, error: 'pickup_coords_invalid' }, { status: 400 })
  }
  if (typeof body.destinationLat !== 'number' || typeof body.destinationLng !== 'number'
      || !inRange(body.destinationLat, body.destinationLng)) {
    return NextResponse.json({ success: false, error: 'destination_coords_invalid' }, { status: 400 })
  }
  if (body.estimatedFare != null &&
      (typeof body.estimatedFare !== 'number' || body.estimatedFare <= 0 || body.estimatedFare > 10000)) {
    return NextResponse.json({ success: false, error: 'fare_invalid' }, { status: 400 })
  }

  // Enum canónico de vehicleType (alineado con /api/rides). Aceptamos aliases
  // legacy del panel viejo por compatibilidad.
  const VEHICLE_TYPE_ALIASES: Record<string, string> = {
    sedan: 'car', car: 'car',
    moto: 'moto', motorcycle: 'moto',
    mototaxi: 'moto_taxi', moto_taxi: 'moto_taxi',
    taxi: 'taxi',
    van: 'van',
    truck: 'truck', flete: 'truck',
    bicycle: 'bicycle',
  }
  const rawVehicleType = (body.vehicleType ?? 'car').toLowerCase()
  const canonicalVehicleType = VEHICLE_TYPE_ALIASES[rawVehicleType]
  if (!canonicalVehicleType) {
    return NextResponse.json({ success: false, error: 'invalid_vehicle_type' }, { status: 400 })
  }

  const allowedStatuses = new Set([
    'requested', 'searching', 'accepted', 'on_way',
    'arrived', 'in_progress', 'completed', 'cancelled', 'no_drivers',
  ])
  const status = body.status && allowedStatuses.has(body.status)
    ? body.status
    : (body.driverId ? 'accepted' : 'requested')

  // Verificar que el pasajero existe y no está eliminado
  const passenger = await maybeOne<{ id: string }>(
    `SELECT id FROM users WHERE id = $1 AND deleted_at IS NULL AND user_type IN ('passenger', 'dual')`,
    [body.passengerId],
  )
  if (!passenger) {
    return NextResponse.json({ success: false, error: 'passenger_not_found' }, { status: 404 })
  }

  // Verificar conductor si se pasó (mismo user no puede ser pasajero+conductor)
  if (body.driverId) {
    if (body.driverId === body.passengerId) {
      return NextResponse.json({ success: false, error: 'passenger_is_driver' }, { status: 400 })
    }
    const driver = await maybeOne<{ id: string }>(
      `SELECT id FROM users WHERE id = $1 AND deleted_at IS NULL AND user_type IN ('driver', 'dual')`,
      [body.driverId],
    )
    if (!driver) {
      return NextResponse.json({ success: false, error: 'driver_not_found' }, { status: 404 })
    }
  }

  // INSERT ride + UPDATE driver_presence en UNA transacción — garantiza
  // que si el driver ya tiene otro `active_ride_id`, todo el POST se
  // rechace (con 409) sin dejar el ride huérfano.
  let created: { id: string; created_at: Date }
  try {
    created = await tx(async (client) => {
      const insertRes = await client.query<{ id: string; created_at: Date }>(
        `INSERT INTO rides (
           passenger_id, driver_id, status,
           pickup_address, pickup_lat, pickup_lng,
           destination_address, destination_lat, destination_lng,
           estimated_fare, vehicle_type, payment_method,
           accepted_at, metadata
         ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
         RETURNING id, created_at`,
        [
          body.passengerId, body.driverId ?? null, status,
          body.pickupAddress, body.pickupLat, body.pickupLng,
          body.destinationAddress, body.destinationLat, body.destinationLng,
          body.estimatedFare ?? null, canonicalVehicleType,
          body.paymentMethod ?? 'cash',
          body.driverId ? new Date() : null,
          JSON.stringify({ createdBy: 'admin', adminId: auth.userId }),
        ],
      )
      const newRide = insertRes.rows[0]!
      if (body.driverId) {
        // Solo marcar activo si NO tiene otro ride activo. Si otro admin ya
        // asignó al driver, esto devuelve 0 filas y hacemos rollback (throw).
        const upd = await client.query(
          `UPDATE driver_presence
              SET active_ride_id = $1
            WHERE driver_id = $2
              AND (active_ride_id IS NULL OR active_ride_id = $1)`,
          [newRide.id, body.driverId],
        )
        if ((upd.rowCount ?? 0) === 0) {
          throw new Error('DRIVER_BUSY')
        }
      }
      return newRide
    })
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err)
    if (msg === 'DRIVER_BUSY') {
      return NextResponse.json(
        { success: false, error: 'driver_busy', message: 'El conductor ya tiene un viaje activo.' },
        { status: 409 },
      )
    }
    console.error('[admin/trips POST] insert failed:', msg)
    return NextResponse.json({ success: false, error: 'insert_failed' }, { status: 500 })
  }

  // Fanout: notificar a los conductores que corresponda.
  //   - Si el admin asignó un `driverId`: solo a ese conductor.
  //   - Si NO: broadcast a los conductores online en radio 5km del pickup.
  let notified = { notified: 0, fcmSent: 0 }
  try {
    const passenger = await maybeOne<{ full_name: string | null; phone: string | null }>(
      `SELECT full_name, phone FROM users WHERE id = $1`,
      [body.passengerId],
    )
    const targetDrivers = body.driverId
      ? [body.driverId]
      : await findNearbyOnlineDrivers(body.pickupLat, body.pickupLng, 5, canonicalVehicleType)
    if (targetDrivers.length > 0) {
      notified = await notifyRideOffer(targetDrivers, {
        rideId: created.id,
        pickupAddress: body.pickupAddress,
        destinationAddress: body.destinationAddress,
        pickupLat: body.pickupLat,
        pickupLng: body.pickupLng,
        destinationLat: body.destinationLat,
        destinationLng: body.destinationLng,
        estimatedFare: body.estimatedFare ?? null,
        passengerName: passenger?.full_name ?? null,
        passengerPhone: passenger?.phone ?? null,
        vehicleType: canonicalVehicleType,
        paymentMethod: body.paymentMethod ?? null,
      })
    }
  } catch (err) {
    console.warn('[admin/trips POST] fanout falló (best-effort):', err instanceof Error ? err.message : err)
  }

  return NextResponse.json({
    success: true,
    trip: { id: created.id, status, createdAt: created.created_at },
    fanout: notified,
  }, { status: 201 })
}
