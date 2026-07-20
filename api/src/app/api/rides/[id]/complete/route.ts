/**
 * POST /api/rides/:id/complete
 *   Driver completa el viaje.
 *   Body: { finalFare, distanceMeters?, durationSeconds? }
 *   UPDATE status='completed', final_fare, completed_at=now().
 *   Si payment_method='wallet', cobrar de wallet_transactions
 *     (insertar type='debit' con amount negativo).
 *   Retorna { ride, walletDebit? }.
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { query, tx } from '@/lib/db'
import { isUuid } from '@/lib/uuid'
import { sendPush } from '@/lib/send-push'

export const runtime = 'nodejs'

interface RideRow {
  id: string
  passenger_id: string | null
  driver_id: string | null
  status: string
  payment_method: string | null
  estimated_fare: string | null
  final_fare: string | null
  distance_meters: number | null
  duration_seconds: number | null
  completed_at: Date | null
}

// Cap para prevenir wallet-drain: driver no puede cobrar más de 1.5x la
// estimación mostrada al passenger al aceptar el viaje. Si el trayecto real
// excede eso, debe abrirse disputa por soporte.
const FINAL_FARE_MAX_MULTIPLIER = 1.5

interface WalletTxRow {
  id: string
  amount: string
  type: string
  status: string
  balance_after: string | null
  created_at: Date
}

export async function POST(req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response
  const { id } = await ctx.params
  if (!isUuid(id)) {
    return NextResponse.json({ success: false, error: 'invalid_id' }, { status: 400 })
  }

  let body: {
    finalFare?: number
    distanceMeters?: number
    durationSeconds?: number
  } = {}
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ success: false, error: 'bad_json' }, { status: 400 })
  }

  const finalFare = Number(body.finalFare ?? 0)
  if (!isFinite(finalFare) || finalFare <= 0) {
    return NextResponse.json(
      { success: false, error: 'invalid_final_fare', message: 'finalFare debe ser > 0' },
      { status: 400 },
    )
  }
  const distanceMeters = typeof body.distanceMeters === 'number' && body.distanceMeters >= 0
    ? Math.round(body.distanceMeters)
    : null
  const durationSeconds = typeof body.durationSeconds === 'number' && body.durationSeconds >= 0
    ? Math.round(body.durationSeconds)
    : null

  try {
    const result = await tx(async (client) => {
      const rideRes = await client.query<RideRow>(
        'SELECT * FROM rides WHERE id = $1 FOR UPDATE',
        [id],
      )
      const ride = rideRes.rows[0]
      if (!ride) throw { code: 'not_found' }
      if (ride.driver_id !== auth.userId) throw { code: 'forbidden' }

      // Advisory locks de passenger + driver para serializar débitos y créditos
      // concurrentes. Ronda 214: antes se adquiría solo el lock del passenger
      // (dejando al driver sin lock → race en credit_after) Y los locks se
      // pedían en orden fijo passenger→driver, lo que causaba deadlock en modo
      // `dual` cuando dos usuarios eran passenger de un ride y driver del otro
      // simultáneamente (rideA: X passenger, Y driver; rideB: Y passenger, X
      // driver → 40P01).
      //
      // Fix: adquirir ambos locks al INICIO, ordenados ASC por hashtextextended
      // — así toda tx concurrente los pide en el mismo orden → no hay ciclo de
      // esperas → no hay deadlock (regla clásica de lock ordering).
      const lockIds: string[] = []
      if (ride.passenger_id) lockIds.push(ride.passenger_id)
      if (ride.driver_id && ride.driver_id !== ride.passenger_id) {
        lockIds.push(ride.driver_id)
      }
      if (lockIds.length > 0) {
        await client.query(
          `SELECT pg_advisory_xact_lock(hashtextextended(id, 42))
             FROM unnest($1::uuid[]) AS t(id)
             ORDER BY hashtextextended(t.id, 42) ASC`,
          [lockIds],
        )
      }

      // Solo permite completar rides que están `in_progress` — obliga a que
      // haya pasado por `start` (que a su vez requiere `arrived`). Sin esto,
      // un driver podía marcar arrived → complete directo, cobrando al
      // passenger un viaje que nunca empezó.
      if (ride.status !== 'in_progress') {
        throw { code: 'invalid_status', message: `El viaje debe estar en curso (in_progress) para completarse. Estado actual: ${ride.status}` }
      }

      // Aplicar descuento de vale si el passenger lo consumió con /vales/apply
      // pre-viaje (Ronda 18 HIGH#3). Sin este SELECT + resta, el vale se marcaba
      // "usado" pero el debit iba por el finalFare completo — el usuario perdía
      // el uso del vale sin recibir descuento.
      //
      // Ronda 214: quitamos el try/catch silencioso. Antes, si vale_usages
      // fallaba por CUALQUIER motivo (permission denied, tabla sin migrar,
      // lock timeout), el discount se hacía 0 y el passenger pagaba SIN
      // descuento sin saberlo. Ahora si falla, la tx aborta → mensaje claro al
      // usuario para que reintente. La tabla existe en TODOS los ambientes
      // desde la migración 019; el "si no existe" era un miedo obsoleto.
      const valeRes = await client.query<{ total: string }>(
        `SELECT COALESCE(SUM(discount_applied), 0)::text AS total
           FROM vale_usages WHERE ride_id = $1`,
        [id],
      )
      const valeDiscount = Number(valeRes.rows[0]?.total ?? 0)
      const adjustedFare = Math.max(0, Math.round((finalFare - valeDiscount) * 100) / 100)

      // Cap contra wallet-drain — 2 cotas:
      // 1) Si hay estimated_fare, cobrar más de 1.5× requiere disputa manual.
      // 2) Cap absoluto de S/ 750 SIEMPRE (incluso si estimated_fare es NULL).
      //    Sin esta cota segunda, un ride creado sin proposedFare (permitido)
      //    llegaba a complete con estimated=NULL → cap = infinito → wallet drain.
      const FINAL_FARE_ABS_CAP = 750
      const estimated = Number(ride.estimated_fare ?? 0)
      if (finalFare > FINAL_FARE_ABS_CAP) {
        throw {
          code: 'fare_exceeds_cap',
          message: `finalFare (${finalFare}) excede el máximo absoluto (S/ ${FINAL_FARE_ABS_CAP}).`,
          estimatedFare: estimated,
          maxAllowed: FINAL_FARE_ABS_CAP,
        }
      }
      if (estimated > 0) {
        const maxAllowed = estimated * FINAL_FARE_MAX_MULTIPLIER
        if (finalFare > maxAllowed) {
          throw {
            code: 'fare_exceeds_cap',
            message: `finalFare (${finalFare}) excede el máximo permitido (${maxAllowed.toFixed(2)})`,
            estimatedFare: estimated,
            maxAllowed,
          }
        }
      }

      const updateRes = await client.query<RideRow>(
        `UPDATE rides
            SET status = 'completed',
                final_fare = $1,
                distance_meters = COALESCE($2, distance_meters),
                duration_seconds = COALESCE($3, duration_seconds),
                completed_at = now()
          WHERE id = $4
          RETURNING *`,
        [finalFare, distanceMeters, durationSeconds, id],
      )
      const updated = updateRes.rows[0]!

      // Liberar al driver del active_ride_id — sin esto queda marcado ocupado
      // hasta el próximo heartbeat con activeRideId=null (que la app puede
      // no enviar) o hasta el janitor del admin/live.
      if (updated.driver_id) {
        await client.query(
          `UPDATE driver_presence
              SET active_ride_id = NULL, updated_at = now()
            WHERE driver_id = $1 AND active_ride_id = $2`,
          [updated.driver_id, id],
        )
      }

      // Ronda 199: leer commissionRate SIEMPRE (no solo para wallet) — se usa
      // también en cash para descontar la comisión de la plataforma al driver.
      const commissionRateRes = await client.query<{ value: unknown }>(
        `SELECT value FROM app_settings WHERE key = 'rides.commission_rate' LIMIT 1`,
      )
      const rawSettingVal = commissionRateRes.rows[0]?.value
      const rawRate = typeof rawSettingVal === 'number'
        ? rawSettingVal
        : Number(rawSettingVal)
      let commissionRate = 0.20
      if (Number.isFinite(rawRate) && rawRate >= 0 && rawRate <= 1) {
        commissionRate = rawRate
      } else if (rawSettingVal !== null && rawSettingVal !== undefined) {
        console.warn(
          `[rides/complete] app_settings.rides.commission_rate inválido (${String(rawSettingVal)}) — usando fallback 0.20. Corregir en admin.`,
        )
      }
      const commissionAmount = Math.round(adjustedFare * commissionRate * 100) / 100
      const driverEarning = Math.round((adjustedFare - commissionAmount) * 100) / 100

      // Cobro de wallet + contraparte de crédito al driver + comisión al platform.
      // Antes solo hacía el debit del passenger — desbalanceaba el libro contable:
      // el dinero del passenger "desaparecía" (SUM negativa) sin acreditar al driver.
      let walletDebit: WalletTxRow | null = null
      if (updated.payment_method === 'wallet' && updated.passenger_id) {
        // Balance actual del passenger
        const balRes = await client.query<{ balance: string }>(
          'SELECT rapi_team_user_balance($1)::text AS balance',
          [updated.passenger_id],
        )
        const currentBalance = Number(balRes.rows[0]?.balance ?? 0)
        // Cobro real = finalFare - descuento_vale (Ronda 18 HIGH#3)
        if (currentBalance < adjustedFare) {
          throw {
            code: 'insufficient_funds',
            message: 'Saldo insuficiente en wallet para completar el cobro',
            balance: currentBalance,
            required: adjustedFare,
          }
        }
        const newBalance = Math.round((currentBalance - adjustedFare) * 100) / 100

        // 1) DEBIT al passenger (dinero sale) — sobre adjustedFare
        const debitRes = await client.query<WalletTxRow>(
          `INSERT INTO wallet_transactions
             (user_id, type, amount, balance_after, description, status, ride_id, completed_at)
           VALUES ($1, 'debit', $2, $3, $4, 'completed', $5, now())
           RETURNING id, amount::text, type, status, balance_after::text, created_at`,
          [
            updated.passenger_id,
            -adjustedFare,
            newBalance,
            valeDiscount > 0
              ? `Cobro viaje ${id} (descuento vale S/${valeDiscount.toFixed(2)})`
              : `Cobro por viaje ${id}`,
            id,
          ],
        )
        walletDebit = debitRes.rows[0]!

        // 2) CREDIT al driver (netamente de la comisión) — cierra la doble entrada
        // Ronda 77: setear balance_after para audit trail contable. Antes NULL
        // rompía cualquier query "reconstruir historial ORDER BY created_at".
        if (updated.driver_id && driverEarning > 0) {
          const driverBalRes = await client.query<{ balance: string }>(
            'SELECT rapi_team_user_balance($1)::text AS balance',
            [updated.driver_id],
          )
          const driverBalAfter = Math.round(
            (Number(driverBalRes.rows[0]?.balance ?? 0) + driverEarning) * 100,
          ) / 100
          await client.query(
            `INSERT INTO wallet_transactions
               (user_id, type, amount, balance_after, description, status, ride_id, metadata, completed_at)
             VALUES ($1, 'credit', $2, $3, $4, 'completed', $5, $6::jsonb, now())`,
            [
              updated.driver_id,
              driverEarning,
              driverBalAfter,
              `Ganancia viaje ${id} (comisión ${(commissionRate * 100).toFixed(0)}%)`,
              id,
              JSON.stringify({ finalFare, commissionRate, commissionAmount, driverEarning }),
            ],
          )
        }

        // 3) COMMISSION al platform (contable) — audit trail.
        // Ronda 214: bucket ahora es driver_id, no passenger_id. La comisión
        // es del driver hacia la plataforma; poner al passenger como user_id
        // era conceptualmente incorrecto: cualquier export CSV filtrado por
        // user_id=passenger exponía al passenger obligaciones de la plataforma
        // en su historial legal. Migración 019 excluye type='commission' del
        // balance visible, así que este cambio NO afecta al saldo del driver.
        if (commissionAmount > 0 && updated.driver_id) {
          await client.query(
            `INSERT INTO wallet_transactions
               (user_id, type, amount, description, status, ride_id, metadata, completed_at)
             VALUES ($1, 'commission', $2, $3, 'completed', $4, $5::jsonb, now())`,
            [
              updated.driver_id,
              commissionAmount,
              `Comisión plataforma viaje ${id}`,
              id,
              JSON.stringify({ finalFare, commissionRate, passengerId: updated.passenger_id }),
            ],
          )
        }
      } else if (
        updated.payment_method &&
        updated.payment_method !== 'wallet' &&
        updated.driver_id &&
        commissionAmount > 0
      ) {
        // Ronda 199 CRITICAL/DINERO: rides NO-wallet (cash, yape, plin,
        // mercadopago directo, etc.) SÍ deben registrar la comisión de la
        // plataforma como DÉBITO al driver. El driver recibió el fare completo
        // en su método, pero le debe la comisión a la plataforma. Antes:
        // TODA la lógica de commission estaba dentro del if (wallet) →
        // platform perdía comisión de cada viaje cash → S/20 por ride cash
        // desaparecidos permanentemente.
        // Ronda 214: el advisory lock del driver ya se adquirió al inicio
        // de la tx en el bloque de lock-ordering. NO reintentarlo aquí (era
        // un no-op y confundía al lector).
        const driverBalRes = await client.query<{ balance: string }>(
          'SELECT rapi_team_user_balance($1)::text AS balance',
          [updated.driver_id],
        )
        const driverBalance = Number(driverBalRes.rows[0]?.balance ?? 0)
        const driverBalAfter = Math.round((driverBalance - commissionAmount) * 100) / 100
        // Débito real al driver: type='debit' entra al balance (a diferencia
        // de 'commission' que la migración 019 excluye para audit-trail).
        await client.query(
          `INSERT INTO wallet_transactions
             (user_id, type, amount, balance_after, description, status, ride_id, metadata, completed_at)
           VALUES ($1, 'debit', $2, $3, $4, 'completed', $5, $6::jsonb, now())`,
          [
            updated.driver_id,
            -commissionAmount,
            driverBalAfter,
            `Comisión plataforma viaje ${id} (${updated.payment_method})`,
            id,
            JSON.stringify({
              finalFare,
              commissionRate,
              paymentMethod: updated.payment_method,
              kind: 'platform_commission_cash',
            }),
          ],
        )
        // Audit trail contable (excluido del balance por migración 019).
        await client.query(
          `INSERT INTO wallet_transactions
             (user_id, type, amount, description, status, ride_id, metadata, completed_at)
           VALUES ($1, 'commission', $2, $3, 'completed', $4, $5::jsonb, now())`,
          [
            updated.driver_id,
            commissionAmount,
            `Comisión plataforma viaje ${id}`,
            id,
            JSON.stringify({
              finalFare,
              commissionRate,
              paymentMethod: updated.payment_method,
              driverId: updated.driver_id,
            }),
          ],
        )
      }

      // Notificar al passenger. Ronda 214: usar adjustedFare (post descuento
      // vale), no finalFare crudo — antes el passenger veía "Total: S/50" en
      // la notif pero solo se le cobró S/40 en wallet → reclamos a soporte.
      if (updated.passenger_id) {
        await client.query(
          `INSERT INTO notifications (user_id, type, title, body, data)
           VALUES ($1, 'ride_completed', $2, $3, $4)`,
          [
            updated.passenger_id,
            'Viaje completado',
            valeDiscount > 0
              ? `Total: S/ ${adjustedFare.toFixed(2)} (descuento vale S/ ${valeDiscount.toFixed(2)})`
              : `Total: S/ ${adjustedFare.toFixed(2)}`,
            JSON.stringify({
              rideId: id,
              driverId: auth.userId,
              finalFare,
              adjustedFare,
              valeDiscount,
              paymentMethod: updated.payment_method,
              walletDebitId: walletDebit?.id ?? null,
            }),
          ],
        )
      }

      return { ride: updated, walletDebit }
    })

    await query(
      `INSERT INTO auth_events (user_id, event_type, provider, metadata)
       VALUES ($1, 'ride_completed', 'app', $2)`,
      [auth.userId, JSON.stringify({ rideId: id, finalFare, walletCharged: !!result.walletDebit })],
    )

    // Ronda 223: FCM push al passenger (antes solo in-app).
    if (result.ride.passenger_id) {
      void sendPush({
        userIds: [result.ride.passenger_id],
        type: 'ride_completed',
        title: 'Viaje completado',
        body: `Total: S/ ${finalFare.toFixed(2)}`,
        data: { rideId: id, finalFare },
        channel: 'rappi_rides',
        sound: 'trip_completed',
        priority: 'high',
        persist: false,
      })
    }

    return NextResponse.json({
      success: true,
      ride: {
        id: result.ride.id,
        status: result.ride.status,
        finalFare: result.ride.final_fare !== null ? Number(result.ride.final_fare) : null,
        distanceMeters: result.ride.distance_meters,
        durationSeconds: result.ride.duration_seconds,
        paymentMethod: result.ride.payment_method,
        completedAt: result.ride.completed_at,
      },
      walletDebit: result.walletDebit
        ? {
            id: result.walletDebit.id,
            amount: Number(result.walletDebit.amount),
            balanceAfter: result.walletDebit.balance_after !== null
              ? Number(result.walletDebit.balance_after)
              : null,
            createdAt: result.walletDebit.created_at,
          }
        : null,
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
    if (knownCode === 'fare_exceeds_cap') {
      const e = err as { message?: string; estimatedFare?: number; maxAllowed?: number }
      return NextResponse.json(
        {
          success: false,
          error: 'fare_exceeds_cap',
          message: e.message,
          estimatedFare: e.estimatedFare,
          maxAllowed: e.maxAllowed,
        },
        { status: 422 },
      )
    }
    if (knownCode === 'insufficient_funds') {
      const e = err as { balance?: number; required?: number; message?: string }
      return NextResponse.json(
        {
          success: false,
          error: 'insufficient_funds',
          message: e.message,
          balance: e.balance,
          required: e.required,
        },
        { status: 402 },
      )
    }
    console.error('[rides/complete] error:', err)
    return NextResponse.json({ success: false, error: 'internal_error' }, { status: 500 })
  }
}
