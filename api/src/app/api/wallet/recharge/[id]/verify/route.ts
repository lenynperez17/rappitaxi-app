/**
 * POST /api/wallet/recharge/:id/verify — "¿se cobró mi recarga?"
 *
 * Ronda 280. La app lo llama al volver del checkout de MercadoPago.
 *
 * POR QUÉ HACE FALTA
 * ------------------
 * Hasta ahora el ÚNICO camino que aprobaba una recarga era el webhook, y el
 * webhook llevaba meses rechazándolo todo por falta de la clave de firma: los
 * catorce pagos de la tabla seguían en `created` desde julio y el saldo se
 * acreditaba a mano desde el panel.
 *
 * Poner la clave arregla el caso normal, pero no el caso raro: un aviso que se
 * pierde, un servidor reiniciando justo en ese segundo, MercadoPago
 * reintentando cuando ya nadie escucha. Con este endpoint el usuario deja de
 * depender de que llegue un mensaje: al volver del pago, su propia app
 * pregunta.
 *
 * NO SE FÍA DE LA APP
 * -------------------
 * El cliente solo dice QUÉ recarga mirar. Quién decide si está pagada es
 * MercadoPago, a quien se le pregunta directamente con nuestro token. La app no
 * puede afirmar "ya pagué": puede pedir que se compruebe.
 *
 * Y solo se puede preguntar por las recargas propias.
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { maybeOne } from '@/lib/db'
import { isUuid } from '@/lib/uuid'
import { keyedRateLimit } from '@/lib/rate-limit'
import {
  applyMpPayment,
  fetchMpPayment,
  mpAccessToken,
  searchMpPaymentsByReference,
} from '@/lib/mercadopago-payments'

export const runtime = 'nodejs'
export const dynamic = 'force-dynamic'

export async function POST(
  req: NextRequest,
  ctx: { params: Promise<{ id: string }> },
) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  const { id } = await ctx.params
  if (!isUuid(id)) {
    return NextResponse.json({ success: false, error: 'invalid_id' }, { status: 400 })
  }

  // Cada consulta golpea la API de MercadoPago. Un usuario impaciente pulsando
  // "reintentar" no debe convertirse en una tormenta de peticiones.
  const limited = keyedRateLimit(`recharge-verify:${auth.userId}`, {
    max: 20,
    windowMs: 60_000,
  })
  if (!limited.ok) {
    return NextResponse.json(
      { success: false, error: 'rate_limited', message: 'Espera unos segundos antes de reintentar.' },
      { status: 429 },
    )
  }

  const row = await maybeOne<{ id: string; user_id: string; status: string; mp_payment_id: string | null }>(
    'SELECT id, user_id, status, mp_payment_id FROM mp_payments WHERE id = $1',
    [id],
  )
  if (!row) {
    return NextResponse.json({ success: false, error: 'not_found' }, { status: 404 })
  }
  if (row.user_id !== auth.userId) {
    // 404 y no 403: no se confirma la existencia de recargas ajenas.
    return NextResponse.json({ success: false, error: 'not_found' }, { status: 404 })
  }

  // Ya resuelta: se responde sin molestar a MercadoPago.
  if (row.status === 'approved') {
    return NextResponse.json({ success: true, status: 'approved', outcome: 'already_applied' })
  }

  const token = mpAccessToken()
  if (!token) {
    console.error('[recharge/verify] falta MP_ACCESS_TOKEN')
    return NextResponse.json({ success: false, error: 'server_misconfigured' }, { status: 500 })
  }

  // Si el webhook llegó alguna vez, tenemos el id de MercadoPago y se consulta
  // directo. Si no —que es el caso de los pagos atascados—, se busca por el
  // `external_reference`, que es el id de nuestra propia fila.
  const payments = row.mp_payment_id
    ? [await fetchMpPayment(row.mp_payment_id, token)].filter((p) => p !== null)
    : await searchMpPaymentsByReference(row.id, token)

  if (payments.length === 0) {
    // Sin rastro en MercadoPago: normalmente significa que el usuario abrió el
    // checkout y no llegó a pagar. No es un error.
    return NextResponse.json({ success: true, status: row.status, outcome: 'no_payment_yet' })
  }

  // Puede haber varios intentos sobre la misma preferencia (un rechazo y luego
  // uno bueno). Se aplica el aprobado si lo hay; si no, el más reciente.
  const aprobado = payments.find((p) => p.status === 'approved')
  const elegido = aprobado ?? payments[0]

  const result = await applyMpPayment(elegido)

  return NextResponse.json({
    success: result.outcome !== 'amount_discrepancy' && result.outcome !== 'unknown_reference',
    outcome: result.outcome,
    status: result.outcome === 'credited' || result.outcome === 'already_applied'
      ? 'approved'
      : elegido.status,
    ...(result.outcome === 'credited' ? { amount: result.amount } : {}),
  })
}
