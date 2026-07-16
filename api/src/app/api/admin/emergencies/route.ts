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
}

export async function GET(req: NextRequest) {
  const auth = await requireAdmin(req)
  if (!auth.ok) return auth.response

  const { searchParams } = new URL(req.url)
  const status = searchParams.get('status')
  const type = searchParams.get('type')
  // Ronda 28 Bug#1: pagination NaN-safe + placeholders parametrizados
  const pageRaw = Number(searchParams.get('page') ?? '1')
  const page = Number.isFinite(pageRaw) ? Math.max(1, Math.floor(pageRaw)) : 1
  const pageSizeRaw = Number(searchParams.get('pageSize') ?? '100')
  const pageSize = Number.isFinite(pageSizeRaw) ? Math.min(200, Math.max(1, Math.floor(pageSizeRaw))) : 100
  const offset = (page - 1) * pageSize

  const where: string[] = []
  const params: unknown[] = []
  if (status) { params.push(status); where.push(`e.status = $${params.length}`) }
  if (type) { params.push(type); where.push(`e.type = $${params.length}`) }
  const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : ''

  // Ronda 28 Bug#2: total lo obtenemos con SELECT COUNT(*) separado — el
  // COUNT(*) OVER() reportaba 0 cuando la página estaba fuera de rango
  // (rows.length===0), ocultando al frontend que sí hay datos.
  const totalRes = await query<{ total: string }>(
    `SELECT COUNT(*)::text AS total FROM emergencies e ${whereSql}`,
    params,
  )
  const total = Number(totalRes[0]?.total ?? 0)

  const pagedParams = [...params, pageSize, offset]
  const limitIdx = pagedParams.length - 1
  const rows = await query<EmRow>(
    `SELECT e.*, u.full_name AS user_name, u.phone AS user_phone
       FROM emergencies e
       LEFT JOIN users u ON u.id = e.user_id
       ${whereSql}
       ORDER BY e.created_at DESC
       LIMIT $${limitIdx} OFFSET $${limitIdx + 1}`,
    pagedParams,
  )
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
