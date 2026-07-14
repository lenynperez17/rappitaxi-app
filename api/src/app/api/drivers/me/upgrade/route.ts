/**
 * POST /api/drivers/me/upgrade
 * Convierte un passenger en dual (habilita el modo conductor).
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth, getClientIp } from '@/lib/auth-middleware'
import { maybeOne, query } from '@/lib/db'

export const runtime = 'nodejs'
export const dynamic = 'force-dynamic'

export async function POST(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  const user = await maybeOne<{ id: string; user_type: string; is_admin: boolean }>(
    'SELECT id, user_type, is_admin FROM users WHERE id = $1 AND deleted_at IS NULL',
    [auth.userId],
  )
  if (!user) return NextResponse.json({ success: false, error: 'user_not_found' }, { status: 404 })

  if (user.user_type === 'driver' || user.user_type === 'dual') {
    return NextResponse.json({ success: true, message: 'Ya eres conductor', userType: user.user_type })
  }

  await query(
    `UPDATE users SET user_type = 'dual', updated_at = now() WHERE id = $1`,
    [auth.userId],
  )
  await query(
    `INSERT INTO auth_events (user_id, event_type, provider, ip_address, user_agent, metadata)
     VALUES ($1, 'upgraded_to_driver', 'app', $2, $3, $4)`,
    [auth.userId, getClientIp(req), req.headers.get('user-agent'), JSON.stringify({ previousType: user.user_type })],
  )

  return NextResponse.json({ success: true, userType: 'dual' })
}
