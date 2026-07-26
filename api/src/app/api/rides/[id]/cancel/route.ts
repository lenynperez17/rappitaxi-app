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
import { isUuid } from '@/lib/uuid'
import { sendPush } from '@/lib/send-push'

export const runtime = 'nodejs'

const NON_CANCELLABLE = ['completed', 'cancelled']

interface RideCore {
  id: string
  passenger_id: string | null
  driver_id: string | null
  status: string
  accepted_at: Date | null
  started_at: Date | null
  final_fare: string | null
  estimated_fare: string | null
}

export async function POST(req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response
  const { id } = await ctx.params
  if (!isUuid(id)) {
    return NextResponse.json({ success: false, error: 'invalid_id' }, { status: 400 })
  }

  let body: { reason?: string; reasonCode?: string } = {}
  try {
    body = await req.json()
  } catch {
    // reason es opcional; body vacío está bien
  }
  const reason = body.reason?.trim().slice(0, 500) || null
  // Ronda 246: código de motivo estructurado (para poder revisarlo en el panel
  // y agrupar estadísticas). El texto libre `reason` sigue siendo el detalle.
  const ALLOWED_REASON_CODES = new Set([
    'passenger_no_show',      // el pasajero no apareció
    'passenger_wrong_address',// dirección incorrecta / inaccesible
    'passenger_request',      // el pasajero pidió cancelar
    'vehicle_issue',          // avería / problema mecánico
    'traffic_or_road',        // vía bloqueada, tráfico extremo
    'safety_concern',         // motivo de seguridad
    'personal_emergency',     // emergencia personal
    'too_far',                // el punto quedaba demasiado lejos
    'price_disagreement',     // desacuerdo con la tarifa
    'other',
  ])
  const reasonCode =
    typeof body.reasonCode === 'string' && ALLOWED_REASON_CODES.has(body.reasonCode.trim())
      ? body.reasonCode.trim()
      : null

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
        `SELECT id, passenger_id, driver_id, status, accepted_at, started_at,
                final_fare::text, estimated_fare::text
           FROM rides WHERE id = $1 FOR UPDATE`,
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

      // Ronda 20 HIGH#2: reglas de cancelación por estado + cancel fee.
      //   - status='in_progress' → CERRAR el ride via /complete, no /cancel.
      //     Passenger no puede cancelar un ride en curso sin cargo; obligamos
      //     al driver a marcar complete con final_fare o al admin a intervenir.
      //   - status='arrived' + passenger cancela → cancel_fee S/2 (driver estuvo
      //     en el punto, gastó combustible). Admin puede eximir con reason='dispute'.
      //   - status='accepted' o 'on_way' + passenger cancela > 2min desde accepted
      //     → cancel_fee S/2 (compensación al driver por reserva).
      //   - Driver cancela cualquier estado → sin fee (política empresa: el driver
      //     se penaliza en su rating, no monetariamente).
      // ---------------------------------------------------------------
      // Ronda 246: penalidad al CONDUCTOR que cancela (modelo tipo inDriver)
      // ---------------------------------------------------------------
      // Antes, un conductor podía cancelar cuantos viajes quisiera sin coste
      // alguno ("se penaliza en su rating"), lo que en la práctica no penaliza
      // nada: aceptaba viajes y los soltaba sin consecuencia, dejando al
      // pasajero tirado. Ahora se le descuenta un porcentaje de la tarifa y
      // queda PENDIENTE DE REVISIÓN: el conductor declara un motivo y un
      // admin decide desde el panel si se lo devuelve.
      //
      // Motivos que el conductor puede alegar (los "justificables" igualmente
      // se cobran de entrada y se marcan para revisión; el admin decide).
      const DRIVER_PENALTY_RATE = 0.12 // 12% de la tarifa estimada
      const DRIVER_PENALTY_MIN = 1.00
      const DRIVER_PENALTY_MAX = 10.00

      let driverPenalty = 0
      let penaltyReviewStatus: 'none' | 'pending' = 'none'

      if (isDriver && !isAdmin) {
        // Solo penalizamos si el conductor ya se había comprometido con el
        // viaje (aceptado en adelante). Rechazar antes de aceptar no penaliza.
        const compromisoEstados = new Set(['accepted', 'on_way', 'arrived', 'in_progress'])
        if (compromisoEstados.has(ride.status)) {
          const base = Number(ride.estimated_fare ?? 0)
          const raw = base > 0 ? base * DRIVER_PENALTY_RATE : DRIVER_PENALTY_MIN
          driverPenalty = Math.min(
            DRIVER_PENALTY_MAX,
            Math.max(DRIVER_PENALTY_MIN, Math.round(raw * 100) / 100),
          )
          // Toda penalidad nace "pendiente de revisión": el conductor dio un
          // motivo y el equipo lo evalúa desde el panel para devolvérsela.
          penaltyReviewStatus = 'pending'
        }
      }

      const CANCEL_FEE = 2.00
      let cancelFee = 0
      if (isPassenger && !isAdmin) {
        if (ride.status === 'in_progress') {
          throw {
            code: 'invalid_status',
            message: 'No puedes cancelar un viaje en curso. Contacta al conductor o soporte.',
          }
        }
        if (ride.status === 'arrived') {
          cancelFee = CANCEL_FEE
        } else if ((ride.status === 'accepted' || ride.status === 'on_way') && ride.accepted_at) {
          const minsSinceAccept = (Date.now() - new Date(ride.accepted_at).getTime()) / 60_000
          if (minsSinceAccept > 2) cancelFee = CANCEL_FEE
        }
      }
      // In-progress rides solo cancelables por admin (o driver en emergencia)
      if (ride.status === 'in_progress' && !isAdmin && !isDriver) {
        throw { code: 'invalid_status', message: 'Solo el conductor o soporte pueden cerrar un viaje en curso.' }
      }

      // Ronda 76: NO poner cancelFee en final_fare — contaminaría reports GMV
      // que suman SUM(final_fare) FROM rides. La fee vive solo en
      // wallet_transactions (audit trail) + metadata del ride. Además drivers
      // veian final_fare=2.00 creyendo que les tocaba comisión sobre eso.
      await client.query(
        `UPDATE rides
            SET status = 'cancelled',
                cancelled_by = $1,
                cancelled_reason = $2,
                cancel_reason_code = $5,
                cancel_penalty_amount = $6::numeric,
                penalty_review_status = $7,
                completed_at = now(),
                final_fare = NULL,
                metadata = COALESCE(metadata, '{}'::jsonb)
                         || jsonb_build_object(
                              'cancellationFee', $3::numeric,
                              'driverPenalty', $6::numeric,
                              'cancelReasonCode', $5::text
                            )
          WHERE id = $4`,
        [
          auth.userId,
          reason,
          cancelFee > 0 ? cancelFee : 0,
          id,
          reasonCode,
          driverPenalty,
          penaltyReviewStatus,
        ],
      )

      // ---------------------------------------------------------------
      // Ronda 246: cobrar la penalidad al conductor que canceló.
      // Queda como transacción de tipo 'penalty' en su billetera, con el
      // motivo en metadata para que el panel pueda revisarla y devolverla.
      // ---------------------------------------------------------------
      if (driverPenalty > 0 && ride.driver_id) {
        await client.query(
          `SELECT pg_advisory_xact_lock(hashtextextended($1, 42))`,
          [ride.driver_id],
        )
        const drvBalRes = await client.query<{ balance: string }>(
          'SELECT rapi_team_user_balance($1)::text AS balance',
          [ride.driver_id],
        )
        const drvBalance = Number(drvBalRes.rows[0]?.balance ?? 0)
        await client.query(
          `INSERT INTO wallet_transactions
             (user_id, type, amount, balance_after, description, status, ride_id, completed_at, metadata)
           VALUES ($1, 'debit', $2, $3, $4, 'completed', $5, now(), $6::jsonb)`,
          [
            ride.driver_id,
            -driverPenalty,
            Math.round((drvBalance - driverPenalty) * 100) / 100,
            `Penalidad por cancelar viaje (S/${driverPenalty.toFixed(2)}) — en revisión`,
            id,
            JSON.stringify({
              kind: 'driver_cancel_penalty',
              reasonCode,
              reason,
              reviewStatus: 'pending',
              rideStatusAtCancel: ride.status,
            }),
          ],
        )
      }

      // Aplicar cancel fee al passenger si corresponde (via wallet debit).
      // Solo cobrable si el ride tenía wallet como payment method — para cash
      // el driver debe cobrar en persona (documentado en notification).
      //
      // Ronda 214 fixes:
      //   1) Quitamos el try/catch silencioso que hacía que si el INSERT
      //      wallet_transactions fallara (deadlock, FK, unique), la ride
      //      quedaba cancelada PERO la fee no se cobraba y nadie se enteraba.
      //      Ahora cualquier error aborta la tx entera (Postgres ROLLBACK
      //      revierte el UPDATE del ride status). El driver reintenta.
      //   2) Cuando el passenger no tiene saldo suficiente, en vez de solo
      //      log-warn, registramos la fee como pending_debit en el ledger
      //      (type='pending_debit', status='pending'). Migración 019 excluye
      //      pending_* del balance, pero el cron nocturno o la próxima
      //      recarga lo materializa. Antes: cancelaciones ilimitadas gratis
      //      → revenue leak de miles S/ mes sin trazabilidad.
      if (cancelFee > 0 && ride.passenger_id) {
        // Ronda 21 HIGH: advisory lock sobre passenger_id — sin esto, cancel de
        // ride A y complete de ride B del mismo passenger corren concurrentes,
        // leen mismo balance, insertan ambos wallet_transactions con
        // balance_after inconsistente.
        await client.query(
          `SELECT pg_advisory_xact_lock(hashtextextended($1, 42))`,
          [ride.passenger_id],
        )
        const balRes = await client.query<{ balance: string }>(
          'SELECT rapi_team_user_balance($1)::text AS balance',
          [ride.passenger_id],
        )
        const balance = Number(balRes.rows[0]?.balance ?? 0)
        if (balance >= cancelFee) {
          await client.query(
            `INSERT INTO wallet_transactions
               (user_id, type, amount, balance_after, description, status, ride_id, completed_at)
             VALUES ($1, 'debit', $2, $3, $4, 'completed', $5, now())`,
            [
              ride.passenger_id,
              -cancelFee,
              Math.round((balance - cancelFee) * 100) / 100,
              `Cancelación viaje ${id} (S/${cancelFee.toFixed(2)})`,
              id,
            ],
          )
        } else {
          // Deuda pendiente: se cobrará en la próxima recarga del passenger.
          // Ronda 214: antes solo se log-warn y la fee se PERDÍA. Ahora se
          // materializa en el ledger para que el cron/nueva recarga la cierre.
          await client.query(
            `INSERT INTO wallet_transactions
               (user_id, type, amount, description, status, ride_id, metadata)
             VALUES ($1, 'pending_debit', $2, $3, 'pending', $4, $5::jsonb)`,
            [
              ride.passenger_id,
              -cancelFee,
              `Cancelación viaje ${id} — pendiente por saldo insuficiente`,
              id,
              JSON.stringify({
                cancelFee,
                balanceAtCancel: balance,
                kind: 'cancel_fee_pending',
              }),
            ],
          )
          console.warn(`[rides/cancel] fee ${cancelFee} > balance ${balance} para user ${ride.passenger_id} — registrada como pending_debit`)
        }
      }

      // Liberar al driver: sin esto queda marcado como "ocupado" hasta que
      // corra el janitor del admin/live. Bloquea nuevas asignaciones del
      // panel y provoca "ghost busy" en dashboards.
      if (ride.driver_id) {
        await client.query(
          `UPDATE driver_presence
              SET active_ride_id = NULL, updated_at = now()
            WHERE driver_id = $1 AND active_ride_id = $2`,
          [ride.driver_id, id],
        )
      }

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
        driverPenalty,
        penaltyReviewStatus,
      }
    })

    await query(
      `INSERT INTO auth_events (user_id, event_type, provider, metadata)
       VALUES ($1, 'ride_cancelled', 'app', $2)`,
      [auth.userId, JSON.stringify({ rideId: id, reason, byAdmin: isAdmin })],
    )

    // Ronda 223: FCM push a las contrapartes que se notificaron.
    const wasPassenger = result.passengerId === auth.userId
    const wasDriver = result.driverId === auth.userId
    const pushRecipients: string[] = []
    const otherParty = wasPassenger ? result.driverId
      : wasDriver ? result.passengerId
      : result.passengerId ?? result.driverId
    if (otherParty) pushRecipients.push(otherParty)
    if (isAdmin) {
      const also = result.passengerId !== otherParty ? result.passengerId : result.driverId
      if (also && also !== otherParty) pushRecipients.push(also)
    }
    if (pushRecipients.length > 0) {
      void sendPush({
        userIds: pushRecipients,
        type: 'ride_cancelled',
        title: 'Viaje cancelado',
        body: result.reason ?? 'El viaje fue cancelado',
        data: { rideId: id, cancelledBy: auth.userId, reason: result.reason ?? '' },
        channel: 'rappi_rides',
        priority: 'high',
        persist: false,
      })
    }

    return NextResponse.json({
      success: true,
      rideId: result.rideId,
      cancelledBy: result.cancelledBy,
      reason: result.reason,
      // Ronda 246: el cliente muestra al conductor cuánto se le descontó y
      // que puede pedir revisión.
      driverPenalty: result.driverPenalty,
      penaltyReviewStatus: result.penaltyReviewStatus,
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
