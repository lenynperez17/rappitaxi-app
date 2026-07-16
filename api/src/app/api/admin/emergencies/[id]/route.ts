/**
 * PATCH /api/admin/emergencies/:id — cambia estado + audita (resolved_by).
 *   Body: { status: 'active' | 'pending' | 'dispatched' | 'escalated' | 'resolved' | 'cancelled', notes?: string }
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAdmin } from '@/lib/admin-middleware'
import { tx } from '@/lib/db'
import { isUuid } from '@/lib/uuid'

export const runtime = 'nodejs'

const ALLOWED_STATUSES = new Set([
  'active', 'pending', 'dispatched', 'escalated', 'resolved', 'cancelled',
])

// State machine: qué estado puede ir a cuál. Terminales (resolved/cancelled)
// no reabren — si el operador se equivocó, debe crear una emergencia nueva.
const ALLOWED_TRANSITIONS: Record<string, string[]> = {
  active: ['pending', 'dispatched', 'escalated', 'resolved', 'cancelled'],
  pending: ['active', 'dispatched', 'escalated', 'resolved', 'cancelled'],
  dispatched: ['escalated', 'resolved', 'cancelled'],
  escalated: ['dispatched', 'resolved', 'cancelled'],
  resolved: [],
  cancelled: [],
}

export async function PATCH(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const auth = await requireAdmin(req)
  if (!auth.ok) return auth.response

  const { id } = await params
  if (!isUuid(id)) return NextResponse.json({ success: false, error: 'invalid_id' }, { status: 400 })

  let body: { status?: string; notes?: string }
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ success: false, error: 'bad_json' }, { status: 400 })
  }

  if (!body.status || !ALLOWED_STATUSES.has(body.status)) {
    return NextResponse.json({ success: false, error: 'invalid_status' }, { status: 400 })
  }

  // Ronda 56 Bug#2: SELECT FOR UPDATE + WHERE status=$current + rowCount.
  // Sin esto, dos admins concurrentes con PATCH dispatched→resolved ambos
  // pasaban validación y el 2do sobrescribía resolved_by/resolved_at del 1ero.
  try {
    const result = await tx(async (client) => {
      const cur = await client.query<{ status: string }>(
        `SELECT status FROM emergencies WHERE id = $1 FOR UPDATE`,
        [id],
      )
      if (cur.rowCount === 0) throw { code: 'not_found' }
      const currentStatus = cur.rows[0]!.status

      const allowed = ALLOWED_TRANSITIONS[currentStatus] ?? []
      if (!allowed.includes(body.status!)) {
        throw { code: 'invalid_transition', currentStatus, nextStatus: body.status }
      }

      const isFinal = body.status === 'resolved' || body.status === 'cancelled'
      const upd = await client.query<{ id: string; status: string; resolved_at: Date | null }>(
        `UPDATE emergencies
            SET status = $1,
                resolved_by = CASE WHEN $2 THEN $3 ELSE resolved_by END,
                resolved_at = CASE WHEN $2 THEN NOW() ELSE resolved_at END,
                metadata = COALESCE(metadata, '{}'::jsonb)
                         || jsonb_build_object(
                              'lastUpdatedBy', $3::text,
                              'lastUpdatedAt', NOW()::text,
                              'adminNotes', COALESCE($4::text, metadata->>'adminNotes')
                            )
          WHERE id = $5 AND status = $6
          RETURNING id, status, resolved_at`,
        [body.status, isFinal, auth.userId, body.notes ?? null, id, currentStatus],
      )
      if (upd.rowCount === 0) throw { code: 'concurrent_update' }
      return upd.rows[0]!
    })
    return NextResponse.json({
      success: true,
      emergency: { id: result.id, status: result.status, resolvedAt: result.resolved_at },
    })
  } catch (err) {
    const known = err as { code?: string; currentStatus?: string; nextStatus?: string }
    if (known?.code === 'not_found') {
      return NextResponse.json({ success: false, error: 'not_found' }, { status: 404 })
    }
    if (known?.code === 'invalid_transition') {
      return NextResponse.json({
        success: false, error: 'invalid_transition',
        message: `No se puede pasar de "${known.currentStatus}" a "${known.nextStatus}".`,
      }, { status: 409 })
    }
    if (known?.code === 'concurrent_update') {
      return NextResponse.json({
        success: false, error: 'concurrent_update',
        message: 'Otro admin actualizó esta emergencia; recarga y reintenta.',
      }, { status: 409 })
    }
    console.error('[admin/emergencies PATCH] error:', err)
    return NextResponse.json({ success: false, error: 'internal_error' }, { status: 500 })
  }
}
