/**
 * /api/drivers/status
 * Auth: Bearer <access_token> (driver o dual)
 *
 * PUT: cambia el estado online/offline del driver.
 *      Body: { isOnline: boolean }
 * GET: devuelve el estado actual del propio driver.
 *
 * Al cambiar de estado registramos un `auth_events` de tipo `driver_online` /
 * `driver_offline` para auditoría, y una `notifications` para el propio driver
 * confirmándole el cambio (útil como historial cuando abra la app).
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth, getClientIp } from '@/lib/auth-middleware'
import { maybeOne, tx } from '@/lib/db'

export const runtime = 'nodejs'

interface UserTypeRow {
  user_type: string
}

interface PresenceRow {
  driver_id: string
  is_online: boolean
  latitude: string | null
  longitude: string | null
  heading: string | null
  accuracy_meters: string | null
  speed_kmh: string | null
  vehicle_type: string | null
  active_ride_id: string | null
  last_heartbeat: Date | null
  updated_at: Date
}

interface StatusBody {
  isOnline?: unknown
}

export async function PUT(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response
  const driverId = auth.userId

  let body: StatusBody = {}
  try {
    body = (await req.json()) as StatusBody
  } catch {
    return NextResponse.json(
      { success: false, error: 'bad_json' },
      { status: 400 },
    )
  }

  if (typeof body.isOnline !== 'boolean') {
    return NextResponse.json(
      { success: false, error: 'invalid_input', message: 'isOnline debe ser booleano' },
      { status: 400 },
    )
  }
  const isOnline = body.isOnline

  const user = await maybeOne<UserTypeRow>(
    'SELECT user_type FROM users WHERE id = $1',
    [driverId],
  )
  if (!user) {
    return NextResponse.json(
      { success: false, error: 'user_not_found' },
      { status: 404 },
    )
  }
  if (user.user_type !== 'driver' && user.user_type !== 'dual') {
    return NextResponse.json(
      { success: false, error: 'forbidden', message: 'Solo drivers' },
      { status: 403 },
    )
  }

  const ip = getClientIp(req)
  const ua = req.headers.get('user-agent') ?? null

  try {
    await tx(async (client) => {
      // UPSERT del estado
      await client.query(
        `INSERT INTO driver_presence (driver_id, is_online, updated_at)
         VALUES ($1, $2, now())
         ON CONFLICT (driver_id) DO UPDATE SET
           is_online = EXCLUDED.is_online,
           updated_at = now()`,
        [driverId, isOnline],
      )

      // Auditoría
      await client.query(
        `INSERT INTO auth_events (user_id, event_type, provider, ip_address, user_agent, metadata)
         VALUES ($1, $2, $3, $4::inet, $5, $6::jsonb)`,
        [
          driverId,
          isOnline ? 'driver_online' : 'driver_offline',
          'driver_status',
          ip,
          ua,
          JSON.stringify({ isOnline }),
        ],
      )

      // Notificación in-app para el propio driver
      await client.query(
        `INSERT INTO notifications (user_id, type, title, body, data)
         VALUES ($1, $2, $3, $4, $5::jsonb)`,
        [
          driverId,
          isOnline ? 'driver_online' : 'driver_offline',
          isOnline ? 'Estás en línea' : 'Estás fuera de línea',
          isOnline
            ? 'Comenzarás a recibir solicitudes de viaje.'
            : 'Dejarás de recibir solicitudes hasta que vuelvas a activarte.',
          JSON.stringify({ isOnline }),
        ],
      )
    })

    return NextResponse.json({
      success: true,
      driver_id: driverId,
      is_online: isOnline,
    })
  } catch (err) {
    console.error('[drivers/status PUT] error:', err)
    return NextResponse.json(
      { success: false, error: 'server_error' },
      { status: 500 },
    )
  }
}

export async function GET(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response
  const driverId = auth.userId

  const row = await maybeOne<PresenceRow>(
    `SELECT driver_id, is_online, latitude, longitude, heading,
            accuracy_meters, speed_kmh, vehicle_type, active_ride_id,
            last_heartbeat, updated_at
       FROM driver_presence
      WHERE driver_id = $1`,
    [driverId],
  )

  if (!row) {
    // Nunca reportó presencia; devolvemos estado por defecto sin crear fila.
    return NextResponse.json({
      success: true,
      driver_id: driverId,
      is_online: false,
      latitude: null,
      longitude: null,
      heading: null,
      accuracyMeters: null,
      speedKmh: null,
      vehicleType: null,
      activeRideId: null,
      lastHeartbeat: null,
      updatedAt: null,
    })
  }

  return NextResponse.json({
    success: true,
    driver_id: row.driver_id,
    is_online: row.is_online,
    latitude: row.latitude !== null ? Number(row.latitude) : null,
    longitude: row.longitude !== null ? Number(row.longitude) : null,
    heading: row.heading !== null ? Number(row.heading) : null,
    accuracyMeters: row.accuracy_meters !== null ? Number(row.accuracy_meters) : null,
    speedKmh: row.speed_kmh !== null ? Number(row.speed_kmh) : null,
    vehicleType: row.vehicle_type,
    activeRideId: row.active_ride_id,
    lastHeartbeat: row.last_heartbeat,
    updatedAt: row.updated_at,
  })
}
