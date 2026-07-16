/**
 * POST /api/vales/validate
 * Auth: Bearer <access_token>
 * Body: { code: string, rideAmount?: number }
 *
 * Valida un código de vale ANTES de aplicarlo — le dice al cliente si es
 * elegible, cuánto descuento le tocaría, y si ya lo usó. NO reserva ni
 * incrementa `used_count`.
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { maybeOne } from '@/lib/db'
import { keyedRateLimit } from '@/lib/rate-limit'

export const runtime = 'nodejs'

interface Vale {
  id: string
  code: string
  description: string | null
  discount_type: 'percent' | 'flat'
  discount_value: string  // NUMERIC llega como string
  max_uses: number | null
  used_count: number
  per_user_limit: number
  min_ride_amount: string | null
  starts_at: Date | null
  expires_at: Date | null
  is_active: boolean
}

function computeDiscount(v: Vale, amount: number): number {
  const val = Number(v.discount_value)
  if (v.discount_type === 'percent') {
    return Math.round((amount * val) / 100 * 100) / 100
  }
  return Math.min(val, amount)
}

export async function POST(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  // Ronda 148 SECURITY: enumeration attack. Un JWT puede brute-forcear el
  // espacio de códigos revelando toda la promo table (activos, agotados,
  // expirados) por las distintas status codes que devolvía el handler.
  // Rate-limit por userId corta el sweep masivo.
  const rl = keyedRateLimit(`vale-validate:${auth.userId}`, { max: 20, windowMs: 60_000 })
  if (!rl.ok) {
    return NextResponse.json({ success: false, error: 'rate_limited' }, { status: 429 })
  }

  let body: { code?: string; rideAmount?: number } = {}
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ success: false, error: 'bad_json' }, { status: 400 })
  }

  const code = body.code?.trim().toUpperCase()
  if (!code || code.length < 3 || code.length > 32) {
    return NextResponse.json({ success: false, error: 'invalid_code' }, { status: 400 })
  }
  // Ronda 53 Bug#1: distinguir pre-check (sin rideAmount) de check real.
  // Sin esto, POST {code} sin rideAmount → 0 → below_minimum, y la UI mostraba
  // "código inválido" para vales válidos aún no aplicados a un viaje.
  const rideAmountRaw = body.rideAmount
  const hasRideAmount = typeof rideAmountRaw === 'number' && Number.isFinite(rideAmountRaw) && rideAmountRaw > 0
  const rideAmount = hasRideAmount ? rideAmountRaw : 0

  const vale = await maybeOne<Vale>(
    'SELECT * FROM vales WHERE code = $1 LIMIT 1',
    [code],
  )
  // Ronda 148: colapsar TODOS los estados "no usable" a la misma respuesta
  // genérica. Antes: 404 (no existe) vs 410 inactive/expired/exhausted
  // (existe) diferenciaban existencia — attacker mapeaba toda la promo table.
  // Solo below_minimum (accionable por el user) mantiene código específico.
  const genericInvalid = NextResponse.json(
    { success: false, error: 'invalid_code', message: 'Código no válido' },
    { status: 404 },
  )
  if (!vale) return genericInvalid

  const now = new Date()
  if (!vale.is_active) return genericInvalid
  if (vale.starts_at && new Date(vale.starts_at) > now) return genericInvalid
  if (vale.expires_at && new Date(vale.expires_at) < now) return genericInvalid
  if (vale.max_uses !== null && vale.used_count >= vale.max_uses) return genericInvalid
  // Solo aplicar el check de monto mínimo si el cliente envió rideAmount real
  // (Ronda 53 Bug#1). Pre-check sin monto → devolver success con discount=null.
  if (hasRideAmount && vale.min_ride_amount !== null && rideAmount < Number(vale.min_ride_amount)) {
    return NextResponse.json({
      success: false,
      error: 'below_minimum',
      message: `Monto mínimo: S/ ${Number(vale.min_ride_amount).toFixed(2)}`,
      minRideAmount: Number(vale.min_ride_amount),
    }, { status: 400 })
  }

  // Cuántas veces lo ha usado este user
  const usageRow = await maybeOne<{ n: string }>(
    'SELECT COUNT(*)::text as n FROM vale_usages WHERE vale_id = $1 AND user_id = $2',
    [vale.id, auth.userId],
  )
  const userUses = Number(usageRow?.n ?? 0)
  // Ronda 23 pattern: per_user_limit NULL = ilimitado
  // Ronda 148: colapsar user_limit_reached a invalid_code para no revelar
  // existencia del código a usuarios que ya lo usaron (enumeration oracle).
  if (vale.per_user_limit !== null && userUses >= vale.per_user_limit) {
    return genericInvalid
  }

  const discount = rideAmount > 0 ? computeDiscount(vale, rideAmount) : null

  return NextResponse.json({
    success: true,
    vale: {
      code: vale.code,
      description: vale.description,
      discountType: vale.discount_type,
      discountValue: Number(vale.discount_value),
      expiresAt: vale.expires_at,
    },
    discount,   // null si no se envió rideAmount — solo pre-check
  })
}
