/**
 * POST /api/drivers/nearby
 * Auth: Bearer <access_token> (cualquier usuario autenticado)
 *
 * Busca conductores online cerca de un punto usando la fórmula haversine
 * definida en la migración 009. Devuelve los `limit` drivers más cercanos
 * (default 10) dentro del `radiusKm` (default 3), opcionalmente filtrados
 * por `vehicleType`. Solo cuenta drivers con `is_online=true` y con
 * `last_heartbeat` dentro de los últimos 2 minutos (para descartar los que
 * cerraron la app sin marcarse offline).
 *
 * Body:
 *   {
 *     latitude: number,
 *     longitude: number,
 *     radiusKm?: number   // default 3, max 25
 *     vehicleType?: string,
 *     limit?: number      // default 10, max 50
 *   }
 *
 * Respuesta:
 *   { success: true, drivers: [{ driverId, fullName, profilePhotoUrl,
 *       rating, totalTrips, latitude, longitude, heading, vehicleType,
 *       distanceKm, lastHeartbeat }] }
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { query } from '@/lib/db'

export const runtime = 'nodejs'

interface NearbyRow {
  driver_id: string
  full_name: string | null
  profile_photo_url: string | null
  rating: string | null
  total_trips: string
  latitude: string
  longitude: string
  heading: string | null
  vehicle_type: string | null
  distance_km: string
  last_heartbeat: Date | null
}

interface NearbyBody {
  latitude?: unknown
  longitude?: unknown
  radiusKm?: unknown
  vehicleType?: unknown
  limit?: unknown
}

function toNumber(v: unknown, fallback: number): number {
  if (v === undefined || v === null || v === '') return fallback
  const n = Number(v)
  return Number.isFinite(n) ? n : fallback
}

export async function POST(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  let body: NearbyBody = {}
  try {
    body = (await req.json()) as NearbyBody
  } catch {
    return NextResponse.json(
      { success: false, error: 'bad_json' },
      { status: 400 },
    )
  }

  const latitude = Number(body.latitude)
  const longitude = Number(body.longitude)
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    return NextResponse.json(
      { success: false, error: 'invalid_input', message: 'latitude/longitude requeridos' },
      { status: 400 },
    )
  }
  if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
    return NextResponse.json(
      { success: false, error: 'invalid_coordinates' },
      { status: 400 },
    )
  }

  const radiusKm = Math.min(25, Math.max(0.1, toNumber(body.radiusKm, 3)))
  const limit = Math.min(50, Math.max(1, Math.floor(toNumber(body.limit, 10))))
  const vehicleType =
    typeof body.vehicleType === 'string' && body.vehicleType.trim() !== ''
      ? body.vehicleType.trim()
      : null

  try {
    const rows = await query<NearbyRow>(
      `SELECT p.driver_id,
              u.full_name,
              u.profile_photo_url,
              (SELECT ROUND(AVG(r.driver_rating)::numeric, 2)::text
                 FROM rides r
                WHERE r.driver_id = p.driver_id
                  AND r.driver_rating IS NOT NULL) AS rating,
              (SELECT COUNT(*)::text
                 FROM rides r
                WHERE r.driver_id = p.driver_id
                  AND r.status = 'completed') AS total_trips,
              p.latitude,
              p.longitude,
              p.heading,
              p.vehicle_type,
              haversine_km(p.latitude, p.longitude, $1::numeric, $2::numeric)::text AS distance_km,
              p.last_heartbeat
         FROM driver_presence p
         JOIN users u ON u.id = p.driver_id
        WHERE p.is_online = true
          AND p.last_heartbeat > now() - interval '2 minutes'
          AND p.latitude IS NOT NULL
          AND p.longitude IS NOT NULL
          AND u.deleted_at IS NULL
          AND u.is_active = true
          AND u.suspended_at IS NULL
          AND ($3::text IS NULL OR p.vehicle_type = $3::text)
          AND haversine_km(p.latitude, p.longitude, $1::numeric, $2::numeric) <= $4::numeric
        ORDER BY distance_km ASC
        LIMIT $5`,
      [latitude, longitude, vehicleType, radiusKm, limit],
    )

    const drivers = rows.map((r) => ({
      driverId: r.driver_id,
      fullName: r.full_name,
      profilePhotoUrl: r.profile_photo_url,
      rating: r.rating !== null ? Number(r.rating) : null,
      totalTrips: Number(r.total_trips),
      latitude: Number(r.latitude),
      longitude: Number(r.longitude),
      heading: r.heading !== null ? Number(r.heading) : null,
      vehicleType: r.vehicle_type,
      distanceKm: Number(r.distance_km),
      lastHeartbeat: r.last_heartbeat,
    }))

    return NextResponse.json({ success: true, drivers })
  } catch (err) {
    console.error('[drivers/nearby] error:', err)
    return NextResponse.json(
      { success: false, error: 'server_error' },
      { status: 500 },
    )
  }
}
