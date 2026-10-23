import { useCallback, useState } from 'react'

/**
 * Ronda 270: qué grupos del mapa en vivo están encendidos. La elección se
 * recuerda entre sesiones: quien trabaja despachando no quiere volver a apagar
 * los desconectados cada vez que entra.
 */
export interface MapLayers {
  free: boolean
  busy: boolean
  offline: boolean
  trips: boolean
}

const STORAGE_KEY = 'rapi_map_layers_v1'

export const DEFAULT_LAYERS: MapLayers = {
  free: true,
  busy: true,
  trips: true,
  offline: false, // apagados por defecto: son los más numerosos y los que menos dicen
}

/**
 * Ronda 287: la preferencia se lee en el inicializador de useState. Antes se
 * leía en un efecto, lo que pintaba primero las capas por defecto y luego las
 * guardadas (dos renders y un parpadeo). El panel es una SPA sin render en
 * servidor, así que no hay hidratación que proteger.
 */
function readStoredLayers(): MapLayers {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (raw) return { ...DEFAULT_LAYERS, ...JSON.parse(raw) }
  } catch {
    // localStorage inaccesible (modo privado) o JSON corrupto: valores por defecto
  }
  return DEFAULT_LAYERS
}

export function useMapLayers(): [MapLayers, (k: keyof MapLayers) => void] {
  const [layers, setLayers] = useState<MapLayers>(readStoredLayers)

  const toggle = useCallback((key: keyof MapLayers) => {
    setLayers((prev) => {
      const next = { ...prev, [key]: !prev[key] }
      try { localStorage.setItem(STORAGE_KEY, JSON.stringify(next)) } catch { /* no persistible */ }
      return next
    })
  }, [])

  return [layers, toggle]
}
