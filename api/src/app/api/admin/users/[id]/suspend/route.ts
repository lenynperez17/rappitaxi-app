/**
 * POST /api/admin/users/:id/suspend
 * Body: { reason?: string }
 *   → suspende cuenta + revoca sesiones activas
 * DELETE (o POST /activate) → reactiva
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAdmin } from '@/lib/admin-middleware'
import { getClientIp } from '@/lib/auth-middleware'
import { query, maybeOne, tx } from '@/lib/db'

export const runtime = 'nodejs'

interface UserRow {
  id: string
  is_active: boolean
  suspended_at: Date | null
  deleted_at: Date | null
}

export async function POST(req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  const auth = await requireAdmin(req)
  if (!auth.ok) return auth.response
  const { id } = await ctx.params

  if (id === auth.userId) {
    return NextResponse.json(
      { success: false, error: 'cannot_suspend_self' },
      { status: 400 },
    )
  }

  let body: { reason?: string } = {}
  try { body = await req.json() } catch { /* body opcional */ }
  const reason = body.reason?.trim() || null

  const user = await maybeOne<UserRow>('SELECT id, is_active, suspended_at, deleted_at FROM users WHERE id = $1', [id])
  if (!user) return NextResponse.json({ success: false, error: 'not_found' }, { status: 404 })
  if (user.deleted_at) return NextResponse.json({ success: false, error: 'user_deleted' }, { status: 410 })

  await tx(async (client) => {
    await client.query(
      `UPDATE users SET is_active = false, suspended_at = now(),
                        suspended_reason = $2, updated_at = now()
       WHERE id = $1`,
      [id, reason],
    )
    await client.query('DELETE FROM sessions WHERE user_id = $1', [id])
    // Cancelar rides activos donde user es passenger o driver — sin esto,
    // rides quedan zombies con user suspendido (contraparte no puede avanzar).
    const activeStates = ['requested', 'searching', 'accepted', 'on_way', 'arrived', 'in_progress']
    const cancelled = await client.query<{ id: string; driver_id: string | null }>(
      `UPDATE rides
          SET status = 'cancelled',
              cancelled_by = $1,
              cancelled_reason = 'user_suspended',
              completed_at = now()
        WHERE (passenger_id = $1 OR driver_id = $1)
          AND status = ANY($2::text[])
        RETURNING id, driver_id`,
      [id, activeStates],
    )
    // Liberar drivers contraparte con active_ride_id apuntando a ride cancelado
    const otherDriverIds = cancelled.rows.map((r) => r.driver_id).filter((d): d is string => d !== null && d !== id)
    if (otherDriverIds.length > 0) {
      await client.query(
        `UPDATE driver_presence SET active_ride_id = NULL, updated_at = now()
          WHERE driver_id = ANY($1::text[]) AND active_ride_id = ANY($2::uuid[])`,
        [otherDriverIds, cancelled.rows.map((r) => r.id)],
      )
    }
    // Limpiar propia driver_presence
    await client.query(
      `UPDATE driver_presence SET is_online = false, active_ride_id = NULL, updated_at = now()
        WHERE driver_id = $1`,
      [id],
    )
  })

  await query(
    `INSERT INTO auth_events (user_id, event_type, provider, ip_address, user_agent, metadata)
     VALUES ($1, 'admin_suspend_user', 'admin', $2, $3, $4)`,
    [id, getClientIp(req), req.headers.get('user-agent'), JSON.stringify({ suspendedBy: auth.userId, reason })],
  )

  return NextResponse.json({ success: true, message: 'Usuario suspendido' })
}

export async function DELETE(req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  const auth = await requireAdmin(req)
  if (!auth.ok) return auth.response
  const { id } = await ctx.params

  const user = await maybeOne<UserRow>('SELECT id, deleted_at FROM users WHERE id = $1', [id])
  if (!user) return NextResponse.json({ success: false, error: 'not_found' }, { status: 404 })
  if (user.deleted_at) return NextResponse.json({ success: false, error: 'user_deleted' }, { status: 410 })

  await query(
    `UPDATE users SET is_active = true, suspended_at = NULL, suspended_reason = NULL, updated_at = now()
     WHERE id = $1`,
    [id],
  )
  await query(
    `INSERT INTO auth_events (user_id, event_type, provider, ip_address, user_agent, metadata)
     VALUES ($1, 'admin_activate_user', 'admin', $2, $3, $4)`,
    [id, getClientIp(req), req.headers.get('user-agent'), JSON.stringify({ activatedBy: auth.userId })],
  )

  return NextResponse.json({ success: true, message: 'Usuario reactivado' })
}
