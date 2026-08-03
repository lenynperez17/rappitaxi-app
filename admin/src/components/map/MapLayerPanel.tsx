import { useEffect, useState, useCallback } from 'react'
import { Layers, ChevronDown } from 'lucide-react'
import { MAP_COLORS } from './mapIcons'

/**
 * Ronda 270: control de capas del mapa en vivo.
 *
 * Con la flota entera encima del plano, el operador no podía quitarse de
 * delante lo que no estaba mirando. Ahora cada grupo se enciende y se apaga, y
 * la elección se recuerda entre sesiones: quien trabaja despachando no quiere
 * volver a apagar los desconectados cada vez que entra.
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

/** Lee la preferencia guardada. Se hace en un efecto, no en el render. */
export function useMapLayers(): [MapLayers, (k: keyof MapLayers) => void] {
  const [layers, setLayers] = useState<MapLayers>(DEFAULT_LAYERS)

  useEffect(() => {
    try {
      const raw = localStorage.getItem(STORAGE_KEY)
      if (raw) setLayers({ ...DEFAULT_LAYERS, ...JSON.parse(raw) })
    } catch {
      // localStorage inaccesible (modo privado) o JSON corrupto: valores por defecto
    }
  }, [])

  const toggle = useCallback((key: keyof MapLayers) => {
    setLayers((prev) => {
      const next = { ...prev, [key]: !prev[key] }
      try { localStorage.setItem(STORAGE_KEY, JSON.stringify(next)) } catch { /* no persistible */ }
      return next
    })
  }, [])

  return [layers, toggle]
}

export function MapLayerPanel({
  layers,
  onToggle,
  counts,
}: {
  layers: MapLayers
  onToggle: (k: keyof MapLayers) => void
  counts: { free: number; busy: number; offline: number; trips: number }
}) {
  // En móvil el panel arranca plegado: son 4 filas que taparían medio mapa.
  const [open, setOpen] = useState(false)

  const rows: Array<{ key: keyof MapLayers; color: string; label: string; count: number }> = [
    { key: 'free', color: MAP_COLORS.free, label: 'Libres', count: counts.free },
    { key: 'busy', color: MAP_COLORS.busy, label: 'En viaje', count: counts.busy },
    { key: 'trips', color: MAP_COLORS.destination, label: 'Viajes', count: counts.trips },
    { key: 'offline', color: MAP_COLORS.offline, label: 'Offline', count: counts.offline },
  ]

  const activeCount = rows.filter((r) => layers[r.key]).length

  return (
    <div className="pointer-events-auto bg-white/95 backdrop-blur border border-gray-200 rounded-lg shadow-md overflow-hidden">
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        aria-expanded={open}
        className="w-full flex items-center gap-2 px-3 py-2 text-xs font-semibold text-gray-700 hover:bg-gray-50 sm:cursor-default"
      >
        <Layers className="w-3.5 h-3.5 text-gray-500" />
        <span>Capas</span>
        <span className="text-gray-400 font-normal">{activeCount}/4</span>
        <ChevronDown className={`w-3.5 h-3.5 ml-auto text-gray-400 transition-transform sm:hidden ${open ? 'rotate-180' : ''}`} />
      </button>
      <div className={`${open ? 'block' : 'hidden'} sm:block px-3 pb-2.5 space-y-1.5`}>
        {rows.map((r) => (
          <label
            key={r.key}
            className="flex items-center gap-2 text-xs text-gray-700 cursor-pointer select-none"
          >
            <input
              type="checkbox"
              checked={layers[r.key]}
              onChange={() => onToggle(r.key)}
              className="w-3.5 h-3.5 rounded border-gray-300 accent-[#E31E24]"
            />
            <span className="inline-block w-2.5 h-2.5 rounded-full flex-shrink-0" style={{ background: r.color }} />
            <span className="flex-1">{r.label}</span>
            <span className="tabular-nums text-gray-500">{r.count}</span>
          </label>
        ))}
      </div>
    </div>
  )
}
