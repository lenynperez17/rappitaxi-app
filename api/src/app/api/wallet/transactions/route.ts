/**
 * GET /api/wallet/transactions
 *
 * Historial paginado de wallet_transactions del user autenticado.
 * Query: ?type=&limit=50&page=1
 * ORDER BY created_at DESC
 * Retorna: transactions, total, page, limit, totalPages.
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { one, query } from '@/lib/db'

export const runtime = 'nodejs'

interface TxRow {
  id: string
  user_id: string
  type: string
  amount: string
  balance_after: string | null
  description: string | null
  status: string
  external_ref: string | null
  ride_id: string | null
  metadata: Record<string, unknown> | null
  created_at: Date
  completed_at: Date | null
}

const VALID_TYPES = new Set([
  'recharge',
  'debit',
  'refund',
  'withdrawal',
  'commission',
  'bonus',
  'adjustment',
])

function serialize(t: TxRow) {
  return {
    id: t.id,
    userId: t.user_id,
    type: t.type,
    amount: Number(t.amount),
    balanceAfter: t.balance_after !== null ? Number(t.balance_after) : null,
    description: t.description,
    status: t.status,
    externalRef: t.external_ref,
    rideId: t.ride_id,
    metadata: t.metadata,
    createdAt: t.created_at,
    completedAt: t.completed_at,
  }
}

export async function GET(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  const { searchParams } = new URL(req.url)
  const typeParam = searchParams.get('type')?.trim().toLowerCase() || null
  const limitRaw = Number(searchParams.get('limit') ?? 50)
  const limit = Number.isFinite(limitRaw) && limitRaw > 0 && limitRaw <= 200 ? Math.floor(limitRaw) : 50
  const pageRaw = Number(searchParams.get('page') ?? 1)
  const page = Number.isFinite(pageRaw) && pageRaw >= 1 ? Math.floor(pageRaw) : 1
  const offset = (page - 1) * limit

  if (typeParam && !VALID_TYPES.has(typeParam)) {
    return NextResponse.json(
      { success: false, error: 'invalid_type', message: 'Tipo de transacción inválido' },
      { status: 400 },
    )
  }

  // Excluir type='commission' del historial personal — esas filas usan
  // user_id=passenger_id como bucket contable (ver migración 019) pero no
  // representan una transacción del usuario. Mostrarlas confunde al pasajero
  // ("¿por qué recibí S/20 de comisión?") y es potencialmente explotable
  // como evidencia contra la plataforma.
  const filters: string[] = [`user_id = $1`, `type != 'commission'`]
  const params: unknown[] = [auth.userId]
  let idx = 2
  if (typeParam) {
    if (typeParam === 'commission') {
      // Nadie puede consultar sus commissions — son ledger interno.
      return NextResponse.json({ success: true, transactions: [], total: 0, page, limit, totalPages: 0 })
    }
    filters.push(`type = $${idx++}`)
    params.push(typeParam)
  }
  const whereSql = filters.join(' AND ')

  // Total
  const totalRow = await one<{ total: string }>(
    `SELECT COUNT(*)::text AS total FROM wallet_transactions WHERE ${whereSql}`,
    params,
  )
  const total = Number(totalRow.total)

  // Página
  const pagedParams = [...params, limit, offset]
  const rows = await query<TxRow>(
    `SELECT id, user_id, type, amount::text, balance_after::text, description, status,
            external_ref, ride_id, metadata, created_at, completed_at
       FROM wallet_transactions
       WHERE ${whereSql}
       ORDER BY created_at DESC
       LIMIT $${idx} OFFSET $${idx + 1}`,
    pagedParams,
  )

  const totalPages = total === 0 ? 0 : Math.ceil(total / limit)

  return NextResponse.json({
    success: true,
    transactions: rows.map(serialize),
    total,
    page,
    limit,
    totalPages,
  })
}
