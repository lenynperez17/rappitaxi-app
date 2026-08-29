/**
 * POST /api/events/ticket
 *
 * Emite un ticket de un solo uso (TTL 60 s) para autenticar la conexión SSE.
 * Evita exponer el JWT en la URL del stream (que quedaría en logs de nginx,
 * cabeceras Referer y historial del navegador).
 *
 * Flujo cliente:
 *   const { ticket } = await api.getSseTicket()
 *   const es = new EventSource(`/api/events/stream?ticket=${ticket}`)
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth, getClientIp } from '@/lib/auth-middleware'
import { maybeOne } from '@/lib/db'

export const runtime = 'nodejs'

export async function POST(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  const row = await maybeOne<{ ticket: string; expires_at: Date }>(
    // Ronda 282: se guarda la sesión de origen. El stream la usa para cerrarse
    // cuando esa sesión concreta muere — antes solo podía comprobar que al
    // usuario le quedara alguna viva, y tras expulsar a un dispositivo la del
    // dispositivo nuevo hacía pasar esa comprobación. Ver la migración 028.
    `INSERT INTO sse_tickets (user_id, ip_address, user_agent, session_id)
     VALUES ($1, $2::inet, $3, $4)
     RETURNING ticket, expires_at`,
    [auth.userId, getClientIp(req) || null, req.headers.get('user-agent'), auth.sessionId],
  )

  if (!row) {
    return NextResponse.json({ success: false, error: 'ticket_creation_failed' }, { status: 500 })
  }

  return NextResponse.json(
    {
      success: true,
      ticket: row.ticket,
      expiresAt: row.expires_at.toISOString(),
      ttlSeconds: 60,
    },
    {
      headers: {
        'Cache-Control': 'private, no-store',
        'Referrer-Policy': 'no-referrer',
      },
    },
  )
}
