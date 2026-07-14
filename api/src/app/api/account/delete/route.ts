/**
 * POST /api/account/delete
 * Auth: Bearer <access_token>
 * Body: { confirmation: 'DELETE' }
 *
 * Cumplimiento de política de Google/Apple: permitir al usuario borrar su
 * propia cuenta. Estrategia: soft-delete + anonimización PII + revocar sesiones.
 *
 * NO borramos el registro físico porque hay foreign keys (rides, transacciones)
 * y necesitamos preservar el historial contable/legal. Anonimizamos:
 *   - full_name → NULL
 *   - email → deleted-<uid>@rapiteam.local
 *   - phone → NULL (¡importante!, deja libre el número para re-registro)
 *   - is_active = false
 *   - deleted_at = now()
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth, getClientIp } from '@/lib/auth-middleware'
import { query, tx } from '@/lib/db'
import { revokeAllUserSessions } from '@/lib/sessions'

export const runtime = 'nodejs'

export async function POST(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  let body: { confirmation?: string; reason?: string } = {}
  try {
    body = await req.json()
  } catch {
    // ignore
  }

  if (body.confirmation !== 'DELETE') {
    return NextResponse.json(
      { success: false, error: 'missing_confirmation', message: 'Debes enviar { confirmation: "DELETE" }' },
      { status: 400 },
    )
  }

  try {
    await tx(async (client) => {
      // Anonimizar el usuario
      await client.query(
        `UPDATE users
           SET full_name = NULL,
               email = 'deleted-' || id || '@rapiteam.local',
               phone = NULL,
               phone_number = NULL,
               profile_photo_url = NULL,
               google_uid = NULL,
               apple_uid = NULL,
               is_active = false,
               deleted_at = now(),
               updated_at = now()
         WHERE id = $1`,
        [auth.userId],
      )
      // Borrar todos los tokens FCM
      await client.query('DELETE FROM fcm_tokens WHERE user_id = $1', [auth.userId])
      // Borrar passkeys
      await client.query('DELETE FROM passkey_credentials WHERE user_id = $1', [auth.userId])
    })

    // Revocar TODAS las sesiones
    await revokeAllUserSessions(auth.userId)

    // Auditoría
    await query(
      `INSERT INTO auth_events (user_id, event_type, provider, ip_address, user_agent, metadata)
       VALUES ($1, 'account_deleted', NULL, $2, $3, $4)`,
      [auth.userId, getClientIp(req), req.headers.get('user-agent'), JSON.stringify({ reason: body.reason ?? null })],
    )

    return NextResponse.json({
      success: true,
      message: 'Cuenta eliminada. El usuario será cerrado de sesión.',
    })
  } catch (err) {
    console.error('[account/delete] error:', err)
    return NextResponse.json({ success: false, error: 'internal_error' }, { status: 500 })
  }
}
