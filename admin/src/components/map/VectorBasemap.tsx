import { useEffect, useState } from 'react'
import { TileLayer, useMap } from 'react-leaflet'
import L from 'leaflet'
import 'mapbox-gl/dist/mapbox-gl.css'
import 'mapbox-gl-leaflet'

/**
 * Mapa base vectorial de Mapbox.
 *
 * Ronda 270: el panel dibujaba encima de las teselas de imagen de
 * OpenStreetMap. Funcionan, pero son fotos de un mapa: el texto se pixela al
 * acercarse, el zoom va a saltos y las etiquetas salen en el idioma con el que
 * se generó la imagen. Se veía viejo al lado del mapa de App-Plus.
 *
 * Ahora el fondo es `streets-v12`, el mismo estilo que usa App-Plus. Lo dibuja
 * el navegador a partir de datos vectoriales: texto nítido a cualquier escala,
 * zoom continuo y etiquetas que se pueden pasar a español al vuelo.
 *
 * El token va en `VITE_MAPBOX_TOKEN` (fichero `.env`, fuera del control de
 * versiones), nunca escrito en el código. Aun así acaba en el paquete que
 * descarga el navegador: los tokens `pk.` de Mapbox son públicos por diseño y
 * la protección real es restringirlos por dominio desde la cuenta de Mapbox.
 * Conviene tener el de Rapi Team limitado a `panel-rapi-team.nyneln8n.com`.
 */

const MAPBOX_TOKEN = import.meta.env.VITE_MAPBOX_TOKEN as string | undefined
const MAPBOX_STYLE = 'mapbox://styles/mapbox/streets-v12'

/** Atribución exigida por las condiciones de uso de Mapbox. */
const MAPBOX_CREDIT =
  '&copy; <a href="https://www.mapbox.com/about/maps/" target="_blank" rel="noreferrer">Mapbox</a> ' +
  '&copy; <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noreferrer">OpenStreetMap</a>'

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

/** El puente expone el mapa de Mapbox, pero sus tipos publicados no lo declaran. */
interface MapboxGLLayer extends L.Layer {
  getMapboxMap(): { setLanguage?: (lang: string) => void; on: (ev: string, cb: () => void) => void }
}

export function VectorBasemap() {
  const map = useMap()
  // Sin token no hay mapa vectorial posible: se arranca ya en modo respaldo en
  // vez de intentarlo y fallar con un error de autorización en consola.
  const [failed, setFailed] = useState(!MAPBOX_TOKEN || !hasWebGL())

  useEffect(() => {
    if (failed || !MAPBOX_TOKEN) return
    let layer: L.MapboxGL | null = null
    try {
      layer = L.mapboxGL({ accessToken: MAPBOX_TOKEN, style: MAPBOX_STYLE })
      layer.addTo(map)
      map.attributionControl?.addAttribution(MAPBOX_CREDIT)

      const gl = (layer as unknown as MapboxGLLayer).getMapboxMap()
      // `setLanguage` es nativo en mapbox-gl v3; sin él las etiquetas salen en
      // inglés ("Lima Province", "Pacific Ocean") en una herramienta que usa
      // personal peruano.
      gl.on('load', () => gl.setLanguage?.('es'))
      // Si el estilo no llega —red caída, token revocado o sin cuota— se vuelve
      // a las teselas de imagen en lugar de dejar un rectángulo gris.
      gl.on('error', () => setFailed(true))
    } catch {
      setFailed(true)
    }
    return () => {
      map.attributionControl?.removeAttribution(MAPBOX_CREDIT)
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
