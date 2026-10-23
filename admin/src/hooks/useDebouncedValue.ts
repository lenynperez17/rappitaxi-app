import { useEffect, useState } from 'react'

/**
 * Ronda 287: devuelve `value` cuando lleva `delayMs` sin cambiar.
 *
 * Los buscadores del panel usaban un `useEffect` con `setTimeout` que llamaba
 * directamente a la petición. Con este hook el texto ya "asentado" pasa a la
 * clave de useQuery y React Query se encarga de pedir, cachear y descartar las
 * respuestas viejas. El setState va dentro del temporizador, no en el cuerpo
 * del efecto, así que no provoca renders en cascada.
 */
export function useDebouncedValue<T>(value: T, delayMs: number): T {
  const [debounced, setDebounced] = useState(value)

  useEffect(() => {
    const t = setTimeout(() => setDebounced(value), delayMs)
    return () => clearTimeout(t)
  }, [value, delayMs])

  return debounced
}
