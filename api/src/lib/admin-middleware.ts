/**
 * Middleware admin: verifica que el JWT sea de un usuario con user_type='admin'
 * o is_admin=true. Uso:
 *   const auth = await requireAdmin(req)
 *   if (!auth.ok) return auth.response
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from './auth-middleware'
import { maybeOne } from './db'

export type AdminAuthOk = { ok: true; userId: string; response?: never }
export type AdminAuthFail = { ok: false; response: NextResponse; userId?: never }
export type AdminAuthResult = AdminAuthOk | AdminAuthFail

interface AdminCheck {
  is_admin: boolean
  user_type: string
  is_active: boolean
}

export async function requireAdmin(req: NextRequest): Promise<AdminAuthResult> {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth

  const user = await maybeOne<AdminCheck>(
    'SELECT is_admin, user_type, is_active FROM users WHERE id = $1',
    [auth.userId],
  )
  if (!user) {
    return {
      ok: false,
      response: NextResponse.json({ success: false, error: 'user_not_found' }, { status: 401 }),
    }
  }
  if (!user.is_active) {
    return {
      ok: false,
      response: NextResponse.json({ success: false, error: 'account_suspended' }, { status: 403 }),
    }
  }
  if (!user.is_admin && user.user_type !== 'admin') {
    return {
      ok: false,
      response: NextResponse.json({ success: false, error: 'forbidden', message: 'Solo admin' }, { status: 403 }),
    }
  }
  return { ok: true, userId: auth.userId }
}
