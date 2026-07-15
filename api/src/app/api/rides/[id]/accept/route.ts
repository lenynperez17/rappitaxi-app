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
      // Prevenir self-ride: un usuario `dual` NO puede aceptar su propio ride.
      // Sin este check, podía crear ride como passenger, aceptar como driver,
      // completarlo, y auto-rating de 5⭐ para farm de reputación (wash-trading).
      if (ride.passenger_id === auth.userId) {
        throw { code: 'cannot_accept_own_ride' }
      }

      // Prevenir double-booking (Ronda 24 Bug#2): materializar la fila
      // driver_presence ANTES del SELECT FOR UPDATE. Sin esto, drivers que
      // nunca fueron online no tenían fila → FOR UPDATE no bloqueaba nada
      // → dos requests concurrentes pasaban ambos el check y aceptaban dos
      // rides distintos. INSERT ... ON CONFLICT DO NOTHING crea la fila
      // vacía si falta, luego el FOR UPDATE bloquea correctamente.
      await client.query(
        `INSERT INTO driver_presence (driver_id, is_online, updated_at)
         VALUES ($1, false, now())
         ON CONFLICT (driver_id) DO NOTHING`,
        [auth.userId],
      )
      const busyRes = await client.query<{ active_ride_id: string | null; is_online: boolean }>(
        `SELECT active_ride_id, is_online FROM driver_presence
          WHERE driver_id = $1 FOR UPDATE`,
        [auth.userId],
      )
      const activeRide = busyRes.rows[0]?.active_ride_id
      if (activeRide && activeRide !== id) {
        throw { code: 'driver_busy', activeRideId: activeRide }
      }
      // Ronda 85: rechazar si el driver no está online. Antes: push antiguo o
      // replay hacía que un driver offline aceptara un ride → passenger espera
      // a alguien que no aparecerá porque el matcher lo excluye por is_online=false.
      if (!busyRes.rows[0]?.is_online) {
        throw { code: 'driver_offline', message: 'Debes estar en línea para aceptar viajes' }
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

      // Marcar al driver como ocupado con este ride.
      await client.query(
        `INSERT INTO driver_presence (driver_id, active_ride_id, updated_at, last_heartbeat)
         VALUES ($1, $2, now(), now())
         ON CONFLICT (driver_id) DO UPDATE
           SET active_ride_id = EXCLUDED.active_ride_id, updated_at = now()`,
        [auth.userId, id],
      )

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
    if (knownCode === 'driver_busy') {
      const e = err as { activeRideId?: string }
      return NextResponse.json(
        {
          success: false,
          error: 'driver_busy',
          message: 'Ya tienes un viaje activo. Complétalo o cancélalo antes de aceptar otro.',
          activeRideId: e.activeRideId,
        },
        { status: 409 },
      )
    }
    if (knownCode === 'cannot_accept_own_ride') {
      return NextResponse.json(
        { success: false, error: 'cannot_accept_own_ride',
          message: 'No puedes aceptar tu propio viaje como conductor.' },
        { status: 403 },
      )
    }
    if (knownCode === 'driver_offline') {
      return NextResponse.json(
        { success: false, error: 'driver_offline',
          message: 'Debes estar en línea para aceptar viajes.' },
        { status: 403 },
      )
    }
    console.error('[rides/accept] error:', err)
    return NextResponse.json({ success: false, error: 'internal_error' }, { status: 500 })
  }
}
