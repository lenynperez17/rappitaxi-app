/**
 * GET  /api/rides/:id/negotiations
 *   Lista todas las contraofertas del ride en orden ASC. Solo passenger o
 *   driver del ride pueden consultarlas.
 *
 * POST /api/rides/:id/negotiations
 *   Propone un precio (contraoferta InDrive-style). Body: { amount, message? }.
 *   Determina automáticamente el role del user en este ride. Marca
 *   propuestas anteriores del mismo user como 'superseded' e inserta la nueva
 *   con status='pending'. Notifica a la contraparte con type='negotiation_new'.
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { query, maybeOne, tx } from '@/lib/db'

export const runtime = 'nodejs'

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

interface RideRow {
  passenger_id: string | null
  driver_id: string | null
  status: string
}

interface NegotiationRow {
  id: string
  ride_id: string
  proposed_by: string
  proposed_by_role: 'passenger' | 'driver'
  amount: string
  message: string | null
  status: string
  created_at: Date
  responded_at: Date | null
}

async function loadRide(rideId: string): Promise<RideRow | null> {
  return maybeOne<RideRow>(
    'SELECT passenger_id, driver_id, status FROM rides WHERE id = $1',
    [rideId],
  )
}

function roleOf(
  ride: RideRow,
  userId: string,
): { role: 'passenger' | 'driver'; counterpartyId: string | null } | null {
  if (ride.passenger_id === userId) return { role: 'passenger', counterpartyId: ride.driver_id }
  if (ride.driver_id === userId) return { role: 'driver', counterpartyId: ride.passenger_id }
  return null
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

  const ride = await loadRide(rideId)
  if (!ride) {
    return NextResponse.json({ success: false, error: 'ride_not_found' }, { status: 404 })
  }
  if (!roleOf(ride, auth.userId)) {
    return NextResponse.json({ success: false, error: 'not_ride_participant' }, { status: 403 })
  }

  const rows = await query<NegotiationRow>(
    `SELECT id, ride_id, proposed_by, proposed_by_role, amount, message,
            status, created_at, responded_at
       FROM ride_negotiations
       WHERE ride_id = $1
       ORDER BY created_at ASC`,
    [rideId],
  )

  const negotiations = rows.map((r) => ({
    id: r.id,
    rideId: r.ride_id,
    proposedBy: r.proposed_by,
    proposedByRole: r.proposed_by_role,
    amount: Number(r.amount),
    message: r.message,
    status: r.status,
    createdAt: r.created_at.toISOString(),
    respondedAt: r.responded_at ? r.responded_at.toISOString() : null,
  }))

  return NextResponse.json({ success: true, negotiations })
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

  let payload: { amount?: unknown; message?: unknown } = {}
  try {
    payload = await req.json()
  } catch {
    return NextResponse.json({ success: false, error: 'bad_json' }, { status: 400 })
  }

  const amount = Number(payload.amount)
  if (!Number.isFinite(amount) || amount <= 0) {
    return NextResponse.json({ success: false, error: 'invalid_amount' }, { status: 400 })
  }
  // Cap absoluto S/ 500 — mismo que rides POST y offers.
  if (amount > 500) {
    return NextResponse.json(
      { success: false, error: 'amount_too_high', message: 'El monto propuesto no puede exceder S/ 500.' },
      { status: 400 },
    )
  }
  const message =
    typeof payload.message === 'string' && payload.message.trim().length > 0
      ? payload.message.trim().slice(0, 500)
      : null

  const ride = await loadRide(rideId)
  if (!ride) {
    return NextResponse.json({ success: false, error: 'ride_not_found' }, { status: 404 })
  }

  const role = roleOf(ride, auth.userId)
  if (!role) {
    return NextResponse.json({ success: false, error: 'not_ride_participant' }, { status: 403 })
  }

  // Solo se aceptan contraofertas mientras el ride esté "en negociación"
  const negotiableStatuses = new Set(['requested', 'searching'])
  if (!negotiableStatuses.has(ride.status)) {
    return NextResponse.json(
      { success: false, error: 'ride_not_negotiable', message: `El viaje está en estado ${ride.status}` },
      { status: 409 },
    )
  }

  try {
    const result = await tx(async (client) => {
      // Marcar propuestas previas del mismo user como superseded
      await client.query(
        `UPDATE ride_negotiations
            SET status = 'superseded', responded_at = now()
          WHERE ride_id = $1 AND proposed_by = $2 AND status = 'pending'`,
        [rideId, auth.userId],
      )

      const inserted = await client.query<{ id: string; created_at: Date }>(
        `INSERT INTO ride_negotiations
           (ride_id, proposed_by, proposed_by_role, amount, message, status)
         VALUES ($1, $2, $3, $4, $5, 'pending')
         RETURNING id, created_at`,
        [rideId, auth.userId, role.role, amount, message],
      )
      const negotiation = inserted.rows[0]!

      if (role.counterpartyId) {
        await client.query(
          `INSERT INTO notifications (user_id, type, title, body, data)
           VALUES ($1, 'negotiation_new', $2, $3, $4::jsonb)`,
          [
            role.counterpartyId,
            role.role === 'passenger' ? 'Nueva oferta del pasajero' : 'Contraoferta del conductor',
            message ?? `Precio propuesto: S/ ${amount.toFixed(2)}`,
            JSON.stringify({
              rideId,
              negotiationId: negotiation.id,
              amount,
              proposedBy: auth.userId,
              proposedByRole: role.role,
            }),
          ],
        )
      }

      return { id: negotiation.id, createdAt: negotiation.created_at }
    })

    return NextResponse.json(
      {
        success: true,
        negotiation: {
          id: result.id,
          rideId,
          proposedBy: auth.userId,
          proposedByRole: role.role,
          amount,
          message,
          status: 'pending',
          createdAt: result.createdAt.toISOString(),
        },
      },
      { status: 201 },
    )
  } catch (err) {
    console.error('[rides/negotiations] POST error:', err)
    return NextResponse.json({ success: false, error: 'internal_error' }, { status: 500 })
  }
}
