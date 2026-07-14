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
  const match = authHeader.match(/^Bearer\s+(.+)$/i)
  if (!match) {
    return {
      ok: false,
      response: NextResponse.json({ success: false, error: 'unauthorized', message: 'Falta token' }, { status: 401 }),
    }
  }
  const token = match[1]!.trim()
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

/** Extrae la IP del cliente desde headers estándar. */
export function getClientIp(req: NextRequest): string | null {
  return (
    req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ??
    req.headers.get('x-real-ip') ??
    null
  )
}
