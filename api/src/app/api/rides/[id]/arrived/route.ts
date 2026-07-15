/**
 * POST /api/rides/:id/arrived
 *   Driver llegó al punto de recogida.
 *   UPDATE status='arrived'. Notificar passenger.
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { query, tx } from '@/lib/db'

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

  try {
    const result = await tx(async (client) => {
      const rideRes = await client.query<RideCore>(
        'SELECT id, passenger_id, driver_id, status FROM rides WHERE id = $1 FOR UPDATE',
        [id],
      )
      const ride = rideRes.rows[0]
      if (!ride) throw { code: 'not_found' }
      if (ride.driver_id !== auth.userId) throw { code: 'forbidden' }
      if (ride.status !== 'accepted' && ride.status !== 'on_way') {
        throw { code: 'invalid_status', message: `Estado actual: ${ride.status}` }
      }

      const updateRes = await client.query<RideCore>(
        `UPDATE rides
            SET status = 'arrived'
          WHERE id = $1
          RETURNING id, passenger_id, driver_id, status`,
        [id],
      )
      const updated = updateRes.rows[0]!

      if (updated.passenger_id) {
        await client.query(
          `INSERT INTO notifications (user_id, type, title, body, data)
           VALUES ($1, 'driver_arrived', $2, $3, $4)`,
          [
            updated.passenger_id,
            'Tu conductor llegó',
            'El conductor te está esperando en el punto de recogida',
            JSON.stringify({ rideId: id, driverId: auth.userId }),
          ],
        )
      }
      return updated
    })

    // Ronda 32 Bug#2: audit log non-blocking (mismo patrón que /start)
    try {
      await query(
        `INSERT INTO auth_events (user_id, event_type, provider, metadata)
         VALUES ($1, 'ride_driver_arrived', 'app', $2)`,
        [auth.userId, JSON.stringify({ rideId: id })],
      )
    } catch (auditErr) {
      console.warn('[rides/arrived] audit_events insert failed (non-blocking):', auditErr)
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
    console.error('[rides/arrived] error:', err)
    return NextResponse.json({ success: false, error: 'internal_error' }, { status: 500 })
  }
}
