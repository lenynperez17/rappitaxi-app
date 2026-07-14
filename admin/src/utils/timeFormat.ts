/**
 * Formats a date as a relative time string in Spanish.
 *
 * Examples:
 *   < 1 min  -> "ahora"
 *   < 60 min -> "hace 12 min"
 *   < 24 h   -> "hace 3 h"
 *   < 7 d    -> "hace 2 d"
 *   este año -> dd/MM
 *   else     -> dd/MM/yyyy (con año, para evitar ambigüedad)
 */
export function relativeTime(date: Date | null | undefined): string {
  if (!date) return '—'
  const diffMs = Date.now() - date.getTime()
  if (diffMs < 0) return 'ahora'
  const diffMin = Math.floor(diffMs / 60_000)
  if (diffMin < 1) return 'ahora'
  if (diffMin < 60) return `hace ${diffMin} min`
  const diffHr = Math.floor(diffMin / 60)
  if (diffHr < 24) return `hace ${diffHr} h`
  const diffDay = Math.floor(diffHr / 24)
  if (diffDay < 7) return `hace ${diffDay} d`
  const currentYear = new Date().getFullYear()
  if (date.getFullYear() === currentYear) {
    return date.toLocaleDateString('es-PE', { day: '2-digit', month: '2-digit' })
  }
  return date.toLocaleDateString('es-PE', { day: '2-digit', month: '2-digit', year: 'numeric' })
}

/**
 * Converts various Firestore-friendly timestamp shapes to a Date.
 * Returns null when input cannot be resolved.
 */
export function toDate(value: unknown): Date | null {
  if (!value) return null
  if (value instanceof Date) return value
  // Firestore Timestamp has toDate()
  if (typeof value === 'object' && value !== null && 'toDate' in value) {
    try {
      const d = (value as { toDate: () => Date }).toDate()
      return d instanceof Date ? d : null
    } catch {
      return null
    }
  }
  if (typeof value === 'number') return new Date(value)
  if (typeof value === 'string') {
    const d = new Date(value)
    return isNaN(d.getTime()) ? null : d
  }
  return null
}
