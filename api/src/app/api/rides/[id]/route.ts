/**
 * GET   /api/rides/:id
 *   Detalle de un viaje. auth.userId debe ser el passenger o el driver.
 *   Incluye joins para passenger_name, driver_name, driver_phone, driver_photo_url.
 *
 * PATCH /api/rides/:id
 *   Actualiza sólo campos permitidos (destination durante negotiation, paymentMethod).
 *   Solo el passenger antes de accept (status in ('requested','searching')).
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { maybeOne, query } from '@/lib/db'

export const runtime = 'nodejs'

const ALLOWED_PAYMENT_METHODS = ['cash', 'mercadopago', 'wallet', 'yape', 'plin', 'card']

interface RideDetailRow {
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
  passenger_name: string | null
  passenger_phone: string | null
  passenger_photo_url: string | null
  driver_name: string | null
  driver_phone: string | null
  driver_photo_url: string | null
}

function serializeRideDetail(r: RideDetailRow) {
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
    passengerName: r.passenger_name,
    passengerPhone: r.passenger_phone,
    passengerPhotoUrl: r.passenger_photo_url,
    driverName: r.driver_name,
    driverPhone: r.driver_phone,
    driverPhotoUrl: r.driver_photo_url,
  }
}

// ============================================================================
// GET — Detalle
// ============================================================================
export async function GET(req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response
  const { id } = await ctx.params

  const ride = await maybeOne<RideDetailRow>(
    `SELECT r.*,
            p.full_name AS passenger_name,
            p.phone     AS passenger_phone,
            p.profile_photo_url AS passenger_photo_url,
            d.full_name AS driver_name,
            d.phone     AS driver_phone,
            d.profile_photo_url AS driver_photo_url
       FROM rides r
       LEFT JOIN users p ON p.id = r.passenger_id
       LEFT JOIN users d ON d.id = r.driver_id
       WHERE r.id = $1`,
    [id],
  )
  if (!ride) {
    return NextResponse.json({ success: false, error: 'not_found' }, { status: 404 })
  }
  if (ride.passenger_id !== auth.userId && ride.driver_id !== auth.userId) {
    return NextResponse.json({ success: false, error: 'forbidden' }, { status: 403 })
  }

  return NextResponse.json({ success: true, ride: serializeRideDetail(ride) })
}

// ============================================================================
// PATCH — passenger edita antes de accept
// ============================================================================
interface PointInput {
  lat?: number
  lng?: number
  address?: string
}

export async function PATCH(req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response
  const { id } = await ctx.params

  let body: {
    destination?: PointInput
    paymentMethod?: string
  } = {}
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ success: false, error: 'bad_json' }, { status: 400 })
  }

  const ride = await maybeOne<{ passenger_id: string | null; status: string }>(
    'SELECT passenger_id, status FROM rides WHERE id = $1',
    [id],
  )
  if (!ride) {
    return NextResponse.json({ success: false, error: 'not_found' }, { status: 404 })
  }
  if (ride.passenger_id !== auth.userId) {
    return NextResponse.json({ success: false, error: 'forbidden' }, { status: 403 })
  }
  if (ride.status !== 'requested' && ride.status !== 'searching') {
    return NextResponse.json(
      { success: false, error: 'invalid_status', message: 'Solo se puede editar antes de aceptar' },
      { status: 409 },
    )
  }

  const sets: string[] = []
  const params: unknown[] = []

  if (body.destination) {
    if (typeof body.destination.lat !== 'number' || typeof body.destination.lng !== 'number') {
      return NextResponse.json(
        { success: false, error: 'invalid_destination', message: 'destination.lat y destination.lng son obligatorios' },
        { status: 400 },
      )
    }
    params.push(body.destination.address ?? null)
    sets.push(`destination_address = $${params.length}`)
    params.push(body.destination.lat)
    sets.push(`destination_lat = $${params.length}`)
    params.push(body.destination.lng)
    sets.push(`destination_lng = $${params.length}`)
    // Ronda 33 Bug#2: invalidar estimated_fare + distance_meters cuando cambia
    // el destino. Sin esto, ofertas ya emitidas siguen usando el fare del
    // destino viejo — passenger termina cobrando por A un viaje a B (30 km
    // más lejos por el mismo precio).
    sets.push(`estimated_fare = NULL`)
    sets.push(`distance_meters = NULL`)
    sets.push(`duration_seconds = NULL`)
    // Ademas invalidar ofertas pending del destino viejo
    sets.push(`status = CASE WHEN status = 'searching' THEN 'requested' ELSE status END`)
  }

  if (body.paymentMethod !== undefined) {
    const pm = body.paymentMethod.trim()
    if (!ALLOWED_PAYMENT_METHODS.includes(pm)) {
      return NextResponse.json(
        { success: false, error: 'invalid_payment_method', message: `paymentMethod debe ser uno de: ${ALLOWED_PAYMENT_METHODS.join(', ')}` },
        { status: 400 },
      )
    }
    params.push(pm)
    sets.push(`payment_method = $${params.length}`)
  }

  if (sets.length === 0) {
    return NextResponse.json({ success: false, error: 'no_changes' }, { status: 400 })
  }

  params.push(id)
  await query(
    `UPDATE rides SET ${sets.join(', ')} WHERE id = $${params.length}`,
    params,
  )

  // Si cambio destination, invalidar ride_offers pendientes (Ronda 33 Bug#2 fu)
  if (body.destination) {
    await query(
      `UPDATE ride_offers SET status = 'expired', responded_at = now()
        WHERE ride_id = $1 AND status = 'pending'`,
      [id],
    )
  }

  const updated = await maybeOne<RideDetailRow>(
    `SELECT r.*,
            p.full_name AS passenger_name,
            p.phone     AS passenger_phone,
            p.profile_photo_url AS passenger_photo_url,
            d.full_name AS driver_name,
            d.phone     AS driver_phone,
            d.profile_photo_url AS driver_photo_url
       FROM rides r
       LEFT JOIN users p ON p.id = r.passenger_id
       LEFT JOIN users d ON d.id = r.driver_id
       WHERE r.id = $1`,
    [id],
  )
  if (!updated) {
    return NextResponse.json({ success: false, error: 'not_found' }, { status: 404 })
  }
  return NextResponse.json({ success: true, ride: serializeRideDetail(updated) })
}
