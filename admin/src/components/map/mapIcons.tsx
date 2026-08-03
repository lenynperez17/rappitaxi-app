import L from 'leaflet'

/**
 * Iconos del mapa en vivo.
 *
 * Ronda 270: antes cada conductor era el MISMO círculo verde de 18px, estuviera
 * libre o en pleno viaje, y los viajes solo pintaban el punto de recojo. Con
 * diez conductores en pantalla el operador no podía distinguir a quién mandar
 * un viaje sin abrir los popups uno por uno.
 *
 * Se construyen como `DivIcon` (HTML plano) en vez de imágenes: pesan cero
 * peticiones, se recolorean con una variable y escalan nítidos en pantallas
 * retina. El SVG va inline por el mismo motivo — un <img> por marcador serían
 * cientos de peticiones con la flota entera en el mapa.
 */

export const MAP_COLORS = {
  free: '#16A34A',     // verde  — conductor disponible
  busy: '#F59E0B',     // ámbar  — conductor dentro de un viaje
  offline: '#9CA3AF',  // gris   — desconectado
  pickup: '#16A34A',   // verde  — punto de recojo
  destination: '#DC2626', // rojo — destino
  passenger: '#7C3AED',   // violeta — pasajero
} as const

/** Silueta de coche vista desde arriba. `viewBox` cuadrado para rotar sin recortes. */
function carSvg(color: string, size: number, opacity: number): string {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 40 40"
    style="opacity:${opacity};filter:drop-shadow(0 1px 2px rgba(0,0,0,.35))">
    <rect x="11" y="4" width="18" height="32" rx="7" fill="${color}"/>
    <rect x="13" y="10" width="14" height="12" rx="4" fill="${color}" stroke="rgba(255,255,255,.45)" stroke-width="1"/>
    <rect x="14" y="11" width="12" height="5" rx="2" fill="rgba(255,255,255,.75)"/>
    <rect x="14" y="24" width="12" height="4" rx="2" fill="rgba(255,255,255,.55)"/>
    <rect x="8" y="8" width="5" height="8" rx="2" fill="#374151"/>
    <rect x="8" y="24" width="5" height="8" rx="2" fill="#374151"/>
    <rect x="27" y="8" width="5" height="8" rx="2" fill="#374151"/>
    <rect x="27" y="24" width="5" height="8" rx="2" fill="#374151"/>
    <circle cx="14" cy="6" r="1.5" fill="#FDE68A"/><circle cx="26" cy="6" r="1.5" fill="#FDE68A"/>
    <circle cx="14" cy="34" r="1.5" fill="#EF4444"/><circle cx="26" cy="34" r="1.5" fill="#EF4444"/>
  </svg>`
}

/** Gota de mapa clásica con una letra dentro (A = recojo, B = destino). */
function pinSvg(color: string, letter: string): string {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="26" height="34" viewBox="0 0 32 42"
    style="filter:drop-shadow(0 1px 2px rgba(0,0,0,.35))">
    <path d="M16 2C8.8 2 3 7.8 3 15c0 9.7 13 24 13 24s13-14.3 13-24C29 7.8 23.2 2 16 2z"
      fill="${color}" stroke="white" stroke-width="1.5"/>
    <circle cx="16" cy="15" r="7" fill="white"/>
    <text x="16" y="19.5" text-anchor="middle" font-size="10" font-weight="700"
      font-family="system-ui,sans-serif" fill="${color}">${letter}</text>
  </svg>`
}

type DriverState = 'free' | 'busy' | 'offline'

/**
 * Marcador de conductor. Los ocupados laten para que el ojo los separe de los
 * libres incluso en blanco y negro o para quien no distingue verde de ámbar —
 * el color por sí solo nunca debe ser el único portador de la información.
 */
export function driverIcon(state: DriverState): L.DivIcon {
  const size = state === 'offline' ? 26 : 34
  const opacity = state === 'offline' ? 0.5 : 1
  const svg = carSvg(MAP_COLORS[state], size, opacity)
  return new L.DivIcon({
    className: `rt-marker${state === 'busy' ? ' rt-marker-pulse' : ''}`,
    html: svg,
    iconSize: [size, size],
    iconAnchor: [size / 2, size / 2],
    popupAnchor: [0, -size / 2],
  })
}

export function pickupIcon(): L.DivIcon {
  return new L.DivIcon({
    className: 'rt-marker',
    html: pinSvg(MAP_COLORS.pickup, 'A'),
    iconSize: [26, 34],
    iconAnchor: [13, 34],
    popupAnchor: [0, -34],
  })
}

export function destinationIcon(): L.DivIcon {
  return new L.DivIcon({
    className: 'rt-marker',
    html: pinSvg(MAP_COLORS.destination, 'B'),
    iconSize: [26, 34],
    iconAnchor: [13, 34],
    popupAnchor: [0, -34],
  })
}
