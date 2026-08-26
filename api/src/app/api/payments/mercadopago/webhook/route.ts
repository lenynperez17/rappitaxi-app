/**
 * POST /api/payments/mercadopago/webhook
 * (público — MercadoPago llama sin auth. Se valida payment_id via API)
 *
 * MP envía notificaciones con { type, data: { id } }. Consultamos el payment
 * completo con Bearer MP_ACCESS_TOKEN y actualizamos mp_payments + creamos
 * wallet_transactions cuando status='approved' e idempotencia por mp_payment_id.
 *
 * Idempotencia: unique constraint mp_payment_id + external_reference matching.
 */
import { NextRequest, NextResponse } from 'next/server'
import { createHmac, timingSafeEqual } from 'node:crypto'
import { applyMpPayment, fetchMpPayment, mpAccessToken } from '@/lib/mercadopago-payments'

/**
 * Verifica x-signature de MercadoPago (HMAC-SHA256).
 * Docs: https://www.mercadopago.com.pe/developers/es/docs/your-integrations/notifications/webhooks
 *
 * Formato del header:
 *   x-signature: ts=<timestamp>,v1=<hex>
 * Payload firmado: `id:<paymentId>;request-id:<requestId>;ts:<timestamp>;`
 *
 * Retorna:
 *   - true si la firma coincide
 *   - false si NO coincide o falta header
 *   - null si no hay MERCADOPAGO_WEBHOOK_SECRET configurado (skip check, log warning)
 */
function verifyMpSignature(
  req: NextRequest,
  paymentId: string,
): boolean | null {
  const secret = process.env.MERCADOPAGO_WEBHOOK_SECRET
  if (!secret) {
    // FAIL-CLOSED en producción: sin secret configurado NO aceptamos nada.
    // En dev/test devolvemos null (skip) para no bloquear desarrollo local.
    // Antes esto era fail-open también en producción — vulnerabilidad.
    if (process.env.NODE_ENV === 'production') {
      console.error('[mp/webhook] CRITICAL: MERCADOPAGO_WEBHOOK_SECRET no configurado en producción — rechazando webhook')
      return false
    }
    console.warn('[mp/webhook] MERCADOPAGO_WEBHOOK_SECRET no configurado (dev) — signature check saltado')
    return null
  }
  const xSig = req.headers.get('x-signature')
  const xRequestId = req.headers.get('x-request-id') ?? ''
  if (!xSig) return false
  const parts = Object.fromEntries(
    xSig.split(',').map((kv) => kv.trim().split('=', 2) as [string, string]),
  )
  const ts = parts.ts
  const v1 = parts.v1
  if (!ts || !v1) return false
  const manifest = `id:${paymentId};request-id:${xRequestId};ts:${ts};`
  const expected = createHmac('sha256', secret).update(manifest).digest('hex')
  try {
    return timingSafeEqual(Buffer.from(v1, 'hex'), Buffer.from(expected, 'hex'))
  } catch {
    return false
  }
}

export const runtime = 'nodejs'

// Ronda 280: el tipo del pago y la consulta a MercadoPago vivían aquí. Ahora
// están en `@/lib/mercadopago-payments`, que es lo que comparten este webhook y
// la verificación que pide la app.

export async function POST(req: NextRequest) {
  // Acepta ambos nombres (nuevo `MP_ACCESS_TOKEN` y legacy `MERCADOPAGO_ACCESS_TOKEN`)
  // para tolerar drift entre .env.example antiguo y el nuevo canónico.
  const mpToken = mpAccessToken()
  if (!mpToken) {
    // Retornar 500 en vez de 200: si prod tiene el token missing, queremos
    // que MP reintente + que el error levante alerta. Un 200 silencioso
    // hacía que los pagos aprobados nunca se acreditaran sin señal visible.
    console.error('[mp/webhook] CRITICAL: MP_ACCESS_TOKEN (o MERCADOPAGO_ACCESS_TOKEN) missing en producción')
    return NextResponse.json(
      { ok: false, error: 'server_misconfigured' },
      { status: 500 },
    )
  }

  let body: {
    type?: string
    action?: string
    data?: { id?: string | number }
    resource?: string
  }
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ ok: true, note: 'no_body' })
  }

  // MP también manda formatos legacy con "topic=payment&id=..." en query
  const { searchParams } = new URL(req.url)
  const queryPaymentId = searchParams.get('id')

  const paymentId = body.data?.id ? String(body.data.id) : queryPaymentId
  const type = body.type ?? searchParams.get('topic')

  // Solo procesamos notificaciones de payment
  if (type !== 'payment' || !paymentId) {
    return NextResponse.json({ ok: true, ignored: true })
  }

  // Verificar HMAC signature de MP. Fail-CLOSED en prod (rechaza si no puede
  // verificar), fail-open solo en dev cuando el secret NO está configurado.
  // Solo procesamos si sigOk === true; null es solo aceptable en dev.
  const sigOk = verifyMpSignature(req, paymentId)
  if (sigOk === false) {
    console.warn('[mp/webhook] firma inválida — request rechazada', {
      hasHeader: !!req.headers.get('x-signature'),
      paymentId,
    })
    return NextResponse.json({ ok: false, error: 'invalid_signature' }, { status: 401 })
  }
  if (sigOk === null && process.env.NODE_ENV === 'production') {
    // Defensa doble: nunca deberíamos llegar acá en prod (verifyMpSignature
    // retorna false, no null, en prod sin secret), pero por si acaso.
    return NextResponse.json({ ok: false, error: 'signature_required' }, { status: 401 })
  }


  // Ronda 280: desde aquí, la lógica es la misma que usa la verificación que
  // pide la app al volver del checkout. Antes vivía escrita en este archivo;
  // ahora está en `@/lib/mercadopago-payments` y la comparten los dos caminos.
  // El dinero no se mueve en dos sitios que puedan divergir con el tiempo.
  const payment = await fetchMpPayment(paymentId, mpToken)
  if (!payment) {
    return NextResponse.json({ ok: false, error: 'fetch_failed' }, { status: 502 })
  }

  try {
    const result = await applyMpPayment(payment)

    if (result.outcome === 'unknown_reference') {
      // No es un error nuestro: puede ser un pago que no originó esta app. Se
      // responde 200 para que MercadoPago no reintente eternamente.
      return NextResponse.json({ ok: true, note: 'unknown_ref' })
    }
    if (result.outcome === 'amount_discrepancy') {
      return NextResponse.json({ ok: false, error: 'amount_discrepancy' }, { status: 422 })
    }

    return NextResponse.json({ ok: true, outcome: result.outcome })
  } catch (err) {
    console.error('[mp/webhook] error procesando el aviso:', err)
    return NextResponse.json({ ok: false, error: 'processing_error' }, { status: 500 })
  }
}
