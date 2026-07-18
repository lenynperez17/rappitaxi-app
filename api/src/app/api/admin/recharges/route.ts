/**
 * GET  /api/admin/recharges?status=&driverId=&method=&fromDate=&toDate=
 * POST /api/admin/recharges     Body: { driverId, amount, method, reference?, notes? }
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAdmin } from '@/lib/admin-middleware'
import { getClientIp } from '@/lib/auth-middleware'
import { query, maybeOne, tx } from '@/lib/db'

export const runtime = 'nodejs'

const ALLOWED_METHODS = ['cash', 'transfer', 'mercadopago', 'yape', 'plin', 'admin_manual', 'other']

interface RechargeRow {
  id: string
  driver_id: string
  amount: string
  method: string
  status: string
  reference: string | null
  notes: string | null
  approved_by: string | null
  external_ref: string | null
  created_at: Date
  approved_at: Date | null
  driver_name: string | null
  driver_phone: string | null
  driver_email: string | null
  total?: string
}

export async function GET(req: NextRequest) {
  const auth = await requireAdmin(req)
  if (!auth.ok) return auth.response

  const { searchParams } = new URL(req.url)
  const status = searchParams.get('status')
  const driverId = searchParams.get('driverId')
  const method = searchParams.get('method')
  const fromDate = searchParams.get('fromDate')
  const toDate = searchParams.get('toDate')
  // Ronda 29: NaN-safe pagination + placeholders
  const pageRaw = Number(searchParams.get('page') ?? '1')
  const page = Number.isFinite(pageRaw) ? Math.max(1, Math.floor(pageRaw)) : 1
  const pageSizeRaw = Number(searchParams.get('pageSize') ?? '50')
  const pageSize = Number.isFinite(pageSizeRaw) ? Math.min(200, Math.max(1, Math.floor(pageSizeRaw))) : 50
  const offset = (page - 1) * pageSize

  const where: string[] = []
  const params: unknown[] = []
  if (status) { params.push(status); where.push(`r.status = $${params.length}`) }
  if (driverId) { params.push(driverId); where.push(`r.driver_id = $${params.length}`) }
  if (method) { params.push(method); where.push(`r.method = $${params.length}`) }
  if (fromDate) { params.push(fromDate); where.push(`r.created_at >= $${params.length}::date`) }
  // Ronda 29 Bug#2: toDate como 'YYYY-MM-DD' se interpreta como 00:00:00 →
  // excluye todo el día. Sumar 1 día para incluir hasta el fin del día.
  if (toDate) { params.push(toDate); where.push(`r.created_at < ($${params.length}::date + interval '1 day')`) }
  const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : ''

  // Ronda 29 Bug#1: total con COUNT separado (COUNT(*) OVER daba 0 si rows vacío)
  const totalRes = await query<{ total: string }>(
    `SELECT COUNT(*)::text AS total FROM driver_recharges r ${whereSql}`,
    params,
  )
  const total = Number(totalRes[0]?.total ?? 0)

  const pagedParams = [...params, pageSize, offset]
  const rows = await query<RechargeRow>(
    `SELECT r.*, u.full_name AS driver_name, u.phone AS driver_phone, u.email AS driver_email
       FROM driver_recharges r
       LEFT JOIN users u ON u.id = r.driver_id
       ${whereSql}
       ORDER BY r.created_at DESC
       LIMIT $${pagedParams.length - 1} OFFSET $${pagedParams.length}`,
    pagedParams,
  )
  return NextResponse.json({
    success: true,
    recharges: rows.map((r) => ({
      id: r.id,
      driverId: r.driver_id,
      driverName: r.driver_name,
      driverPhone: r.driver_phone,
      driverEmail: r.driver_email,
      amount: Number(r.amount),
      method: r.method,
      status: r.status,
      reference: r.reference,
      notes: r.notes,
      approvedBy: r.approved_by,
      externalRef: r.external_ref,
      createdAt: r.created_at,
      approvedAt: r.approved_at,
    })),
    page, pageSize, total, totalPages: Math.ceil(total / pageSize),
  })
}

export async function POST(req: NextRequest) {
  const auth = await requireAdmin(req)
  if (!auth.ok) return auth.response

  let body: { driverId?: string; amount?: number; method?: string; reference?: string; notes?: string }
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ success: false, error: 'bad_json' }, { status: 400 })
  }

  const driverId = body.driverId?.trim()
  const amount = Number(body.amount)
  const method = body.method?.trim() ?? 'admin_manual'
  if (!driverId) return NextResponse.json({ success: false, error: 'missing_driver_id' }, { status: 400 })
  if (!Number.isFinite(amount) || amount <= 0) return NextResponse.json({ success: false, error: 'invalid_amount' }, { status: 400 })
  if (!ALLOWED_METHODS.includes(method)) return NextResponse.json({ success: false, error: 'invalid_method' }, { status: 400 })

  const driver = await maybeOne<{ id: string; user_type: string }>(
    `SELECT id, user_type FROM users WHERE id = $1 AND user_type IN ('driver','dual') AND deleted_at IS NULL`,
    [driverId],
  )
  if (!driver) return NextResponse.json({ success: false, error: 'driver_not_found' }, { status: 404 })

  // Idempotency-Key desde header — si viene, exigimos que sea único por driver.
  // Sin key, seguimos aceptando (compat) pero desde el panel siempre se envía.
  const idempotencyKey = req.headers.get('idempotency-key')?.trim() || null

  let rechargeId: string
  try {
    rechargeId = await tx(async (client) => {
      // Chequear si ya existe una recarga con esta key para este driver (retry).
      if (idempotencyKey) {
        const existing = await client.query<{ id: string }>(
          `SELECT id FROM driver_recharges
            WHERE driver_id = $1 AND idempotency_key = $2 LIMIT 1`,
          [driverId, idempotencyKey],
        )
        if (existing.rows[0]) return existing.rows[0].id
      }

      const rechargeRes = await client.query<{ id: string }>(
        `INSERT INTO driver_recharges
           (driver_id, amount, method, reference, notes, approved_by, status, approved_at, idempotency_key)
         VALUES ($1, $2, $3, $4, $5, $6, 'completed', now(), $7)
         RETURNING id`,
        [driverId, amount, method, body.reference ?? null, body.notes ?? null, auth.userId, idempotencyKey],
      )
      const newId = rechargeRes.rows[0]!.id
      // Ronda 214: balance_after ausente rompía reconstrucción de extracto
      // ORDER BY created_at para el driver. Ahora advisory lock por driver_id
      // (mismo bucket 42 que /rides/complete y /rides/cancel) para serializar
      // contra debits concurrentes, luego calcular balance_after en tx.
      await client.query(
        `SELECT pg_advisory_xact_lock(hashtextextended($1, 42))`,
        [driverId],
      )
      const balRes = await client.query<{ balance: string }>(
        'SELECT rapi_team_user_balance($1)::text AS balance',
        [driverId],
      )
      const currentBalance = Number(balRes.rows[0]?.balance ?? 0)
      const balanceAfter = Math.round((currentBalance + amount) * 100) / 100
      // Refleja en wallet como crédito
      await client.query(
        `INSERT INTO wallet_transactions
           (user_id, type, amount, balance_after, description, status, external_ref, metadata, completed_at)
         VALUES ($1, 'recharge', $2, $3, $4, 'completed', $5, $6, now())`,
        [driverId, amount, balanceAfter, `Recarga admin ${method}`, newId,
         JSON.stringify({ method, adminId: auth.userId, reference: body.reference })],
      )
      return newId
    })
  } catch (e) {
    // UNIQUE violation en (driver_id, idempotency_key) → retornar el existente
    if ((e as { code?: string }).code === '23505' && idempotencyKey) {
      const existing = await maybeOne<{ id: string }>(
        `SELECT id FROM driver_recharges WHERE driver_id = $1 AND idempotency_key = $2 LIMIT 1`,
        [driverId, idempotencyKey],
      )
      if (existing) rechargeId = existing.id
      else {
        // Ronda 214: log estructurado antes de propagar. Antes: throw e sin
        // catch externo → 500 sin trace → admin veía "internal server error"
        // sin saber si la recarga se aplicó.
        console.error('[admin/recharges POST] error tras UNIQUE 23505:', e)
        throw e
      }
    } else {
      // Ronda 214: log estructurado del error real antes de propagar. Cubre
      // deadlocks (40P01), foreign key violations (23503), etc. — cualquier
      // error no-23505 caía sin log y devolvía 500 opaco.
      console.error('[admin/recharges POST] tx error:', e)
      throw e
    }
  }

  await query(
    `INSERT INTO auth_events (user_id, event_type, provider, ip_address, user_agent, metadata)
     VALUES ($1, 'admin_recharge_driver', 'admin', $2, $3, $4)`,
    [driverId, getClientIp(req), req.headers.get('user-agent'),
     JSON.stringify({ rechargedBy: auth.userId, amount, method, rechargeId })],
  )

  return NextResponse.json({ success: true, id: rechargeId, amount, method }, { status: 201 })
}
