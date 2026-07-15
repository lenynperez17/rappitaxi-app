/**
 * /api/payment-methods
 *
 * GET  — Lista los métodos de pago del user autenticado.
 *        ORDER BY is_default DESC, created_at ASC
 *
 * POST — Agrega un método de pago.
 *        Body: { methodType, label?, isDefault?, metadata? }
 *        Si isDefault=true, primero desmarca los demás.
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { query, tx } from '@/lib/db'

export const runtime = 'nodejs'

interface PaymentMethodRow {
  id: string
  user_id: string
  method_type: string
  label: string | null
  is_default: boolean
  metadata: Record<string, unknown> | null
  created_at: Date
}

const VALID_TYPES = new Set(['cash', 'mercadopago', 'wallet', 'yape', 'plin', 'card'])

function serialize(m: PaymentMethodRow) {
  return {
    id: m.id,
    userId: m.user_id,
    methodType: m.method_type,
    label: m.label,
    isDefault: m.is_default,
    metadata: m.metadata,
    createdAt: m.created_at,
  }
}

// ============================================================================
// GET — Lista
// ============================================================================
export async function GET(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  const rows = await query<PaymentMethodRow>(
    `SELECT id, user_id, method_type, label, is_default, metadata, created_at
       FROM user_payment_methods
       WHERE user_id = $1
       ORDER BY is_default DESC, created_at ASC`,
    [auth.userId],
  )

  return NextResponse.json({ success: true, methods: rows.map(serialize) })
}

// ============================================================================
// POST — Agregar
// ============================================================================
export async function POST(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  let body: {
    methodType?: string
    label?: string | null
    isDefault?: boolean
    metadata?: Record<string, unknown> | null
  }
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ success: false, error: 'bad_json' }, { status: 400 })
  }

  const methodType = body.methodType?.trim().toLowerCase()
  if (!methodType || !VALID_TYPES.has(methodType)) {
    return NextResponse.json(
      { success: false, error: 'invalid_method_type', message: 'methodType inválido' },
      { status: 400 },
    )
  }
  const label = body.label?.trim() || null
  const isDefault = !!body.isDefault
  const metadataJson = body.metadata != null ? JSON.stringify(body.metadata) : null

  try {
    const method = await tx(async (client) => {
      // Ronda 50 Bug#2: advisory lock por user_id + auto-primary si es el primero.
      // Sin el lock, doble tap con isDefault:true dejaba dos defaults simultáneos.
      // Sin auto-primary, primer método sin isDefault dejaba usuario sin default.
      await client.query(
        `SELECT pg_advisory_xact_lock(hashtextextended($1, 249))`,
        [auth.userId],
      )
      let effectiveDefault = isDefault
      if (!effectiveDefault) {
        const existing = await client.query<{ count: string }>(
          `SELECT COUNT(*)::text AS count FROM user_payment_methods WHERE user_id = $1`,
          [auth.userId],
        )
        if (Number(existing.rows[0]?.count ?? '0') === 0) {
          effectiveDefault = true
        }
      }
      if (effectiveDefault) {
        await client.query(
          `UPDATE user_payment_methods SET is_default = false WHERE user_id = $1`,
          [auth.userId],
        )
      }
      const res = await client.query<PaymentMethodRow>(
        `INSERT INTO user_payment_methods (user_id, method_type, label, is_default, metadata)
         VALUES ($1, $2, $3, $4, $5::jsonb)
         RETURNING id, user_id, method_type, label, is_default, metadata, created_at`,
        [auth.userId, methodType, label, effectiveDefault, metadataJson],
      )
      return res.rows[0]!
    })

    return NextResponse.json({ success: true, method: serialize(method) })
  } catch (err) {
    console.error('[payment-methods/POST] error:', err)
    return NextResponse.json({ success: false, error: 'server_error' }, { status: 500 })
  }
}
