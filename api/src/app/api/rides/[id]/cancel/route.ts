/**
 * POST /api/rides/:id/cancel
 *   Body: { reason? }
 *   Puede cancelar el passenger, driver o admin del viaje.
 *   UPDATE status='cancelled', cancelled_by=$userId, cancelled_reason=$reason, completed_at=now()
 *   Inserta notification a la contraparte.
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { maybeOne, query, tx } from '@/lib/db'

export const runtime = 'nodejs'

const NON_CANCELLABLE = ['completed', 'cancelled']

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

  let body: { reason?: string } = {}
  try {
    body = await req.json()
  } catch {
    // reason es opcional; body vacío está bien
  }
  const reason = body.reason?.trim().slice(0, 500) || null

  // Roles del user
  const requester = await maybeOne<{ is_admin: boolean; user_type: string }>(
    'SELECT is_admin, user_type FROM users WHERE id = $1',
    [auth.userId],
  )
  if (!requester) {
    return NextResponse.json({ success: false, error: 'user_not_found' }, { status: 401 })
  }
  const isAdmin = requester.is_admin || requester.user_type === 'admin'

  try {
    const result = await tx(async (client) => {
      const rideRes = await client.query<RideCore>(
        'SELECT id, passenger_id, driver_id, status FROM rides WHERE id = $1 FOR UPDATE',
        [id],
      )
      const ride = rideRes.rows[0]
      if (!ride) throw { code: 'not_found' }
      if (NON_CANCELLABLE.includes(ride.status)) {
        throw { code: 'invalid_status', message: `Estado actual: ${ride.status}` }
      }

      // Autorización
      const isPassenger = ride.passenger_id === auth.userId
      const isDriver = ride.driver_id === auth.userId
      if (!isPassenger && !isDriver && !isAdmin) {
        throw { code: 'forbidden' }
      }

      await client.query(
        `UPDATE rides
            SET status = 'cancelled',
                cancelled_by = $1,
                cancelled_reason = $2,
                completed_at = now()
          WHERE id = $3`,
        [auth.userId, reason, id],
      )

      // Notificar a la contraparte
      const otherPartyId =
        isPassenger ? ride.driver_id
        : isDriver ? ride.passenger_id
        : ride.passenger_id ?? ride.driver_id  // admin: notificar a ambos abajo si aplica

      if (otherPartyId) {
        await client.query(
          `INSERT INTO notifications (user_id, type, title, body, data)
           VALUES ($1, 'ride_cancelled', $2, $3, $4)`,
          [
            otherPartyId,
            'Viaje cancelado',
            reason ?? 'El viaje fue cancelado',
            JSON.stringify({ rideId: id, cancelledBy: auth.userId, reason }),
          ],
        )
      }

      // Si el admin canceló y ambos existen, notificar también al otro extremo
      if (isAdmin) {
        const also = ride.passenger_id !== otherPartyId ? ride.passenger_id : ride.driver_id
        if (also && also !== otherPartyId) {
          await client.query(
            `INSERT INTO notifications (user_id, type, title, body, data)
             VALUES ($1, 'ride_cancelled', $2, $3, $4)`,
            [
              also,
              'Viaje cancelado',
              reason ?? 'El viaje fue cancelado por soporte',
              JSON.stringify({ rideId: id, cancelledBy: auth.userId, reason, byAdmin: true }),
            ],
          )
        }
      }

      return {
        rideId: id,
        cancelledBy: auth.userId,
        reason,
        passengerId: ride.passenger_id,
        driverId: ride.driver_id,
      }
    })

    await query(
      `INSERT INTO auth_events (user_id, event_type, provider, metadata)
       VALUES ($1, 'ride_cancelled', 'app', $2)`,
      [auth.userId, JSON.stringify({ rideId: id, reason, byAdmin: isAdmin })],
    )

    return NextResponse.json({
      success: true,
      rideId: result.rideId,
      cancelledBy: result.cancelledBy,
      reason: result.reason,
    })
  } catch (err) {
    const knownCode = (err as { code?: string; message?: string })?.code
    if (knownCode === 'not_found') {
      return NextResponse.json({ success: false, error: 'not_found' }, { status: 404 })
    }
    if (knownCode === 'invalid_status') {
      return NextResponse.json(
        { success: false, error: 'invalid_status', message: (err as { message?: string }).message },
        { status: 409 },
      )
    }
    if (knownCode === 'forbidden') {
      return NextResponse.json({ success: false, error: 'forbidden' }, { status: 403 })
    }
    console.error('[rides/cancel] error:', err)
    return NextResponse.json({ success: false, error: 'internal_error' }, { status: 500 })
  }
}
