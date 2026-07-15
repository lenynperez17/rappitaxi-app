/**
 * GET /api/admin/drivers?search=&status=&online=
 *   → conductores (users con userType='driver' o 'dual') con stats mínimas
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAdmin } from '@/lib/admin-middleware'
import { query } from '@/lib/db'

export const runtime = 'nodejs'

interface DriverRow {
  id: string
  full_name: string | null
  email: string | null
  phone: string | null
  user_type: string
  is_active: boolean
  is_verified: boolean
  profile_photo_url: string | null
  suspended_at: Date | null
  created_at: Date
  total_trips: string
  avg_rating: string | null
  total?: string
}

export async function GET(req: NextRequest) {
  const auth = await requireAdmin(req)
  if (!auth.ok) return auth.response

  const { searchParams } = new URL(req.url)
  const search = (searchParams.get('search') ?? '').trim().toLowerCase()
  const status = searchParams.get('status')
  // Ronda 29: NaN-safe pagination
  const pageRaw = Number(searchParams.get('page') ?? '1')
  const page = Number.isFinite(pageRaw) ? Math.max(1, pageRaw) : 1
  const pageSizeRaw = Number(searchParams.get('pageSize') ?? '50')
  const pageSize = Number.isFinite(pageSizeRaw) ? Math.min(200, Math.max(1, pageSizeRaw)) : 50
  const offset = (page - 1) * pageSize

  const where: string[] = [
    `u.user_type IN ('driver','dual')`,
    `u.deleted_at IS NULL`,
  ]
  const params: unknown[] = []

  if (status === 'active') where.push(`u.is_active = true AND u.suspended_at IS NULL`)
  else if (status === 'suspended') where.push(`u.suspended_at IS NOT NULL`)
  else if (status === 'verified') where.push(`u.is_verified = true`)
  else if (status === 'unverified') where.push(`u.is_verified = false`)
  if (search) {
    params.push(`%${search}%`)
    where.push(`(LOWER(u.full_name) LIKE $${params.length} OR LOWER(u.email) LIKE $${params.length} OR u.phone LIKE $${params.length})`)
  }

  const whereSql = where.join(' AND ')

  // Ronda 29 Bug#1: total separado (COUNT(*) OVER daba 0 si rows vacío OOR)
  const totalRes = await query<{ total: string }>(
    `SELECT COUNT(*)::text AS total FROM users u WHERE ${whereSql}`,
    params,
  )
  const total = Number(totalRes[0]?.total ?? 0)

  const pagedParams = [...params, pageSize, offset]
  const rows = await query<DriverRow>(
    `SELECT u.id, u.full_name, u.email, u.phone, u.user_type, u.is_active,
            u.is_verified, u.profile_photo_url, u.suspended_at, u.created_at,
            (SELECT COUNT(*)::text FROM rides r WHERE r.driver_id = u.id AND r.status = 'completed') AS total_trips,
            (SELECT ROUND(AVG(rr.stars)::numeric, 2)::text
               FROM ride_ratings rr WHERE rr.rated_user_id = u.id AND rr.role = 'driver') AS avg_rating
       FROM users u
       WHERE ${whereSql}
       ORDER BY u.created_at DESC
       LIMIT $${pagedParams.length - 1} OFFSET $${pagedParams.length}`,
    pagedParams,
  )
  return NextResponse.json({
    success: true,
    drivers: rows.map((d) => ({
      id: d.id,
      fullName: d.full_name,
      email: d.email,
      phone: d.phone,
      userType: d.user_type,
      isActive: d.is_active,
      isVerified: d.is_verified,
      profilePhotoUrl: d.profile_photo_url,
      suspendedAt: d.suspended_at,
      createdAt: d.created_at,
      totalTrips: Number(d.total_trips ?? 0),
      avgRating: d.avg_rating ? Number(d.avg_rating) : null,
    })),
    page, pageSize, total, totalPages: Math.ceil(total / pageSize),
  })
}
