/**
 * GET/POST /api/wallet/withdrawals — retiros del wallet del conductor
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { query, tx } from '@/lib/db'
import type { PoolClient } from 'pg'

export const runtime = 'nodejs'
export const dynamic = 'force-dynamic'

interface WithdrawalRow {
  id: string
  bank_account_id: string
  bank_name: string | null
  account_number: string | null
  amount: string
  fee: string
  net_amount: string
  status: string
  external_ref: string | null
  reject_reason: string | null
  approved_at: Date | null
  completed_at: Date | null
  created_at: Date
}

export async function GET(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response
  const rows = await query<WithdrawalRow>(
    `SELECT w.id, w.bank_account_id, b.bank_name, b.account_number,
            w.amount, w.fee, w.net_amount, w.status, w.external_ref,
            w.reject_reason, w.approved_at, w.completed_at, w.created_at
       FROM wallet_withdrawals w
       LEFT JOIN driver_bank_accounts b ON b.id = w.bank_account_id
      WHERE w.driver_id = $1
      ORDER BY w.created_at DESC
      LIMIT 100`,
    [auth.userId],
  )
  return NextResponse.json({
    success: true,
    withdrawals: rows.map((w) => ({
      id: w.id,
      bankAccountId: w.bank_account_id,
      bankName: w.bank_name,
      accountNumber: w.account_number,
      amount: Number(w.amount),
      fee: Number(w.fee),
      netAmount: Number(w.net_amount),
      status: w.status,
      externalRef: w.external_ref,
      rejectReason: w.reject_reason,
      approvedAt: w.approved_at,
      completedAt: w.completed_at,
      createdAt: w.created_at,
    })),
  })
}

const MIN_WITHDRAWAL = 20      // S/ mínimo
const MAX_WITHDRAWAL = 10000   // S/ tope por operación (evita mistap + fraude)
const WITHDRAWAL_FEE = 2       // S/ fee fijo

export async function POST(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  let body: { bankAccountId?: string; amount?: number } = {}
  try { body = await req.json() } catch {
    return NextResponse.json({ success: false, error: 'bad_json' }, { status: 400 })
  }
  const bankAccountId = body.bankAccountId?.trim()
  const amount = Number(body.amount)
  // Ronda 130 SECURITY: NaN/Infinity envenenaban wallet_transactions.amount
  // (Postgres numeric acepta 'NaN'). NaN < MIN_WITHDRAWAL = false, y
  // balance < NaN = false → validación bypasseada, ledger contaminado
  // permanentemente: balance = SUM(NaN, ...) = NaN para siempre.
  // Además chequeamos tope máximo y 2 decimales.
  if (
    !bankAccountId ||
    !Number.isFinite(amount) ||
    amount < MIN_WITHDRAWAL ||
    amount > MAX_WITHDRAWAL ||
    Math.round(amount * 100) !== amount * 100
  ) {
    return NextResponse.json({ success: false, error: 'invalid_input',
      message: `Monto entre S/ ${MIN_WITHDRAWAL} y S/ ${MAX_WITHDRAWAL}, máximo 2 decimales` }, { status: 400 })
  }

  // Idempotency: la app móvil envía este header para que un tap-tap accidental
  // no cree 2 withdrawals distintos. UNIQUE (driver_id, idempotency_key)
  // garantiza atomicidad; devolvemos el withdrawal existente si la 2da request
  // trae el mismo key.
  const idempotencyKey = req.headers.get('idempotency-key')?.trim() || null

  try {
    const result = await tx(async (client: PoolClient) => {
      // CRÍTICO: advisory lock por driver_id para serializar POST /withdrawals
      // concurrentes del mismo driver. Migración 014 solo cerró el race
      // reader-vs-committed-writer; no cierra el race concurrent-writer bajo
      // READ COMMITTED (dos txs leen el mismo balance antes de que ninguna
      // commitee → ambas pasan el check → double-spend). Con este lock, las
      // txs concurrentes del mismo driver se serializan sin bloquear a otros.
      await client.query(
        `SELECT pg_advisory_xact_lock(hashtextextended($1, 42))`,
        [auth.userId],
      )

      // Check idempotency: si ya existe withdrawal con este key para este
      // driver, retornarlo — PERO validar coincidencia de payload primero.
      // Ronda 81: sin este check, un attacker con key capturado podía POST
      // con bankAccountId/amount distintos y recibir el withdrawal viejo
      // como si fuera nuevo (violación contract idempotencia RFC).
      if (idempotencyKey) {
        const existing = await client.query<WithdrawalRow>(
          `SELECT id, bank_account_id, amount, fee, net_amount, status, external_ref,
                  reject_reason, approved_at, completed_at, created_at
             FROM wallet_withdrawals
            WHERE driver_id = $1 AND idempotency_key = $2 LIMIT 1`,
          [auth.userId, idempotencyKey],
        )
        if (existing.rows[0]) {
          const row = existing.rows[0]
          if (row.bank_account_id !== bankAccountId || Math.abs(Number(row.amount) - amount) > 0.001) {
            throw {
              code: 'idempotency_key_conflict',
              status: 409,
              message: 'La misma idempotency-key ya se usó con parámetros distintos.',
            }
          }
          return row
        }
      }

      // Verificar que la cuenta bancaria pertenece al driver
      const bankRes = await client.query<{ id: string }>(
        `SELECT id FROM driver_bank_accounts
          WHERE id = $1 AND driver_id = $2 AND is_active = true`,
        [bankAccountId, auth.userId],
      )
      if (bankRes.rowCount === 0) throw { code: 'bank_account_not_found', status: 404 }

      // Verificar saldo disponible (ahora dentro del lock — ya no hay race)
      const balRes = await client.query<{ balance: string }>(
        `SELECT COALESCE(rapi_team_user_balance($1), 0) AS balance`,
        [auth.userId],
      )
      const balance = Number(balRes.rows[0].balance)
      if (balance < amount) {
        throw { code: 'insufficient_balance', status: 400, balance }
      }

      const fee = WITHDRAWAL_FEE
      const netAmount = amount - fee

      // Insertar withdrawal
      const wRes = await client.query<WithdrawalRow>(
        `INSERT INTO wallet_withdrawals (driver_id, bank_account_id, amount, fee, net_amount, status, idempotency_key)
         VALUES ($1, $2, $3, $4, $5, 'pending', $6)
         RETURNING id, bank_account_id, amount, fee, net_amount, status, external_ref,
                   reject_reason, approved_at, completed_at, created_at`,
        [auth.userId, bankAccountId, amount, fee, netAmount, idempotencyKey],
      )
      const w = wRes.rows[0]

      // Debitar del wallet (transaction pending) — con balance_after para audit
      // trail consistente (Ronda 21 MEDIUM). Sin esto, el ledger tiene rows con
      // balance_after=NULL y no se puede reconstruir historial ORDER BY created_at.
      const newBalance = Math.round((balance - amount) * 100) / 100
      await client.query(
        `INSERT INTO wallet_transactions (user_id, type, amount, balance_after, description, status, external_ref, metadata)
         VALUES ($1, 'withdrawal', $2, $3, $4, 'pending', $5, $6::jsonb)`,
        [
          auth.userId,
          -amount, // negativo por débito
          newBalance,
          `Retiro a cuenta bancaria`,
          w.id,
          JSON.stringify({ withdrawalId: w.id, bankAccountId, fee }),
        ],
      )

      // Ronda 172 CONTABLE/SUNAT: registrar el fee como wallet_transaction
      // 'commission' (mismo patrón que rides/complete, ya excluido del balance
      // del driver por migración 019). Antes: los S/2 de fee retenidos NUNCA
      // se registraban en el ledger — SUM(amount) global desfasado por -fee
      // en cada retiro. En 5000 retiros/mes = S/10 000 en revenue nunca
      // contabilizado ni reportable a SUNAT. Rompe invariante dual-entry.
      // status='pending' + external_ref=w.id: si el withdrawal se cancela,
      // el DELETE handler ya hace `WHERE external_ref=$1 AND user_id=$2 AND
      // status='pending'` — cancela AMBAS filas de una.
      if (fee > 0) {
        await client.query(
          `INSERT INTO wallet_transactions (user_id, type, amount, description, status, external_ref, metadata)
           VALUES ($1, 'commission', $2, $3, 'pending', $4, $5::jsonb)`,
          [
            auth.userId,
            fee, // positivo — bucket contable de la plataforma (mig 019 lo excluye del balance del user)
            `Comisión retiro ${w.id}`,
            w.id,
            JSON.stringify({ withdrawalId: w.id, kind: 'withdrawal_fee' }),
          ],
        )
      }

      // Notificación al usuario
      await client.query(
        `INSERT INTO notifications (user_id, type, title, body, data)
         VALUES ($1, 'withdrawal_requested', $2, $3, $4::jsonb)`,
        [auth.userId, 'Retiro solicitado',
         `Solicitud de retiro S/ ${amount.toFixed(2)} en revisión`,
         JSON.stringify({ withdrawalId: w.id, amount, netAmount })],
      )

      return w
    })

    return NextResponse.json({
      success: true,
      withdrawal: {
        id: result.id,
        bankAccountId: result.bank_account_id,
        amount: Number(result.amount),
        fee: Number(result.fee),
        netAmount: Number(result.net_amount),
        status: result.status,
        createdAt: result.created_at,
      },
    }, { status: 201 })
  } catch (err) {
    const e = err as { code?: string; status?: number; balance?: number }
    if (e?.code && e?.status) {
      return NextResponse.json({ success: false, error: e.code,
        ...(e.balance !== undefined ? { balance: e.balance } : {}) }, { status: e.status })
    }
    console.error('[wallet/withdrawals POST]', err)
    return NextResponse.json({ success: false, error: 'internal_error' }, { status: 500 })
  }
}
