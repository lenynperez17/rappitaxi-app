/**
 * POST /api/drivers/presence
 * Auth: Bearer <access_token> (driver o dual)
 *
 * Heartbeat de presencia del conductor. La app llama este endpoint cada 5-15s
 * mientras el driver esté online para actualizar su ubicación en tiempo real
 * en `driver_presence`. Además de la lat/lng, admite heading, accuracy, speed,
 * vehicleType y activeRideId opcionales.
 *
 * Body:
 *   {
 *     latitude: number,
 *     longitude: number,
 *     heading?: number,
 *     accuracy?: number,      // metros
 *     speed?: number,         // km/h
 *     vehicleType?: string,
 *     activeRideId?: string,  // UUID del ride en curso, si lo hay
 *   }
 *
 * Respuestas:
 *   200 { success: true, ok: true, driver_id }
 *   400 body inválido
 *   401 sin token
 *   403 el usuario no es driver ni dual
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { maybeOne, query } from '@/lib/db'

export const runtime = 'nodejs'

interface UserTypeRow {
  user_type: string
}

interface PresenceBody {
  latitude?: unknown
  longitude?: unknown
  heading?: unknown
  accuracy?: unknown
  speed?: unknown
  vehicleType?: unknown
  activeRideId?: unknown
  clearActiveRide?: unknown
}

function toNumberOrNull(v: unknown): number | null {
  if (v === undefined || v === null || v === '') return null
  const n = Number(v)
  return Number.isFinite(n) ? n : null
}

export async function POST(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response
  const driverId = auth.userId

  let body: PresenceBody = {}
  try {
    body = (await req.json()) as PresenceBody
  } catch {
    return NextResponse.json(
      { success: false, error: 'bad_json' },
      { status: 400 },
    )
  }

  const latitude = toNumberOrNull(body.latitude)
  const longitude = toNumberOrNull(body.longitude)
  if (latitude === null || longitude === null) {
    return NextResponse.json(
      { success: false, error: 'invalid_input', message: 'latitude y longitude son requeridos' },
      { status: 400 },
    )
  }
  if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
    return NextResponse.json(
      { success: false, error: 'invalid_coordinates' },
      { status: 400 },
    )
  }

  // Ronda 47 Bug#2: verificar deleted_at + is_active + suspended_at. Sin esto
  // un driver soft-deleted o suspendido seguía haciendo heartbeats hasta que
  // expirara su JWT (hasta 1h), apareciendo online en /admin/live y recibiendo
  // asignaciones. Ahora la revocación de cuenta surte efecto inmediato.
  const user = await maybeOne<UserTypeRow & { is_active: boolean; suspended_at: Date | null; deleted_at: Date | null }>(
    'SELECT user_type, is_active, suspended_at, deleted_at FROM users WHERE id = $1',
    [driverId],
  )
  if (!user || user.deleted_at) {
    return NextResponse.json(
      { success: false, error: 'user_not_found' },
      { status: 404 },
    )
  }
  if (!user.is_active || user.suspended_at) {
    return NextResponse.json(
      { success: false, error: 'account_disabled', message: 'Cuenta suspendida' },
      { status: 403 },
    )
  }
  if (user.user_type !== 'driver' && user.user_type !== 'dual') {
    return NextResponse.json(
      { success: false, error: 'forbidden', message: 'Solo drivers pueden reportar presencia' },
      { status: 403 },
    )
  }

  const heading = toNumberOrNull(body.heading)
  const accuracy = toNumberOrNull(body.accuracy)
  const speed = toNumberOrNull(body.speed)
  const vehicleType =
    typeof body.vehicleType === 'string' && body.vehicleType.trim() !== ''
      ? body.vehicleType.trim()
      : null
  const rawActiveRideId =
    typeof body.activeRideId === 'string' && body.activeRideId.trim() !== ''
      ? body.activeRideId.trim()
      : null
  // Flag explícito para limpiar el active_ride_id (driver quiere liberarse
  // manualmente sin esperar cancel/complete). Sin este flag, con COALESCE
  // ningún heartbeat puede setear el campo a NULL.
  const clearActiveRide = body.clearActiveRide === true

  // B#15: si el driver envía `activeRideId`, verificar que ese ride existe
  // y está asignado a este mismo driver. Sin este check, un driver malicioso
  // envenena driver_presence.active_ride_id con IDs ajenos → confunde
  // admin/live y podría filtrar contexto en dashboards.
  let activeRideId: string | null = null
  if (rawActiveRideId) {
    const owned = await query<{ id: string }>(
      `SELECT id FROM rides WHERE id = $1 AND driver_id = $2 LIMIT 1`,
      [rawActiveRideId, driverId],
    )
    if (owned.length === 0) {
      return NextResponse.json(
        { success: false, error: 'active_ride_not_owned' },
        { status: 403 },
      )
    }
    activeRideId = rawActiveRideId
  }

  // Estrategia para active_ride_id:
  // - `clearActiveRide=true` → set NULL explícito (driver quiere liberarse)
  // - activeRideId con valor → sobreescribir con ese valor
  // - sin activeRideId ni clearActiveRide → COALESCE (preservar el previo,
  //   evita wipe silencioso en cada heartbeat que omite el campo)
  const activeRideExpr = clearActiveRide
    ? 'NULL'
    : 'COALESCE(EXCLUDED.active_ride_id, driver_presence.active_ride_id)'

  try {
    await query(
      `INSERT INTO driver_presence (
         driver_id, latitude, longitude, heading, accuracy_meters, speed_kmh,
         vehicle_type, active_ride_id, last_heartbeat, updated_at
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, now(), now())
       ON CONFLICT (driver_id) DO UPDATE SET
         latitude = EXCLUDED.latitude,
         longitude = EXCLUDED.longitude,
         heading = EXCLUDED.heading,
         accuracy_meters = EXCLUDED.accuracy_meters,
         speed_kmh = EXCLUDED.speed_kmh,
         vehicle_type = COALESCE(EXCLUDED.vehicle_type, driver_presence.vehicle_type),
         active_ride_id = ${activeRideExpr},
         last_heartbeat = now(),
         updated_at = now()`,
      [driverId, latitude, longitude, heading, accuracy, speed, vehicleType, activeRideId],
    )

    return NextResponse.json({ success: true, ok: true, driver_id: driverId })
  } catch (err) {
    console.error('[drivers/presence] error:', err)
    return NextResponse.json(
      { success: false, error: 'server_error' },
      { status: 500 },
    )
  }
}
