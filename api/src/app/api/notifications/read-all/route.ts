/**
 * POST /api/notifications/read-all
 *
 * Marca como leídas TODAS las notifications no leídas del user autenticado.
 * Retorna el número de filas actualizadas.
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { queryFull } from '@/lib/db'

export const runtime = 'nodejs'

export async function POST(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  const res = await queryFull(
    `UPDATE notifications SET read_at = now()
      WHERE user_id = $1 AND read_at IS NULL`,
    [auth.userId],
  )

  return NextResponse.json({ success: true, updated: res.rowCount ?? 0 })
}
