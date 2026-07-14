/**
 * GET  /api/admin/emergencies?status=&type=
 * PATCH /api/admin/emergencies/:id → cambiar estado
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAdmin } from '@/lib/admin-middleware'
import { query } from '@/lib/db'

export const runtime = 'nodejs'

interface EmRow {
  id: string
  user_id: string | null
  ride_id: string | null
  type: string
  status: string
  latitude: string | null
  longitude: string | null
  address: string | null
  description: string | null
  resolved_by: string | null
  resolved_at: Date | null
  created_at: Date
  user_name: string | null
  user_phone: string | null
  total: string
}

export async function GET(req: NextRequest) {
  const auth = await requireAdmin(req)
  if (!auth.ok) return auth.response

  const { searchParams } = new URL(req.url)
  const status = searchParams.get('status')
  const type = searchParams.get('type')
  const page = Math.max(1, Number(searchParams.get('page') ?? '1'))
  const pageSize = Math.min(200, Math.max(1, Number(searchParams.get('pageSize') ?? '100')))
  const offset = (page - 1) * pageSize

  const where: string[] = []
  const params: unknown[] = []
  if (status) { params.push(status); where.push(`e.status = $${params.length}`) }
  if (type) { params.push(type); where.push(`e.type = $${params.length}`) }
  const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : ''

  const rows = await query<EmRow>(
    `SELECT e.*, u.full_name AS user_name, u.phone AS user_phone,
            COUNT(*) OVER() AS total
       FROM emergencies e
       LEFT JOIN users u ON u.id = e.user_id
       ${whereSql}
       ORDER BY e.created_at DESC
       LIMIT ${pageSize} OFFSET ${offset}`,
    params,
  )

  const total = rows.length ? Number(rows[0].total) : 0
  return NextResponse.json({
    success: true,
    emergencies: rows.map((e) => ({
      id: e.id,
      userId: e.user_id,
      rideId: e.ride_id,
      userName: e.user_name,
      userPhone: e.user_phone,
      type: e.type,
      status: e.status,
      latitude: e.latitude ? Number(e.latitude) : null,
      longitude: e.longitude ? Number(e.longitude) : null,
      address: e.address,
      description: e.description,
      resolvedBy: e.resolved_by,
      resolvedAt: e.resolved_at,
      createdAt: e.created_at,
    })),
    page, pageSize, total, totalPages: Math.ceil(total / pageSize),
  })
}
