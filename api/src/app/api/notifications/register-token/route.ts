/**
 * POST /api/notifications/register-token
 * Auth: Bearer <access_token>
 * Body: { token: string, platform: 'ios'|'android'|'web', deviceId?: string }
 *
 * Registra el token FCM del dispositivo para futuras notificaciones server-side.
 * Idempotente: si el token ya existe, actualiza `last_seen_at`.
 * NOTA: mantener FCM (Firebase Cloud Messaging) durante la transición híbrida.
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { query } from '@/lib/db'

export const runtime = 'nodejs'

const ALLOWED_PLATFORMS = ['ios', 'android', 'web'] as const

export async function POST(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  let body: { token?: string; platform?: string; deviceId?: string }
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ success: false, error: 'bad_json' }, { status: 400 })
  }

  const token = body.token?.trim()
  const platform = body.platform?.trim()
  const deviceInfo = body.deviceId ? { deviceId: body.deviceId } : null

  if (!token || token.length < 10) {
    return NextResponse.json({ success: false, error: 'invalid_token' }, { status: 400 })
  }
  if (!platform || !ALLOWED_PLATFORMS.includes(platform as typeof ALLOWED_PLATFORMS[number])) {
    return NextResponse.json({ success: false, error: 'invalid_platform' }, { status: 400 })
  }

  await query(
    `INSERT INTO fcm_tokens (user_id, token, platform, device_info, last_seen_at)
     VALUES ($1, $2, $3, $4, now())
     ON CONFLICT (token) DO UPDATE
       SET user_id = EXCLUDED.user_id,
           platform = EXCLUDED.platform,
           device_info = EXCLUDED.device_info,
           last_seen_at = now()`,
    [auth.userId, token, platform, deviceInfo ? JSON.stringify(deviceInfo) : null],
  )

  return NextResponse.json({ success: true })
}

/**
 * DELETE /api/notifications/register-token
 * Body: { token: string }
 * Se llama al desinstalar / cerrar sesión — quita el token de la BD.
 */
export async function DELETE(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  let body: { token?: string }
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ success: false, error: 'bad_json' }, { status: 400 })
  }

  if (!body.token) {
    return NextResponse.json({ success: false, error: 'missing_token' }, { status: 400 })
  }

  const result = await query(
    'DELETE FROM fcm_tokens WHERE user_id = $1 AND token = $2',
    [auth.userId, body.token],
  )

  return NextResponse.json({ success: true, deleted: result.length })
}
