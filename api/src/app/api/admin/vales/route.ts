/**
 * GET/POST /api/admin/vales — CRUD de vales (promociones)
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAdmin } from '@/lib/admin-middleware'
import { query } from '@/lib/db'

export const runtime = 'nodejs'
export const dynamic = 'force-dynamic'

interface ValeRow {
  id: string
  code: string
  description: string | null
  discount_type: string
  discount_value: string
  max_uses: number | null
  used_count: number
  per_user_limit: number
  min_ride_amount: string | null
  starts_at: Date | null
  expires_at: Date | null
  is_active: boolean
  created_at: Date
}

export async function GET(req: NextRequest) {
  const auth = await requireAdmin(req)
  if (!auth.ok) return auth.response
  const rows = await query<ValeRow>(
    `SELECT id, code, description, discount_type, discount_value, max_uses, used_count,
            per_user_limit, min_ride_amount, starts_at, expires_at, is_active, created_at
       FROM vales ORDER BY created_at DESC LIMIT 200`,
  )
  return NextResponse.json({
    success: true,
    vales: rows.map((v) => ({
      id: v.id,
      code: v.code,
      description: v.description,
      discountType: v.discount_type,
      discountValue: Number(v.discount_value),
      maxUses: v.max_uses,
      usedCount: v.used_count,
      perUserLimit: v.per_user_limit,
      minRideAmount: v.min_ride_amount ? Number(v.min_ride_amount) : null,
      startsAt: v.starts_at,
      expiresAt: v.expires_at,
      isActive: v.is_active,
      createdAt: v.created_at,
    })),
  })
}

export async function POST(req: NextRequest) {
  const auth = await requireAdmin(req)
  if (!auth.ok) return auth.response
  let body: {
    code?: string
    description?: string
    discountType?: 'percent' | 'flat'
    discountValue?: number
    maxUses?: number
    perUserLimit?: number
    minRideAmount?: number
    startsAt?: string
    expiresAt?: string
  } = {}
  try { body = await req.json() } catch {
    return NextResponse.json({ success: false, error: 'bad_json' }, { status: 400 })
  }
  const code = body.code?.trim().toUpperCase()
  const dt = body.discountType
  const dv = Number(body.discountValue ?? 0)
  // Ronda 31 Bug#1: Number('abc') = NaN; NaN <= 0 es false, NaN > 100/500 es
  // false → validación pasaba y NaN se persistía en discount_value (Postgres
  // numeric acepta NaN) → toda math futura sobre el vale devolvía NaN.
  if (!code || !dt || !['percent', 'flat'].includes(dt) || !Number.isFinite(dv) || dv <= 0) {
    return NextResponse.json({ success: false, error: 'invalid_input' }, { status: 400 })
  }
  // Cap: percent no puede exceder 100 (típo daría vale > costo del viaje);
  // flat capped a S/ 500 (razonable para taxi urbano Perú, cambiar si crecen).
  if (dt === 'percent' && dv > 100) {
    return NextResponse.json(
      { success: false, error: 'percent_too_high', message: 'Descuento porcentual no puede exceder 100%' },
      { status: 400 },
    )
  }
  if (dt === 'flat' && dv > 500) {
    return NextResponse.json(
      { success: false, error: 'flat_too_high', message: 'Descuento fijo máximo S/ 500' },
      { status: 400 },
    )
  }
  try {
    const rows = await query<ValeRow>(
      `INSERT INTO vales (code, description, discount_type, discount_value, max_uses,
                           per_user_limit, min_ride_amount, starts_at, expires_at, is_active)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, true)
       RETURNING id, code, description, discount_type, discount_value, max_uses, used_count,
                 per_user_limit, min_ride_amount, starts_at, expires_at, is_active, created_at`,
      [
        code,
        body.description ?? null,
        dt,
        dv,
        body.maxUses ?? null,
        body.perUserLimit ?? 1,
        body.minRideAmount ?? null,
        body.startsAt ?? null,
        body.expiresAt ?? null,
      ],
    )
    const v = rows[0]
    return NextResponse.json({ success: true, vale: {
      id: v.id, code: v.code, discountType: v.discount_type,
      discountValue: Number(v.discount_value), isActive: v.is_active,
    } }, { status: 201 })
  } catch (e: unknown) {
    const err = e as { code?: string }
    if (err?.code === '23505') {
      return NextResponse.json({ success: false, error: 'code_taken' }, { status: 409 })
    }
    console.error('[admin/vales POST]', e)
    return NextResponse.json({ success: false, error: 'internal_error' }, { status: 500 })
  }
}
