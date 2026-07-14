/**
 * MercadoPago Peru - Comision real por transaccion (acreditacion estandar 2026)
 *
 * Tarifa pública MercadoPago Peru para checkout estandar:
 *   - Comision porcentual:  4.49% sobre el monto bruto
 *   - IGV financiero fijo:  S/ 0.55 por cada transaccion aprobada
 *
 * Estos valores son referenciales y deben actualizarse si MercadoPago cambia su tarifario.
 * Si el conductor recarga S/ X, se le acredita: X - (X * 0.0449) - 0.55
 *
 * Importante: SUNAT también requiere desglose IGV (18%) cuando se emite la boleta/factura.
 * El IGV de SUNAT (18%) es DISTINTO del IGV financiero MercadoPago (0.55 PEN fijo).
 */

export const MP_PERU_PERCENTAGE = 0.0449
export const MP_PERU_IGV_FIXED = 0.55
export const SUNAT_IGV_RATE = 0.18

export interface RechargeBreakdown {
  /** Monto bruto pagado por el conductor (lo que paga en MercadoPago) */
  grossAmount: number
  /** Comision MercadoPago = 4.49% del grossAmount */
  mpCommission: number
  /** IGV financiero MercadoPago = S/ 0.55 fijo */
  mpIgv: number
  /** Suma de comisiones MercadoPago retenidas */
  totalMpFee: number
  /** Monto neto que se acredita al wallet del conductor */
  netAmount: number
  /** Porcentaje efectivo descontado */
  effectiveFeePercentage: number
}

/**
 * Calcula el desglose completo de una recarga MercadoPago.
 *
 * @param grossAmount Monto bruto en PEN (lo que el conductor pagó)
 * @returns Desglose con comision, IGV y monto neto a acreditar
 *
 * @example
 *   calculateRechargeBreakdown(100)
 *   // => {
 *   //   grossAmount: 100,
 *   //   mpCommission: 4.49,
 *   //   mpIgv: 0.55,
 *   //   totalMpFee: 5.04,
 *   //   netAmount: 94.96,
 *   //   effectiveFeePercentage: 0.0504
 *   // }
 */
export function calculateRechargeBreakdown(grossAmount: number): RechargeBreakdown {
  if (grossAmount <= 0) {
    return {
      grossAmount: 0,
      mpCommission: 0,
      mpIgv: 0,
      totalMpFee: 0,
      netAmount: 0,
      effectiveFeePercentage: 0,
    }
  }
  const mpCommission = round2(grossAmount * MP_PERU_PERCENTAGE)
  const mpIgv = MP_PERU_IGV_FIXED
  const totalMpFee = round2(mpCommission + mpIgv)
  const netAmount = round2(grossAmount - totalMpFee)
  const effectiveFeePercentage = round4(totalMpFee / grossAmount)
  return { grossAmount: round2(grossAmount), mpCommission, mpIgv, totalMpFee, netAmount, effectiveFeePercentage }
}

/**
 * Calcula el desglose SUNAT (sin IGV / con IGV) para emitir comprobante.
 * Si el monto total de la transaccion es T, entonces:
 *   subtotal = T / 1.18
 *   igv     = T - subtotal
 */
export function calculateSunatBreakdown(totalWithIgv: number) {
  const subtotal = round2(totalWithIgv / (1 + SUNAT_IGV_RATE))
  const igv = round2(totalWithIgv - subtotal)
  return { subtotal, igv, total: round2(totalWithIgv) }
}

/**
 * Formatea PEN: "S/ 1,234.56"
 */
export function formatPEN(amount: number): string {
  return new Intl.NumberFormat('es-PE', {
    style: 'currency',
    currency: 'PEN',
    minimumFractionDigits: 2,
  }).format(amount)
}

function round2(n: number): number {
  return Math.round(n * 100) / 100
}

function round4(n: number): number {
  return Math.round(n * 10000) / 10000
}
