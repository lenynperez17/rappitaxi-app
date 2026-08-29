/**
 * POST /api/admin/trips/{id}/assign — asignar un conductor a un viaje.
 * Body: { driverId: string }
 *
 * Ronda 283. Desde el panel se podía CREAR un viaje eligiendo conductor, pero
 * no asignárselo a un viaje que ya existía. Si alguien pedía un coche y nadie
 * lo aceptaba, no había forma de decir "que vaya Juan": el viaje se quedaba
 * esperando hasta caducar.
 *
 * QUÉ SIGNIFICA ASIGNAR
 * ---------------------
 * El viaje queda aceptado a nombre de ese conductor, igual que si lo hubiera
 * aceptado él. Es lo que hace falta en una central: alguien llama por teléfono
 * y quien atiende decide quién va.
 *
 * Y se le avisa. Asignar en silencio sería dejarle un viaje a alguien que no
 * se entera: le llega push con sonido y prioridad alta, y la fila en
 * `notifications` que su app recoge por el stream aunque el push se pierda.
 *
 * NO se le cobra ni se le penaliza nada por esto, y no se toca su saldo: la
 * comisión se aplica al completar el viaje, como en cualquier otro.
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAdmin } from '@/lib/admin-middleware'
import { tx } from '@/lib/db'
import { sendPush } from '@/lib/send-push'

export const runtime = 'nodejs'
export const dynamic = 'force-dynamic'

/**
 * Estados a los que se le puede poner conductor. Un viaje ya aceptado, en
 * curso, terminado o cancelado no se reasigna desde aquí: eso es otra
 * operación y con otras consecuencias (hay un conductor al que avisar de que
 * se le quitó el viaje).
 */
const ASIGNABLES = ['requested', 'searching', 'no_drivers']

function isUuid(v: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v)
}

export async function POST(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const auth = await requireAdmin(req)
  if (!auth.ok) return auth.response

  const { id } = await params
  if (!isUuid(id)) {
    return NextResponse.json({ success: false, error: 'invalid_id' }, { status: 400 })
  }

  let body: { driverId?: string }
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ success: false, error: 'bad_json' }, { status: 400 })
  }

  const driverId = typeof body.driverId === 'string' ? body.driverId.trim() : ''
  if (!driverId) {
    return NextResponse.json(
      { success: false, error: 'driver_required', message: 'Falta el conductor.' },
      { status: 400 },
    )
  }

  try {
    const resultado = await tx(async (client) => {
      // El viaje, bloqueado: sin esto, dos personas del panel asignando a la
      // vez dejarían al segundo conductor pisando al primero.
      const rideRes = await client.query<{
        id: string
        status: string
        driver_id: string | null
        passenger_id: string | null
        pickup_address: string | null
        estimated_fare: string | null
      }>(
        `SELECT id, status, driver_id, passenger_id, pickup_address,
                estimated_fare::text
           FROM rides WHERE id = $1 FOR UPDATE`,
        [id],
      )
      const ride = rideRes.rows[0]
      if (!ride) throw { code: 'not_found' }

      if (ride.driver_id) throw { code: 'already_assigned' }
      if (!ASIGNABLES.includes(ride.status)) {
        throw { code: 'invalid_status', status: ride.status }
      }

      // El conductor: tiene que poder conducir de verdad. Se comprueba aquí y
      // no solo en el panel porque el panel manda un id y nada impide que sea
      // el de una cuenta que no debería.
      const drvRes = await client.query<{
        user_type: string; is_verified: boolean; is_active: boolean
        suspended_at: Date | null; deleted_at: Date | null; full_name: string | null
      }>(
        `SELECT user_type, is_verified, is_active, suspended_at, deleted_at, full_name
           FROM users WHERE id = $1`,
        [driverId],
      )
      const drv = drvRes.rows[0]
      if (!drv || drv.deleted_at) throw { code: 'driver_not_found' }
      // Ronda 282: quien conduce es 'dual'. Ver la migración 027.
      if (drv.user_type !== 'dual') throw { code: 'not_a_driver' }
      if (!drv.is_verified) throw { code: 'driver_not_verified' }
      if (!drv.is_active || drv.suspended_at) throw { code: 'driver_suspended' }

      await client.query(
        `UPDATE rides
            SET driver_id = $2, status = 'accepted', accepted_at = now()
          WHERE id = $1`,
        [id, driverId],
      )

      // Las ofertas que seguían abiertas para otros conductores ya no valen:
      // si no, otro podría aceptar un viaje que ya tiene dueño.
      await client.query(
        `UPDATE ride_offers SET status = 'expired', responded_at = now()
          WHERE ride_id = $1 AND status = 'pending'`,
        [id],
      )

      return { ride, driverName: drv.full_name }
    })

    // Fuera de la transacción: que un fallo del push no deshaga una asignación
    // que en la base de datos ya es correcta.
    const donde = resultado.ride.pickup_address ?? 'el punto de recogida'
    try {
      await sendPush({
        userIds: [driverId],
        type: 'ride_assigned',
        title: 'Se te asignó un viaje',
        body: `Recoge en ${donde}`,
        data: { rideId: id, assignedByAdmin: 'true' },
        channel: 'rappi_rides',
        sound: 'ride_accepted',
        priority: 'high',
      })
    } catch (err) {
      console.error('[admin/trips/assign] no se pudo avisar al conductor:', err)
    }

    // Al pasajero también: pidió un coche y ahora tiene uno.
    if (resultado.ride.passenger_id) {
      try {
        await sendPush({
          userIds: [resultado.ride.passenger_id],
          type: 'ride_accepted',
          title: 'Tu conductor está en camino',
          body: resultado.driverName
            ? `${resultado.driverName} atenderá tu viaje`
            : 'Un conductor atenderá tu viaje',
          data: { rideId: id },
          channel: 'rappi_rides',
          sound: 'ride_accepted',
          priority: 'high',
        })
      } catch (err) {
        console.error('[admin/trips/assign] no se pudo avisar al pasajero:', err)
      }
    }

    return NextResponse.json({ success: true, rideId: id, driverId })
  } catch (err) {
    const code = (err as { code?: string })?.code
    const mensajes: Record<string, { msg: string; status: number }> = {
      not_found: { msg: 'Ese viaje ya no existe.', status: 404 },
      already_assigned: { msg: 'Ese viaje ya tiene conductor.', status: 409 },
      invalid_status: {
        msg: `Ese viaje ya no admite conductor (estado: ${(err as { status?: string })?.status}).`,
        status: 409,
      },
      driver_not_found: { msg: 'Ese conductor no existe.', status: 404 },
      not_a_driver: { msg: 'Esa cuenta no es de conductor.', status: 400 },
      driver_not_verified: { msg: 'Ese conductor no tiene el alta aprobada.', status: 409 },
      driver_suspended: { msg: 'Ese conductor está suspendido.', status: 409 },
    }
    const m = code ? mensajes[code] : undefined
    if (m) {
      return NextResponse.json({ success: false, error: code, message: m.msg }, { status: m.status })
    }
    console.error('[admin/trips/assign] error:', err)
    return NextResponse.json({ success: false, error: 'assign_failed' }, { status: 500 })
  }
}
