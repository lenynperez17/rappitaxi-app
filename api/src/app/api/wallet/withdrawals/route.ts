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
const WITHDRAWAL_FEE = 2       // S/ fee fijo

export async function POST(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  let body: { bankAccountId?: string; amount?: number } = {}
  try { body = await req.json() } catch {
    return NextResponse.json({ success: false, error: 'bad_json' }, { status: 400 })
  }
  const bankAccountId = body.bankAccountId?.trim()
  const amount = Number(body.amount ?? 0)
  if (!bankAccountId || amount < MIN_WITHDRAWAL) {
    return NextResponse.json({ success: false, error: 'invalid_input',
      message: `Monto mínimo S/ ${MIN_WITHDRAWAL}` }, { status: 400 })
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
      // driver, retornarlo sin crear nuevo.
      if (idempotencyKey) {
        const existing = await client.query<WithdrawalRow>(
          `SELECT id, bank_account_id, amount, fee, net_amount, status, external_ref,
                  reject_reason, approved_at, completed_at, created_at
             FROM wallet_withdrawals
            WHERE driver_id = $1 AND idempotency_key = $2 LIMIT 1`,
          [auth.userId, idempotencyKey],
        )
        if (existing.rows[0]) return existing.rows[0]
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
