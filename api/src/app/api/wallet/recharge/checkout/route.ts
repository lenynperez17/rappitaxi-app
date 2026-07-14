/**
 * POST /api/wallet/recharge/checkout
 * Auth: Bearer <access_token>
 * Body: { amount: number }  // en soles, mínimo 5, máximo 500
 *
 * Crea una preferencia de pago en MercadoPago y devuelve la URL/init_point.
 * El acceso al access token de MP vive server-side (variable MP_ACCESS_TOKEN).
 *
 * external_reference = mp_payments.id — el webhook lo usa para correlacionar.
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { maybeOne } from '@/lib/db'

export const runtime = 'nodejs'

const MIN_AMOUNT = 5
const MAX_AMOUNT = 500

const APP_URL = process.env.APP_PUBLIC_URL ?? 'https://rapi-team-api.nynelmkt.cloud'

export async function POST(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  const mpToken = process.env.MP_ACCESS_TOKEN
  if (!mpToken) {
    return NextResponse.json({ success: false, error: 'mp_not_configured' }, { status: 503 })
  }

  let body: { amount?: number } = {}
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ success: false, error: 'bad_json' }, { status: 400 })
  }

  const amount = Number(body.amount)
  if (!Number.isFinite(amount) || amount < MIN_AMOUNT || amount > MAX_AMOUNT) {
    return NextResponse.json({
      success: false,
      error: 'invalid_amount',
      message: `Monto entre S/ ${MIN_AMOUNT} y S/ ${MAX_AMOUNT}`,
    }, { status: 400 })
  }

  // Registrar mp_payment antes de llamar a MP (para tener external_reference)
  const payment = await maybeOne<{ id: string }>(
    `INSERT INTO mp_payments (user_id, amount, status, purpose)
     VALUES ($1, $2, 'created', 'wallet_recharge')
     RETURNING id`,
    [auth.userId, amount],
  )

  const externalRef = payment!.id

  const prefBody = {
    items: [
      {
        title: 'Recarga wallet Rapi Team',
        quantity: 1,
        currency_id: 'PEN',
        unit_price: amount,
      },
    ],
    external_reference: externalRef,
    metadata: { userId: auth.userId, purpose: 'wallet_recharge' },
    notification_url: `${APP_URL}/api/payments/mercadopago/webhook`,
    back_urls: {
      success: `${APP_URL}/mp/return?status=success&ref=${externalRef}`,
      failure: `${APP_URL}/mp/return?status=failure&ref=${externalRef}`,
      pending: `${APP_URL}/mp/return?status=pending&ref=${externalRef}`,
    },
    auto_return: 'approved',
    statement_descriptor: 'RAPI TEAM',
  }

  try {
    const r = await fetch('https://api.mercadopago.com/checkout/preferences', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${mpToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(prefBody),
      signal: AbortSignal.timeout(10_000),
    })
    const data = await r.json()
    if (!r.ok) {
      console.error('[wallet/recharge] MP error', r.status, data)
      return NextResponse.json({ success: false, error: 'mp_error', status: r.status }, { status: 502 })
    }

    // Guardar el preference_id
    await maybeOne(
      'UPDATE mp_payments SET mp_preference_id = $1, raw = $2 WHERE id = $3',
      [data.id, JSON.stringify(data), externalRef],
    )

    return NextResponse.json({
      success: true,
      externalReference: externalRef,
      preferenceId: data.id,
      initPoint: data.init_point,
      sandboxInitPoint: data.sandbox_init_point,
    })
  } catch (err) {
    console.error('[wallet/recharge] fetch error', err)
    return NextResponse.json({ success: false, error: 'mp_fetch_failed' }, { status: 502 })
  }
}
