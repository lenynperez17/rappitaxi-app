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

export async function POST(req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response
  const { id } = await ctx.params

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
