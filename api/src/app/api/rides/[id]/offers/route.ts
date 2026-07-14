/**
 * GET  /api/rides/:id/offers
 *   Lista las ofertas activas de drivers al viaje. Solo el passenger dueño
 *   del ride puede consultarlas. Ordena por eta_seconds ASC (más rápido
 *   primero). Incluye nombre, foto, rating promedio, tipo de vehículo y
 *   distancia estimada del driver al pickup (haversine_km).
 *
 * POST /api/rides/:id/offers
 *   Un driver oferta al viaje. Body: { amount?, etaSeconds?, message? }.
 *   Verifica que:
 *     - auth.userId es driver
 *     - existe presencia con is_online=true
 *     - el ride está en 'requested' o 'searching'
 *   Si ya existe una oferta previa del mismo driver, hace UPDATE. Si no,
 *   INSERT. Notifica al passenger con type='new_offer'.
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { query, maybeOne, tx, isUniqueViolation } from '@/lib/db'

export const runtime = 'nodejs'

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

interface RideRow {
  passenger_id: string | null
  driver_id: string | null
  status: string
  pickup_lat: string | null
  pickup_lng: string | null
}

interface OfferListRow {
  id: string
  driver_id: string
  amount: string | null
  eta_seconds: number | null
  message: string | null
  status: string
  created_at: Date
  driver_name: string | null
  driver_photo: string | null
  driver_rating: string | null
  vehicle_type: string | null
  distance_km: string | null
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

  const ride = await maybeOne<RideRow>(
    `SELECT passenger_id, driver_id, status, pickup_lat, pickup_lng
       FROM rides WHERE id = $1`,
    [rideId],
  )
  if (!ride) {
    return NextResponse.json({ success: false, error: 'ride_not_found' }, { status: 404 })
  }
  if (ride.passenger_id !== auth.userId) {
    return NextResponse.json({ success: false, error: 'not_ride_passenger' }, { status: 403 })
  }

  const rows = await query<OfferListRow>(
    `SELECT o.id,
            o.driver_id,
            o.amount,
            o.eta_seconds,
            o.message,
            o.status,
            o.created_at,
            COALESCE(u.display_name, u.full_name) AS driver_name,
            u.profile_photo_url AS driver_photo,
            (SELECT AVG(stars)::numeric(3,2)
               FROM ride_ratings r
              WHERE r.rated_user_id = o.driver_id AND r.role = 'driver') AS driver_rating,
            dp.vehicle_type,
            CASE
              WHEN $2::numeric IS NOT NULL AND $3::numeric IS NOT NULL
                   AND dp.latitude IS NOT NULL AND dp.longitude IS NOT NULL
              THEN haversine_km(dp.latitude, dp.longitude, $2::numeric, $3::numeric)
              ELSE NULL
            END AS distance_km
       FROM ride_offers o
       LEFT JOIN users u ON u.id = o.driver_id
       LEFT JOIN driver_presence dp ON dp.driver_id = o.driver_id
      WHERE o.ride_id = $1 AND o.status = 'pending'
      ORDER BY o.eta_seconds ASC NULLS LAST, o.created_at ASC`,
    [rideId, ride.pickup_lat, ride.pickup_lng],
  )

  const offers = rows.map((r) => ({
    id: r.id,
    driverId: r.driver_id,
    driverName: r.driver_name,
    driverPhoto: r.driver_photo,
    driverRating: r.driver_rating !== null ? Number(r.driver_rating) : null,
    driverVehicleType: r.vehicle_type,
    amount: r.amount !== null ? Number(r.amount) : null,
    etaSeconds: r.eta_seconds,
    message: r.message,
    status: r.status,
    distanceKm: r.distance_km !== null ? Number(r.distance_km) : null,
    createdAt: r.created_at.toISOString(),
  }))

  return NextResponse.json({ success: true, offers })
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

  let payload: { amount?: unknown; etaSeconds?: unknown; message?: unknown } = {}
  try {
    payload = await req.json()
  } catch {
    return NextResponse.json({ success: false, error: 'bad_json' }, { status: 400 })
  }

  const amount =
    payload.amount === undefined || payload.amount === null
      ? null
      : Number(payload.amount)
  const etaSeconds =
    payload.etaSeconds === undefined || payload.etaSeconds === null
      ? null
      : Math.trunc(Number(payload.etaSeconds))
  const message =
    typeof payload.message === 'string' && payload.message.trim().length > 0
      ? payload.message.trim().slice(0, 500)
      : null

  if (amount !== null && (!Number.isFinite(amount) || amount <= 0)) {
    return NextResponse.json({ success: false, error: 'invalid_amount' }, { status: 400 })
  }
  // Cap absoluto — sin esto un driver malicioso podía ofertar S/999999
  // que si el passenger acepta por fat-finger, wallet drain.
  if (amount !== null && amount > 500) {
    return NextResponse.json(
      { success: false, error: 'amount_too_high', message: 'La oferta no puede exceder S/ 500.' },
      { status: 400 },
    )
  }
  if (etaSeconds !== null && (!Number.isFinite(etaSeconds) || etaSeconds < 0)) {
    return NextResponse.json({ success: false, error: 'invalid_eta' }, { status: 400 })
  }
  if (amount === null && etaSeconds === null && !message) {
    return NextResponse.json({ success: false, error: 'empty_offer' }, { status: 400 })
  }

  try {
    const result = await tx(async (client) => {
      // 1. Verificar que el user es driver
      const userRes = await client.query<{ user_type: string }>(
        'SELECT user_type FROM users WHERE id = $1',
        [auth.userId],
      )
      const user = userRes.rows[0]
      if (!user) throw { code: 'user_not_found', status: 404 }
      // B#13: aceptar 'dual' además de 'driver'. Un usuario dual ya puede
      // aceptar negociaciones y viajes; bloquearlo solo aquí era incoherente.
      if (user.user_type !== 'driver' && user.user_type !== 'dual') {
        throw { code: 'not_a_driver', status: 403 }
      }

      // 2. Verificar presencia online
      const presenceRes = await client.query<{ is_online: boolean }>(
        'SELECT is_online FROM driver_presence WHERE driver_id = $1',
        [auth.userId],
      )
      const presence = presenceRes.rows[0]
      if (!presence || !presence.is_online) {
        throw { code: 'driver_offline', status: 403 }
      }

      // 3. Verificar estado del ride (con lock ligero)
      const rideRes = await client.query<{
        passenger_id: string | null
        status: string
      }>(
        'SELECT passenger_id, status FROM rides WHERE id = $1 FOR UPDATE',
        [rideId],
      )
      const ride = rideRes.rows[0]
      if (!ride) throw { code: 'ride_not_found', status: 404 }

      const openStates = new Set(['requested', 'searching'])
      if (!openStates.has(ride.status)) {
        throw { code: 'ride_not_open', status: 409, currentStatus: ride.status }
      }
      if (ride.passenger_id === auth.userId) {
        throw { code: 'cannot_offer_own_ride', status: 403 }
      }

      // 4. UPSERT: UNIQUE(ride_id, driver_id) — si repite, UPDATE
      const upsertRes = await client.query<{ id: string; created_at: Date; is_new: boolean }>(
        `INSERT INTO ride_offers (ride_id, driver_id, amount, eta_seconds, message, status)
         VALUES ($1, $2, $3, $4, $5, 'pending')
         ON CONFLICT (ride_id, driver_id) DO UPDATE
            SET amount = EXCLUDED.amount,
                eta_seconds = EXCLUDED.eta_seconds,
                message = EXCLUDED.message,
                status = 'pending',
                responded_at = NULL,
                created_at = ride_offers.created_at
         RETURNING id,
                   created_at,
                   (xmax = 0) AS is_new`,
        [rideId, auth.userId, amount, etaSeconds, message],
      )
      const offer = upsertRes.rows[0]!

      // 5. Nombre del driver para el push
      const driverName = await client.query<{ name: string | null }>(
        `SELECT COALESCE(display_name, full_name) AS name FROM users WHERE id = $1`,
        [auth.userId],
      )
      const nameStr = driverName.rows[0]?.name ?? 'Conductor'

      // 6. Notificar al passenger
      if (ride.passenger_id) {
        await client.query(
          `INSERT INTO notifications (user_id, type, title, body, data)
           VALUES ($1, 'new_offer', $2, $3, $4::jsonb)`,
          [
            ride.passenger_id,
            offer.is_new ? `Nueva oferta de ${nameStr}` : `${nameStr} actualizó su oferta`,
            amount !== null ? `Precio: S/ ${amount.toFixed(2)}` : (message ?? 'Oferta enviada'),
            JSON.stringify({
              rideId,
              offerId: offer.id,
              driverId: auth.userId,
              driverName: nameStr,
              amount,
              etaSeconds,
            }),
          ],
        )
      }

      return { offerId: offer.id, isNew: offer.is_new, createdAt: offer.created_at }
    })

    return NextResponse.json(
      {
        success: true,
        offer: {
          id: result.offerId,
          rideId,
          driverId: auth.userId,
          amount,
          etaSeconds,
          message,
          status: 'pending',
          createdAt: result.createdAt.toISOString(),
        },
      },
      { status: result.isNew ? 201 : 200 },
    )
  } catch (err) {
    const e = err as { code?: string; status?: number; currentStatus?: string }
    if (typeof e?.code === 'string' && typeof e?.status === 'number') {
      return NextResponse.json(
        {
          success: false,
          error: e.code,
          ...(e.currentStatus ? { currentStatus: e.currentStatus } : {}),
        },
        { status: e.status },
      )
    }
    if (isUniqueViolation(err)) {
      return NextResponse.json({ success: false, error: 'duplicate_offer' }, { status: 409 })
    }
    console.error('[rides/offers] POST error:', err)
    return NextResponse.json({ success: false, error: 'internal_error' }, { status: 500 })
  }
}
