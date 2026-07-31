/**
 * GET /api/maps/autocomplete?q=<query>&session=<uuid>&lat=<lat>&lng=<lng>
 * Auth: Bearer <access_token>
 *
 * Estrategia dual con fallback automático:
 *   1. Si GOOGLE_MAPS_API_KEY funciona → Google Places
 *   2. Si Google falla (billing off, quota, denied) → OSM Nominatim (gratis)
 *
 * OSM Nominatim: gratis, sin API key, sin billing. Ligeramente menos preciso
 * que Google pero suficiente para autocomplete de direcciones. Requiere
 * User-Agent identificando la app (policy Nominatim).
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { ipRateLimit, keyedRateLimit } from '@/lib/rate-limit'

export const runtime = 'nodejs'

const PLACES_URL = 'https://maps.googleapis.com/maps/api/place/autocomplete/json'
const NOMINATIM_URL = 'https://nominatim.openstreetmap.org/search'
// Ronda 268: Photon PROPIO, en el VPS. La instancia pública de komoot queda
// como respaldo si la nuestra no responde.
//
// La diferencia no es solo de coste. Sobre los mismos datos de OpenStreetMap,
// nuestra instancia devuelve el CENTRO COMERCIAL, mientras que los datos
// comerciales de Mapbox devuelven las TIENDAS DE DENTRO — que no es lo que
// pide quien escribe "jockey plaza":
//   jockey plaza  → propio:  "Jockey Plaza Shopping Center, Surco"
//                   Mapbox:  "Falabella Jockey Plaza", "Tottus Jockey Plaza"
//   mega plaza    → propio:  "Mega Plaza, Los Olivos"
//   larcomar      → propio:  "Larcomar, Miraflores"
const PHOTON_SELF_URL = process.env.PHOTON_SELF_URL ?? 'https://photon.nynelmkt.cloud/api/'
const PHOTON_URL = 'https://photon.komoot.io/api/'
const MAPBOX_URL = 'https://api.mapbox.com/geocoding/v5/mapbox.places'
const MAPBOX_SEARCHBOX_URL = 'https://api.mapbox.com/search/searchbox/v1/forward'

interface Prediction {
  placeId: string | null
  description: string
  mainText: string
  secondaryText?: string
  lat?: number
  lng?: number
}

/**
 * Ronda 267: cortacircuitos para Google.
 *
 * Con la facturación desactivada en Google Cloud, Places responde
 * REQUEST_DENIED a TODAS las peticiones. Aun así se le seguía consultando en
 * cada pulsación de tecla del autocompletado, y cada intento fallido añadía su
 * ida y vuelta a la red antes de pasar al proveedor siguiente. El pasajero
 * pagaba esa espera en cada letra que escribía.
 *
 * Tras un fallo se deja de llamar a Google durante 5 minutos. Es un fallo de
 * configuración de cuenta, no un error transitorio: reintentar cada tecla no
 * lo arregla. Al reintentar pasados los 5 minutos, el día que se active la
 * facturación la cadena vuelve sola a Google sin tocar código ni reiniciar.
 */
let googleDisabledUntil = 0
const GOOGLE_COOLDOWN_MS = 5 * 60_000

async function fromGoogle(q: string, key: string, session?: string, lat?: string, lng?: string): Promise<Prediction[] | null> {
  if (Date.now() < googleDisabledUntil) return null
  const params = new URLSearchParams({ input: q, key, language: 'es', components: 'country:pe' })
  if (session) params.set('sessiontoken', session)
  if (lat && lng) {
    params.set('location', `${lat},${lng}`)
    params.set('radius', '30000')
  }
  try {
    const r = await fetch(`${PLACES_URL}?${params.toString()}`, { signal: AbortSignal.timeout(6000) })
    const data = await r.json()
    if (data.status !== 'OK' && data.status !== 'ZERO_RESULTS') {
      googleDisabledUntil = Date.now() + GOOGLE_COOLDOWN_MS
      console.warn('[maps] Google status=', data.status,
        '— desactivado 5 min, usando Mapbox/Photon')
      return null
    }
    googleDisabledUntil = 0
    return (data.predictions ?? []).map((p: {
      place_id?: string; description?: string
      structured_formatting?: { main_text?: string; secondary_text?: string }
    }) => ({
      placeId: p.place_id ?? null,
      description: p.description ?? '',
      mainText: p.structured_formatting?.main_text ?? p.description ?? '',
      secondaryText: p.structured_formatting?.secondary_text,
    }))
  } catch (e) {
    googleDisabledUntil = Date.now() + GOOGLE_COOLDOWN_MS
    console.warn('[maps] Google excepción:', e instanceof Error ? e.message : e)
    return null
  }
}

