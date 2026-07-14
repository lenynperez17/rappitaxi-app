/**
 * POST /api/negotiations/:id/reject
 *
 * La contraparte rechaza una oferta pendiente. Solo puede rechazarla el user
 * que NO propuso (mismo criterio que accept). Actualiza:
 *   - ride_negotiations: status='rejected', responded_at=now()
 * Notifica al proponente con type='negotiation_rejected'.
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { tx } from '@/lib/db'

export const runtime = 'nodejs'

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

export async function POST(
  req: NextRequest,
  ctx: { params: Promise<{ id: string }> },
) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  const { id: negotiationId } = await ctx.params
  if (!UUID_RE.test(negotiationId)) {
    return NextResponse.json({ success: false, error: 'invalid_negotiation_id' }, { status: 400 })
  }

  try {
    const result = await tx(async (client) => {
      const negRes = await client.query<{
        id: string
        ride_id: string
        proposed_by: string
        proposed_by_role: 'passenger' | 'driver'
        amount: string
        status: string
      }>(
        `SELECT id, ride_id, proposed_by, proposed_by_role, amount, status
           FROM ride_negotiations
          WHERE id = $1
          FOR UPDATE`,
        [negotiationId],
      )
      const negotiation = negRes.rows[0]
      if (!negotiation) throw { code: 'not_found', status: 404 }
      if (negotiation.status !== 'pending') {
        throw { code: 'not_pending', status: 409, currentStatus: negotiation.status }
      }

      // Cargar ride solo para validar autorización
      const rideRes = await client.query<{
        passenger_id: string | null
        driver_id: string | null
      }>('SELECT passenger_id, driver_id FROM rides WHERE id = $1', [negotiation.ride_id])
      const ride = rideRes.rows[0]
      if (!ride) throw { code: 'ride_not_found', status: 404 }

      // Solo la contraparte de quien propuso puede rechazar
      if (auth.userId === negotiation.proposed_by) {
        throw { code: 'cannot_reject_own_offer', status: 403 }
      }

      // Verificar rol y estado del caller
      const callerRes = await client.query<{ user_type: string; is_active: boolean; suspended_at: Date | null }>(
        'SELECT user_type, is_active, suspended_at FROM users WHERE id = $1 AND deleted_at IS NULL',
        [auth.userId],
      )
      const caller = callerRes.rows[0]
      if (!caller) throw { code: 'user_not_found', status: 401 }
      if (!caller.is_active || caller.suspended_at) throw { code: 'account_disabled', status: 403 }

      if (negotiation.proposed_by_role === 'passenger') {
        // Rechaza un driver. Debe ser driver o dual, y tener un ride_offer
        // previo para este ride (haber postulado) — igual que en accept.
        if (caller.user_type !== 'driver' && caller.user_type !== 'dual') {
          throw { code: 'not_a_driver', status: 403 }
        }
        const offerRes = await client.query<{ id: string }>(
          `SELECT id FROM ride_offers
             WHERE ride_id = $1 AND driver_id = $2 AND status IN ('pending','accepted')`,
          [negotiation.ride_id, auth.userId],
        )
        if (offerRes.rowCount === 0) {
          throw { code: 'no_prior_offer', status: 403,
            message: 'Debes postularte al viaje primero para poder rechazar ofertas.' }
        }
      } else {
        // Rechaza el passenger — debe ser el passenger del ride
        if (ride.passenger_id !== auth.userId) {
          throw { code: 'not_authorized', status: 403 }
        }
      }

      await client.query(
        `UPDATE ride_negotiations
            SET status = 'rejected', responded_at = now()
          WHERE id = $1`,
        [negotiationId],
      )

      const amount = Number(negotiation.amount)

      await client.query(
        `INSERT INTO notifications (user_id, type, title, body, data)
         VALUES ($1, 'negotiation_rejected', $2, $3, $4::jsonb)`,
        [
          negotiation.proposed_by,
          'Oferta rechazada',
          `Tu oferta de S/ ${amount.toFixed(2)} fue rechazada`,
          JSON.stringify({
            rideId: negotiation.ride_id,
            negotiationId,
            amount,
            rejectedBy: auth.userId,
          }),
        ],
      )

      return { rideId: negotiation.ride_id, amount }
    })

    return NextResponse.json({
      success: true,
      negotiationId,
      rideId: result.rideId,
      amount: result.amount,
    })
  } catch (err) {
    const e = err as { code?: string; status?: number; currentStatus?: string }
    if (typeof e?.code === 'string' && typeof e?.status === 'number') {
      return NextResponse.json(
        {
          success: false,
          error: e.code,
          ...(e.currentStatus ? { currentStatus: e.currentStatus } : {}),
        },
        { status: e.status },
      )
    }
    console.error('[negotiations/reject] error:', err)
    return NextResponse.json({ success: false, error: 'internal_error' }, { status: 500 })
  }
}
