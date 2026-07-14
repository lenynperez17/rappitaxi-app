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
      // Cancelar rides activos donde el user es passenger o driver.
      // Sin esto, quedan huérfanos hasta el janitor 24h de admin/live: el
      // otro lado ve viaje fantasma y el driver contraparte queda con
      // driver_presence.active_ride_id bloqueado sin driver alcanzable.
      const activeStates = ['requested', 'searching', 'accepted', 'on_way', 'arrived', 'in_progress']
      const cancelledRides = await client.query<{ id: string; driver_id: string | null }>(
        `UPDATE rides
            SET status = 'cancelled',
                cancelled_by = $1,
                cancelled_reason = 'user_deleted',
                completed_at = now()
          WHERE (passenger_id = $1 OR driver_id = $1)
            AND status = ANY($2::text[])
          RETURNING id, driver_id`,
        [auth.userId, activeStates],
      )
      // Liberar drivers contraparte que quedaron con active_ride_id apuntando
      // a un ride del user borrado.
      const otherDriverIds = cancelledRides.rows
        .map((r) => r.driver_id)
        .filter((d): d is string => d !== null && d !== auth.userId)
      if (otherDriverIds.length > 0) {
        await client.query(
          `UPDATE driver_presence
              SET active_ride_id = NULL, updated_at = now()
            WHERE driver_id = ANY($1::text[])
              AND active_ride_id = ANY($2::uuid[])`,
          [otherDriverIds, cancelledRides.rows.map((r) => r.id)],
        )
      }

      // Rechazar withdrawals pending — sin esto siguen consumiendo balance
      // (rapi_team_user_balance de migración 014 cuenta pending).
      await client.query(
        `UPDATE wallet_withdrawals
            SET status = 'rejected',
                reject_reason = 'user_deleted'
          WHERE driver_id = $1 AND status = 'pending'`,
        [auth.userId],
      )
      // Marcar wallet_transactions pending como cancelled correspondientemente
      await client.query(
        `UPDATE wallet_transactions
            SET status = 'cancelled'
          WHERE user_id = $1 AND status = 'pending'`,
        [auth.userId],
      )

      // Limpiar driver_presence propia
      await client.query(
        `UPDATE driver_presence
            SET is_online = false, active_ride_id = NULL, updated_at = now()
          WHERE driver_id = $1`,
        [auth.userId],
      )

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
