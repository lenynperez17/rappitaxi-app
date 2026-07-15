/**
 * POST /api/vales/apply
 * Auth: Bearer <access_token>
 * Body: { code: string, rideId: string, rideAmount: number }
 *
 * Aplica el vale: registra en `vale_usages`, incrementa `used_count`.
 * Se ejecuta en transacción con UPDATE conditional para evitar
 * carreras (2 requests simultáneos del mismo user con el último uso).
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { tx, isUniqueViolation } from '@/lib/db'

export const runtime = 'nodejs'

export async function POST(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  let body: { code?: string; rideId?: string; rideAmount?: number } = {}
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ success: false, error: 'bad_json' }, { status: 400 })
  }

  const code = body.code?.trim().toUpperCase()
  const rideId = body.rideId?.trim()
  if (!code || !rideId) {
    return NextResponse.json({ success: false, error: 'invalid_input' }, { status: 400 })
  }

  try {
    const result = await tx(async (client) => {
      // Cargar ride y verificar ownership antes de tocar el vale (B#3).
      // El `rideAmount` NO se toma del body — el driver malicioso podría inflar
      // el descuento porcentual o quemar el vale sobre un ride ajeno.
      const rideRes = await client.query(
        `SELECT id, passenger_id, estimated_fare, final_fare, status
           FROM rides
           WHERE id = $1
           FOR UPDATE`,
        [rideId],
      )
      const ride = rideRes.rows[0]
      if (!ride) throw { code: 'ride_not_found' }
      if (ride.passenger_id !== auth.userId) throw { code: 'ride_forbidden' }
      // Solo permitir aplicar vale antes de completar el viaje
      if (ride.status === 'completed' || ride.status === 'cancelled') {
        throw { code: 'ride_closed', status: ride.status }
      }

      const rideAmount = Number(ride.final_fare ?? ride.estimated_fare ?? 0)
      if (rideAmount <= 0) throw { code: 'ride_no_amount' }

      // Lock del vale para evitar race sobre used_count/max_uses
      const valeRes = await client.query(
        `SELECT id, discount_type, discount_value, max_uses, used_count,
                per_user_limit, min_ride_amount, is_active,
                starts_at, expires_at
           FROM vales
           WHERE code = $1
           FOR UPDATE`,
        [code],
      )
      const vale = valeRes.rows[0]
      if (!vale) throw { code: 'not_found' }

      const now = new Date()
      if (!vale.is_active) throw { code: 'inactive' }
      if (vale.starts_at && new Date(vale.starts_at) > now) throw { code: 'not_yet_active' }
      if (vale.expires_at && new Date(vale.expires_at) < now) throw { code: 'expired' }
      if (vale.max_uses !== null && vale.used_count >= vale.max_uses) throw { code: 'exhausted' }
      if (vale.min_ride_amount !== null && rideAmount < Number(vale.min_ride_amount)) {
        throw { code: 'below_minimum', minRideAmount: Number(vale.min_ride_amount) }
      }

      // Cuántas veces lo usó este user
      const usesRes = await client.query(
        'SELECT COUNT(*)::int as n FROM vale_usages WHERE vale_id = $1 AND user_id = $2',
        [vale.id, auth.userId],
      )
      // Ronda 23 Bug#1: per_user_limit NULL = ilimitado (patrón consistente
       // con max_uses/min_ride_amount arriba). Sin este guard, `n >= null` es
       // false en JS y silenciosamente bypasea el check — cualquier vale con
       // per_user_limit NULL permitía uso infinito por usuario.
      if (vale.per_user_limit !== null && usesRes.rows[0].n >= vale.per_user_limit) {
        throw { code: 'user_limit_reached' }
      }

      const val = Number(vale.discount_value)
      const discount = vale.discount_type === 'percent'
        ? Math.round((rideAmount * val) / 100 * 100) / 100
        : Math.min(val, rideAmount)

      // Registrar uso; UNIQUE(vale_id, ride_id) previene doble apply
      await client.query(
        `INSERT INTO vale_usages (vale_id, user_id, ride_id, discount_applied)
         VALUES ($1, $2, $3, $4)`,
        [vale.id, auth.userId, rideId, discount],
      )

      // Incrementar contador
      await client.query('UPDATE vales SET used_count = used_count + 1 WHERE id = $1', [vale.id])

      return { discount, valeId: vale.id }
    })

    return NextResponse.json({
      success: true,
      code,
      rideId,
      discount: result.discount,
    })
  } catch (err) {
    if (isUniqueViolation(err)) {
      return NextResponse.json(
        { success: false, error: 'already_applied', message: 'Este código ya se aplicó a este viaje' },
        { status: 409 },
      )
    }
    const knownCode = (err as { code?: string })?.code
    if (typeof knownCode === 'string' && knownCode.length < 40) {
      // Códigos de ownership/estado de ride merecen 4xx específicos, no 410.
      const statusByCode: Record<string, number> = {
        ride_not_found: 404,
        ride_forbidden: 403,
        ride_closed: 409,
        ride_no_amount: 422,
      }
      const status = statusByCode[knownCode] ?? 410
      return NextResponse.json({ success: false, error: knownCode, ...err as object }, { status })
    }
    console.error('[vales/apply] error:', err)
    return NextResponse.json({ success: false, error: 'internal_error' }, { status: 500 })
  }
}
