/**
 * POST /api/notifications/[id]/read
 *
 * Marca una notification como leída para el user autenticado.
 * Si ya estaba leída, es idempotente (no actualiza read_at).
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { query } from '@/lib/db'

export const runtime = 'nodejs'

interface UpdRow {
  id: string
  read_at: Date | null
}

// UUID v4 pattern — evita que Postgres tire 22P02 (invalid syntax) al
// pasar el string al UPDATE, que sin catch se convertía en 500.
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

export async function POST(req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response
  const { id } = await ctx.params

  if (!UUID_RE.test(id)) {
    return NextResponse.json({ success: false, error: 'invalid_id' }, { status: 400 })
  }

  const rows = await query<UpdRow>(
    `UPDATE notifications
        SET read_at = COALESCE(read_at, now())
      WHERE id = $1 AND user_id = $2
    RETURNING id, read_at`,
    [id, auth.userId],
  )

  if (rows.length === 0) {
    return NextResponse.json({ success: false, error: 'not_found' }, { status: 404 })
  }

  return NextResponse.json({ success: true, id: rows[0]!.id, readAt: rows[0]!.read_at })
}
