/**
 * GET /api/admin/cancellations
 *   ?status=pending|approved|rejected|all   (default: pending)
 *   ?page=1&pageSize=50
 *
 * Ronda 246: bandeja de revisión de penalidades por cancelación.
 *
 * Cuando un conductor cancela un viaje ya comprometido, se le descuenta un
 * porcentaje de la tarifa y la penalidad queda `pending`. El equipo revisa el
 * motivo que declaró y decide si se la devuelve (aprobar) o si la penalidad
 * se mantiene (rechazar). Es el mismo modelo que usa inDriver.
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAdmin } from '@/lib/admin-middleware'
import { query } from '@/lib/db'

export const runtime = 'nodejs'

const VALID_STATUS = new Set(['pending', 'approved', 'rejected', 'all'])

interface Row {
  id: string
  status: string
  cancelled_by: string | null
  cancelled_reason: string | null
  cancel_reason_code: string | null
  cancel_penalty_amount: string | null
  penalty_review_status: string | null
  penalty_reviewed_by: string | null
  penalty_reviewed_at: Date | null
  penalty_review_notes: string | null
  estimated_fare: string | null
  pickup_address: string | null
  destination_address: string | null
  completed_at: Date | null
  created_at: Date
  driver_id: string | null
  driver_name: string | null
  driver_email: string | null
  driver_phone: string | null
  driver_photo_url: string | null
  passenger_name: string | null
  total: string
}

export async function GET(req: NextRequest) {
  const auth = await requireAdmin(req)
  if (!auth.ok) return auth.response

  const { searchParams } = new URL(req.url)
  const status = (searchParams.get('status') ?? 'pending').trim()
  if (!VALID_STATUS.has(status)) {
    return NextResponse.json({ success: false, error: 'invalid_status' }, { status: 400 })
  }
  const pageRaw = Number(searchParams.get('page') ?? 1)
  const page = Number.isFinite(pageRaw) ? Math.max(1, Math.floor(pageRaw)) : 1
  const sizeRaw = Number(searchParams.get('pageSize') ?? 50)
  const pageSize = Number.isFinite(sizeRaw) ? Math.min(200, Math.max(1, Math.floor(sizeRaw))) : 50
  const offset = (page - 1) * pageSize

  const where: string[] = [
    `r.status = 'cancelled'`,
    `r.cancel_penalty_amount > 0`,
  ]
  const params: unknown[] = []
  if (status !== 'all') {
    params.push(status)
    where.push(`r.penalty_review_status = $${params.length}`)
  }

  const pagedParams = [...params, pageSize, offset]
  const rows = await query<Row>(
    `SELECT r.id, r.status, r.cancelled_by, r.cancelled_reason, r.cancel_reason_code,
            r.cancel_penalty_amount::text, r.penalty_review_status,
            r.penalty_reviewed_by, r.penalty_reviewed_at, r.penalty_review_notes,
            r.estimated_fare::text, r.pickup_address, r.destination_address,
            r.completed_at, r.created_at, r.driver_id,
            d.full_name  AS driver_name,
            d.email      AS driver_email,
            d.phone      AS driver_phone,
            d.profile_photo_url AS driver_photo_url,
            p.full_name  AS passenger_name,
            COUNT(*) OVER()::text AS total
       FROM rides r
       LEFT JOIN users d ON d.id = r.driver_id
       LEFT JOIN users p ON p.id = r.passenger_id
      WHERE ${where.join(' AND ')}
      ORDER BY r.completed_at DESC NULLS LAST
      LIMIT $${pagedParams.length - 1} OFFSET $${pagedParams.length}`,
    pagedParams,
  )

  const total = rows.length ? Number(rows[0].total) : 0

  return NextResponse.json({
    success: true,
    total,
    page,
    pageSize,
    totalPages: Math.ceil(total / pageSize),
    cancellations: rows.map((r) => ({
      rideId: r.id,
      cancelledBy: r.cancelled_by,
      cancelledByDriver: r.cancelled_by === r.driver_id,
      reason: r.cancelled_reason,
      reasonCode: r.cancel_reason_code,
      penaltyAmount: r.cancel_penalty_amount !== null ? Number(r.cancel_penalty_amount) : 0,
      reviewStatus: r.penalty_review_status ?? 'none',
      reviewedBy: r.penalty_reviewed_by,
      reviewedAt: r.penalty_reviewed_at,
      reviewNotes: r.penalty_review_notes,
      estimatedFare: r.estimated_fare !== null ? Number(r.estimated_fare) : null,
      pickupAddress: r.pickup_address,
      destinationAddress: r.destination_address,
      cancelledAt: r.completed_at,
      createdAt: r.created_at,
      driver: {
        id: r.driver_id,
        fullName: r.driver_name,
        email: r.driver_email,
        phone: r.driver_phone,
        photoUrl: r.driver_photo_url,
      },
      passengerName: r.passenger_name,
    })),
  })
}
