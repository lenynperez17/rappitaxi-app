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
const PHOTON_URL = 'https://photon.komoot.io/api/'

interface Prediction {
  placeId: string | null
  description: string
  mainText: string
  secondaryText?: string
  lat?: number
  lng?: number
}

async function fromGoogle(q: string, key: string, session?: string, lat?: string, lng?: string): Promise<Prediction[] | null> {
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
      console.warn('[maps] Google status=', data.status, '—cayendo a Nominatim')
      return null
    }
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
    console.warn('[maps] Google exception:', e instanceof Error ? e.message : e)
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
async function fromPhoton(q: string, lat?: string, lng?: string): Promise<Prediction[]> {
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
  const r = await fetch(`${PHOTON_URL}?${params.toString()}`, {
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
    const country = String(p.countrycode ?? '')
    // Restringimos a Perú (Photon no tiene filtro de país en la query).
    if (country && country.toUpperCase() !== 'PE') continue

    const street = p.street ? String(p.street) : (p.name ? String(p.name) : '')
    const houseNumber = p.housenumber ? String(p.housenumber) : (userNumber ?? '')
    const district = p.district ? String(p.district) : ''
    const city = p.city ? String(p.city) : (p.county ? String(p.county) : '')
    const state = p.state ? String(p.state) : ''

    const main = houseNumber && street ? `${street} ${houseNumber}` : (street || String(p.name ?? ''))
    if (!main) continue

    const rest = [district, city, state].filter((x) => x && x !== main)
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
  return out
}

async function fromNominatim(q: string, lat?: string, lng?: string): Promise<Prediction[]> {
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
  const key = process.env.GOOGLE_MAPS_API_KEY

  // 1. Intento Google si tenemos API key
  if (key) {
    const g = await fromGoogle(q, key, session, lat, lng)
    if (g !== null) {
      return NextResponse.json({ success: true, predictions: g, provider: 'google' })
    }
  }

  // 2. Photon: geocodificador gratuito con mucha mejor precisión que la
  // búsqueda de texto libre de Nominatim (ver docblock de fromPhoton).
  try {
    const predictions = await fromPhoton(q, lat, lng)
    if (predictions.length > 0) {
      return NextResponse.json({ success: true, predictions, provider: 'photon' })
    }
  } catch (err) {
    console.warn('[maps] Photon falló, cayendo a Nominatim:',
      err instanceof Error ? err.message : err)
  }

  // 3. Último recurso: Nominatim.
  try {
    const predictions = await fromNominatim(q, lat, lng)
    return NextResponse.json({ success: true, predictions, provider: 'nominatim' })
  } catch (err) {
    console.error('[maps/autocomplete] Nominatim failed:', err)
    return NextResponse.json({ success: false, error: 'places_unavailable' }, { status: 502 })
  }
}
