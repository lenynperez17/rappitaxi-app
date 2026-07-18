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
import { isUuid } from '@/lib/uuid'

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
  if (!isUuid(id)) {
    return NextResponse.json({ success: false, error: 'invalid_id' }, { status: 400 })
  }

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
  if (!isUuid(id)) {
    return NextResponse.json({ success: false, error: 'invalid_id' }, { status: 400 })
  }

  let body: { status?: string; resolvedBy?: string | null; description?: string | null }
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ success: false, error: 'bad_json' }, { status: 400 })
  }

  if (body.status !== undefined && !VALID_STATUS.has(body.status)) {
    return NextResponse.json({ success: false, error: 'invalid_status' }, { status: 400 })
  }

  // Ronda 41 Bug#2: resolvedBy solo aceptable cuando también se setea
  // status='resolved'. Sin este guard, PATCH { resolvedBy: X } dejaba fila
  // con resolved_by poblado + status='active' + resolved_at=NULL rompiendo
  // el invariante y confundiendo reportes filtrados por resolved_at.
  const nextStatus = body.status
  const willResolve = nextStatus === 'resolved'
  if (body.resolvedBy !== undefined && !willResolve) {
    return NextResponse.json({
      success: false,
      error: 'resolved_by_requires_resolve',
      message: 'resolvedBy solo se acepta cuando status=resolved',
    }, { status: 400 })
  }

  const updates: string[] = []
  const params: unknown[] = []
  let idx = 1

  if (nextStatus !== undefined) {
    updates.push(`status = $${idx++}`)
    params.push(nextStatus)
  }
  if (body.resolvedBy !== undefined) {
    // Ronda 214 SECURITY: validar que resolvedBy sea (a) UUID válido y (b)
    // un admin real. Antes admin podía sembrar resolved_by='attacker-id'
    // para culpar a otro operador y ensuciar audit trail forense.
    if (body.resolvedBy !== null) {
      if (typeof body.resolvedBy !== 'string' || !isUuid(body.resolvedBy)) {
        return NextResponse.json(
          { success: false, error: 'invalid_resolved_by' },
          { status: 400 },
        )
      }
      const adminExists = await maybeOne<{ id: string }>(
        `SELECT id FROM users
          WHERE id = $1 AND (is_admin = true OR user_type = 'admin')
            AND deleted_at IS NULL`,
        [body.resolvedBy],
      )
      if (!adminExists) {
        return NextResponse.json(
          { success: false, error: 'resolved_by_not_admin' },
          { status: 400 },
        )
      }
    }
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
      // Ronda 41 Bug#1: SELECT FOR UPDATE dentro de la tx para atomicidad.
      // Antes: SELECT fuera → dos admins con PATCH concurrente pasaban ambos
      // ALLOWED_TRANSITIONS y el UPDATE second ganaba en silencio (podía
      // materializar resolved→cancelled o vv, prohibido por el state machine).
      if (nextStatus !== undefined) {
        const cur = await client.query<{ status: string }>(
          `SELECT status FROM emergencies WHERE id = $1 FOR UPDATE`,
          [id],
        )
        if (cur.rowCount === 0) throw { code: 'not_found' }
        const currentStatus = cur.rows[0]!.status
        if (currentStatus !== nextStatus) {
          const allowed = ALLOWED_TRANSITIONS[currentStatus] ?? []
          if (!allowed.includes(nextStatus)) {
            throw { code: 'invalid_transition', currentStatus, nextStatus }
          }
        }
      }
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
    const known = err as { code?: string; currentStatus?: string; nextStatus?: string }
    if (known?.code === 'not_found') {
      return NextResponse.json({ success: false, error: 'not_found' }, { status: 404 })
    }
    if (known?.code === 'invalid_transition') {
      return NextResponse.json({
        success: false,
        error: 'invalid_transition',
        message: `No se permite pasar de '${known.currentStatus}' a '${known.nextStatus}'`,
        currentStatus: known.currentStatus,
      }, { status: 409 })
    }
    console.error('[emergencies/PATCH] error:', err)
    return NextResponse.json({ success: false, error: 'server_error' }, { status: 500 })
  }
}
