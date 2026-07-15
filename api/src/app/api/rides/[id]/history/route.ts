/**
 * GET /api/rides/:id/history
 *   Historial de estados del ride. Devuelve un array cronológico basado en los
 *   timestamps de la propia fila (created_at, accepted_at, started_at,
 *   completed_at) más la marca de cancelled si aplica.
 *   Solo passenger, driver o admin del viaje pueden verlo.
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { maybeOne } from '@/lib/db'

export const runtime = 'nodejs'

interface RideTimestampsRow {
  id: string
  passenger_id: string | null
  driver_id: string | null
  status: string
  cancelled_by: string | null
  cancelled_reason: string | null
  created_at: Date
  accepted_at: Date | null
  started_at: Date | null
  completed_at: Date | null
  updated_at: Date | null
}

interface HistoryEntry {
  status: string
  at: Date
  actorId?: string | null
  reason?: string | null
}

export async function GET(req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response
  const { id } = await ctx.params

  const ride = await maybeOne<RideTimestampsRow>(
    `SELECT id, passenger_id, driver_id, status,
            cancelled_by, cancelled_reason,
            created_at, accepted_at, started_at, completed_at, updated_at
       FROM rides
       WHERE id = $1`,
    [id],
  )
  if (!ride) {
    return NextResponse.json({ success: false, error: 'not_found' }, { status: 404 })
  }

  // Autorización: passenger, driver o admin
  const isParticipant = ride.passenger_id === auth.userId || ride.driver_id === auth.userId
  if (!isParticipant) {
    const adminCheck = await maybeOne<{ is_admin: boolean; user_type: string }>(
      'SELECT is_admin, user_type FROM users WHERE id = $1',
      [auth.userId],
    )
    const isAdmin = !!adminCheck && (adminCheck.is_admin || adminCheck.user_type === 'admin')
    if (!isAdmin) {
      return NextResponse.json({ success: false, error: 'forbidden' }, { status: 403 })
    }
  }

  const history: HistoryEntry[] = []
  history.push({ status: 'requested', at: ride.created_at, actorId: ride.passenger_id })
  if (ride.accepted_at) {
    history.push({ status: 'accepted', at: ride.accepted_at, actorId: ride.driver_id })
  }
  if (ride.started_at) {
    history.push({ status: 'in_progress', at: ride.started_at, actorId: ride.driver_id })
  }
  // Ronda 50 Bug#1: cancelaciones tempranas no tienen completed_at (solo se
  // rellena al finalizar exitosamente). Antes: cancel en 'requested' o
  // 'accepted' no aparecía en history. Ahora usar ride.status === 'cancelled'
  // como fuente independiente + completed_at OR updated_at fallback.
  if (ride.status === 'cancelled') {
    history.push({
      status: 'cancelled',
      at: ride.completed_at ?? ride.updated_at ?? ride.created_at,
      actorId: ride.cancelled_by,
      reason: ride.cancelled_reason,
    })
  } else if (ride.completed_at) {
    history.push({ status: 'completed', at: ride.completed_at, actorId: ride.driver_id })
  }

  history.sort((a, b) => new Date(a.at).getTime() - new Date(b.at).getTime())

  return NextResponse.json({
    success: true,
    rideId: ride.id,
    currentStatus: ride.status,
    history,
  })
}
