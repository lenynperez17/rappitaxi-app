/**
 * Ronda 283 — descodificar la polilínea que devuelve `/api/maps/directions`.
 *
 * El backend entrega la ruta como "encoded polyline", el formato comprimido de
 * Google: en vez de una lista de coordenadas manda una cadena corta. Una ruta
 * de mil puntos ocupa unos pocos kilobytes en lugar de decenas.
 *
 * Es el reflejo exacto de `encodePolyline` en
 * `api/src/app/api/maps/directions/route.ts`, que es quien la genera —también
 * para las rutas de OSRM, que llegan como GeoJSON y allí se convierten a este
 * formato para que el cliente solo tenga que entender uno.
 *
 * Se escribe a mano en vez de añadir una dependencia: son veinte líneas de un
 * algoritmo que lleva fijo desde 2005 y que ya está implementado en el otro
 * sentido dentro de este mismo proyecto.
 *
 * Cómo funciona: cada coordenada se guarda como la DIFERENCIA con la anterior
 * (números pequeños), multiplicada por 1e5 y troceada en grupos de 5 bits.
 */

/** Un punto [lat, lng], que es el orden que espera Leaflet. */
export type LatLngTuple = [number, number]

export function decodePolyline(encoded: string): LatLngTuple[] {
  const puntos: LatLngTuple[] = []
  let indice = 0
  let lat = 0
  let lng = 0

  while (indice < encoded.length) {
    // Cada valor son varios caracteres: se van juntando de 5 en 5 bits hasta
    // encontrar uno cuyo bit de continuación (0x20) esté apagado.
    let resultado = 0
    let desplazamiento = 0
    let byte: number
    do {
      byte = encoded.charCodeAt(indice++) - 63
      resultado |= (byte & 0x1f) << desplazamiento
      desplazamiento += 5
    } while (byte >= 0x20)
    // El bit menos significativo indica el signo (complemento a uno).
    lat += resultado & 1 ? ~(resultado >> 1) : resultado >> 1

    resultado = 0
    desplazamiento = 0
    do {
      byte = encoded.charCodeAt(indice++) - 63
      resultado |= (byte & 0x1f) << desplazamiento
      desplazamiento += 5
    } while (byte >= 0x20)
    lng += resultado & 1 ? ~(resultado >> 1) : resultado >> 1

    puntos.push([lat / 1e5, lng / 1e5])
  }

  return puntos
}
