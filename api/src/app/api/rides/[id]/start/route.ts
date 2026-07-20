/**
 * POST /api/rides/:id/start
 *   Driver marca "iniciado" (pasajero abordó).
 *   Verificar status='accepted' o 'arrived'.
 *   UPDATE status='in_progress', started_at=now().
 *   Notificar al passenger.
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { query, tx } from '@/lib/db'
import { isUuid } from '@/lib/uuid'
import { sendPush } from '@/lib/send-push'

export const runtime = 'nodejs'

interface RideCore {
  id: string
  passenger_id: string | null
  driver_id: string | null
  status: string
}

export async function POST(req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response
  const { id } = await ctx.params
  if (!isUuid(id)) {
    return NextResponse.json({ success: false, error: 'invalid_id' }, { status: 400 })
  }

  try {
    const result = await tx(async (client) => {
      const rideRes = await client.query<RideCore>(
        'SELECT id, passenger_id, driver_id, status FROM rides WHERE id = $1 FOR UPDATE',
        [id],
      )
      const ride = rideRes.rows[0]
      if (!ride) throw { code: 'not_found' }
      if (ride.driver_id !== auth.userId) throw { code: 'forbidden' }
      // Ronda 32 Bug#1: state machine consistente con /arrive — aceptar también
      // 'on_way'. Antes /arrive aceptaba accepted|on_way pero /start solo
      // accepted|arrived, obligando a un driver en 'on_way' a pasar por
      // 'arrived' antes de iniciar (aunque el arribo pudo ser skipeado por
      // el flujo real).
      if (!['accepted', 'on_way', 'arrived'].includes(ride.status)) {
        throw { code: 'invalid_status', message: `Estado actual: ${ride.status}` }
      }

      const updateRes = await client.query<RideCore>(
        `UPDATE rides
            SET status = 'in_progress',
                started_at = now()
          WHERE id = $1
          RETURNING id, passenger_id, driver_id, status`,
        [id],
      )
      const updated = updateRes.rows[0]!

      if (updated.passenger_id) {
        await client.query(
          `INSERT INTO notifications (user_id, type, title, body, data)
           VALUES ($1, 'ride_started', $2, $3, $4)`,
          [
            updated.passenger_id,
            'Viaje iniciado',
            'Estás en camino a tu destino',
            JSON.stringify({ rideId: id, driverId: auth.userId }),
          ],
        )
      }
      return updated
    })

    // Ronda 32 Bug#2: audit log en try-catch silencioso. Si el INSERT falla
    // (constraint/DB glitch), NO devolver 500 porque el UPDATE del ride ya se
    // commiteó — un 500 provoca que el cliente reintente y reciba 409
    // (status ya cambió), quedando UI desincronizada.
    try {
      await query(
        `INSERT INTO auth_events (user_id, event_type, provider, metadata)
         VALUES ($1, 'ride_started', 'app', $2)`,
        [auth.userId, JSON.stringify({ rideId: id })],
      )
    } catch (auditErr) {
      console.warn('[rides/start] audit_events insert failed (non-blocking):', auditErr)
    }

    // Ronda 223: FCM push al passenger.
    if (result.passenger_id) {
      void sendPush({
        userIds: [result.passenger_id],
        type: 'ride_started',
        title: 'Viaje iniciado',
        body: 'Estás en camino a tu destino',
        data: { rideId: id, driverId: auth.userId },
        channel: 'rappi_rides',
        priority: 'high',
        persist: false,
      })
    }

    return NextResponse.json({
      success: true,
      ride: {
        id: result.id,
        status: result.status,
        driverId: result.driver_id,
        passengerId: result.passenger_id,
      },
    })
  } catch (err) {
    const knownCode = (err as { code?: string; message?: string })?.code
    if (knownCode === 'not_found') {
      return NextResponse.json({ success: false, error: 'not_found' }, { status: 404 })
    }
    if (knownCode === 'forbidden') {
      return NextResponse.json({ success: false, error: 'forbidden' }, { status: 403 })
    }
    if (knownCode === 'invalid_status') {
      return NextResponse.json(
        { success: false, error: 'invalid_status', message: (err as { message?: string }).message },
        { status: 409 },
      )
    }
    console.error('[rides/start] error:', err)
    return NextResponse.json({ success: false, error: 'internal_error' }, { status: 500 })
  }
}
