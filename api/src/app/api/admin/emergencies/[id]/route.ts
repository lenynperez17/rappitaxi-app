/**
 * PATCH /api/admin/emergencies/:id — cambia estado + audita (resolved_by).
 *   Body: { status: 'active' | 'pending' | 'dispatched' | 'escalated' | 'resolved' | 'cancelled', notes?: string }
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAdmin } from '@/lib/admin-middleware'
import { maybeOne } from '@/lib/db'

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
  if (!id) return NextResponse.json({ success: false, error: 'id_required' }, { status: 400 })

  let body: { status?: string; notes?: string }
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ success: false, error: 'bad_json' }, { status: 400 })
  }

  if (!body.status || !ALLOWED_STATUSES.has(body.status)) {
    return NextResponse.json({ success: false, error: 'invalid_status' }, { status: 400 })
  }

  const current = await maybeOne<{ status: string }>(
    `SELECT status FROM emergencies WHERE id = $1`,
    [id],
  )
  if (!current) return NextResponse.json({ success: false, error: 'not_found' }, { status: 404 })

  const allowed = ALLOWED_TRANSITIONS[current.status] ?? []
  if (!allowed.includes(body.status)) {
    return NextResponse.json(
      { success: false, error: 'invalid_transition', message: `No se puede pasar de "${current.status}" a "${body.status}".` },
      { status: 409 },
    )
  }

  const isFinal = body.status === 'resolved' || body.status === 'cancelled'
  const updated = await maybeOne<{ id: string; status: string; resolved_at: Date | null }>(
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
      WHERE id = $5
      RETURNING id, status, resolved_at`,
    [body.status, isFinal, auth.userId, body.notes ?? null, id],
  )
  if (!updated) {
    return NextResponse.json({ success: false, error: 'not_found' }, { status: 404 })
  }

  return NextResponse.json({
    success: true,
    emergency: { id: updated.id, status: updated.status, resolvedAt: updated.resolved_at },
  })
}
