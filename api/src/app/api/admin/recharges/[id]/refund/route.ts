/**
 * POST /api/admin/recharges/:id/refund
 * Body: { reason: string }
 *
 * Anula una recarga completada del driver. Crea una wallet_transaction tipo
 * 'debit' por el mismo monto (con external_ref = recharge id) y marca la
 * recarga como 'refunded'. Idempotente: si la recarga ya está refunded
 * devuelve 200 con noop=true.
 *
 * Usado por: admin panel → RechargeDetailPage → botón "Anular recarga".
 * Caso: admin le recargó de más al driver y necesita restar.
 *
 * Nota: si el driver ya gastó el saldo, el balance queda negativo. Es
 * intencional — el admin sabe lo que hace y verá el saldo negativo en la
 * lista de conductores.
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAdmin } from '@/lib/admin-middleware'
import { getClientIp } from '@/lib/auth-middleware'
import { query, maybeOne, tx } from '@/lib/db'

export const runtime = 'nodejs'

interface RechargeRow {
  id: string
  driver_id: string
  amount: string
  status: string
  method: string
}

export async function POST(
  req: NextRequest,
  ctx: { params: Promise<{ id: string }> },
) {
  const auth = await requireAdmin(req)
  if (!auth.ok) return auth.response

  const { id: rechargeId } = await ctx.params
  if (!rechargeId || !/^[0-9a-f-]{36}$/i.test(rechargeId)) {
    return NextResponse.json({ success: false, error: 'invalid_id' }, { status: 400 })
  }

  let body: { reason?: string }
  try {
    body = await req.json()
  } catch {
    body = {}
  }
  const reason = body.reason?.trim()
  if (!reason || reason.length < 3) {
    return NextResponse.json({
      success: false,
      error: 'reason_required',
      message: 'Escribe el motivo de la anulación (mín. 3 caracteres).',
    }, { status: 400 })
  }

  const recharge = await maybeOne<RechargeRow>(
    `SELECT id, driver_id, amount::text, status, method
       FROM driver_recharges WHERE id = $1 LIMIT 1`,
    [rechargeId],
  )
  if (!recharge) {
    return NextResponse.json({ success: false, error: 'not_found' }, { status: 404 })
  }
  if (recharge.status === 'refunded') {
    return NextResponse.json({ success: true, noop: true, message: 'La recarga ya estaba anulada.' })
  }
  if (recharge.status !== 'completed') {
    return NextResponse.json({
      success: false,
      error: 'invalid_state',
      message: `Solo se pueden anular recargas en estado 'completed' (actual: ${recharge.status}).`,
    }, { status: 400 })
  }

  const amount = Number(recharge.amount)
  if (!Number.isFinite(amount) || amount <= 0) {
    return NextResponse.json({ success: false, error: 'invalid_amount' }, { status: 500 })
  }

  try {
    await tx(async (client) => {
      // Lock del driver para serializar contra otros débitos/recargas concurrentes
      await client.query(
        `SELECT pg_advisory_xact_lock(hashtextextended($1, 42))`,
        [recharge.driver_id],
      )
      // Balance actual (postgres function que suma todas las wallet_transactions)
      const balRes = await client.query<{ balance: string }>(
        'SELECT rapi_team_user_balance($1)::text AS balance',
        [recharge.driver_id],
      )
      const currentBalance = Number(balRes.rows[0]?.balance ?? 0)
      const balanceAfter = Math.round((currentBalance - amount) * 100) / 100
      // Insertar el debit
      await client.query(
        `INSERT INTO wallet_transactions
           (user_id, type, amount, balance_after, description, status, external_ref, metadata, completed_at)
         VALUES ($1, 'debit', $2, $3, $4, 'completed', $5, $6, now())`,
        [
          recharge.driver_id,
          amount,
          balanceAfter,
          `Anulación de recarga: ${reason}`,
          rechargeId,
          JSON.stringify({
            refundOf: rechargeId,
            adminId: auth.userId,
            originalMethod: recharge.method,
            reason,
          }),
        ],
      )
      // Marcar la recarga como refunded
      await client.query(
        `UPDATE driver_recharges
            SET status = 'refunded',
                notes = COALESCE(notes, '') || CASE WHEN notes IS NULL OR notes = '' THEN '' ELSE E'\n' END || $1,
                updated_at = now()
          WHERE id = $2`,
        [`[ANULADA por admin ${auth.userId}]: ${reason}`, rechargeId],
      )
    })
  } catch (e) {
    console.error('[admin/recharges/refund] tx error:', e)
    return NextResponse.json({ success: false, error: 'refund_failed' }, { status: 500 })
  }

  await query(
    `INSERT INTO auth_events (user_id, event_type, provider, ip_address, user_agent, metadata)
     VALUES ($1, 'admin_refund_recharge', 'admin', $2, $3, $4)`,
    [
      auth.userId,
      getClientIp(req),
      req.headers.get('user-agent'),
      JSON.stringify({ rechargeId, driverId: recharge.driver_id, amount, reason }),
    ],
  )

  return NextResponse.json({ success: true, rechargeId, refundedAmount: amount })
}
