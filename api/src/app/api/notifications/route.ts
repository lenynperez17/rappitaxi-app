/**
 * /api/notifications
 *
 * GET    — Lista notifications del user autenticado.
 *          Query: ?onlyUnread=1&limit=50
 *          ORDER BY created_at DESC
 *          Retorna también `unreadCount`.
 *
 * DELETE — Borra todas las notifications LEÍDAS del user autenticado
 *          (deja las no leídas).
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { one, query, queryFull } from '@/lib/db'

export const runtime = 'nodejs'

interface NotificationRow {
  id: string
  user_id: string
  type: string
  title: string
  body: string | null
  data: Record<string, unknown> | null
  read_at: Date | null
  created_at: Date
}

function serialize(n: NotificationRow) {
  return {
    id: n.id,
    userId: n.user_id,
    type: n.type,
    title: n.title,
    body: n.body,
    data: n.data,
    readAt: n.read_at,
    createdAt: n.created_at,
  }
}

// ============================================================================
// GET — Lista
// ============================================================================
export async function GET(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  const { searchParams } = new URL(req.url)
  const onlyUnread = searchParams.get('onlyUnread') === '1'
  const limitRaw = Number(searchParams.get('limit') ?? 50)
  const limit = Number.isFinite(limitRaw) && limitRaw > 0 && limitRaw <= 200 ? Math.floor(limitRaw) : 50

  const filters: string[] = [`user_id = $1`]
  const params: unknown[] = [auth.userId]
  let idx = 2
  if (onlyUnread) {
    filters.push('read_at IS NULL')
  }
  params.push(limit)

  const rows = await query<NotificationRow>(
    `SELECT id, user_id, type, title, body, data, read_at, created_at
       FROM notifications
       WHERE ${filters.join(' AND ')}
       ORDER BY created_at DESC
       LIMIT $${idx}`,
    params,
  )

  const countRow = await one<{ unread: string }>(
    `SELECT COUNT(*)::text AS unread FROM notifications
      WHERE user_id = $1 AND read_at IS NULL`,
    [auth.userId],
  )

  return NextResponse.json({
    success: true,
    notifications: rows.map(serialize),
    unreadCount: Number(countRow.unread),
  })
}

// ============================================================================
// DELETE — Borra todas las leídas
// ============================================================================
export async function DELETE(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  const res = await queryFull(
    `DELETE FROM notifications WHERE user_id = $1 AND read_at IS NOT NULL`,
    [auth.userId],
  )
  return NextResponse.json({ success: true, deleted: res.rowCount ?? 0 })
}
