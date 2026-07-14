/**
 * POST /api/offers/:id/accept
 *
 * El passenger acepta una oferta de un driver. Efectos atómicos:
 *   - ride_offers: la oferta aceptada → status='accepted', responded_at=now()
 *   - Resto de ofertas del mismo ride pending → status='rejected'
 *   - rides: driver_id=offer.driver_id, estimated_fare=offer.amount,
 *            status='accepted', accepted_at=now()
 *   - Notifica al driver aceptado con type='offer_accepted'
 *   - Notifica a los drivers rechazados con type='offer_rejected'
 *   - Auditoría en auth_events
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

  const { id: offerId } = await ctx.params
  if (!UUID_RE.test(offerId)) {
    return NextResponse.json({ success: false, error: 'invalid_offer_id' }, { status: 400 })
  }

  try {
    const result = await tx(async (client) => {
      const offerRes = await client.query<{
        id: string
        ride_id: string
        driver_id: string
        amount: string | null
        status: string
      }>(
        `SELECT id, ride_id, driver_id, amount, status
           FROM ride_offers
          WHERE id = $1
          FOR UPDATE`,
        [offerId],
      )
      const offer = offerRes.rows[0]
      if (!offer) throw { code: 'offer_not_found', status: 404 }
      if (offer.status !== 'pending') {
        throw { code: 'offer_not_pending', status: 409, currentStatus: offer.status }
      }

      const rideRes = await client.query<{
        passenger_id: string | null
        driver_id: string | null
        status: string
        estimated_fare: string | null
      }>(
        `SELECT passenger_id, driver_id, status, estimated_fare
           FROM rides
          WHERE id = $1
          FOR UPDATE`,
        [offer.ride_id],
      )
      const ride = rideRes.rows[0]
      if (!ride) throw { code: 'ride_not_found', status: 404 }
      if (ride.passenger_id !== auth.userId) {
        throw { code: 'not_ride_passenger', status: 403 }
      }

      const openStates = new Set(['requested', 'searching'])
      if (!openStates.has(ride.status)) {
        throw { code: 'ride_not_open', status: 409, currentStatus: ride.status }
      }
      if (ride.driver_id && ride.driver_id !== offer.driver_id) {
        throw { code: 'ride_already_assigned', status: 409 }
      }

      // Aceptar esta oferta
      await client.query(
        `UPDATE ride_offers
            SET status = 'accepted', responded_at = now()
          WHERE id = $1`,
        [offerId],
      )

      // Rechazar resto de ofertas pendientes del mismo ride
      const rejectedRes = await client.query<{ id: string; driver_id: string }>(
        `UPDATE ride_offers
            SET status = 'rejected', responded_at = now()
          WHERE ride_id = $1 AND id <> $2 AND status = 'pending'
          RETURNING id, driver_id`,
        [offer.ride_id, offerId],
      )

      // Determinar tarifa final: usa el amount de la oferta o preserva la existente
      const finalFare =
        offer.amount !== null ? Number(offer.amount) : (ride.estimated_fare !== null ? Number(ride.estimated_fare) : null)

      await client.query(
        `UPDATE rides
            SET driver_id = $1,
                estimated_fare = COALESCE($2, estimated_fare),
                status = 'accepted',
                accepted_at = now()
          WHERE id = $3`,
        [offer.driver_id, finalFare, offer.ride_id],
      )

      // Nombre del passenger para el push
      const paxRes = await client.query<{ name: string | null }>(
        `SELECT COALESCE(display_name, full_name) AS name FROM users WHERE id = $1`,
        [auth.userId],
      )
      const paxName = paxRes.rows[0]?.name ?? 'Pasajero'

      // Notificar al driver aceptado
      await client.query(
        `INSERT INTO notifications (user_id, type, title, body, data)
         VALUES ($1, 'offer_accepted', $2, $3, $4::jsonb)`,
        [
          offer.driver_id,
          'Oferta aceptada',
          `${paxName} aceptó tu oferta${finalFare !== null ? ` de S/ ${finalFare.toFixed(2)}` : ''}`,
          JSON.stringify({
            rideId: offer.ride_id,
            offerId,
            amount: finalFare,
            passengerId: auth.userId,
            passengerName: paxName,
          }),
        ],
      )

      // Notificar a los drivers rechazados
      for (const rejected of rejectedRes.rows) {
        await client.query(
          `INSERT INTO notifications (user_id, type, title, body, data)
           VALUES ($1, 'offer_rejected', $2, $3, $4::jsonb)`,
          [
            rejected.driver_id,
            'Oferta no seleccionada',
            'El pasajero eligió a otro conductor',
            JSON.stringify({
              rideId: offer.ride_id,
              offerId: rejected.id,
            }),
          ],
        )
      }

      // Auditoría
      await client.query(
        `INSERT INTO auth_events (user_id, event_type, metadata)
         VALUES ($1, 'ride_accepted', $2::jsonb)`,
        [
          auth.userId,
          JSON.stringify({
            rideId: offer.ride_id,
            offerId,
            driverId: offer.driver_id,
            amount: finalFare,
            via: 'offer',
          }),
        ],
      )

      return {
        rideId: offer.ride_id,
        driverId: offer.driver_id,
        amount: finalFare,
        rejectedCount: rejectedRes.rowCount ?? 0,
      }
    })

    return NextResponse.json({
      success: true,
      offerId,
      rideId: result.rideId,
      driverId: result.driverId,
      amount: result.amount,
      rejectedOffers: result.rejectedCount,
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
    console.error('[offers/accept] error:', err)
    return NextResponse.json({ success: false, error: 'internal_error' }, { status: 500 })
  }
}
