/**
 * GET /api/admin/documents
 *   Query params:
 *     ?status=pending|approved|rejected|expired  (default: pending)
 *     ?driverId=<uuid>                          (opcional, filtrar por driver)
 *     ?pageSize=50 (default 50, max 200)
 *     ?page=1
 *   Lista documentos del pool para revisión con nombre/email/phone del driver
 *   para que el admin sepa a quién pertenece.
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAdmin } from '@/lib/admin-middleware'
import { query } from '@/lib/db'

export const runtime = 'nodejs'

interface DocumentRow {
  id: string
  driver_id: string
  doc_type: string
  file_url: string
  status: string
  rejection_reason: string | null
  reviewed_by: string | null
  reviewed_at: Date | null
  expires_at: Date | null
  metadata: Record<string, unknown> | null
  created_at: Date
  updated_at: Date
  driver_full_name: string | null
  driver_email: string | null
  driver_phone: string | null
  total_count?: string
}

const VALID_STATUS = new Set(['pending', 'approved', 'rejected', 'expired', 'all'])

export async function GET(req: NextRequest) {
  const auth = await requireAdmin(req)
  if (!auth.ok) return auth.response

  const { searchParams } = new URL(req.url)
  const status = (searchParams.get('status') ?? 'pending').trim()
  if (!VALID_STATUS.has(status)) {
    return NextResponse.json({ success: false, error: 'invalid_status' }, { status: 400 })
  }
  const driverIdFilter = searchParams.get('driverId')?.trim() || null
  // Ronda 28: NaN-safe pagination
  const pageSizeRaw = Number(searchParams.get('pageSize') ?? 50)
  const pageSize = Number.isFinite(pageSizeRaw) ? Math.min(200, Math.max(1, Math.floor(pageSizeRaw))) : 50
  const pageRaw = Number(searchParams.get('page') ?? 1)
  const page = Number.isFinite(pageRaw) ? Math.max(1, Math.floor(pageRaw)) : 1
  const offset = (page - 1) * pageSize

  const clauses: string[] = []
  const params: unknown[] = []
  if (status !== 'all') {
    clauses.push(`d.status = $${params.length + 1}`)
    params.push(status)
  }
  if (driverIdFilter) {
    clauses.push(`d.driver_id = $${params.length + 1}`)
    params.push(driverIdFilter)
  }
  const where = clauses.length > 0 ? `WHERE ${clauses.join(' AND ')}` : ''

  // Ronda 28 Bug#2: SELECT COUNT(*) separado. COUNT(*) OVER() reportaba 0
  // cuando la página estaba fuera de rango (rows vacío) → UI paginación rota.
  const totalRes = await query<{ total: string }>(
    `SELECT COUNT(*)::text AS total FROM driver_documents d ${where}`,
    params,
  )
  const total = Number(totalRes[0]?.total ?? 0)

  const pagedParams = [...params, pageSize, offset]
  const rows = await query<DocumentRow>(
    `SELECT d.id, d.driver_id, d.doc_type, d.file_url, d.status,
            d.rejection_reason, d.reviewed_by, d.reviewed_at, d.expires_at,
            d.metadata, d.created_at, d.updated_at,
            u.full_name AS driver_full_name,
            u.email AS driver_email,
            u.phone AS driver_phone
       FROM driver_documents d
       JOIN users u ON u.id = d.driver_id
       ${where}
       ORDER BY d.created_at DESC
       LIMIT $${pagedParams.length - 1} OFFSET $${pagedParams.length}`,
    pagedParams,
  )

  return NextResponse.json({
    success: true,
    total,
    page,
    pageSize,
    documents: rows.map((d) => ({
      id: d.id,
      driverId: d.driver_id,
      docType: d.doc_type,
      fileUrl: d.file_url,
      status: d.status,
      rejectionReason: d.rejection_reason,
      reviewedBy: d.reviewed_by,
      reviewedAt: d.reviewed_at,
      expiresAt: d.expires_at,
      metadata: d.metadata,
      createdAt: d.created_at,
      updatedAt: d.updated_at,
      driver: {
        id: d.driver_id,
        fullName: d.driver_full_name,
        email: d.driver_email,
        phone: d.driver_phone,
      },
    })),
  })
}
