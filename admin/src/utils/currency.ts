/**
 * Formatea un monto en PEN con dos decimales.
 *   formatPEN(1234.5) => "S/ 1,234.50"
 */
export function formatPEN(amount: number | null | undefined): string {
  if (amount == null || isNaN(amount)) return 'S/ 0.00'
  return new Intl.NumberFormat('es-PE', {
    style: 'currency',
    currency: 'PEN',
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(amount)
}

export function formatPercentage(value: number, decimals = 2): string {
  return `${(value * 100).toFixed(decimals)}%`
}
