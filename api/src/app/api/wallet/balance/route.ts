/**
 * GET /api/wallet/balance
 * Auth: Bearer <access_token>
 *
 * Devuelve balance actual + últimas 30 transacciones.
 * Balance = SUM(amount) de wallet_transactions status='completed'.
 * (Signo: recharge/bonus/refund > 0, debit/withdrawal < 0)
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { one, query } from '@/lib/db'

export const runtime = 'nodejs'

interface Tx {
  id: string
  type: string
  amount: string
  description: string | null
  status: string
  ride_id: string | null
  external_ref: string | null
  created_at: Date
}

export async function GET(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  const balanceRow = await one<{ balance: string }>(
    'SELECT rapi_team_user_balance($1)::text as balance',
    [auth.userId],
  )

  // Excluir type='commission' del listado — es bucket contable interno
  // (ver migración 019) y mostrarlo confunde al pasajero + expone ledger
  // legal como evidencia en disputas.
  const txns = await query<Tx>(
    `SELECT id, type, amount::text, description, status, ride_id, external_ref, created_at
       FROM wallet_transactions
       WHERE user_id = $1 AND type != 'commission'
       ORDER BY created_at DESC
       LIMIT 30`,
    [auth.userId],
  )

  return NextResponse.json({
    success: true,
    balance: Number(balanceRow.balance),
    currency: 'PEN',
    transactions: txns.map((t) => ({
      id: t.id,
      type: t.type,
      amount: Number(t.amount),
      description: t.description,
      status: t.status,
      rideId: t.ride_id,
      externalRef: t.external_ref,
      createdAt: t.created_at,
    })),
  })
}
