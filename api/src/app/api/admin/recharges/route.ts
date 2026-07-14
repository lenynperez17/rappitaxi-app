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
  total: string
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
  const page = Math.max(1, Number(searchParams.get('page') ?? '1'))
  const pageSize = Math.min(200, Math.max(1, Number(searchParams.get('pageSize') ?? '50')))
  const offset = (page - 1) * pageSize

  const where: string[] = []
  const params: unknown[] = []
  if (status) { params.push(status); where.push(`r.status = $${params.length}`) }
  if (driverId) { params.push(driverId); where.push(`r.driver_id = $${params.length}`) }
  if (method) { params.push(method); where.push(`r.method = $${params.length}`) }
  if (fromDate) { params.push(fromDate); where.push(`r.created_at >= $${params.length}`) }
  if (toDate) { params.push(toDate); where.push(`r.created_at <= $${params.length}`) }
  const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : ''

  const rows = await query<RechargeRow>(
    `SELECT r.*, u.full_name AS driver_name, u.phone AS driver_phone, u.email AS driver_email,
            COUNT(*) OVER() AS total
       FROM driver_recharges r
       LEFT JOIN users u ON u.id = r.driver_id
       ${whereSql}
       ORDER BY r.created_at DESC
       LIMIT ${pageSize} OFFSET ${offset}`,
    params,
  )

  const total = rows.length ? Number(rows[0].total) : 0
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

  const rechargeId = await tx(async (client) => {
    const rechargeRes = await client.query<{ id: string }>(
      `INSERT INTO driver_recharges
         (driver_id, amount, method, reference, notes, approved_by, status, approved_at)
       VALUES ($1, $2, $3, $4, $5, $6, 'completed', now())
       RETURNING id`,
      [driverId, amount, method, body.reference ?? null, body.notes ?? null, auth.userId],
    )
    const rechargeId = rechargeRes.rows[0]!.id
    // Refleja en wallet como crédito
    await client.query(
      `INSERT INTO wallet_transactions
         (user_id, type, amount, description, status, external_ref, metadata, completed_at)
       VALUES ($1, 'recharge', $2, $3, 'completed', $4, $5, now())`,
      [driverId, amount, `Recarga admin ${method}`, rechargeId,
       JSON.stringify({ method, adminId: auth.userId, reference: body.reference })],
    )
    return rechargeId
  })

  await query(
    `INSERT INTO auth_events (user_id, event_type, provider, ip_address, user_agent, metadata)
     VALUES ($1, 'admin_recharge_driver', 'admin', $2, $3, $4)`,
    [driverId, getClientIp(req), req.headers.get('user-agent'),
     JSON.stringify({ rechargedBy: auth.userId, amount, method, rechargeId })],
  )

  return NextResponse.json({ success: true, id: rechargeId, amount, method }, { status: 201 })
}
