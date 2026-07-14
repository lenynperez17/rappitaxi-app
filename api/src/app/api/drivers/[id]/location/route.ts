/**
 * GET /api/drivers/:id/location
 * Auth: Bearer <access_token>
 *
 * Devuelve la última ubicación conocida del conductor `:id` desde la tabla
 * `driver_presence`. Autorización granular:
 *   - el propio driver puede consultar su ubicación,
 *   - un admin puede consultar cualquiera,
 *   - un passenger solo puede consultarla si tiene un ride activo con ese
 *     driver (status IN accepted, on_way, arrived, in_progress).
 *
 * Respuesta:
 *   { success: true, latitude, longitude, heading, updatedAt, lastHeartbeat }
 * Errores:
 *   401 sin token
 *   403 sin permiso
 *   404 el driver no tiene registro de presencia (nunca envió heartbeat)
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { maybeOne } from '@/lib/db'

export const runtime = 'nodejs'

interface PresenceRow {
  latitude: string | null
  longitude: string | null
  heading: string | null
  vehicle_type: string | null
  is_online: boolean
  last_heartbeat: Date | null
  updated_at: Date
}

interface RequesterRow {
  is_admin: boolean
  user_type: string
}

interface ActiveRideRow {
  id: string
}

const ACTIVE_STATUSES = ['accepted', 'on_way', 'arrived', 'in_progress']

export async function GET(
  req: NextRequest,
  ctx: { params: Promise<{ id: string }> },
) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response
  const requesterId = auth.userId

  const { id: driverId } = await ctx.params
  if (!driverId || typeof driverId !== 'string') {
    return NextResponse.json(
      { success: false, error: 'invalid_id' },
      { status: 400 },
    )
  }

  // ¿Es el propio driver?
  const isSelf = requesterId === driverId

  // Cargar datos del requester para saber si es admin
  let isAdmin = false
  if (!isSelf) {
    const requester = await maybeOne<RequesterRow>(
      'SELECT is_admin, user_type FROM users WHERE id = $1',
      [requesterId],
    )
    if (requester && (requester.is_admin || requester.user_type === 'admin')) {
      isAdmin = true
    }
  }

  // Si no es él mismo ni admin, comprobar que sea passenger con un ride activo
  // con este driver.
  if (!isSelf && !isAdmin) {
    const activeRide = await maybeOne<ActiveRideRow>(
      `SELECT id FROM rides
        WHERE driver_id = $1
          AND passenger_id = $2
          AND status = ANY($3::text[])
        ORDER BY created_at DESC
        LIMIT 1`,
      [driverId, requesterId, ACTIVE_STATUSES],
    )
    if (!activeRide) {
      return NextResponse.json(
        { success: false, error: 'forbidden', message: 'No tienes un viaje activo con este conductor' },
        { status: 403 },
      )
    }
  }

  const presence = await maybeOne<PresenceRow>(
    `SELECT latitude, longitude, heading, vehicle_type, is_online,
            last_heartbeat, updated_at
       FROM driver_presence
      WHERE driver_id = $1`,
    [driverId],
  )

  if (!presence || presence.latitude === null || presence.longitude === null) {
    return NextResponse.json(
      { success: false, error: 'not_found', message: 'El conductor no tiene ubicación registrada' },
      { status: 404 },
    )
  }

  return NextResponse.json({
    success: true,
    latitude: Number(presence.latitude),
    longitude: Number(presence.longitude),
    heading: presence.heading !== null ? Number(presence.heading) : null,
    vehicleType: presence.vehicle_type,
    isOnline: presence.is_online,
    lastHeartbeat: presence.last_heartbeat,
    updatedAt: presence.updated_at,
  })
}
