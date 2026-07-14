/**
 * GET /api/admin/stats — stats agregadas para dashboard + páginas
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAdmin } from '@/lib/admin-middleware'
import { one } from '@/lib/db'

export const runtime = 'nodejs'

export async function GET(req: NextRequest) {
  const auth = await requireAdmin(req)
  if (!auth.ok) return auth.response

  const s = await one<{
    total_users: string; total_passengers: string; total_drivers: string;
    total_dual: string; total_admins: string; total_active: string; total_suspended: string;
    total_trips: string; trips_today: string; trips_completed: string; trips_cancelled: string;
    total_recharges: string; recharges_today: string; recharges_month: string;
    total_emergencies: string; active_emergencies: string;
  }>(`
    SELECT
      (SELECT COUNT(*)::text FROM users WHERE deleted_at IS NULL) AS total_users,
      (SELECT COUNT(*)::text FROM users WHERE user_type = 'passenger' AND deleted_at IS NULL) AS total_passengers,
      (SELECT COUNT(*)::text FROM users WHERE user_type = 'driver' AND deleted_at IS NULL) AS total_drivers,
      (SELECT COUNT(*)::text FROM users WHERE user_type = 'dual' AND deleted_at IS NULL) AS total_dual,
      (SELECT COUNT(*)::text FROM users WHERE (user_type = 'admin' OR is_admin = true) AND deleted_at IS NULL) AS total_admins,
      (SELECT COUNT(*)::text FROM users WHERE is_active = true AND suspended_at IS NULL AND deleted_at IS NULL) AS total_active,
      (SELECT COUNT(*)::text FROM users WHERE suspended_at IS NOT NULL AND deleted_at IS NULL) AS total_suspended,
      (SELECT COUNT(*)::text FROM rides) AS total_trips,
      (SELECT COUNT(*)::text FROM rides WHERE created_at >= date_trunc('day', now())) AS trips_today,
      (SELECT COUNT(*)::text FROM rides WHERE status = 'completed') AS trips_completed,
      (SELECT COUNT(*)::text FROM rides WHERE status = 'cancelled') AS trips_cancelled,
      (SELECT COALESCE(SUM(amount), 0)::text FROM driver_recharges WHERE status = 'completed') AS total_recharges,
      (SELECT COALESCE(SUM(amount), 0)::text FROM driver_recharges WHERE status = 'completed' AND created_at >= date_trunc('day', now())) AS recharges_today,
      (SELECT COALESCE(SUM(amount), 0)::text FROM driver_recharges WHERE status = 'completed' AND created_at >= date_trunc('month', now())) AS recharges_month,
      (SELECT COUNT(*)::text FROM emergencies) AS total_emergencies,
      (SELECT COUNT(*)::text FROM emergencies WHERE status IN ('active','pending','escalated')) AS active_emergencies
  `)

  return NextResponse.json({
    success: true,
    stats: {
      users: {
        total: Number(s.total_users),
        passengers: Number(s.total_passengers),
        drivers: Number(s.total_drivers),
        dual: Number(s.total_dual),
        admins: Number(s.total_admins),
        active: Number(s.total_active),
        suspended: Number(s.total_suspended),
      },
      trips: {
        total: Number(s.total_trips),
        today: Number(s.trips_today),
        completed: Number(s.trips_completed),
        cancelled: Number(s.trips_cancelled),
      },
      recharges: {
        total: Number(s.total_recharges),
        today: Number(s.recharges_today),
        month: Number(s.recharges_month),
      },
      emergencies: {
        total: Number(s.total_emergencies),
        active: Number(s.active_emergencies),
      },
    },
  })
}
