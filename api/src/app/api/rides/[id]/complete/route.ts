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

      // Advisory lock del passenger para serializar débitos concurrentes.
      // Sin este lock, dos rides distintos completándose en paralelo (2 drivers
      // distintos, sin lock contention en la fila ride) leen el mismo balance
      // y ambos hacen debit → balance negativo. Mismo patrón que /wallet/withdrawals.
      if (ride.passenger_id) {
        await client.query(
          `SELECT pg_advisory_xact_lock(hashtextextended($1, 42))`,
          [ride.passenger_id],
        )
      }

      // Solo permite completar rides que están `in_progress` — obliga a que
      // haya pasado por `start` (que a su vez requiere `arrived`). Sin esto,
      // un driver podía marcar arrived → complete directo, cobrando al
      // passenger un viaje que nunca empezó.
      if (ride.status !== 'in_progress') {
        throw { code: 'invalid_status', message: `El viaje debe estar en curso (in_progress) para completarse. Estado actual: ${ride.status}` }
      }

      // Cap contra wallet-drain: si hay estimación previa y el driver
      // envía un finalFare que la excede 1.5x, rechazar. El passenger vio
      // el estimated_fare al aceptar el viaje — cobrar mucho más allá de
      // eso requiere disputa manual.
      const estimated = Number(ride.estimated_fare ?? 0)
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
        if (currentBalance < finalFare) {
          throw {
            code: 'insufficient_funds',
            message: 'Saldo insuficiente en wallet para completar el cobro',
            balance: currentBalance,
            required: finalFare,
          }
        }
        const newBalance = Math.round((currentBalance - finalFare) * 100) / 100

        // Comisión platform (Rapi Team) sobre finalFare. Configurable via
        // app_settings; default 20% (típico ride-hailing Perú).
        const commissionRateRes = await client.query<{ value_num: string | null }>(
          `SELECT value_num FROM app_settings WHERE key = 'rides.commission_rate' LIMIT 1`,
        )
        const commissionRate = Number(commissionRateRes.rows[0]?.value_num ?? 0.20)
        const commissionAmount = Math.round(finalFare * commissionRate * 100) / 100
        const driverEarning = Math.round((finalFare - commissionAmount) * 100) / 100

        // 1) DEBIT al passenger (dinero sale)
        const debitRes = await client.query<WalletTxRow>(
          `INSERT INTO wallet_transactions
             (user_id, type, amount, balance_after, description, status, ride_id, completed_at)
           VALUES ($1, 'debit', $2, $3, $4, 'completed', $5, now())
           RETURNING id, amount::text, type, status, balance_after::text, created_at`,
          [
            updated.passenger_id,
            -finalFare,
            newBalance,
            `Cobro por viaje ${id}`,
            id,
          ],
        )
        walletDebit = debitRes.rows[0]!

        // 2) CREDIT al driver (netamente de la comisión) — cierra la doble entrada
        if (updated.driver_id && driverEarning > 0) {
          await client.query(
            `INSERT INTO wallet_transactions
               (user_id, type, amount, description, status, ride_id, metadata, completed_at)
             VALUES ($1, 'credit', $2, $3, 'completed', $4, $5::jsonb, now())`,
            [
              updated.driver_id,
              driverEarning,
              `Ganancia viaje ${id} (comisión ${(commissionRate * 100).toFixed(0)}%)`,
              id,
              JSON.stringify({ finalFare, commissionRate, commissionAmount, driverEarning }),
            ],
          )
        }

        // 3) COMMISSION al platform (userId=null, contable) — audit trail
        if (commissionAmount > 0) {
          await client.query(
            `INSERT INTO wallet_transactions
               (user_id, type, amount, description, status, ride_id, metadata, completed_at)
             VALUES ($1, 'commission', $2, $3, 'completed', $4, $5::jsonb, now())`,
            [
              // Platform commission bucket — usamos passenger_id como referencia (no null porque hay NOT NULL constraint)
              // Se distingue por type='commission'. TODO: user_id='__platform__' cuando se relaje NOT NULL.
              updated.passenger_id,
              commissionAmount,
              `Comisión plataforma viaje ${id}`,
              id,
              JSON.stringify({ finalFare, commissionRate, driverId: updated.driver_id }),
            ],
          )
        }
      }

      // Notificar al passenger
      if (updated.passenger_id) {
        await client.query(
          `INSERT INTO notifications (user_id, type, title, body, data)
           VALUES ($1, 'ride_completed', $2, $3, $4)`,
          [
            updated.passenger_id,
            'Viaje completado',
            `Total: S/ ${finalFare.toFixed(2)}`,
            JSON.stringify({
              rideId: id,
              driverId: auth.userId,
              finalFare,
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
