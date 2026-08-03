import { useEffect, useState } from 'react'
import { TileLayer, useMap } from 'react-leaflet'
import L from 'leaflet'
import 'maplibre-gl/dist/maplibre-gl.css'
import '@maplibre/maplibre-gl-leaflet'

/**
 * Mapa base vectorial.
 *
 * Ronda 270: el panel dibujaba encima de las teselas de imagen de
 * OpenStreetMap. Funcionan, pero son fotos de mapa: el texto se pixela al
 * acercarse, el zoom va a saltos y las etiquetas salen en el idioma con el que
 * se generó la imagen. Se ve viejo al lado del mapa de App-Plus.
 *
 * Ahora el fondo son teselas vectoriales servidas por OpenFreeMap: el navegador
 * dibuja el mapa, así que el texto queda nítido a cualquier escala, el zoom es
 * continuo y las etiquetas se pueden pasar a español sobre la marcha.
 *
 * Por qué OpenFreeMap y no Mapbox, que es lo que usa App-Plus: Mapbox exige una
 * clave de acceso. La única a mano es la de App-Plus, y meter la credencial de
 * otro proyecto aquí mezcla su consumo y su facturación con los de Rapi Team.
 * OpenFreeMap sirve el mismo tipo de teselas sin clave y con uso comercial
 * permitido. Si algún día se quiere el estilo exacto de Mapbox, hay que sacar
 * una clave a nombre de Rapi Team; ver `MAPBOX_STYLE_URL` más abajo.
 */

/** Estilo vectorial de OpenFreeMap. "Liberty" es el más parecido a Mapbox Streets. */
const VECTOR_STYLE_URL = 'https://tiles.openfreemap.org/styles/liberty'

/**
 * Para migrar a Mapbox el día que Rapi Team tenga su propia clave:
 *   const MAPBOX_STYLE_URL = `https://api.mapbox.com/styles/v1/mapbox/streets-v12?access_token=${import.meta.env.VITE_MAPBOX_TOKEN}`
 * y pasarlo como `style`. El resto de este archivo no cambia.
 */

/**
 * Las teselas vectoriales se dibujan con WebGL. En equipos sin aceleración —
 * máquinas virtuales, escritorios remotos, navegadores con WebGL desactivado —
 * no hay nada que hacer, y un mapa en blanco sería peor que uno anticuado. Se
 * comprueba antes y en ese caso se sirven las teselas de imagen de siempre.
 */
function hasWebGL(): boolean {
  try {
    const canvas = document.createElement('canvas')
    return !!(canvas.getContext('webgl2') || canvas.getContext('webgl'))
  } catch {
    return false
  }
}

/** Pasa a español las etiquetas del estilo (calles, ciudades, países). */
function setSpanishLabels(maplibreMap: maplibregl.Map) {
  try {
    for (const layer of maplibreMap.getStyle().layers ?? []) {
      if (layer.type !== 'symbol') continue
      const field = maplibreMap.getLayoutProperty(layer.id, 'text-field')
      if (field === undefined) continue
      // `coalesce` para que un topónimo sin traducción caiga a su nombre local
      // en vez de quedarse en blanco.
      maplibreMap.setLayoutProperty(layer.id, 'text-field', [
        'coalesce', ['get', 'name:es'], ['get', 'name'],
      ])
    }
  } catch {
    // Un estilo puede no admitir el cambio; se queda el idioma de origen antes
    // que romper el render del mapa entero.
  }
}

export function VectorBasemap() {
  const map = useMap()
  const [failed, setFailed] = useState(!hasWebGL())

  useEffect(() => {
    if (failed) return
    let layer: L.MaplibreGL | null = null
    const credit = '&copy; <a href="https://openfreemap.org" target="_blank" rel="noreferrer">OpenFreeMap</a> · OpenStreetMap'
    try {
      // `attributionControl: false` — los créditos los pone el control de
      // Leaflet que ya existe abajo a la derecha. Con los dos activos salen dos
      // líneas de créditos superpuestas en la misma esquina.
      layer = L.maplibreGL({ style: VECTOR_STYLE_URL, attributionControl: false })
      layer.addTo(map)
      map.attributionControl?.addAttribution(credit)
      const gl = layer.getMaplibreMap()
      gl.on('load', () => setSpanishLabels(gl))
      // Si el estilo no llega (red, CDN caído), se vuelve a las teselas de
      // imagen en lugar de dejar al operador mirando un rectángulo gris.
      gl.on('error', () => setFailed(true))
    } catch {
      setFailed(true)
    }
    return () => {
      map.attributionControl?.removeAttribution(credit)
      if (layer) map.removeLayer(layer)
    }
  }, [map, failed])

  if (!failed) return null

  return (
    <TileLayer
      attribution='&copy; OpenStreetMap contributors'
      url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
    />
  )
}
