/**
 * POST /api/rides/:id/accept
 *   Driver acepta el viaje.
 *   - Verifica que auth.userId es driver (user_type in ('driver','dual'))
 *   - Verifica que ride está en 'requested' o 'searching'
 *   - UPDATE ride SET driver_id=$userId, status='accepted', accepted_at=now()
 *   - Inserta notification para el passenger + auth_event.
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { maybeOne, query, tx } from '@/lib/db'

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

  // Validar que el user autenticado sea driver o dual
  const driver = await maybeOne<{ user_type: string; full_name: string | null }>(
    'SELECT user_type, full_name FROM users WHERE id = $1',
    [auth.userId],
  )
  if (!driver) {
    return NextResponse.json({ success: false, error: 'user_not_found' }, { status: 401 })
  }
  if (driver.user_type !== 'driver' && driver.user_type !== 'dual') {
    return NextResponse.json(
      { success: false, error: 'forbidden', message: 'Solo un conductor puede aceptar' },
      { status: 403 },
    )
  }

  try {
    const result = await tx(async (client) => {
      const rideRes = await client.query<RideCore>(
        'SELECT id, passenger_id, driver_id, status FROM rides WHERE id = $1 FOR UPDATE',
        [id],
      )
      const ride = rideRes.rows[0]
      if (!ride) throw { code: 'not_found' }
      if (ride.status !== 'requested' && ride.status !== 'searching') {
        throw { code: 'invalid_status', message: `Estado actual: ${ride.status}` }
      }
      if (ride.driver_id && ride.driver_id !== auth.userId) {
        throw { code: 'already_taken' }
      }

      const updateRes = await client.query<RideCore>(
        `UPDATE rides
            SET driver_id = $1,
                status = 'accepted',
                accepted_at = now()
          WHERE id = $2
          RETURNING id, passenger_id, driver_id, status`,
        [auth.userId, id],
      )
      const updated = updateRes.rows[0]!

      // Notificar al passenger
      if (updated.passenger_id) {
        await client.query(
          `INSERT INTO notifications (user_id, type, title, body, data)
           VALUES ($1, 'ride_accepted', $2, $3, $4)`,
          [
            updated.passenger_id,
            'Tu conductor está en camino',
            driver.full_name
              ? `${driver.full_name} aceptó tu viaje`
              : 'Un conductor aceptó tu viaje',
            JSON.stringify({ rideId: id, driverId: auth.userId }),
          ],
        )
      }
      return updated
    })

    // Auditoría fuera de la transacción
    await query(
      `INSERT INTO auth_events (user_id, event_type, provider, metadata)
       VALUES ($1, 'ride_accepted', 'app', $2)`,
      [auth.userId, JSON.stringify({ rideId: id, passengerId: result.passenger_id })],
    )

    return NextResponse.json({
      success: true,
      ride: {
        id: result.id,
        passengerId: result.passenger_id,
        driverId: result.driver_id,
        status: result.status,
      },
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
    if (knownCode === 'already_taken') {
      return NextResponse.json(
        { success: false, error: 'already_taken', message: 'Otro conductor ya tomó este viaje' },
        { status: 409 },
      )
    }
    console.error('[rides/accept] error:', err)
    return NextResponse.json({ success: false, error: 'internal_error' }, { status: 500 })
  }
}
