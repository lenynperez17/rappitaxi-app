/**
 * Ronda 280 — acreditar una recarga de MercadoPago, en un solo sitio.
 *
 * POR QUÉ EXISTE
 * --------------
 * Hasta ahora el único camino que aprobaba un pago era el webhook. Y el webhook
 * llevaba meses rechazando TODO: falta `MERCADOPAGO_WEBHOOK_SECRET` en el
 * servidor, así que la comprobación de firma —correctamente cerrada en
 * producción— devolvía 401 a los avisos legítimos igual que a los falsos. Los
 * catorce pagos de la tabla seguían en `created` desde julio, y las recargas se
 * acreditaban a mano desde el panel.
 *
 * Arreglar la clave es necesario pero no suficiente: un aviso que se pierda deja
 * la recarga colgada otra vez. Por eso hay un segundo camino —la app pregunta al
 * volver del checkout— y por eso esta lógica vive aquí en vez de duplicarse: el
 * dinero no se mueve en dos sitios distintos que puedan divergir.
 *
 * IDEMPOTENCIA
 * ------------
 * Se puede llamar tantas veces como haga falta con el mismo pago. Dentro de la
 * transacción se toma un advisory lock por usuario y se relee el estado con
 * `FOR UPDATE`: si ya está `approved`, no se vuelve a acreditar. Además
 * `wallet_transactions.external_ref` es único, que es la segunda red.
 */
import { isUniqueViolation, maybeOne, query, tx } from './db'
import { sendPush } from './send-push'

export interface MpPayment {
  id: number
  status: string
  external_reference: string | null
  transaction_amount: number
  metadata?: { userId?: string; purpose?: string }
  date_approved?: string
  status_detail?: string
  payer?: { email?: string }
}

/** El token de MercadoPago, aceptando el nombre nuevo y el heredado. */
export function mpAccessToken(): string | undefined {
  return process.env.MP_ACCESS_TOKEN || process.env.MERCADOPAGO_ACCESS_TOKEN
}

/** Pregunta a MercadoPago por un pago. `null` si no se pudo consultar. */
export async function fetchMpPayment(
  paymentId: string,
  token: string,
): Promise<MpPayment | null> {
  try {
    const r = await fetch(`https://api.mercadopago.com/v1/payments/${paymentId}`, {
      headers: { Authorization: `Bearer ${token}` },
      signal: AbortSignal.timeout(8_000),
    })
    if (!r.ok) {
      console.warn('[mercadopago] no se pudo leer el pago', paymentId, r.status)
      return null
    }
    return (await r.json()) as MpPayment
  } catch (err) {
    console.warn('[mercadopago] error consultando el pago', paymentId, err)
    return null
  }
}

/**
 * Busca en MercadoPago los pagos asociados a una recarga nuestra.
 *
 * El `external_reference` que mandamos al crear la preferencia es el UUID de la
 * fila de `mp_payments`, así que se puede preguntar por él sin conocer el id de
 * MercadoPago — que es justo lo que nos falta en los pagos atascados, porque
 * ese id solo lo escribía el webhook.
 */
export async function searchMpPaymentsByReference(
  externalReference: string,
  token: string,
): Promise<MpPayment[]> {
  try {
    const url = new URL('https://api.mercadopago.com/v1/payments/search')
    url.searchParams.set('external_reference', externalReference)
    url.searchParams.set('sort', 'date_created')
    url.searchParams.set('criteria', 'desc')
    const r = await fetch(url, {
      headers: { Authorization: `Bearer ${token}` },
      signal: AbortSignal.timeout(8_000),
    })
    if (!r.ok) {
      console.warn('[mercadopago] búsqueda fallida', externalReference, r.status)
      return []
    }
    const body = (await r.json()) as { results?: MpPayment[] }
    return Array.isArray(body.results) ? body.results : []
  } catch (err) {
    console.warn('[mercadopago] error buscando pagos de', externalReference, err)
    return []
  }
}

/** El estado de MercadoPago traducido al nuestro. */
export function mapMpStatus(mpStatus: string): string {
  // `charged_back` es un contracargo resuelto a favor del comprador. Estaba sin
  // mapear hasta la ronda 134 y caía en 'pending', lo que dejaba el saldo
  // acreditado mientras el banco devolvía el dinero.
  switch (mpStatus) {
    case 'approved': return 'approved'
    case 'rejected': return 'rejected'
    case 'cancelled': return 'cancelled'
    case 'refunded': return 'refunded'
    case 'charged_back': return 'charged_back'
    default: return 'pending'
  }
}

