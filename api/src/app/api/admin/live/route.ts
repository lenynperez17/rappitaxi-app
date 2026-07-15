/**
 * GET /api/admin/live — snapshot en tiempo real para el panel:
 *   - activeTrips: viajes en curso (requested/searching/accepted/on_way/arrived/in_progress)
 *   - onlineDrivers: conductores con is_online=true y heartbeat reciente
 *   - offlineDrivers: conductores desconectados recientemente (última hora)
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAdmin } from '@/lib/admin-middleware'
import { query } from '@/lib/db'

export const runtime = 'nodejs'

// Throttle in-memory del janitor (Ronda 19 MEDIUM#4). Es process-local — con
// múltiples workers PM2 cada uno tiene su propio contador, pero el impacto
// combinado sigue siendo N janitor-runs por minuto en vez de N por request.
const JANITOR_INTERVAL_MS = 60_000
let LAST_JANITOR_RUN = 0

interface ActiveTripRow {
  id: string
  status: string
  pickup_address: string | null
  destination_address: string | null
  pickup_lat: string | null
  pickup_lng: string | null
  destination_lat: string | null
  destination_lng: string | null
  estimated_fare: string | null
  created_at: Date
  accepted_at: Date | null
  passenger_id: string | null
  passenger_name: string | null
  passenger_phone: string | null
  driver_id: string | null
  driver_name: string | null
  driver_phone: string | null
  driver_lat: string | null
  driver_lng: string | null
}

interface DriverRow {
  driver_id: string
  full_name: string | null
  phone: string | null
  profile_photo_url: string | null
  rating: string | null
  is_online: boolean
  latitude: string | null
  longitude: string | null
  vehicle_type: string | null
  active_ride_id: string | null
  last_heartbeat: Date | null
  minutes_since_heartbeat: string | null
}

export async function GET(req: NextRequest) {
  const auth = await requireAdmin(req)
  if (!auth.ok) return auth.response

  // 0. Auto-cleanup zombie state. Throttled a 1 vez cada 60s (Ronda 19 MEDIUM#4):
  //    antes cada GET del panel disparaba 3 UPDATEs sobre rides + driver_presence
  //    → row lock contention con endpoints hot (/rides/accept, /presence). Con N
  //    admins polling cada 3-5s la contención era permanente. In-memory throttle
  //    (process-level, aceptable porque el janitor real es idempotente y sirve
  //    solo como fallback UX del panel).
  const now = Date.now()
  if (now - LAST_JANITOR_RUN > JANITOR_INTERVAL_MS) {
    LAST_JANITOR_RUN = now
    await query(
      `UPDATE rides
          SET status = 'cancelled',
              cancelled_by = 'system',
              cancelled_reason = 'timeout_24h_stale',
              completed_at = COALESCE(completed_at, NOW())
        WHERE status IN ('requested','searching','accepted','on_way','arrived','in_progress')
          AND created_at < NOW() - INTERVAL '24 hours'`,
    )
    await query(
      `UPDATE driver_presence
          SET active_ride_id = NULL
        WHERE active_ride_id IS NOT NULL
          AND active_ride_id NOT IN (
            SELECT id FROM rides
             WHERE status IN ('accepted','on_way','arrived','in_progress')
          )`,
    )
    await query(
      `UPDATE driver_presence
          SET is_online = false
        WHERE is_online = true
          AND last_heartbeat IS NOT NULL
          AND last_heartbeat < NOW() - INTERVAL '5 minutes'`,
    )
  }

  // 1. Viajes activos (no completados ni cancelados) — con datos del pasajero, conductor
  //    y posición actual del conductor si está online.
  const activeTrips = await query<ActiveTripRow>(
    `SELECT r.id, r.status,
            r.pickup_address, r.destination_address,
            r.pickup_lat, r.pickup_lng, r.destination_lat, r.destination_lng,
            r.estimated_fare, r.created_at, r.accepted_at,
            r.passenger_id, p.full_name AS passenger_name, p.phone AS passenger_phone,
            r.driver_id, d.full_name AS driver_name, d.phone AS driver_phone,
            dp.latitude AS driver_lat, dp.longitude AS driver_lng
       FROM rides r
       LEFT JOIN users p ON p.id = r.passenger_id
       LEFT JOIN users d ON d.id = r.driver_id
       LEFT JOIN driver_presence dp ON dp.driver_id = r.driver_id
      WHERE r.status IN ('requested', 'searching', 'accepted', 'on_way', 'arrived', 'in_progress')
      ORDER BY r.created_at DESC
      LIMIT 200`,
  )

  // 2. Conductores online: is_online=true y heartbeat en últimos 5 min
  // Ronda 19 MEDIUM#3: reemplazado subquery correlacionada (`SELECT AVG(stars)
  // FROM ride_ratings ...`) — hacía N+1 hasta 700 queries por poll del panel.
  // Ahora LEFT JOIN LATERAL con LIMIT 1 (o mejor, precompute) sobre una CTE
  // agregada una sola vez.
  const onlineDrivers = await query<DriverRow>(
    `WITH driver_ratings AS (
       SELECT rated_user_id, AVG(stars) AS avg_stars
         FROM ride_ratings
        WHERE role = 'driver'
        GROUP BY rated_user_id
     )
     SELECT dp.driver_id, u.full_name, u.phone, u.profile_photo_url,
            dr.avg_stars AS rating,
            dp.is_online, dp.latitude, dp.longitude, dp.vehicle_type,
            dp.active_ride_id, dp.last_heartbeat,
            NULL AS minutes_since_heartbeat
       FROM driver_presence dp
       JOIN users u ON u.id = dp.driver_id
       LEFT JOIN driver_ratings dr ON dr.rated_user_id = u.id
      WHERE dp.is_online = true
        AND (dp.last_heartbeat IS NULL OR dp.last_heartbeat > NOW() - INTERVAL '5 minutes')
        AND u.deleted_at IS NULL
      ORDER BY dp.last_heartbeat DESC NULLS LAST
      LIMIT 500`,
  )

  // 3. Conductores offline: TODOS los drivers/dual activos que no están online.
  // Mismo fix N+1 aplicado.
  const offlineDrivers = await query<DriverRow>(
    `WITH driver_ratings AS (
       SELECT rated_user_id, AVG(stars) AS avg_stars
         FROM ride_ratings
        WHERE role = 'driver'
        GROUP BY rated_user_id
     )
     SELECT u.id AS driver_id, u.full_name, u.phone, u.profile_photo_url,
            dr.avg_stars AS rating,
            COALESCE(dp.is_online, false) AS is_online,
            dp.latitude, dp.longitude, dp.vehicle_type,
            dp.active_ride_id, dp.last_heartbeat,
            CASE WHEN dp.last_heartbeat IS NULL THEN NULL
                 ELSE EXTRACT(EPOCH FROM (NOW() - dp.last_heartbeat)) / 60
            END AS minutes_since_heartbeat
       FROM users u
       LEFT JOIN driver_presence dp ON dp.driver_id = u.id
       LEFT JOIN driver_ratings dr ON dr.rated_user_id = u.id
      WHERE u.user_type IN ('driver', 'dual')
        AND u.deleted_at IS NULL
        AND u.is_active = true
        AND (dp.is_online IS NULL OR dp.is_online = false)
      ORDER BY dp.last_heartbeat DESC NULLS LAST
      LIMIT 200`,
  )

  const mapDriver = (r: DriverRow) => ({
    driverId: r.driver_id,
    fullName: r.full_name,
    phone: r.phone,
    profilePhotoUrl: r.profile_photo_url,
    rating: r.rating ? Number(r.rating) : null,
    latitude: r.latitude ? Number(r.latitude) : null,
    longitude: r.longitude ? Number(r.longitude) : null,
    vehicleType: r.vehicle_type,
    activeRideId: r.active_ride_id,
    lastHeartbeat: r.last_heartbeat,
    minutesSinceHeartbeat: r.minutes_since_heartbeat ? Number(r.minutes_since_heartbeat) : null,
  })

  return NextResponse.json({
    success: true,
    activeTrips: activeTrips.map((r) => ({
      id: r.id,
      status: r.status,
      pickupAddress: r.pickup_address,
      destinationAddress: r.destination_address,
      pickupLat: r.pickup_lat ? Number(r.pickup_lat) : null,
      pickupLng: r.pickup_lng ? Number(r.pickup_lng) : null,
      destinationLat: r.destination_lat ? Number(r.destination_lat) : null,
      destinationLng: r.destination_lng ? Number(r.destination_lng) : null,
      estimatedFare: r.estimated_fare ? Number(r.estimated_fare) : null,
      createdAt: r.created_at,
      acceptedAt: r.accepted_at,
      passenger: r.passenger_id
        ? { id: r.passenger_id, fullName: r.passenger_name, phone: r.passenger_phone }
        : null,
      driver: r.driver_id
        ? {
            id: r.driver_id,
            fullName: r.driver_name,
            phone: r.driver_phone,
            latitude: r.driver_lat ? Number(r.driver_lat) : null,
            longitude: r.driver_lng ? Number(r.driver_lng) : null,
          }
        : null,
    })),
    onlineDrivers: onlineDrivers.map(mapDriver),
    offlineDrivers: offlineDrivers.map(mapDriver),
    counts: {
      activeTrips: activeTrips.length,
      onlineDrivers: onlineDrivers.length,
      offlineDrivers: offlineDrivers.length,
    },
  })
}