// Extrae el número de casa/edificio del query del usuario.
// Nominatim en Perú rara vez tiene house_number mapeado, así que preservamos
// el número que el usuario escribió y lo añadimos al mainText/description.
function extractHouseNumber(query: string): string | null {
  // Ronda 52 Bug#2: usar match global + tomar el ÚLTIMO número. Antes el
  // regex tomaba el primer número, corrompiendo direcciones como "Av 28 de
  // Julio 350" → capturaba "28" en vez de "350".
  const matches = [...query.matchAll(/(?:^|\s|#|nro\.?|no\.?|número|numero)\s*(\d{1,6})(?:[-A-Za-z]?)?/gi)]
  return matches.length > 0 ? matches[matches.length - 1]![1]! : null
}

/**
 * Ronda 258: Photon (komoot) — geocodificador gratuito sobre datos OSM, sin
 * API key ni facturación, PENSADO para autocompletar (Nominatim está pensado
 * para búsqueda exacta).
 *
 * Por qué se añade: la búsqueda de texto libre en Nominatim devolvía
 * coordenadas equivocadas de forma sistemática. Comprobado con casos reales:
 *   "Jirón Las Coralinas 870"  → Nominatim: lon -77.080 (Callao, ERROR)
 *                                Photon:    lon -77.009 (San Juan de
 *                                           Lurigancho, correcto)
 *   "Parque Kennedy"           → Nominatim: -12.36,-76.79 (a 40 km, ERROR)
 * El mismo Nominatim acierta si se le pasan street/city por separado, pero el
 * usuario escribe texto libre, así que no siempre hay distrito que extraer.
 *
 * Además devolvemos lat/lng EN LA PREDICCIÓN: así la app usa exactamente la
 * coordenada del resultado que el usuario tocó, sin una segunda consulta que
 * pueda resolver a otro sitio distinto.
 */
/**
 * Ronda 261: Mapbox Geocoding.
 *
 * POR QUÉ HACE FALTA: OpenStreetMap NO tiene mapeada la numeración de las
 * calles de Lima. Comprobado consultando el dato crudo: para "Av. Túpac Amaru
 * 1150, Comas" OSM responde `house_number: NO MAPEADO` y devuelve el centroide
 * del tramo de la avenida. Como esas avenidas miden varios kilómetros, el
 * nombre sale correcto pero la coordenada se desvía 4-9 km. Medido sobre 15
 * direcciones con número: 10/15 dentro de 3 km, y los 5 desvíos eran todos
 * por esta causa (calle correcta, número inexistente en el mapa base).
 *
 * Mapbox interpola la numeración a lo largo del tramo, que es justo lo que
 * falta. Su nivel gratuito cubre 100.000 peticiones al mes.
 *
 * ACTIVACIÓN: basta con poner MAPBOX_ACCESS_TOKEN en el .env; si no está, la
 * cadena sigue funcionando igual con Photon y Nominatim.
 */
/**
 * Ronda 268: caché de lo que ya se preguntó a Mapbox.
 *
 * El autocompletado dispara una petición por tecla, así que "larcomar" son
 * cuatro búsquedas facturables desde la cuarta letra — y las repite entera
 * cada pasajero que escribe lo mismo. Guardar la respuesta 24 h convierte esas
 * repeticiones en cero peticiones. Los sitios no se mudan; un día de desfase
 * no tiene ningún efecto práctico.
 *
 * Vive en memoria del proceso: se pierde al reiniciar y no se comparte entre
 * instancias, que para un único proceso PM2 es exactamente lo que hace falta.
 * El tope de entradas evita que un bot que teclee basura infinita haga crecer
 * el mapa sin límite.
 */
/**
 * Clave de deduplicación: nombre + posición redondeada a ~110 m.
 *
 * Tres decimales, no cuatro: OpenStreetMap tiene el mismo sitio registrado más
 * de una vez con coordenadas ligeramente distintas —"Plaza Norte" aparecía dos
 * veces separadas por 11 m, una etiquetada en San Martín de Porres y otra en
 * Independencia, porque el centro comercial está en el límite entre ambos—.
 * Con 4 decimales las dos sobrevivían y el pasajero veía la misma opción
 * repetida. Dos sitios DISTINTOS que compartan nombre exacto a menos de 110 m
 * es un caso que en la práctica no se da, y si se diera, están en la misma
 * esquina.
 */
function dedupeKey(p: Prediction): string {
  return `${p.mainText.toLowerCase()}|${(p.lat ?? 0).toFixed(3)}|${(p.lng ?? 0).toFixed(3)}`
}

function dedupePredictions(list: Prediction[]): Prediction[] {
  const seen = new Set<string>()
  return list.filter((p) => {
    const k = dedupeKey(p)
    if (seen.has(k)) return false
    seen.add(k)
    return true
  })
}

/**
 * Primero lo nuestro, después lo de Mapbox, sin repetidos y con un tope de 8
 * porque es lo que cabe en la lista que ve el pasajero sin desplazarse.
 */
function mergePredictions(primary: Prediction[], secondary: Prediction[]): Prediction[] {
  return dedupePredictions([...primary, ...secondary]).slice(0, 8)
}

const MAPBOX_CACHE_TTL_MS = 24 * 60 * 60_000
const MAPBOX_CACHE_MAX = 2000
const mapboxCache = new Map<string, { at: number; predictions: Prediction[] }>()

function getCachedMapbox(q: string): Prediction[] | null {
  const hit = mapboxCache.get(q.toLowerCase())
  if (!hit) return null
  if (Date.now() - hit.at > MAPBOX_CACHE_TTL_MS) {
    mapboxCache.delete(q.toLowerCase())
    return null
  }
  return hit.predictions
}

function setCachedMapbox(q: string, predictions: Prediction[]): void {
  if (mapboxCache.size >= MAPBOX_CACHE_MAX) {
    // Map conserva el orden de inserción: la primera clave es la más antigua.
    const oldest = mapboxCache.keys().next().value
    if (oldest !== undefined) mapboxCache.delete(oldest)
  }
  mapboxCache.set(q.toLowerCase(), { at: Date.now(), predictions })
}

/**
 * Ronda 267: Mapbox Search Box — el único proveedor de la cadena que indexa
 * NEGOCIOS por su nombre comercial.
 *
 * POR QUÉ HACE FALTA: con la facturación de Google Cloud desactivada, Places
 * responde REQUEST_DENIED y la cadena cae a geocodificadores de DIRECCIONES.
 * Esos no saben qué es "Mega Plaza". Comprobado en producción:
 *   "mega plaza"           → Photon: "Alfredo Mendiola 3698, Independencia"
 *   "plaza norte"          → Mapbox v5: "Pasaje Plaza"
 *   "jockey plaza"         → Mapbox v5: "Ingreso Estacionamiento Jockey Plaza"
 *   "real plaza salaverry" → Mapbox v5: "Avenida Salaverry"
 * El primero es literalmente la dirección de MegaPlaza, pero sin el nombre que
 * el pasajero reconoce nadie lo elige, así que el destino nunca se marcaba.
 *
 * Search Box devuelve el sitio por su nombre y con coordenadas correctas:
 *   plaza norte → Falabella Plaza Norte    (-12.0063, -77.0571)
 *   jockey plaza → Falabella Jockey Plaza  (-12.0865, -76.9780)
 *
 * Va ANTES de la v5 porque no pierde nada a cambio: medido sobre direcciones
 * con numeración —el caso que motivó añadir la v5 en la ronda 261— devuelve la
 * coordenada idéntica, dígito a dígito. La v5 se conserva detrás como respaldo.
 *
 * Se usa `/forward` y no `/suggest` porque suggest solo da el nombre y exige
 * una segunda llamada a `/retrieve` para las coordenadas; forward las trae de
 * una vez, que es lo que necesita la predicción.
 *
 * Mismo MAPBOX_ACCESS_TOKEN que la v5.
 */
async function fromMapboxSearchBox(q: string, token: string, lat?: string, lng?: string): Promise<Prediction[] | null> {
  const params = new URLSearchParams({
    q,
    access_token: token,
    country: 'pe',
    language: 'es',
    limit: '8',
  })
  if (lat && lng) params.set('proximity', `${lng},${lat}`)

  try {
    const r = await fetch(`${MAPBOX_SEARCHBOX_URL}?${params.toString()}`, {
      signal: AbortSignal.timeout(6000),
    })
    if (!r.ok) {
      console.warn('[maps] Mapbox SearchBox HTTP', r.status, '— cayendo al siguiente proveedor')
      return null
    }
    const data = await r.json() as {
      features?: Array<{
        geometry?: { coordinates?: [number, number] }
        properties?: {
          mapbox_id?: string
          name?: string
          full_address?: string
          place_formatted?: string
        }
      }>
    }
    const out: Prediction[] = []
    // Search Box devuelve la misma tienda repetida cuando tiene varias
    // entradas en el índice: "tottus" traía dos veces "Tottus Jockey Plaza" y
    // "parque kennedy" dos veces "SSHH del Parque Kennedy", ocupando la lista
    // corta que ve el pasajero. Se descarta el duplicado por nombre + posición
    // redondeada a ~11 m, que es la precisión con la que dos entradas del
    // índice se refieren al mismo local.
    const seen = new Set<string>()
    for (const f of data.features ?? []) {
      const c = f.geometry?.coordinates
      const p = f.properties
      if (!c || c.length < 2 || !p?.name) continue
      const [lon, la] = c
      // Misma guarda geográfica que el resto de proveedores.
      if (la < -19 || la > 0.5 || lon < -82 || lon > -68) continue
      const key = `${p.name.toLowerCase()}|${la.toFixed(3)}|${lon.toFixed(3)}`
      if (seen.has(key)) continue
      seen.add(key)
      const secondary = p.full_address ?? p.place_formatted
      out.push({
        placeId: p.mapbox_id ?? null,
        description: secondary ? `${p.name}, ${secondary}` : p.name,
        mainText: p.name,
        secondaryText: secondary,
        lat: Number(la),
        lng: Number(lon),
      })
    }
    return out.length > 0 ? out : null
  } catch (e) {
    console.warn('[maps] Mapbox SearchBox excepción:', e instanceof Error ? e.message : e)
    return null
  }
}

async function fromMapbox(q: string, token: string, lat?: string, lng?: string): Promise<Prediction[] | null> {
  const params = new URLSearchParams({
    access_token: token,
    country: 'pe',
    language: 'es',
    limit: '8',
    // Ronda 261: 'street' NO es un tipo válido en la API v5 de Mapbox y la
    // petición entera se rechazaba con HTTP 422 — el proveedor quedaba
    // descartado en silencio y todo seguía cayendo a Photon. Tipos válidos:
    // country, region, postcode, district, place, locality, neighborhood,
    // address, poi.
    types: 'address,poi,place,neighborhood,locality,district',
  })
  // `proximity` solo ordena por cercanía; nunca excluye resultados lejanos.
  if (lat && lng) params.set('proximity', `${lng},${lat}`)

  try {
    const url = `${MAPBOX_URL}/${encodeURIComponent(q)}.json?${params.toString()}`
    const r = await fetch(url, { signal: AbortSignal.timeout(6000) })
    if (!r.ok) {
      console.warn('[maps] Mapbox HTTP', r.status, '— cayendo al siguiente proveedor')
      return null
    }
    const data = await r.json() as {
      features?: Array<{
        center?: [number, number]
        text?: string
        place_name?: string
        address?: string
        id?: string
      }>
    }
    const out: Prediction[] = []
    for (const f of data.features ?? []) {
      const c = f.center
      if (!c || c.length < 2) continue
      const [lon, la] = c
      // Misma guarda geográfica que el resto de proveedores.
      if (la < -19 || la > 0.5 || lon < -82 || lon > -68) continue
      const main = f.address && f.text ? `${f.text} ${f.address}` : (f.text ?? '')
      const full = f.place_name ?? main
      if (!main) continue
      out.push({
        placeId: f.id ?? null,
        description: full,
        mainText: main,
        secondaryText: full.split(',').slice(1).join(',').trim(),
        lat: Number(la),
        lng: Number(lon),
      })
    }
    return out.length > 0 ? out : null
  } catch (e) {
    console.warn('[maps] Mapbox excepción:', e instanceof Error ? e.message : e)
    return null
  }
}

async function fromPhoton(q: string, lat?: string, lng?: string, baseUrl = PHOTON_URL): Promise<Prediction[]> {
  // Photon SOLO acepta lang en/de/fr/it — con `lang=es` responde HTTP 400 y
  // el proveedor entero quedaba descartado en silencio. Se omite el
  // parámetro: los nombres propios de calles y lugares vienen igual en
  // español desde OSM, el idioma solo afecta a etiquetas genéricas.
  const params = new URLSearchParams({ q, limit: '8' })
  // Photon usa lat/lon solo para PRIORIZAR cercanía, nunca para excluir.
  if (lat && lng) {
    params.set('lat', lat)
    params.set('lon', lng)
  }
  const r = await fetch(`${baseUrl}?${params.toString()}`, {
    headers: { 'User-Agent': 'RapiTeam/1.0 (contact: facturacion.rapiteam@gmail.com)' },
    signal: AbortSignal.timeout(6000),
  })
  if (!r.ok) throw new Error(`photon_http_${r.status}`)
  const data = await r.json() as {
    features?: Array<{
      geometry?: { coordinates?: [number, number] }
      properties?: Record<string, string | number>
    }>
  }

  const userNumber = extractHouseNumber(q)
  const out: Prediction[] = []

  for (const f of data.features ?? []) {
    const coords = f.geometry?.coordinates
    if (!coords || coords.length < 2) continue
    const [lon, la] = coords
    const p = f.properties ?? {}

    // Ronda 260: BUG CRÍTICO introducido en la ronda 258. El filtro era
    // `if (country && country !== 'PE') continue` — solo descartaba cuando
    // Photon DEVOLVÍA countrycode. Cuando no lo devolvía (bastante común), el
    // resultado pasaba sin control; y como Photon es de komoot (alemán) su
    // índice prioriza Europa: al buscar "Jirón Las Coralinas 870" devolvía un
    // punto en AUSTRIA (lat 46.78, lng 15.57). Se guardó así en producción en
    // tres viajes reales: el mapa salía completamente azul (el punto medio
    // entre Perú y Austria cae en el Atlántico) y la distancia quedaba nula.
    //
    // Ahora se valida la COORDENADA contra el recuadro de Perú, que no depende
    // de que el proveedor etiquete bien el país.
    const country = String(p.countrycode ?? '')
    if (country && country.toUpperCase() !== 'PE') continue
    if (la < -19 || la > 0.5 || lon < -82 || lon > -68) continue

    const street = p.street ? String(p.street) : ''
    const houseNumber = p.housenumber ? String(p.housenumber) : (userNumber ?? '')
    const district = p.district ? String(p.district) : ''
    const city = p.city ? String(p.city) : (p.county ? String(p.county) : '')
    const state = p.state ? String(p.state) : ''
    const name = p.name ? String(p.name) : ''

    // Ronda 268: la calle NO puede ganarle al nombre propio del sitio.
    //
    // Antes se calculaba `street = p.street ?? p.name`, así que en cuanto
    // OpenStreetMap sabía en qué calle está un lugar, el nombre desaparecía de
    // la lista y el pasajero veía la dirección postal de algo que había
    // buscado por su nombre:
    //   "jockey plaza" → "Javier Prado Este 4200"   (es su dirección, sí)
    //   "mega plaza"   → "Avenida Alfredo Mendiola"
    //   "larcomar"     → "Malecón de la Reserva 610"
    // El sitio correcto estaba ahí, con la coordenada correcta, pero sin el
    // nombre nadie lo reconoce y nadie lo toca.
    //
    // Ahora: si el resultado tiene nombre propio, ese es el texto principal y
    // la calle baja a la línea de contexto, donde ayuda a distinguir entre dos
    // sitios homónimos. Si no tiene nombre, es una dirección y se muestra como
    // tal, que es el caso para el que se escribió esto originalmente.
    const streetLine = houseNumber && street ? `${street} ${houseNumber}` : street
    const main = name || streetLine
    if (!main) continue

    const rest = [name ? streetLine : '', district, city, state].filter((x) => x && x !== main)
    // Quitar repetidos consecutivos ("Miraflores, Miraflores, Lima").
    const secondary = rest.filter((x, i) => i === 0 || x !== rest[i - 1]).join(', ')

    out.push({
      placeId: p.osm_id != null ? `osm:${p.osm_id}` : null,
      description: secondary ? `${main}, ${secondary}` : main,
      mainText: main,
      secondaryText: secondary,
      lat: Number(la),
      lng: Number(lon),
    })
  }
  // OSM repite entradas del mismo sitio ("Casa de la Moneda" salía dos veces
  // para "Avenida Arequipa 4545"), y cada repetición come un hueco de la lista.
  return dedupePredictions(out)
}

// Sin lat/lng a propósito: desde que se eliminó el viewbox (nota de abajo)
// Nominatim ya no recibe sesgo geográfico, y mantener los parámetros en la
// firma solo dejaba dos argumentos muertos que el compilador marcaba.
async function fromNominatim(q: string): Promise<Prediction[]> {
  const params = new URLSearchParams({
    q,
    format: 'json',
    countrycodes: 'pe',
    'accept-language': 'es',
    limit: '8',
    addressdetails: '1',
  })
  // Ronda 258: se ELIMINÓ el viewbox por completo.
  //
  // Historia: primero iba con `bounded=1`, que DESCARTABA todo lo que cayera
  // fuera de ±0.3° del origen — así un pasajero en Puente Piedra buscando
  // "Parque Kennedy" (Miraflores) no lo encontraba y recibía otro sitio.
  // Después se amplió a ±1.0° sin bounded, pero eso trajo un problema nuevo:
  // el viewbox SESGA el ranking hacia el centro de la caja (el origen), así
  // que al buscar "Jirón Las Coralinas 870" desde Puente Piedra promovía
  // calles homónimas del OESTE (Callao, lon -77.08) por encima de la real de
  // San Juan de Lurigancho (lon -77.01). El usuario veía DOS opciones con el
  // texto idéntico "…, San Juan de Lurigancho" y coordenadas opuestas.
  //
  // Comprobado consultando Nominatim directamente: SIN viewbox devuelve solo
  // los resultados correctos en SJL. Su orden por `importance` ya es bueno y
  // `countrycodes=pe` acota lo suficiente. El sesgo geográfico hacía más daño
  // que bien en una ciudad con calles de nombre repetido entre distritos.

  const r = await fetch(`${NOMINATIM_URL}?${params.toString()}`, {
    headers: { 'User-Agent': 'RapiTeam/1.0 (contact: facturacion.rapiteam@gmail.com)' },
    signal: AbortSignal.timeout(6000),
  })
  const data = await r.json() as Array<{
    place_id?: number | string; display_name?: string
    address?: Record<string, string>; lat?: string; lon?: string
  }>

  // Extraer número del query del usuario para restaurarlo si Nominatim lo descarta.
  const userNumber = extractHouseNumber(q)

  return data.map((p) => {
    const road = p.address?.road
    const houseNumber = p.address?.house_number ?? userNumber ?? null
    // mainText: "Avenida Javier Prado Oeste 1068" o solo la vía si no hay número.
    //
    // Ronda 219: cuando Nominatim devuelve un POI (parque, plaza, edificio),
    // NO viene road pero el NOMBRE del POI está como PRIMER segmento del
    // display_name. Antes el fallback iba directo a suburb → el user veía
    // "Miraflores" en vez de "Parque John F. Kennedy" al buscar "parque
    // kennedy". Ahora priorizamos ese primer segmento cuando no hay road.
    let main: string
    if (road && houseNumber) {
      main = `${road} ${houseNumber}`
    } else if (road) {
      main = road
    } else {
      const firstSegment = p.display_name?.split(',')[0]?.trim()
      main = firstSegment && firstSegment.length > 0
        ? firstSegment
        : (p.address?.suburb ?? p.address?.city ?? '')
    }
    // description: si el número no venía en display_name pero el usuario lo escribió, insertarlo.
    // Ronda 52 Bug#1: solo reemplazar en el primer segmento (antes de la
    // primera coma). Antes: "Los Pinos, Los Pinos Norte, Lima" reemplazaba
    // el 1er match que a veces era el distrito → dirección corrupta.
    let description = p.display_name ?? ''
    if (userNumber && road && !description.includes(userNumber)) {
      const parts = description.split(',')
      if (parts[0] && parts[0].includes(road)) {
        parts[0] = parts[0].replace(road, `${road} ${userNumber}`)
        description = parts.join(',')
      }
    }
    const secondary = description.split(',').slice(1).join(',').trim()
    return {
      placeId: p.place_id != null ? `osm:${p.place_id}` : null,
      description,
      mainText: main,
      secondaryText: secondary,
      lat: p.lat ? Number(p.lat) : undefined,
      lng: p.lon ? Number(p.lon) : undefined,
    }
  })
}

export async function GET(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  // Ronda 147 FINANZAS: Google Places cobra ~$2.83/request. Sin rate limit
  // un solo JWT haciendo 100 req/s × 1h = $1,000 USD quemados sin señal.
  // Doble bucket (IP + userId) protege contra spoofing y sharing de tokens.
  const ipRl = ipRateLimit(req, 'maps-autocomplete', { max: 60, windowMs: 60_000 })
  if (!ipRl.ok) {
    return NextResponse.json({ success: false, error: 'rate_limited' }, { status: 429 })
  }
  const userRl = keyedRateLimit(`maps-autocomplete:${auth.userId}`, { max: 200, windowMs: 60_000 })
  if (!userRl.ok) {
    return NextResponse.json({ success: false, error: 'rate_limited' }, { status: 429 })
  }

  const { searchParams } = new URL(req.url)
  const q = (searchParams.get('q') ?? '').trim()
  if (q.length < 2) return NextResponse.json({ success: true, predictions: [], provider: 'none' })

  const session = searchParams.get('session') ?? undefined
  const lat = searchParams.get('lat') ?? undefined
  const lng = searchParams.get('lng') ?? undefined

  const mapboxToken = process.env.MAPBOX_ACCESS_TOKEN
  // Una dirección con número la resuelve mejor Mapbox: interpola la numeración
  // a lo largo del tramo, que es justo lo que OpenStreetMap no tiene mapeado
  // en Lima (ver docblock de fromMapbox). Para todo lo demás —nombres de
  // sitios— manda nuestro Photon.
  const looksLikeNumberedAddress = extractHouseNumber(q) !== null

  // 1. Photon propio. Es nuestro servidor: no cuesta por búsqueda y da MEJOR
  // resultado que los datos comerciales para lo que la gente escribe — el
  // centro comercial, no las tiendas de dentro (ver PHOTON_SELF_URL).
  let selfPredictions: Prediction[] = []
  if (!looksLikeNumberedAddress) {
    try {
      selfPredictions = await fromPhoton(q, lat, lng, PHOTON_SELF_URL)
      // Con dos o más resultados propios, OSM cubre lo que se busca y no hace
      // falta gastar una petición facturable.
      if (selfPredictions.length > 1) {
        return NextResponse.json({ success: true, predictions: selfPredictions, provider: 'photon-self' })
      }
    } catch (err) {
      console.warn('[maps] Photon propio falló:', err instanceof Error ? err.message : err)
    }
  }

  // 2. Mapbox, para tapar el hueco que deja OpenStreetMap: locales concretos
  // dentro de una cadena ("Starbucks Larcomar", "Plaza Vea Higuereta") y la
  // numeración de las calles. El centro comercial está en OSM; el local de
  // dentro y el portal 870 no siempre.
  //
  // Se consulta solo cuando el propio devolvió 0 o 1 resultado —señal de que
  // OSM no lo cubre— y con 4 letras o más, porque el autocompletado dispara en
  // cada tecla y "me", "meg" son prefijos que todavía no significan nada.
  if (mapboxToken && q.length >= 4) {
    const cached = getCachedMapbox(q)
    const s = cached ?? await fromMapboxSearchBox(q, mapboxToken, lat, lng)
    if (s !== null && s.length > 0) {
      if (!cached) setCachedMapbox(q, s)
      // El resultado propio, cuando lo hay, va DELANTE: viene de OSM, que
      // nombra el sitio entero ("Real Plaza Salaverry") mientras Mapbox
      // devuelve los locales de dentro ("Skechers Real Plaza Salaverry").
      // Antes se sustituía en vez de anteponerse, y el centro comercial que el
      // pasajero buscaba desaparecía de la lista.
      const merged = mergePredictions(selfPredictions, s)
      return NextResponse.json({
        success: true,
        predictions: merged,
        provider: cached ? 'mapbox-searchbox-cache' : 'mapbox-searchbox',
      })
    }
    if (selfPredictions.length > 0) {
      return NextResponse.json({ success: true, predictions: selfPredictions, provider: 'photon-self' })
    }
    const m = await fromMapbox(q, mapboxToken, lat, lng)
    if (m !== null) {
      return NextResponse.json({ success: true, predictions: m, provider: 'mapbox' })
    }
  } else if (selfPredictions.length > 0) {
    return NextResponse.json({ success: true, predictions: selfPredictions, provider: 'photon-self' })
  }

  // Una dirección con número que Mapbox no resolvió: probar igualmente el
  // propio antes de seguir bajando en la cadena.
  if (looksLikeNumberedAddress) {
    try {
      const p = await fromPhoton(q, lat, lng, PHOTON_SELF_URL)
      if (p.length > 0) {
        return NextResponse.json({ success: true, predictions: p, provider: 'photon-self' })
      }
    } catch (err) {
      console.warn('[maps] Photon propio falló:', err instanceof Error ? err.message : err)
    }
  }

  // 3. Google, solo si hay key Y responde. Con la facturación desactivada
  // devuelve REQUEST_DENIED y el cortacircuitos lo aparta 5 minutos.
  const key = process.env.GOOGLE_MAPS_API_KEY
  if (key) {
    const g = await fromGoogle(q, key, session, lat, lng)
    if (g !== null && g.length > 0) {
      return NextResponse.json({ success: true, predictions: g, provider: 'google' })
    }
  }

  // 4. Photon público de komoot, por si nuestra instancia está caída.
  try {
    const predictions = await fromPhoton(q, lat, lng)
    if (predictions.length > 0) {
      return NextResponse.json({ success: true, predictions, provider: 'photon' })
    }
  } catch (err) {
    console.warn('[maps] Photon público falló, cayendo a Nominatim:',
      err instanceof Error ? err.message : err)
  }

  // 5. Último recurso: Nominatim.
  try {
    const predictions = await fromNominatim(q)
    return NextResponse.json({ success: true, predictions, provider: 'nominatim' })
  } catch (err) {
    console.error('[maps/autocomplete] Nominatim failed:', err)
    return NextResponse.json({ success: false, error: 'places_unavailable' }, { status: 502 })
  }
}
