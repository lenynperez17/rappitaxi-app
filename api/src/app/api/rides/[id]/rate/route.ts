/**
 * POST /api/rides/:id/rate
 *   Calificar al otro participante (passenger califica driver o viceversa).
 *   Body: { stars, comment? }
 *   Inserta en ride_ratings. UNIQUE(ride_id, rated_by) evita doble rate.
 *
 *   Persistencia:
 *   - `ride_ratings` es la fuente de verdad (una fila por rating individual).
 *   - `rides.driver_rating` / `rides.passenger_rating` guardan el rating INDIVIDUAL
 *     del viaje (no un promedio) para lectura rápida del historial.
 *   - El rating agregado del user (promedio global) se calcula con AVG(stars)
 *     sobre ride_ratings desde admin/live u otros consumidores.
 *   Ronda 21 MEDIUM: docblock corregido — antes decía "actualiza el rating
 *   agregado" pero el código siempre guardó el individual.
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { isUniqueViolation, tx } from '@/lib/db'
import { isUuid } from '@/lib/uuid'

export const runtime = 'nodejs'

interface RideCore {
  id: string
  passenger_id: string | null
  driver_id: string | null
  status: string
}

interface RatingRow {
  id: string
  stars: string
  comment: string | null
  created_at: Date
  role: string
}

export async function POST(req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response
  const { id } = await ctx.params
  if (!isUuid(id)) {
    return NextResponse.json({ success: false, error: 'invalid_id' }, { status: 400 })
  }

  let body: { stars?: number; comment?: string } = {}
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ success: false, error: 'bad_json' }, { status: 400 })
  }

  const stars = Number(body.stars ?? 0)
  if (!isFinite(stars) || stars < 1 || stars > 5) {
    return NextResponse.json(
      { success: false, error: 'invalid_stars', message: 'stars debe estar entre 1 y 5' },
      { status: 400 },
    )
  }
  const comment = body.comment?.trim().slice(0, 500) || null

  try {
    const result = await tx(async (client) => {
      const rideRes = await client.query<RideCore>(
        'SELECT id, passenger_id, driver_id, status FROM rides WHERE id = $1 FOR UPDATE',
        [id],
      )
      const ride = rideRes.rows[0]
      if (!ride) throw { code: 'not_found' }
      if (ride.status !== 'completed') {
        throw { code: 'invalid_status', message: 'Solo se pueden calificar viajes completados' }
      }

      // Determinar rol del que califica y a quién califica
      let raterRole: 'passenger' | 'driver'
      let ratedUserId: string | null
      if (ride.passenger_id === auth.userId) {
        raterRole = 'passenger'
        ratedUserId = ride.driver_id
      } else if (ride.driver_id === auth.userId) {
        raterRole = 'driver'
        ratedUserId = ride.passenger_id
      } else {
        throw { code: 'forbidden' }
      }
      if (!ratedUserId) {
        throw { code: 'no_counterpart', message: 'No hay contraparte que calificar' }
      }
      // Defensa en profundidad: NUNCA permitir auto-rating (fraude de rating).
      // El check de accept ya bloquea self-ride, pero rides pre-existentes o
      // futuros paths podrían tener passenger_id === driver_id.
      if (ratedUserId === auth.userId) {
        throw { code: 'cannot_rate_self', message: 'No puedes calificarte a ti mismo' }
      }

      // ride_ratings.role guarda el rol del CALIFICADO (patrón consistente con la app)
      const ratedRole = raterRole === 'passenger' ? 'driver' : 'passenger'

      const insertRes = await client.query<RatingRow>(
        `INSERT INTO ride_ratings (ride_id, rated_by, rated_user_id, role, stars, comment)
         VALUES ($1, $2, $3, $4, $5, $6)
         RETURNING id, stars::text, comment, created_at, role`,
        [id, auth.userId, ratedUserId, ratedRole, stars, comment],
      )
      const rating = insertRes.rows[0]!

      // Recalcular media móvil del user calificado desde ride_ratings
      const avgRes = await client.query<{ avg: string | null; count: string }>(
        'SELECT AVG(stars)::text AS avg, COUNT(*)::text AS count FROM ride_ratings WHERE rated_user_id = $1',
        [ratedUserId],
      )
      const avg = avgRes.rows[0]?.avg !== null && avgRes.rows[0]?.avg !== undefined
        ? Number(avgRes.rows[0].avg)
        : stars
      const count = Number(avgRes.rows[0]?.count ?? 1)
      const roundedAvg = Math.round(avg * 10) / 10

      // Ronda 250: el promedio se calculaba (roundedAvg) pero NUNCA se
      // persistía en ningún sitio — la columna users.rating no existía. El
      // cliente hace `rating: json['rating'] ?? 5.0`, así que TODOS los
      // usuarios mostraban 5.0 estrellas permanentemente: un rating falso en
      // el drawer, el perfil y la tarjeta de oferta que el pasajero usa para
      // decidir con qué conductor viajar.
      await client.query(
        `UPDATE users SET rating = $1, total_ratings = $2 WHERE id = $3`,
        [roundedAvg, count, ratedUserId],
      )

      // Guardar snapshot rápido en la propia fila rides
      if (raterRole === 'passenger') {
        await client.query(
          `UPDATE rides SET driver_rating = $1 WHERE id = $2`,
          [stars, id],
        )
      } else {
        await client.query(
          `UPDATE rides SET passenger_rating = $1 WHERE id = $2`,
          [stars, id],
        )
      }

      // Notificar al calificado
      await client.query(
        `INSERT INTO notifications (user_id, type, title, body, data)
         VALUES ($1, 'ride_rated', $2, $3, $4)`,
        [
          ratedUserId,
          'Recibiste una calificación',
          `Nueva calificación de ${stars} estrellas`,
          JSON.stringify({
            rideId: id,
            ratedBy: auth.userId,
            stars,
            comment,
            newAverage: roundedAvg,
            totalRatings: count,
          }),
        ],
      )

      return { rating, ratedUserId, newAverage: roundedAvg, totalRatings: count }
    })

    return NextResponse.json({
      success: true,
      rating: {
        id: result.rating.id,
        stars: Number(result.rating.stars),
        comment: result.rating.comment,
        role: result.rating.role,
        createdAt: result.rating.created_at,
      },
      ratedUserId: result.ratedUserId,
      newAverage: result.newAverage,
      totalRatings: result.totalRatings,
    })
  } catch (err) {
    if (isUniqueViolation(err)) {
      return NextResponse.json(
        { success: false, error: 'already_rated', message: 'Ya calificaste este viaje' },
        { status: 409 },
      )
    }
    const knownCode = (err as { code?: string; message?: string })?.code
    if (knownCode === 'not_found') {
      return NextResponse.json({ success: false, error: 'not_found' }, { status: 404 })
    }
    if (knownCode === 'invalid_status') {
      return NextResponse.json(
        { success: false, error: 'invalid_status', message: (err as { message?: string }).message },
        { status: 409 },
      )
    }
    if (knownCode === 'forbidden') {
      return NextResponse.json({ success: false, error: 'forbidden' }, { status: 403 })
    }
    if (knownCode === 'no_counterpart') {
      return NextResponse.json(
        { success: false, error: 'no_counterpart', message: (err as { message?: string }).message },
        { status: 409 },
      )
    }
    // Ronda 75: mapear cannot_rate_self antes del fallback 500
    if (knownCode === 'cannot_rate_self') {
      return NextResponse.json(
        { success: false, error: 'cannot_rate_self', message: (err as { message?: string }).message },
        { status: 409 },
      )
    }
    console.error('[rides/rate] error:', err)
    return NextResponse.json({ success: false, error: 'internal_error' }, { status: 500 })
  }
}
