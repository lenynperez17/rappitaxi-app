/**
 * /api/favorites/[id]
 *
 * PATCH  — Actualiza un favorito del user (label, address, latitude, longitude, icon).
 *
 * DELETE — Borra el favorito (solo del user autenticado).
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { query } from '@/lib/db'

export const runtime = 'nodejs'

interface FavoriteRow {
  id: string
  user_id: string
  label: string
  address: string
  latitude: string | null
  longitude: string | null
  icon: string | null
  created_at: Date
}

function serialize(f: FavoriteRow) {
  return {
    id: f.id,
    userId: f.user_id,
    label: f.label,
    address: f.address,
    latitude: f.latitude !== null ? Number(f.latitude) : null,
    longitude: f.longitude !== null ? Number(f.longitude) : null,
    icon: f.icon,
    createdAt: f.created_at,
  }
}

// ============================================================================
// PATCH — Actualizar
// ============================================================================
export async function PATCH(req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response
  const { id } = await ctx.params

  let body: {
    label?: string
    address?: string
    latitude?: number | null
    longitude?: number | null
    icon?: string | null
  }
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ success: false, error: 'bad_json' }, { status: 400 })
  }

  const updates: string[] = []
  const params: unknown[] = []
  let idx = 1

  if (body.label !== undefined) {
    if (!body.label.trim()) {
      return NextResponse.json({ success: false, error: 'invalid_label' }, { status: 400 })
    }
    updates.push(`label = $${idx++}`)
    params.push(body.label.trim())
  }
  if (body.address !== undefined) {
    if (!body.address.trim()) {
      return NextResponse.json({ success: false, error: 'invalid_address' }, { status: 400 })
    }
    updates.push(`address = $${idx++}`)
    params.push(body.address.trim())
  }
  if (body.latitude !== undefined) {
    const lat = body.latitude === null ? null : Number(body.latitude)
    if (lat !== null && !Number.isFinite(lat)) {
      return NextResponse.json({ success: false, error: 'invalid_latitude' }, { status: 400 })
    }
    updates.push(`latitude = $${idx++}`)
    params.push(lat)
  }
  if (body.longitude !== undefined) {
    const lng = body.longitude === null ? null : Number(body.longitude)
    if (lng !== null && !Number.isFinite(lng)) {
      return NextResponse.json({ success: false, error: 'invalid_longitude' }, { status: 400 })
    }
    updates.push(`longitude = $${idx++}`)
    params.push(lng)
  }
  if (body.icon !== undefined) {
    // Ronda 54 Bug#2: verificar typeof string antes de trim() para evitar
    // TypeError → 500 si el cliente envía number/boolean/object.
    updates.push(`icon = $${idx++}`)
    params.push(typeof body.icon === 'string' ? (body.icon.trim() || null) : null)
  }

  if (updates.length === 0) {
    return NextResponse.json(
      { success: false, error: 'no_changes', message: 'Nada para actualizar' },
      { status: 400 },
    )
  }

  params.push(id, auth.userId)

  const rows = await query<FavoriteRow>(
    `UPDATE user_favorites SET ${updates.join(', ')}
       WHERE id = $${idx} AND user_id = $${idx + 1}
     RETURNING id, user_id, label, address, latitude::text, longitude::text, icon, created_at`,
    params,
  )

  if (rows.length === 0) {
    return NextResponse.json({ success: false, error: 'not_found' }, { status: 404 })
  }
  return NextResponse.json({ success: true, favorite: serialize(rows[0]!) })
}

// ============================================================================
// DELETE — Borrar
// ============================================================================
export async function DELETE(req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response
  const { id } = await ctx.params

  const rows = await query<{ id: string }>(
    `DELETE FROM user_favorites WHERE id = $1 AND user_id = $2 RETURNING id`,
    [id, auth.userId],
  )
  if (rows.length === 0) {
    return NextResponse.json({ success: false, error: 'not_found' }, { status: 404 })
  }
  return NextResponse.json({ success: true, deletedId: rows[0]!.id })
}
