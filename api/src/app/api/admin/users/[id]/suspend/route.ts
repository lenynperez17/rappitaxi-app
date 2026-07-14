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
