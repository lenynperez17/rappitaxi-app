/**
 * PATCH /api/admin/cancellations/:id/review
 *   Body: { decision: 'approved' | 'rejected', notes?: string }
 *
 * Ronda 246: el equipo revisa la penalidad que se le cobró a un conductor por
 * cancelar un viaje.
 *
 *   - decision='approved' → el motivo era válido ⇒ SE LE DEVUELVE el dinero
 *     (crédito en su billetera) y se le notifica.
 *   - decision='rejected' → la penalidad se mantiene; solo se registra la
 *     decisión y se le notifica.
 *
 * Es idempotente: una penalidad ya revisada no se puede volver a revisar
 * (evita devolver el importe dos veces si el admin hace doble clic).
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAdmin } from '@/lib/admin-middleware'
import { getClientIp } from '@/lib/auth-middleware'
import { isUuid } from '@/lib/uuid'
import { query, tx } from '@/lib/db'
import { sendPush } from '@/lib/send-push'

export const runtime = 'nodejs'

interface RideRow {
  id: string
  driver_id: string | null
  cancel_penalty_amount: string | null
  penalty_review_status: string | null
  cancelled_reason: string | null
  cancel_reason_code: string | null
}

export async function PATCH(req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  const auth = await requireAdmin(req)
  if (!auth.ok) return auth.response

  const { id } = await ctx.params
  if (!isUuid(id)) {
    return NextResponse.json({ success: false, error: 'invalid_id' }, { status: 400 })
  }

  let body: { decision?: string; notes?: string }
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ success: false, error: 'bad_json' }, { status: 400 })
  }

  const decision = body.decision?.trim()
  if (decision !== 'approved' && decision !== 'rejected') {
    return NextResponse.json(
      { success: false, error: 'invalid_decision', message: "decision debe ser 'approved' o 'rejected'" },
      { status: 400 },
    )
  }
  const notes = body.notes?.trim().slice(0, 1000) || null
  // Rechazar exige justificación: el conductor tiene derecho a saber por qué
  // se le mantiene el descuento.
  if (decision === 'rejected' && !notes) {
    return NextResponse.json(
      { success: false, error: 'notes_required', message: 'Indica el motivo del rechazo' },
      { status: 400 },
    )
  }

  try {
    const result = await tx(async (client) => {
      const rideRes = await client.query<RideRow>(
        `SELECT id, driver_id, cancel_penalty_amount::text, penalty_review_status,
                cancelled_reason, cancel_reason_code
           FROM rides WHERE id = $1 FOR UPDATE`,
        [id],
      )
      const ride = rideRes.rows[0]
      if (!ride) throw { code: 'not_found', status: 404 }

      const penalty = Number(ride.cancel_penalty_amount ?? 0)
      if (penalty <= 0) {
        throw { code: 'no_penalty', status: 409, message: 'Este viaje no tiene penalidad que revisar' }
      }
      if (ride.penalty_review_status !== 'pending') {
        throw {
          code: 'already_reviewed',
          status: 409,
          message: `Esta penalidad ya fue revisada (${ride.penalty_review_status})`,
        }
      }

      await client.query(
        `UPDATE rides
            SET penalty_review_status = $1,
                penalty_reviewed_by = $2,
                penalty_reviewed_at = now(),
                penalty_review_notes = $3
          WHERE id = $4`,
        [decision, auth.userId, notes, id],
      )

      let refunded = 0
      if (decision === 'approved' && ride.driver_id) {
        // Devolver la penalidad: crédito en la billetera del conductor.
        await client.query(
          `SELECT pg_advisory_xact_lock(hashtextextended($1, 42))`,
          [ride.driver_id],
        )
        const balRes = await client.query<{ balance: string }>(
          'SELECT rapi_team_user_balance($1)::text AS balance',
          [ride.driver_id],
        )
        const balance = Number(balRes.rows[0]?.balance ?? 0)
        await client.query(
          `INSERT INTO wallet_transactions
             (user_id, type, amount, balance_after, description, status, ride_id, completed_at, metadata)
           VALUES ($1, 'credit', $2, $3, $4, 'completed', $5, now(), $6::jsonb)`,
          [
            ride.driver_id,
            penalty,
            Math.round((balance + penalty) * 100) / 100,
            `Devolución de penalidad por cancelación (S/${penalty.toFixed(2)})`,
            id,
            JSON.stringify({
              kind: 'driver_cancel_penalty_refund',
              reviewedBy: auth.userId,
              notes,
              originalReasonCode: ride.cancel_reason_code,
            }),
          ],
        )
        refunded = penalty
      }

      // Notificación in-app para el conductor.
      if (ride.driver_id) {
        await client.query(
          `INSERT INTO notifications (user_id, type, title, body, data)
           VALUES ($1, 'cancellation_review', $2, $3, $4::jsonb)`,
          [
            ride.driver_id,
            decision === 'approved' ? 'Penalidad devuelta' : 'Penalidad confirmada',
            decision === 'approved'
              ? `Revisamos tu cancelación y te devolvimos S/ ${penalty.toFixed(2)} a tu billetera.`
              : `Revisamos tu cancelación y la penalidad de S/ ${penalty.toFixed(2)} se mantiene.${notes ? ` Motivo: ${notes}` : ''}`,
            JSON.stringify({ rideId: id, decision, amount: penalty, notes }),
          ],
        )
      }

      return { driverId: ride.driver_id, penalty, refunded }
    })

    await query(
      `INSERT INTO auth_events (user_id, event_type, provider, ip_address, user_agent, metadata)
       VALUES ($1, 'admin_review_cancellation', 'admin', $2, $3, $4::jsonb)`,
      [
        result.driverId,
        getClientIp(req),
        req.headers.get('user-agent'),
        JSON.stringify({ rideId: id, decision, notes, refunded: result.refunded, reviewedBy: auth.userId }),
      ],
    )

    if (result.driverId) {
      void sendPush({
        userIds: [result.driverId],
        type: 'cancellation_review',
        title: decision === 'approved' ? 'Penalidad devuelta' : 'Penalidad confirmada',
        body: decision === 'approved'
          ? `Te devolvimos S/ ${result.penalty.toFixed(2)} a tu billetera.`
          : `La penalidad de S/ ${result.penalty.toFixed(2)} se mantiene.`,
        data: { rideId: id, decision, amount: result.penalty },
        channel: 'rappi_payments',
        priority: 'high',
        persist: false,
      })
    }

    return NextResponse.json({
      success: true,
      rideId: id,
      decision,
      penalty: result.penalty,
      refunded: result.refunded,
    })
  } catch (err) {
    const e = err as { code?: string; status?: number; message?: string }
    if (typeof e?.code === 'string' && typeof e?.status === 'number') {
      return NextResponse.json(
        { success: false, error: e.code, message: e.message },
        { status: e.status },
      )
    }
    console.error('[admin/cancellations/review] error:', err)
    return NextResponse.json({ success: false, error: 'internal_error' }, { status: 500 })
  }
}
