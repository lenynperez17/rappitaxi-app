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
import { keyedRateLimit } from '@/lib/rate-limit'

export const runtime = 'nodejs'

const MIN_AMOUNT = 5
const MAX_AMOUNT = 500

const APP_URL = process.env.APP_PUBLIC_URL ?? 'https://rapi-team-api.nynelmkt.cloud'

export async function POST(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  // Ronda 169: rate limit por userId. Sin esto, cada POST crea una fila
  // mp_payments 'created' + llama MP con timeout 10s. Un attacker con JWT
  // hace 1000 req/s → 1000 filas huérfanas + saturación pool de conns +
  // Rate limit anti-abuso de MP eventualmente rechaza al negocio real.
  // Un usuario legítimo hace <5 recargas/hora en el peor caso.
  const rl = keyedRateLimit(`recharge-checkout:${auth.userId}`, { max: 20, windowMs: 60_000 })
  if (!rl.ok) {
    return NextResponse.json(
      { success: false, error: 'rate_limited', message: 'Demasiadas recargas seguidas. Espera un momento.' },
      { status: 429 },
    )
  }

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

  const amountRaw = Number(body.amount)
  if (!Number.isFinite(amountRaw) || amountRaw < MIN_AMOUNT || amountRaw > MAX_AMOUNT) {
    return NextResponse.json({
      success: false,
      error: 'invalid_amount',
      message: `Monto entre S/ ${MIN_AMOUNT} y S/ ${MAX_AMOUNT}`,
    }, { status: 400 })
  }
  // Ronda 82: rechazar >2 decimales. Antes {amount:5.999} pasaba, MP redondeaba
  // a 2 decimales y el webhook comparaba contra 5.999 → ledger descuadrado.
  const amountCents = Math.round(amountRaw * 100)
  if (Math.abs(amountCents - amountRaw * 100) > 0.001) {
    return NextResponse.json({
      success: false,
      error: 'invalid_amount',
      message: 'Monto debe tener máximo 2 decimales',
    }, { status: 400 })
  }
  const amount = amountCents / 100

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
    // Ronda 23 Bug#2: X-Idempotency-Key con externalRef evita que retry del
    // cliente cree preferencias duplicadas (usuario cobrado 2x). MP acepta
    // este header y devuelve la misma preferencia si ya se creó con esa key.
    const r = await fetch('https://api.mercadopago.com/checkout/preferences', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${mpToken}`,
        'Content-Type': 'application/json',
        'X-Idempotency-Key': externalRef,
      },
      body: JSON.stringify(prefBody),
      signal: AbortSignal.timeout(10_000),
    })
    const data = await r.json()
    if (!r.ok) {
      console.error('[wallet/recharge] MP error', r.status, data)
      // Ronda 214: en vez de DELETE (que si falla dejaba fila huérfana + race
      // con webhook: MP podía llegar entre INSERT y DELETE, aprobar el pago,
      // y luego DELETE borraba un pago APROBADO), marcamos la fila como
      // 'cancelled' — status es finite state machine, webhook no puede
      // sobrescribir 'cancelled' con 'approved'. Log warning (no catch vacío)
      // para monitoreo.
      const cancelErr = await maybeOne(
        `UPDATE mp_payments SET status = 'cancelled', raw = COALESCE(raw, '{}'::jsonb) || $2::jsonb
           WHERE id = $1 AND status = 'created'
         RETURNING id`,
        [externalRef, JSON.stringify({ cancelReason: 'mp_error', mpStatus: r.status })],
      ).catch((e) => {
        console.warn('[wallet/recharge] fallo marcando mp_payment cancelled:', e)
        return null
      })
      if (!cancelErr) {
        console.warn(`[wallet/recharge] mp_payment ${externalRef} no encontrado para cancelar — posible race con webhook.`)
      }
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
    // Mismo fix Ronda 214: UPDATE cancelled en vez de DELETE.
    await maybeOne(
      `UPDATE mp_payments SET status = 'cancelled', raw = COALESCE(raw, '{}'::jsonb) || $2::jsonb
         WHERE id = $1 AND status = 'created'
       RETURNING id`,
      [externalRef, JSON.stringify({ cancelReason: 'mp_fetch_failed' })],
    ).catch((e) => {
      console.warn('[wallet/recharge] fallo marcando mp_payment cancelled tras fetch failure:', e)
      return null
    })
    return NextResponse.json({ success: false, error: 'mp_fetch_failed' }, { status: 502 })
  }
}
