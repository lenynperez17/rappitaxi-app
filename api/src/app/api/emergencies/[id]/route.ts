/**
 * /api/emergencies/[id]
 *
 * GET   — Detalle de una emergencia.
 *         Auth: usuario creador o admin.
 *
 * PATCH — Actualizar emergencia (SOLO admin).
 *         Body: { status?, resolvedBy?, description? }
 *         Al pasar a 'resolved' se marca resolved_at=now() y se registra en auth_events.
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth, getClientIp } from '@/lib/auth-middleware'
import { requireAdmin } from '@/lib/admin-middleware'
import { maybeOne, tx } from '@/lib/db'

export const runtime = 'nodejs'

interface EmergencyRow {
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
  metadata: Record<string, unknown> | null
  created_at: Date
}

interface AdminCheckRow {
  is_admin: boolean
  user_type: string
}

const VALID_STATUS = new Set(['active', 'pending', 'dispatched', 'escalated', 'resolved', 'cancelled'])

// Espejo de ALLOWED_TRANSITIONS en /api/admin/emergencies/[id] — evita que
// este endpoint permita transiciones que el otro bloquea (ej. resolved →
// active). Sin esto, un admin podía reabrir emergencias resueltas desde este
// endpoint y romper el audit trail.
const ALLOWED_TRANSITIONS: Record<string, string[]> = {
  active: ['pending', 'dispatched', 'escalated', 'resolved', 'cancelled'],
  pending: ['active', 'dispatched', 'escalated', 'resolved', 'cancelled'],
  dispatched: ['escalated', 'resolved', 'cancelled'],
  escalated: ['dispatched', 'resolved', 'cancelled'],
  resolved: [],
  cancelled: [],
}

function serialize(e: EmergencyRow) {
  return {
    id: e.id,
    userId: e.user_id,
    rideId: e.ride_id,
    type: e.type,
    status: e.status,
    latitude: e.latitude !== null ? Number(e.latitude) : null,
    longitude: e.longitude !== null ? Number(e.longitude) : null,
    address: e.address,
    description: e.description,
    resolvedBy: e.resolved_by,
    resolvedAt: e.resolved_at,
    metadata: e.metadata,
    createdAt: e.created_at,
  }
}

// ============================================================================
// GET — Detalle
// ============================================================================
export async function GET(req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response
  const { id } = await ctx.params

  const emergency = await maybeOne<EmergencyRow>(
    `SELECT id, user_id, ride_id, type, status,
            latitude::text, longitude::text,
            address, description, resolved_by, resolved_at, metadata, created_at
       FROM emergencies WHERE id = $1`,
    [id],
  )
  if (!emergency) {
    return NextResponse.json({ success: false, error: 'not_found' }, { status: 404 })
  }

  // Solo el creador o admin puede ver.
  if (emergency.user_id !== auth.userId) {
    const adminCheck = await maybeOne<AdminCheckRow>(
      'SELECT is_admin, user_type FROM users WHERE id = $1',
      [auth.userId],
    )
    const isAdmin = !!(adminCheck && (adminCheck.is_admin || adminCheck.user_type === 'admin'))
    if (!isAdmin) {
      return NextResponse.json({ success: false, error: 'forbidden' }, { status: 403 })
    }
  }

  return NextResponse.json({ success: true, emergency: serialize(emergency) })
}

// ============================================================================
// PATCH — Actualizar (solo admin)
// ============================================================================
export async function PATCH(req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  const auth = await requireAdmin(req)
  if (!auth.ok) return auth.response
  const { id } = await ctx.params

  let body: { status?: string; resolvedBy?: string | null; description?: string | null }
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ success: false, error: 'bad_json' }, { status: 400 })
  }

  if (body.status !== undefined && !VALID_STATUS.has(body.status)) {
    return NextResponse.json({ success: false, error: 'invalid_status' }, { status: 400 })
  }

  // Validar transición contra el estado actual — mismo state machine que
  // /api/admin/emergencies/[id]. Sin esto, un admin podría revertir un
  // 'resolved' a 'active' desde este endpoint y confundir auditoría.
  if (body.status !== undefined) {
    const current = await maybeOne<{ status: string }>(
      'SELECT status FROM emergencies WHERE id = $1',
      [id],
    )
    if (!current) {
      return NextResponse.json({ success: false, error: 'not_found' }, { status: 404 })
    }
    if (current.status !== body.status) {
      const allowed = ALLOWED_TRANSITIONS[current.status] ?? []
      if (!allowed.includes(body.status)) {
        return NextResponse.json({
          success: false,
          error: 'invalid_transition',
          message: `No se permite pasar de '${current.status}' a '${body.status}'`,
          currentStatus: current.status,
        }, { status: 409 })
      }
    }
  }

  const updates: string[] = []
  const params: unknown[] = []
  let idx = 1
  const nextStatus = body.status
  const willResolve = nextStatus === 'resolved'

  if (nextStatus !== undefined) {
    updates.push(`status = $${idx++}`)
    params.push(nextStatus)
  }
  if (body.resolvedBy !== undefined) {
    updates.push(`resolved_by = $${idx++}`)
    params.push(body.resolvedBy)
  } else if (willResolve) {
    // Si pasa a resolved y no vino resolvedBy, ponemos al admin actual.
    updates.push(`resolved_by = $${idx++}`)
    params.push(auth.userId)
  }
  if (willResolve) {
    updates.push(`resolved_at = now()`)
  }
  if (body.description !== undefined) {
    updates.push(`description = $${idx++}`)
    params.push(body.description)
  }

  if (updates.length === 0) {
    return NextResponse.json(
      { success: false, error: 'no_changes', message: 'No hay campos para actualizar' },
      { status: 400 },
    )
  }

  params.push(id)

  try {
    const result = await tx(async (client) => {
      const upd = await client.query<EmergencyRow>(
        `UPDATE emergencies SET ${updates.join(', ')}
           WHERE id = $${idx}
         RETURNING id, user_id, ride_id, type, status,
                   latitude::text, longitude::text, address, description,
                   resolved_by, resolved_at, metadata, created_at`,
        params,
      )
      const emergency = upd.rows[0]
      if (!emergency) throw { code: 'not_found' }

      // Notificar al creador cuando la emergencia se marca como resuelta.
      if (willResolve && emergency.user_id) {
        await client.query(
          `INSERT INTO notifications (user_id, type, title, body, data)
           VALUES ($1, 'emergency_resolved', $2, $3, $4)`,
          [
            emergency.user_id,
            'Tu emergencia ha sido resuelta',
            'El equipo de seguridad ha marcado la alerta como resuelta.',
            JSON.stringify({ emergencyId: emergency.id, resolvedBy: emergency.resolved_by }),
          ],
        )

        // Auditoría
        await client.query(
          `INSERT INTO auth_events (user_id, event_type, ip_address, user_agent, metadata)
           VALUES ($1, 'sos_resolved', $2, $3, $4)`,
          [
            emergency.user_id,
            getClientIp(req),
            req.headers.get('user-agent'),
            JSON.stringify({ emergencyId: emergency.id, resolvedBy: auth.userId }),
          ],
        )
      }

      return emergency
    })

    return NextResponse.json({ success: true, emergency: serialize(result) })
  } catch (err) {
    if ((err as { code?: string })?.code === 'not_found') {
      return NextResponse.json({ success: false, error: 'not_found' }, { status: 404 })
    }
    console.error('[emergencies/PATCH] error:', err)
    return NextResponse.json({ success: false, error: 'server_error' }, { status: 500 })
  }
}
