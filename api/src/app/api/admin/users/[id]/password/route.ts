/**
 * PUT /api/admin/users/:id/password
 * Body: { password }
 *
 * Cambia la contraseña del usuario. Solo admin puede llamar.
 * Un admin puede resetear su propia contraseña o la de otro admin.
 */
import { NextRequest, NextResponse } from 'next/server'
import bcrypt from 'bcryptjs'
import { requireAdmin } from '@/lib/admin-middleware'
import { getClientIp } from '@/lib/auth-middleware'
import { query, maybeOne } from '@/lib/db'
import { revokeAllUserSessions } from '@/lib/sessions'
import { isUuid } from '@/lib/uuid'

export const runtime = 'nodejs'

export async function PUT(req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  const auth = await requireAdmin(req)
  if (!auth.ok) return auth.response
  const { id } = await ctx.params
  // Ronda 142: UUID guard.
  if (!isUuid(id)) {
    return NextResponse.json({ success: false, error: 'invalid_id' }, { status: 400 })
  }

  let body: { password?: string }
  try { body = await req.json() } catch {
    return NextResponse.json({ success: false, error: 'bad_json' }, { status: 400 })
  }

  const password = body.password
  // Ronda 214 SECURITY: subimos a 8 chars + al menos 1 letra Y 1 número.
  // Antes el reset admin permitía "abc123" mientras el login exigía >=8 →
  // asimetría explotable si admin comprometido reseteaba a "123456" y el
  // atacante entraba por brute-force offline.
  if (!password || password.length < 8) {
    return NextResponse.json(
      { success: false, error: 'invalid_password', message: 'Mínimo 8 caracteres' },
      { status: 400 },
    )
  }
  const hasLetter = /[A-Za-z]/.test(password)
  const hasDigit = /\d/.test(password)
  if (!hasLetter || !hasDigit) {
    return NextResponse.json(
      { success: false, error: 'weak_password', message: 'Debe contener letras y números' },
      { status: 400 },
    )
  }

  const user = await maybeOne<{ id: string; deleted_at: Date | null }>(
    'SELECT id, deleted_at FROM users WHERE id = $1',
    [id],
  )
  if (!user) return NextResponse.json({ success: false, error: 'not_found' }, { status: 404 })
  if (user.deleted_at) return NextResponse.json({ success: false, error: 'user_deleted' }, { status: 410 })

  const hash = await bcrypt.hash(password, 10)
  await query(
    `UPDATE users SET password_hash = $1, updated_at = now() WHERE id = $2`,
    [hash, id],
  )

  // B#7: revocar todas las sesiones existentes. Sin esto, sesiones activas
  // del user comprometido (o del atacante si el reset es correctivo) siguen
  // válidas hasta la expiración del refresh token.
  const revokedCount = await revokeAllUserSessions(id)

  await query(
    `INSERT INTO auth_events (user_id, event_type, provider, ip_address, user_agent, metadata)
     VALUES ($1, 'admin_password_changed', 'admin', $2, $3, $4)`,
    [
      id,
      getClientIp(req),
      req.headers.get('user-agent'),
      JSON.stringify({ changedBy: auth.userId, sessionsRevoked: revokedCount }),
    ],
  )

  return NextResponse.json({
    success: true,
    message: 'Contraseña actualizada',
    sessionsRevoked: revokedCount,
  })
}
