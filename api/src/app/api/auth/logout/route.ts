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
import { revokeSession, revokeAllUserSessions, peekJti } from '@/lib/sessions'
import { verifyAccessToken } from '@/lib/jwt'
import { query } from '@/lib/db'

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
      // BUG FIX: antes se pasaba el JWT completo como sessionId, y
      // revokeSession(sessionId) hacía UPDATE WHERE id=<JWT> → nunca matcheaba.
      // Ahora: derivar el jti (sessionId real) del JWT.
      const sessionId = peekJti(body.refreshToken)
      if (sessionId) {
        // Ownership check: solo revocar si la sesión pertenece al user autenticado.
        // Sin esto, un attacker que conoce sessionId ajeno podría revocarlo (DoS).
        const owner = await query<{ user_id: string }>(
          'SELECT user_id FROM sessions WHERE id = $1 LIMIT 1',
          [sessionId],
        )
        if (owner[0]?.user_id === auth.userId) {
          await revokeSession(sessionId)
        }
      }
    } else {
      // Ronda 58 CRITICAL: sin refreshToken en body, revocar la sesión del
      // access token actual. Antes era no-op silencioso → cliente veía logout
      // exitoso pero sesión seguía viva hasta expirar JWT. Extraemos el `sid`
      // del claim del bearer y revocamos esa sesión específica.
      // Ronda 150: usar ` +` (solo espacios ASCII, RFC 6750) — misma corrección
      // que auth-middleware.ts Ronda 124. \s+ permite \t/\n/etc → smuggling.
      const bearer = req.headers.get('authorization')?.replace(/^Bearer +/i, '')
      if (bearer) {
        const claims = await verifyAccessToken(bearer)
        if (claims?.sid && typeof claims.sid === 'string') {
          const owner = await query<{ user_id: string }>(
            'SELECT user_id FROM sessions WHERE id = $1 LIMIT 1',
            [claims.sid],
          )
          if (owner[0]?.user_id === auth.userId) {
            await revokeSession(claims.sid)
          }
        }
      }
    }
    return NextResponse.json({ success: true })
  } catch (err) {
    console.error('[auth/logout] error:', err)
    return NextResponse.json({ success: false, error: 'internal_error' }, { status: 500 })
  }
}
