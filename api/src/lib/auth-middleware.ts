/**
 * Helpers de autenticación para route handlers.
 *
 * Uso típico:
 *   const auth = await requireAuth(req)
 *   if (!auth.ok) return auth.response
 *   // auth.userId disponible
 */
import { NextRequest, NextResponse } from 'next/server'
import { verifyAccessToken } from './jwt'
import { maybeOne } from './db'

export type AuthOk = { ok: true; userId: string; response?: never }
export type AuthFail = { ok: false; response: NextResponse; userId?: never }
export type AuthResult = AuthOk | AuthFail

export async function requireAuth(req: NextRequest): Promise<AuthResult> {
  const authHeader = req.headers.get('authorization') ?? ''
  // Ronda 124: usar ` +` (solo espacios ASCII, RFC 6750) en vez de \s+ que
  // permite \n\t → smuggling con caracteres de control.
  const match = authHeader.match(/^Bearer +(.+)$/i)
  if (!match) {
    return {
      ok: false,
      response: NextResponse.json({ success: false, error: 'unauthorized', message: 'Falta token' }, { status: 401 }),
    }
  }
  const token = match[1]!.trim()
  // Ronda 124: rechazar token vacío ("Bearer   " tras trim → '').
  if (!token) {
    return {
      ok: false,
      response: NextResponse.json({ success: false, error: 'unauthorized', message: 'Token vacío' }, { status: 401 }),
    }
  }
  const payload = await verifyAccessToken(token)
  if (!payload || !payload.sub) {
    return {
      ok: false,
      response: NextResponse.json({ success: false, error: 'invalid_token' }, { status: 401 }),
    }
  }

  // Enforcement de estado del user: si fue suspendido o eliminado desde admin,
  // rechazar el request aunque el JWT siga vigente.
  const user = await maybeOne<{ is_active: boolean; suspended_at: Date | null; deleted_at: Date | null }>(
    'SELECT is_active, suspended_at, deleted_at FROM users WHERE id = $1',
    [payload.sub],
  )
  if (!user) {
    return {
      ok: false,
      response: NextResponse.json({ success: false, error: 'user_not_found' }, { status: 401 }),
    }
  }
  if (user.deleted_at) {
    return {
      ok: false,
      response: NextResponse.json({ success: false, error: 'account_deleted' }, { status: 403 }),
    }
  }
  if (!user.is_active || user.suspended_at) {
    return {
      ok: false,
      response: NextResponse.json({ success: false, error: 'account_suspended' }, { status: 403 }),
    }
  }

  return { ok: true, userId: payload.sub }
}

/**
 * Extrae la IP del cliente desde headers estándar.
 * Ronda 138: validar que sea IPv4/IPv6 plausible y devolver null si no. Sin
 * esto, XFF="" o "unknown" (fallback de proxies antiguos/CDNs) llegaba a
 * INSERTs sobre columnas INET → PostgreSQL rechazaba "invalid input syntax
 * for type inet" → 500 después de operaciones exitosas (SOS registrado en
 * emergencias pero sin auth_event, similar al bug de sms/verify Ronda 128).
 */
export function getClientIp(req: NextRequest): string | null {
  const raw =
    req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ??
    req.headers.get('x-real-ip')?.trim() ??
    null
  if (!raw) return null
  if (raw.length > 45) return null
  if (!/^[0-9a-fA-F:.]+$/.test(raw)) return null
  return raw
}
