/**
 * GET  /api/rides/:id/messages
 *   Lista mensajes del chat del ride. Query params:
 *     ?since=<isoDate>   — opcional, solo mensajes con created_at > since
 *     ?limit=<n>         — opcional, default 100, tope 500
 *   Solo el passenger o el driver asignado al ride pueden leer el chat.
 *   Retorna { success:true, messages:[...] } orden ASC por created_at.
 *
 * POST /api/rides/:id/messages
 *   Envía un mensaje al chat del ride. Body: { body?, attachmentUrl? }.
 *   Al menos uno de los dos debe venir. Solo passenger o driver del ride.
 *   Inserta ride_messages + una notification para la contraparte con
 *   type='new_message'.
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { query, maybeOne, tx } from '@/lib/db'

export const runtime = 'nodejs'

// Regex para validar UUID (evita SQL error 22P02 en inputs mal formateados)
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

interface RideParticipants {
  passenger_id: string | null
  driver_id: string | null
  status: string
}

interface MessageRow {
  id: string
  sender_id: string
  sender_name: string | null
  body: string | null
  attachment_url: string | null
  read_at: Date | null
  created_at: Date
}

/** Valida que el user es passenger o driver del ride y devuelve la info. */
async function loadRideParticipation(
  rideId: string,
  userId: string,
): Promise<
  | { ok: true; ride: RideParticipants; role: 'passenger' | 'driver'; counterpartyId: string | null }
  | { ok: false; status: number; error: string }
> {
  const ride = await maybeOne<RideParticipants>(
    'SELECT passenger_id, driver_id, status FROM rides WHERE id = $1',
    [rideId],
  )
  if (!ride) return { ok: false, status: 404, error: 'ride_not_found' }

  if (ride.passenger_id === userId) {
    return { ok: true, ride, role: 'passenger', counterpartyId: ride.driver_id }
  }
  if (ride.driver_id === userId) {
    return { ok: true, ride, role: 'driver', counterpartyId: ride.passenger_id }
  }
  return { ok: false, status: 403, error: 'not_ride_participant' }
}

export async function GET(
  req: NextRequest,
  ctx: { params: Promise<{ id: string }> },
) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  const { id: rideId } = await ctx.params
  if (!UUID_RE.test(rideId)) {
    return NextResponse.json({ success: false, error: 'invalid_ride_id' }, { status: 400 })
  }

  const participation = await loadRideParticipation(rideId, auth.userId)
  if (!participation.ok) {
    return NextResponse.json(
      { success: false, error: participation.error },
      { status: participation.status },
    )
  }

  const url = new URL(req.url)
  const sinceRaw = url.searchParams.get('since')
  const limitRaw = url.searchParams.get('limit')

  let since: Date | null = null
  if (sinceRaw) {
    const parsed = new Date(sinceRaw)
    if (Number.isNaN(parsed.getTime())) {
      return NextResponse.json({ success: false, error: 'invalid_since' }, { status: 400 })
    }
    since = parsed
  }

  const limit = Math.min(Math.max(parseInt(limitRaw ?? '100', 10) || 100, 1), 500)

  const rows = await query<MessageRow>(
    `SELECT m.id,
            m.sender_id,
            COALESCE(u.display_name, u.full_name) AS sender_name,
            m.body,
            m.attachment_url,
            m.read_at,
            m.created_at
       FROM ride_messages m
       LEFT JOIN users u ON u.id = m.sender_id
       WHERE m.ride_id = $1
         AND ($2::timestamptz IS NULL OR m.created_at > $2::timestamptz)
       ORDER BY m.created_at ASC
       LIMIT $3`,
    [rideId, since, limit],
  )

  const messages = rows.map((r) => ({
    id: r.id,
    senderId: r.sender_id,
    senderName: r.sender_name,
    body: r.body,
    attachmentUrl: r.attachment_url,
    readAt: r.read_at ? r.read_at.toISOString() : null,
    createdAt: r.created_at.toISOString(),
  }))

  return NextResponse.json({ success: true, messages })
}

export async function POST(
  req: NextRequest,
  ctx: { params: Promise<{ id: string }> },
) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  const { id: rideId } = await ctx.params
  if (!UUID_RE.test(rideId)) {
    return NextResponse.json({ success: false, error: 'invalid_ride_id' }, { status: 400 })
  }

  let payload: { body?: unknown; attachmentUrl?: unknown } = {}
  try {
    payload = await req.json()
  } catch {
    return NextResponse.json({ success: false, error: 'bad_json' }, { status: 400 })
  }

  const body =
    typeof payload.body === 'string' && payload.body.trim().length > 0
      ? payload.body.trim().slice(0, 4000)
      : null
  const attachmentUrl =
    typeof payload.attachmentUrl === 'string' && payload.attachmentUrl.trim().length > 0
      ? payload.attachmentUrl.trim().slice(0, 2048)
      : null

  if (!body && !attachmentUrl) {
    return NextResponse.json(
      { success: false, error: 'empty_message', message: 'Se requiere body o attachmentUrl' },
      { status: 400 },
    )
  }

  const participation = await loadRideParticipation(rideId, auth.userId)
  if (!participation.ok) {
    return NextResponse.json(
      { success: false, error: participation.error },
      { status: participation.status },
    )
  }

  // No permitir enviar mensajes cuando el ride ya terminó — evita spam
  // post-viaje y confusión con conversaciones "fantasmas".
  const closedStates = new Set(['completed', 'cancelled', 'no_show', 'expired'])
  if (closedStates.has(participation.ride.status)) {
    return NextResponse.json(
      {
        success: false,
        error: 'ride_closed',
        message: `El viaje está ${participation.ride.status}; no se pueden enviar más mensajes.`,
      },
      { status: 409 },
    )
  }

  try {
    const result = await tx(async (client) => {
      const inserted = await client.query<{
        id: string
        created_at: Date
      }>(
        `INSERT INTO ride_messages (ride_id, sender_id, body, attachment_url)
         VALUES ($1, $2, $3, $4)
         RETURNING id, created_at`,
        [rideId, auth.userId, body, attachmentUrl],
      )
      const row = inserted.rows[0]!

      // Nombre del sender para el título del push in-app
      const sender = await client.query<{ name: string | null }>(
        `SELECT COALESCE(display_name, full_name) AS name FROM users WHERE id = $1`,
        [auth.userId],
      )
      const senderName = sender.rows[0]?.name ?? 'Usuario'

      if (participation.counterpartyId) {
        await client.query(
          `INSERT INTO notifications (user_id, type, title, body, data)
           VALUES ($1, 'new_message', $2, $3, $4::jsonb)`,
          [
            participation.counterpartyId,
            `Nuevo mensaje de ${senderName}`,
            body ?? '[Adjunto]',
            JSON.stringify({
              rideId,
              messageId: row.id,
              senderId: auth.userId,
              senderName,
              hasAttachment: attachmentUrl !== null,
            }),
          ],
        )
      }

      return { id: row.id, createdAt: row.created_at }
    })

    return NextResponse.json(
      {
        success: true,
        message: {
          id: result.id,
          senderId: auth.userId,
          body,
          attachmentUrl,
          createdAt: result.createdAt.toISOString(),
        },
      },
      { status: 201 },
    )
  } catch (err) {
    console.error('[rides/messages] POST error:', err)
    return NextResponse.json({ success: false, error: 'internal_error' }, { status: 500 })
  }
}
