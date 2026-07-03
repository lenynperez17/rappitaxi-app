/**
 * Decoder de Encoded Polyline Algorithm Format (PolylineAlgorithmFormat).
 *
 * Estándar de Google ampliamente adoptado (Mapbox, OSRM también lo usan en
 * `geometries=polyline`). El backend `directionsProxy` siempre devuelve en
 * este formato normalizado para que cliente y backend hablen lo mismo
 * independientemente del provider.
 *
 * Spec: https://developers.google.com/maps/documentation/utilities/polylinealgorithm
 *
 * Precisión: 5 decimales (multiplier 1e5). Suficiente para rutas a nivel calle
 * (~1.1 m de precisión en el ecuador).
 */

/**
 * Decodifica una polilínea encoded en un array de coordenadas {lat, lng}.
 * Listo para usar directamente con Mapbox GL JS / react-map-gl.
 */
export function decodePolyline(encoded: string): Array<{ lat: number; lng: number }> {
  if (!encoded) return [];

  const points: Array<{ lat: number; lng: number }> = [];
  let index = 0;
  const len = encoded.length;
  let lat = 0;
  let lng = 0;

  while (index < len) {
    let result = 0;
    let shift = 0;
    let b: number;

    // Leer delta de latitud
    do {
      b = encoded.charCodeAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    const dlat = result & 1 ? ~(result >> 1) : result >> 1;
    lat += dlat;

    result = 0;
    shift = 0;
    // Leer delta de longitud
    do {
      b = encoded.charCodeAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    const dlng = result & 1 ? ~(result >> 1) : result >> 1;
    lng += dlng;

    points.push({ lat: lat / 1e5, lng: lng / 1e5 });
  }

  return points;
}
