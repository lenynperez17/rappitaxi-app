/**
 * Ronda 279 — el saldo que un conductor necesita para tomar trabajo.
 *
 * LO QUE OBSERVÓ EL DUEÑO
 * -----------------------
 * "He visto que el conductor acepta viajes teniendo saldo 0, ¿es verdad?".
 * Lo es. La comprobación que había (ronda 256) solo rechazaba el saldo
 * NEGATIVO, así que con S/ 0 exactos se pasaba. Y al completar el viaje se le
 * cobra la comisión permitiendo que el saldo quede en negativo a propósito
 * (`rides/[id]/complete`): el resultado es un viaje de gracia hacia la deuda,
 * y una deuda que la app no tiene forma de cobrar.
 *
 * EL MÍNIMO LO PONE EL DUEÑO, NO EL CÓDIGO
 * ----------------------------------------
 * `rides.min_balance_to_accept` se despliega en 0, que es exactamente el
 * comportamiento de hoy: nadie nota el cambio el día del despliegue. Subirlo
 * es una decisión de negocio y se toma desde el panel.
 *
 * LOS DOS CAMINOS
 * ---------------
 * Un conductor llega a un viaje por dos sitios: aceptándolo directamente, y
 * ofertando un precio que el pasajero acepta. La comprobación de la ronda 256
 * solo estaba en el primero; la de ofertas se añadió en la 257, y el tercero
 * —el pasajero aceptando la oferta del conductor— no miraba nada. Los tres
 * usan esto.
 */
import { maybeOne } from './db'

export interface BalanceGuardResult {
  ok: boolean
  balance: number
  minimum: number
}

/** El mínimo configurado, o 0 si no está puesto o es ilegible. */
export async function getMinBalanceToAccept(): Promise<number> {
  try {
    const row = await maybeOne<{ value: unknown }>(
      `SELECT value FROM app_settings WHERE key = 'rides.min_balance_to_accept'`,
    )
    const n = typeof row?.value === 'number' ? row.value : Number(row?.value)
    if (!Number.isFinite(n) || n < 0) return 0
    return n
  } catch (err) {
    // Sin poder leer el ajuste, no inventamos una barrera: dejar a todos los
    // conductores sin trabajar por un fallo de configuración sería peor que
    // el problema que esto previene.
    console.error('[driver-balance-guard] no se pudo leer el mínimo:', err)
    return 0
  }
}

/**
 * Comprueba si [driverId] tiene saldo suficiente para tomar un viaje.
 *
 * El balance ya excluye las filas 'commission' (que son el registro contable
 * de la plataforma, no dinero del conductor), así que refleja lo que
 * realmente tiene.
 */
export async function checkDriverBalance(driverId: string): Promise<BalanceGuardResult> {
  const minimum = await getMinBalanceToAccept()
  const row = await maybeOne<{ balance: string }>(
    'SELECT rapi_team_user_balance($1)::text AS balance',
    [driverId],
  )
  const balance = Number(row?.balance ?? 0)

  // Un balance ilegible se trata como insuficiente: es el lado seguro.
  if (!Number.isFinite(balance)) return { ok: false, balance: 0, minimum }

  // Con el mínimo en 0 se conserva la regla de la ronda 256: se rechaza el
  // saldo negativo, se acepta el cero.
  if (minimum <= 0) return { ok: balance >= 0, balance, minimum }
  return { ok: balance >= minimum, balance, minimum }
}

/** El mensaje que ve el conductor. Distinto según sea deuda o falta de saldo. */
export function insufficientBalanceMessage({ balance, minimum }: BalanceGuardResult): string {
  if (balance < 0) {
    return 'Tu saldo es negativo. Recarga tus créditos para volver a aceptar viajes.'
  }
  return `Necesitas al menos S/ ${minimum.toFixed(2)} de saldo para aceptar viajes. ` +
    `Tienes S/ ${balance.toFixed(2)}.`
}
