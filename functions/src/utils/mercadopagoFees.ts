/**
 * MercadoPago Peru - Calculo de comision real por recarga
 *
 * Tarifa estandar checkout MercadoPago Peru (referencia 2026):
 *   - Comision porcentual:  4.49% sobre monto bruto
 *   - IGV financiero fijo:  S/ 0.55 por transaccion aprobada
 *
 * Si el conductor recarga S/ X, recibe en su wallet: X - (X * 0.0449) - 0.55
 *
 * IMPORTANTE: Estos valores deben mantenerse sincronizados con
 * `admin/src/utils/mercadopagoFees.ts` (frontend) para evitar discrepancias.
 */

export const MP_PERU_PERCENTAGE = 0.0449
export const MP_PERU_IGV_FIXED = 0.55
export const SUNAT_IGV_RATE = 0.18

export interface RechargeBreakdown {
  grossAmount: number
  mpCommission: number
  mpIgv: number
  totalMpFee: number
  netAmount: number
  effectiveFeePercentage: number
}

/**
 * Calcula el desglose completo de una recarga MercadoPago.
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
  return {
    grossAmount: round2(grossAmount),
    mpCommission,
    mpIgv,
    totalMpFee,
    netAmount,
    effectiveFeePercentage,
  }
}

/**
 * SUNAT breakdown: dado un total con IGV, separa subtotal e IGV (18%).
 */
export function calculateSunatBreakdown(totalWithIgv: number) {
  const subtotal = round2(totalWithIgv / (1 + SUNAT_IGV_RATE))
  const igv = round2(totalWithIgv - subtotal)
  return { subtotal, igv, total: round2(totalWithIgv) }
}

function round2(n: number): number {
  return Math.round(n * 100) / 100
}

function round4(n: number): number {
  return Math.round(n * 10000) / 10000
}