export type ApplyOutcome =
  | { outcome: 'credited'; amount: number; userId: string }
  | { outcome: 'already_applied'; status: string }
  | { outcome: 'reversed'; status: string; amount: number; userId: string }
  | { outcome: 'status_updated'; status: string }
  | { outcome: 'unknown_reference' }
  | { outcome: 'amount_discrepancy'; expected: number; actual: number }

/**
 * Aplica a nuestra base de datos lo que MercadoPago dice de un pago.
 *
 * Es la función que usan **los dos** caminos: el webhook y la verificación que
 * pide la app. No decide si el pago es legítimo —eso lo hace quien llama, con
 * la firma o preguntando directamente a MercadoPago—; decide qué hacer con él.
 */
export async function applyMpPayment(payment: MpPayment): Promise<ApplyOutcome> {
  const externalRef = payment.external_reference
  if (!externalRef) return { outcome: 'unknown_reference' }

  const mpRow = await maybeOne<{
    id: string; user_id: string; status: string; mp_payment_id: string | null; amount: string | null
  }>(
    'SELECT id, user_id, status, mp_payment_id, amount FROM mp_payments WHERE id = $1',
    [externalRef],
  )
  if (!mpRow) return { outcome: 'unknown_reference' }

  // El monto tiene que coincidir con el que originamos nosotros. Si no, se
  // marca la discrepancia y NO se acredita: defensa contra manipulación o
  // contra un cambio silencioso en la preferencia.
  const expectedAmount = Number(mpRow.amount ?? 0)
  if (expectedAmount > 0 && Math.abs(payment.transaction_amount - expectedAmount) > 0.01) {
    console.error(
      '[mercadopago] DISCREPANCIA: esperado', expectedAmount,
      'recibido', payment.transaction_amount, 'ref', externalRef,
    )
    await query(
      `UPDATE mp_payments SET status = 'discrepancy', raw = $1, updated_at = now() WHERE id = $2`,
      [
        JSON.stringify({
          ...payment,
          _discrepancy: { expected: expectedAmount, actual: payment.transaction_amount },
        }),
        externalRef,
      ],
    )
    return {
      outcome: 'amount_discrepancy',
      expected: expectedAmount,
      actual: payment.transaction_amount,
    }
  }

  const newStatus = mapMpStatus(payment.status)

  // El resultado se devuelve DESDE la transacción, no se asigna a una variable
  // de fuera: TypeScript no sigue las asignaciones dentro del callback y acaba
  // creyendo que el tipo es solo el del valor inicial.
  const resultado: ApplyOutcome = await tx(async (client): Promise<ApplyOutcome> => {
    // Advisory lock por usuario (bucket 42, el mismo que usan rides/complete y
    // los retiros) para serializar un reverso cruzado con un débito del saldo.
    await client.query(
      `SELECT pg_advisory_xact_lock(hashtextextended($1, 42))`,
      [mpRow.user_id],
    )
    // Se relee DENTRO de la transacción: dos avisos concurrentes del mismo pago
    // veían la foto vieja y el reverso se perdía.
    const locked = await client.query<{ status: string }>(
      `SELECT status FROM mp_payments WHERE id = $1 FOR UPDATE`,
      [externalRef],
    )
    const currentDbStatus = locked.rows[0]?.status
    if (currentDbStatus === undefined) {
      return { outcome: 'unknown_reference' }
    }

    if (newStatus === 'approved' && currentDbStatus === 'approved') {
      return { outcome: 'already_applied', status: 'approved' }
    }

    if (newStatus === 'approved') {
      await client.query(
        `UPDATE mp_payments
           SET mp_payment_id = $1, status = 'approved', raw = $2, updated_at = now()
         WHERE id = $3`,
        [String(payment.id), JSON.stringify(payment), externalRef],
      )
      const balRes = await client.query<{ balance: string }>(
        'SELECT rapi_team_user_balance($1)::text AS balance',
        [mpRow.user_id],
      )
      const balAfter = Math.round(
        (Number(balRes.rows[0]?.balance ?? 0) + payment.transaction_amount) * 100,
      ) / 100
      try {
        await client.query(
          `INSERT INTO wallet_transactions
             (user_id, type, amount, balance_after, description, status, external_ref, metadata, completed_at)
           VALUES ($1, 'recharge', $2, $3, $4, 'completed', $5, $6, now())`,
          [
            mpRow.user_id,
            payment.transaction_amount,
            balAfter,
            `Recarga MercadoPago #${payment.id}`,
            String(payment.id),
            JSON.stringify({ mp_payment_id: payment.id, external_reference: externalRef }),
          ],
        )
        return {
          outcome: 'credited',
          amount: payment.transaction_amount,
          userId: mpRow.user_id,
        }
      } catch (e) {
        // `external_ref` es único: si la fila ya existía, el saldo ya estaba
        // acreditado por el otro camino y no hay nada que hacer.
        if (!isUniqueViolation(e)) throw e
        return { outcome: 'already_applied', status: 'approved' }
      }
    }

    if (
      (newStatus === 'refunded' || newStatus === 'cancelled' || newStatus === 'charged_back')
      && currentDbStatus === 'approved'
    ) {
      // Devolución o contracargo después de haber acreditado: hay que reversar,
      // o el usuario se queda con el saldo Y con su dinero de vuelta.
      await client.query(
        `UPDATE mp_payments SET status = $1, raw = $2, updated_at = now() WHERE id = $3`,
        [newStatus, JSON.stringify(payment), externalRef],
      )
      const refundRef = `refund:${payment.id}`
      const existing = await client.query(
        `SELECT 1 FROM wallet_transactions WHERE external_ref = $1 LIMIT 1`,
        [refundRef],
      )
      if (existing.rowCount === 0) {
        const balRes = await client.query<{ balance: string }>(
          'SELECT rapi_team_user_balance($1)::text AS balance',
          [mpRow.user_id],
        )
        const balAfter = Math.round(
          (Number(balRes.rows[0]?.balance ?? 0) - payment.transaction_amount) * 100,
        ) / 100
        await client.query(
          `INSERT INTO wallet_transactions
             (user_id, type, amount, balance_after, description, status, external_ref, metadata, completed_at)
           VALUES ($1, 'refund', $2, $3, $4, 'completed', $5, $6::jsonb, now())`,
          [
            mpRow.user_id,
            -payment.transaction_amount,
            balAfter,
            `Reverso ${newStatus} MP #${payment.id}`,
            refundRef,
            JSON.stringify({
              mp_payment_id: payment.id,
              reason: newStatus,
              external_reference: externalRef,
            }),
          ],
        )
      }
      return {
        outcome: 'reversed',
        status: newStatus,
        amount: payment.transaction_amount,
        userId: mpRow.user_id,
      }
    }

    await client.query(
      `UPDATE mp_payments SET status = $1, raw = $2, updated_at = now() WHERE id = $3`,
      [newStatus, JSON.stringify(payment), externalRef],
    )
    return { outcome: 'status_updated', status: newStatus }
  })

  // Los avisos al usuario se mandan aquí, y no en quien llama, por el mismo
  // motivo que el resto: hay dos caminos que acreditan y el usuario tiene que
  // enterarse igual por los dos.
  if (resultado.outcome === 'credited') {
    void sendPush({
      userIds: [resultado.userId],
      type: 'recharge_approved',
      title: 'Recarga acreditada',
      body: `S/ ${resultado.amount.toFixed(2)} ya están disponibles en tu billetera`,
      data: { mpPaymentId: String(payment.id), amount: resultado.amount },
      channel: 'rappi_payments',
      priority: 'high',
      persist: true,
    })
  } else if (resultado.outcome === 'reversed') {
    void sendPush({
      userIds: [resultado.userId],
      type: 'recharge_refunded',
      title: resultado.status === 'charged_back' ? 'Contracargo procesado' : 'Pago revertido',
      body: `S/ ${resultado.amount.toFixed(2)} — motivo: ${resultado.status}`,
      data: {
        mpPaymentId: String(payment.id),
        amount: resultado.amount,
        reason: resultado.status,
      },
      channel: 'rappi_payments',
      priority: 'high',
      persist: true,
    })
  }

  return resultado
}
