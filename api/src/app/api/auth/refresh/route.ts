/**
 * POST /api/auth/refresh
 * Body: { refreshToken }
 *
 * Rota la sesión: valida el refresh, revoca el actual, emite un par nuevo.
 * Fuerza al cliente a persistir el nuevo par cada refresh (rotación).
 */
import { NextRequest, NextResponse } from 'next/server'
import { refreshSession } from '@/lib/sessions'
import { ACCESS_TTL_SECONDS, REFRESH_TTL_SECONDS } from '@/lib/jwt'
import { deviceInfoFromHeaders } from '@/lib/sessions'

export const runtime = 'nodejs'

export async function POST(req: NextRequest) {
  let body: { refreshToken?: unknown }
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ success: false, error: 'bad_json' }, { status: 400 })
  }

  // Ronda 38 LOW: validar typeof antes de trim(). Cliente que envía
  // {refreshToken: 123} o {refreshToken: {...}} lanzaba TypeError → 500.
  if (typeof body.refreshToken !== 'string') {
    return NextResponse.json({ success: false, error: 'missing_refresh_token' }, { status: 400 })
  }
  const refreshToken = body.refreshToken.trim()
  if (!refreshToken) {
    return NextResponse.json({ success: false, error: 'missing_refresh_token' }, { status: 400 })
  }

  try {
    const device = deviceInfoFromHeaders(req.headers)
    const next = await refreshSession(refreshToken, device)
    if (!next) {
      return NextResponse.json(
        { success: false, error: 'invalid_refresh_token', message: 'Sesión inválida o expirada' },
        { status: 401 },
      )
    }
    return NextResponse.json({
      success: true,
      jwt: next.accessToken,
      refreshToken: next.refreshToken,
      accessTtlSec: ACCESS_TTL_SECONDS,
      refreshTtlSec: REFRESH_TTL_SECONDS,
    })
  } catch (err) {
    // InvalidRefreshError → sesión inválida/reusada. Devolver 401 (no 500).
    // B#11: los códigos reales que lanza InvalidRefreshError son
    // `invalid_refresh` y `reuse_detected` (ver lib/sessions.ts).
    // Los aliases viejos (`invalid_refresh_token`, `expired_refresh_token`)
    // se mantienen por compat con clientes antiguos.
    const code = (err as { code?: string })?.code
    if (code === 'account_suspended') {
      return NextResponse.json(
        { success: false, error: 'account_suspended', message: 'Cuenta suspendida' },
        { status: 403 },
      )
    }
    if (
      code === 'reuse_detected' ||
      code === 'invalid_refresh' ||
      code === 'invalid_refresh_token' ||
      code === 'expired_refresh_token'
    ) {
      return NextResponse.json(
        { success: false, error: code, message: 'Sesión inválida o expirada' },
        { status: 401 },
      )
    }
    console.error('[auth/refresh] unexpected error:', err)
    return NextResponse.json({ success: false, error: 'internal_error' }, { status: 500 })
  }
}
