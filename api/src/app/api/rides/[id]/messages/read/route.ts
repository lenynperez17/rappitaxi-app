/**
 * POST /api/rides/:id/messages/read
 *
 * Marca como leídos todos los mensajes del chat del ride que fueron
 * enviados por la contraparte y aún no tienen read_at.
 * Solo el passenger o el driver del ride pueden invocar.
 *
 * Response: { success:true, marked:<n> }
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { maybeOne, queryFull } from '@/lib/db'

export const runtime = 'nodejs'

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

interface RideRow {
  passenger_id: string | null
  driver_id: string | null
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

  const ride = await maybeOne<RideRow>(
    'SELECT passenger_id, driver_id FROM rides WHERE id = $1',
    [rideId],
  )
  if (!ride) {
    return NextResponse.json({ success: false, error: 'ride_not_found' }, { status: 404 })
  }
  if (ride.passenger_id !== auth.userId && ride.driver_id !== auth.userId) {
    return NextResponse.json({ success: false, error: 'not_ride_participant' }, { status: 403 })
  }

  const result = await queryFull(
    `UPDATE ride_messages
        SET read_at = now()
      WHERE ride_id = $1
        AND sender_id <> $2
        AND read_at IS NULL`,
    [rideId, auth.userId],
  )

  return NextResponse.json({ success: true, marked: result.rowCount ?? 0 })
}
