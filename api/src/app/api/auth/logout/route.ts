/**
 * POST /api/auth/logout
 * Auth: Bearer <access_token>
 * Body: { refreshToken?, allDevices? }
 *
 * Revoca la sesión actual. Si `allDevices=true`, revoca TODAS las sesiones
 * del usuario (útil para "cerrar sesión en todos los dispositivos").
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { revokeSession, revokeAllUserSessions } from '@/lib/sessions'

export const runtime = 'nodejs'

export async function POST(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  let body: { refreshToken?: string; allDevices?: boolean } = {}
  try {
    body = await req.json()
  } catch {
    // body opcional; ignorar parse error
  }

  try {
    if (body.allDevices) {
      const revoked = await revokeAllUserSessions(auth.userId)
      return NextResponse.json({ success: true, revokedCount: revoked })
    }
    if (body.refreshToken) {
      await revokeSession(body.refreshToken)
    }
    return NextResponse.json({ success: true })
  } catch (err) {
    console.error('[auth/logout] error:', err)
    return NextResponse.json({ success: false, error: 'internal_error' }, { status: 500 })
  }
}
