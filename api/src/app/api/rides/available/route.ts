/**
 * GET /api/rides/available?lat=&lng=&radiusKm=5&limit=20&vehicleType=
 *   Driver ve viajes disponibles cerca.
 *   - SELECT rides con status='requested' o 'searching'
 *   - Filtro por haversine_km(pickup_lat, pickup_lng, $lat, $lng) <= $radiusKm
 *   - Ordenar por distancia ASC
 *   - Excluir viajes ya rechazados por este driver (ride_offers status='rejected')
 *   - Incluir passenger_name
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { maybeOne, query } from '@/lib/db'

export const runtime = 'nodejs'

interface AvailableRideRow {
  id: string
  passenger_id: string | null
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
  payment_method: string | null
  vehicle_type: string | null
  created_at: Date
  passenger_name: string | null
  passenger_photo_url: string | null
  distance_km: string
}

export async function GET(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  const { searchParams } = new URL(req.url)
  const lat = Number(searchParams.get('lat'))
  const lng = Number(searchParams.get('lng'))
  // Ronda 33 Bug#1: NaN-safe. Sin fallback, Number('abc')=NaN se propagaba
  // como $3::numeric al haversine → Postgres 22P02 → 500 en vez de 400.
  const radiusRaw = Number(searchParams.get('radiusKm') ?? '5')
  const radiusKm = Number.isFinite(radiusRaw) ? Math.min(50, Math.max(0.1, radiusRaw)) : 5
  const limitRaw = Number(searchParams.get('limit') ?? '20')
  const limit = Number.isFinite(limitRaw) ? Math.min(100, Math.max(1, limitRaw)) : 20
  const vehicleType = searchParams.get('vehicleType')

  if (!isFinite(lat) || !isFinite(lng) || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
    return NextResponse.json(
      { success: false, error: 'invalid_coordinates', message: 'lat y lng son obligatorios y deben ser válidos' },
      { status: 400 },
    )
  }

  // Debe ser driver o dual
  const driver = await maybeOne<{ user_type: string }>(
    'SELECT user_type FROM users WHERE id = $1',
    [auth.userId],
  )
  if (!driver || (driver.user_type !== 'driver' && driver.user_type !== 'dual')) {
    return NextResponse.json(
      { success: false, error: 'forbidden', message: 'Solo un conductor puede ver viajes disponibles' },
      { status: 403 },
    )
  }

  const params: unknown[] = [lat, lng, radiusKm, auth.userId, limit]
  let vehicleFilter = ''
  if (vehicleType) {
    params.push(vehicleType)
    vehicleFilter = `AND r.vehicle_type = $${params.length}`
  }

  const rows = await query<AvailableRideRow>(
    `SELECT r.id,
            r.passenger_id,
            r.status,
            r.pickup_address, r.pickup_lat, r.pickup_lng,
            r.destination_address, r.destination_lat, r.destination_lng,
            r.distance_meters, r.duration_seconds,
            r.estimated_fare, r.payment_method, r.vehicle_type,
            r.created_at,
            p.full_name AS passenger_name,
            p.profile_photo_url AS passenger_photo_url,
            haversine_km(r.pickup_lat, r.pickup_lng, $1::numeric, $2::numeric)::text AS distance_km
       FROM rides r
       LEFT JOIN users p ON p.id = r.passenger_id
      WHERE r.status IN ('requested','searching')
        AND r.driver_id IS NULL
        AND r.pickup_lat IS NOT NULL
        AND r.pickup_lng IS NOT NULL
        AND haversine_km(r.pickup_lat, r.pickup_lng, $1::numeric, $2::numeric) <= $3::numeric
        AND NOT EXISTS (
              SELECT 1 FROM ride_offers o
               WHERE o.ride_id = r.id
                 AND o.driver_id = $4
                 AND o.status = 'rejected'
        )
        ${vehicleFilter}
      ORDER BY haversine_km(r.pickup_lat, r.pickup_lng, $1::numeric, $2::numeric) ASC
      LIMIT $5`,
    params,
  )

  return NextResponse.json({
    success: true,
    rides: rows.map((r) => ({
      id: r.id,
      passengerId: r.passenger_id,
      passengerName: r.passenger_name,
      passengerPhotoUrl: r.passenger_photo_url,
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
      paymentMethod: r.payment_method,
      vehicleType: r.vehicle_type,
      distanceKm: Number(r.distance_km),
      createdAt: r.created_at,
    })),
    center: { lat, lng },
    radiusKm,
    total: rows.length,
  })
}
