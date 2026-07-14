/**
 * POST /api/negotiations/:id/accept
 *
 * La contraparte acepta una oferta pendiente. Solo puede aceptarla el user
 * que NO propuso: si la oferta fue del passenger, solo el driver puede
 * aceptarla, y viceversa. Al aceptarla:
 *   - UPDATE ride_negotiations: status='accepted', responded_at=now()
 *   - UPDATE rides: estimated_fare=amount, status='accepted',
 *                   driver_id=(el driver que corresponda), accepted_at=now()
 *   - Notifica al proponente con type='negotiation_accepted'
 *   - Registra en auth_events el cambio de estado del ride
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
      // Bloqueo optimista sobre la fila de la negociación
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

      // Lock del ride para evitar race con otra aceptación paralela
      const rideRes = await client.query<{
        passenger_id: string | null
        driver_id: string | null
        status: string
      }>(
        `SELECT passenger_id, driver_id, status
           FROM rides
          WHERE id = $1
          FOR UPDATE`,
        [negotiation.ride_id],
      )
      const ride = rideRes.rows[0]
      if (!ride) throw { code: 'ride_not_found', status: 404 }

      // Solo la contraparte de quien propuso puede aceptar
      if (auth.userId === negotiation.proposed_by) {
        throw { code: 'cannot_accept_own_offer', status: 403 }
      }

      // Verificar el rol del caller (driver o passenger) desde `users`.
      // Un passenger NO puede aceptar una oferta del passenger (y viceversa),
      // y solo drivers/dual pueden aceptar ofertas de passenger.
      const callerRes = await client.query<{ user_type: string; is_active: boolean; suspended_at: Date | null }>(
        'SELECT user_type, is_active, suspended_at FROM users WHERE id = $1 AND deleted_at IS NULL',
        [auth.userId],
      )
      const caller = callerRes.rows[0]
      if (!caller) throw { code: 'user_not_found', status: 401 }
      if (!caller.is_active || caller.suspended_at) throw { code: 'account_disabled', status: 403 }

      // Determinar quién puede aceptar (la contraparte de quien propuso)
      let acceptorRole: 'passenger' | 'driver'
      let newDriverId: string | null
      if (negotiation.proposed_by_role === 'passenger') {
        // Propuso el passenger → acepta un driver.
        // El caller DEBE ser driver o dual, y opcionalmente haber postulado
        // (tener un ride_offer activo) — así evitamos IDOR de cualquier user
        // reclamando el viaje.
        if (caller.user_type !== 'driver' && caller.user_type !== 'dual') {
          throw { code: 'not_a_driver', status: 403 }
        }
        // Requerir un ride_offer del caller para este viaje (postulación previa)
        const offerRes = await client.query<{ id: string }>(
          `SELECT id FROM ride_offers
             WHERE ride_id = $1 AND driver_id = $2 AND status IN ('pending','accepted')`,
          [negotiation.ride_id, auth.userId],
        )
        if (offerRes.rowCount === 0) {
          throw { code: 'no_prior_offer', status: 403,
            message: 'Debes postularte al viaje primero (submitRideOffer) antes de aceptar una oferta del pasajero.' }
        }
        acceptorRole = 'driver'
        newDriverId = auth.userId
      } else {
        // Propuso el driver → acepta el passenger. Verifica que es EL passenger del ride.
        if (ride.passenger_id !== auth.userId) {
          throw { code: 'not_authorized', status: 403 }
        }
        acceptorRole = 'passenger'
        newDriverId = negotiation.proposed_by
      }

      // Ride debe estar aún en fase de negociación
      const allowedStates = new Set(['requested', 'searching'])
      if (!allowedStates.has(ride.status)) {
        throw { code: 'ride_not_negotiable', status: 409, currentStatus: ride.status }
      }

      // Si el ride ya tiene un driver distinto asignado, no permitir aceptar
      if (ride.driver_id && newDriverId && ride.driver_id !== newDriverId) {
        throw { code: 'ride_already_assigned', status: 409 }
      }

      const amount = Number(negotiation.amount)

      await client.query(
        `UPDATE ride_negotiations
            SET status = 'accepted', responded_at = now()
          WHERE id = $1`,
        [negotiationId],
      )

      // Marcar el resto de negociaciones pendientes de este ride como superseded
      await client.query(
        `UPDATE ride_negotiations
            SET status = 'superseded', responded_at = now()
          WHERE ride_id = $1 AND id <> $2 AND status = 'pending'`,
        [negotiation.ride_id, negotiationId],
      )

      await client.query(
        `UPDATE rides
            SET estimated_fare = $1,
                status = 'accepted',
                driver_id = COALESCE(driver_id, $2),
                accepted_at = now()
          WHERE id = $3`,
        [amount, newDriverId, negotiation.ride_id],
      )

      // Notificar al proponente
      await client.query(
        `INSERT INTO notifications (user_id, type, title, body, data)
         VALUES ($1, 'negotiation_accepted', $2, $3, $4::jsonb)`,
        [
          negotiation.proposed_by,
          'Oferta aceptada',
          `Tu oferta de S/ ${amount.toFixed(2)} fue aceptada`,
          JSON.stringify({
            rideId: negotiation.ride_id,
            negotiationId,
            amount,
            acceptedBy: auth.userId,
            acceptorRole,
          }),
        ],
      )

      // Auditoría del cambio de estado del ride
      await client.query(
        `INSERT INTO auth_events (user_id, event_type, metadata)
         VALUES ($1, 'ride_accepted', $2::jsonb)`,
        [
          auth.userId,
          JSON.stringify({
            rideId: negotiation.ride_id,
            negotiationId,
            amount,
            via: 'negotiation',
          }),
        ],
      )

      return {
        rideId: negotiation.ride_id,
        amount,
        driverId: newDriverId,
      }
    })

    return NextResponse.json({
      success: true,
      negotiationId,
      rideId: result.rideId,
      amount: result.amount,
      driverId: result.driverId,
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
    console.error('[negotiations/accept] error:', err)
    return NextResponse.json({ success: false, error: 'internal_error' }, { status: 500 })
  }
}
