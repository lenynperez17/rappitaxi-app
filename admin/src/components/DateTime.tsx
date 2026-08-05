import { formatDateTime, formatDateTimeExact, relativeTime, toDate } from '../utils/timeFormat'

/**
 * Ronda 273: fecha y hora de un registro, siempre en el mismo formato.
 *
 * Muestra `dd/MM/yyyy HH:mm` en hora de Lima. Al pasar el ratón por encima
 * aparecen los segundos y cuánto hace, para no tener que elegir entre saber el
 * momento exacto y saber si fue hace un rato.
 *
 * Existe como componente y no como una simple llamada a función para que el
 * tooltip y el formato viajen juntos: repartidos por veinte sitios, tarde o
 * temprano cada listado acabaría enseñando la fecha a su manera, que es
 * justamente de donde se venía.
 */
export function DateTime({
  value,
  relative = false,
  className = '',
}: {
  value: unknown
  /** Añade "· hace 3 min" al lado. Útil donde la antigüedad importa más que el reloj. */
  relative?: boolean
  className?: string
}) {
  const date = toDate(value)
  if (!date) return <span className={className}>—</span>

  return (
    <time
      dateTime={date.toISOString()}
      title={`${formatDateTimeExact(date)} (${relativeTime(date)})`}
      className={`tabular-nums whitespace-nowrap ${className}`}
    >
      {formatDateTime(date)}
      {relative && <span className="text-gray-400"> · {relativeTime(date)}</span>}
    </time>
  )
}
