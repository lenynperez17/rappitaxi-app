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

async function fromNominatim(q: string, lat?: string, lng?: string): Promise<Prediction[]> {
  const params = new URLSearchParams({
    q,
    format: 'json',
    countrycodes: 'pe',
    'accept-language': 'es',
    limit: '8',
    addressdetails: '1',
  })
  if (lat && lng) {
    // Viewbox solo si el pickup está en Perú (aprox lat -18 a 0, lng -82 a -68).
    // Fuera de Perú (ej. Simulator en SF), usamos country=pe sin viewbox.
    const latN = Number(lat), lngN = Number(lng)
    const inPeru = latN >= -19 && latN <= 0 && lngN >= -82 && lngN <= -68
    if (inPeru) {
      params.set('viewbox', `${lngN - 0.3},${latN + 0.3},${lngN + 0.3},${latN - 0.3}`)
      params.set('bounded', '1')
    }
  }
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
    let main: string
    if (road && houseNumber) {
      main = `${road} ${houseNumber}`
    } else {
      main = road ?? p.address?.suburb ?? p.address?.city ?? p.display_name?.split(',')[0] ?? ''
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

  // 2. Fallback Nominatim (gratis, sin billing)
  try {
    const predictions = await fromNominatim(q, lat, lng)
    return NextResponse.json({ success: true, predictions, provider: 'nominatim' })
  } catch (err) {
    console.error('[maps/autocomplete] Nominatim failed:', err)
    return NextResponse.json({ success: false, error: 'places_unavailable' }, { status: 502 })
  }
}
