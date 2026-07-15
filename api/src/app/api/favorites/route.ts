/**
 * /api/favorites
 *
 * GET  — Lista favoritos del user autenticado (direcciones guardadas).
 *
 * POST — Agrega un favorito.
 *        Body: { label, address, latitude?, longitude?, icon? }
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { query, isUniqueViolation } from '@/lib/db'

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
// GET — Lista favoritos
// ============================================================================
export async function GET(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  const rows = await query<FavoriteRow>(
    `SELECT id, user_id, label, address, latitude::text, longitude::text, icon, created_at
       FROM user_favorites
       WHERE user_id = $1
       ORDER BY created_at ASC`,
    [auth.userId],
  )

  return NextResponse.json({ success: true, favorites: rows.map(serialize) })
}

// ============================================================================
// POST — Agregar favorito
// ============================================================================
export async function POST(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

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

  const label = body.label?.trim()
  const address = body.address?.trim()
  if (!label || !address) {
    return NextResponse.json(
      { success: false, error: 'invalid_input', message: 'label y address son requeridos' },
      { status: 400 },
    )
  }

  const latitude = body.latitude != null && Number.isFinite(Number(body.latitude))
    ? Number(body.latitude)
    : null
  const longitude = body.longitude != null && Number.isFinite(Number(body.longitude))
    ? Number(body.longitude)
    : null
  const icon = body.icon?.trim() || null

  // Ronda 49 Bug#1: try/catch en el INSERT — sin esto, unique violation
  // (label duplicado por user) o pool error → 500 con stacktrace expuesta.
  try {
    const rows = await query<FavoriteRow>(
      `INSERT INTO user_favorites (user_id, label, address, latitude, longitude, icon)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING id, user_id, label, address, latitude::text, longitude::text, icon, created_at`,
      [auth.userId, label, address, latitude, longitude, icon],
    )
    return NextResponse.json({ success: true, favorite: serialize(rows[0]!) })
  } catch (err) {
    if (isUniqueViolation(err)) {
      return NextResponse.json(
        { success: false, error: 'duplicate_label', message: 'Ya tienes un favorito con ese nombre' },
        { status: 409 },
      )
    }
    console.error('[favorites/POST] error:', err)
    return NextResponse.json({ success: false, error: 'server_error' }, { status: 500 })
  }
}
