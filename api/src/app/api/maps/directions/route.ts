/**
 * GET /api/maps/directions?originLat=&originLng=&destLat=&destLng=&mode=driving
 * Auth: Bearer <access_token>
 *
 * Estrategia dual con fallback:
 *   1. Google Directions si GOOGLE_MAPS_API_KEY funciona
 *   2. OSRM público (router.project-osrm.org) — routing gratis basado en OSM
 *
 * OSRM devuelve la polyline como geometría GeoJSON — la convertimos a
 * encoded polyline compatible con Google Maps SDK del cliente.
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'

export const runtime = 'nodejs'

const DIRECTIONS_URL = 'https://maps.googleapis.com/maps/api/directions/json'
const OSRM_URL = 'https://router.project-osrm.org/route/v1'

/** Encoding de polyline compatible con Google (algoritmo estándar). */
function encodePolyline(coords: Array<[number, number]>): string {
  let output = ''
  let prevLat = 0, prevLng = 0
  for (const [lat, lng] of coords) {
    const dLat = Math.round(lat * 1e5) - prevLat
    const dLng = Math.round(lng * 1e5) - prevLng
    prevLat = Math.round(lat * 1e5)
    prevLng = Math.round(lng * 1e5)
    output += encodeSignedNumber(dLat) + encodeSignedNumber(dLng)
  }
  return output
}
function encodeSignedNumber(n: number): string {
  let s = n < 0 ? ~(n << 1) : (n << 1)
  let out = ''
  while (s >= 0x20) {
    out += String.fromCharCode((0x20 | (s & 0x1f)) + 63)
    s >>= 5
  }
  out += String.fromCharCode(s + 63)
  return out
}

async function fromGoogle(
  originLat: string, originLng: string, destLat: string, destLng: string,
  mode: string, key: string,
) {
  const params = new URLSearchParams({
    origin: `${originLat},${originLng}`,
    destination: `${destLat},${destLng}`,
    mode, key, language: 'es', units: 'metric', region: 'pe',
  })
  try {
    const r = await fetch(`${DIRECTIONS_URL}?${params.toString()}`, { signal: AbortSignal.timeout(8000) })
    const data = await r.json()
    if (data.status !== 'OK') return null
    const route = data.routes?.[0]
    const leg = route?.legs?.[0]
    if (!leg) return null
    return {
      provider: 'google',
      distanceMeters: leg.distance?.value as number,
      distanceText: leg.distance?.text as string,
      durationSeconds: leg.duration?.value as number,
      durationText: leg.duration?.text as string,
      polyline: route.overview_polyline?.points as string,
      bounds: route.bounds,
      startAddress: leg.start_address as string,
      endAddress: leg.end_address as string,
    }
  } catch (e) {
    console.warn('[maps/directions] Google:', e instanceof Error ? e.message : e)
    return null
  }
}

async function fromOsrm(originLat: string, originLng: string, destLat: string, destLng: string, mode: string) {
  const profile = mode === 'walking' ? 'foot' : mode === 'bicycling' ? 'bike' : 'driving'
  const url = `${OSRM_URL}/${profile}/${originLng},${originLat};${destLng},${destLat}?overview=full&geometries=geojson`
  const r = await fetch(url, { signal: AbortSignal.timeout(8000) })
  const data = await r.json() as {
    code?: string
    routes?: Array<{
      distance: number; duration: number
      geometry: { coordinates: [number, number][] }
    }>
  }
  if (data.code !== 'Ok' || !data.routes?.length) return null
  const route = data.routes[0]
  // GeoJSON viene [lng,lat]; encoding necesita [lat,lng]
  const coords: Array<[number, number]> = route.geometry.coordinates.map(([lng, lat]) => [lat, lng])
  const polyline = encodePolyline(coords)
  const lats = coords.map(c => c[0])
  const lngs = coords.map(c => c[1])
  return {
    provider: 'osrm',
    distanceMeters: Math.round(route.distance),
    distanceText: `${(route.distance / 1000).toFixed(1)} km`,
    durationSeconds: Math.round(route.duration),
    durationText: `${Math.round(route.duration / 60)} min`,
    polyline,
    bounds: {
      northeast: { lat: Math.max(...lats), lng: Math.max(...lngs) },
      southwest: { lat: Math.min(...lats), lng: Math.min(...lngs) },
    },
    startAddress: null,
    endAddress: null,
  }
}

export async function GET(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  const { searchParams } = new URL(req.url)
  const originLat = searchParams.get('originLat')
  const originLng = searchParams.get('originLng')
  const destLat = searchParams.get('destLat')
  const destLng = searchParams.get('destLng')
  const mode = searchParams.get('mode') ?? 'driving'
  if (!originLat || !originLng || !destLat || !destLng) {
    return NextResponse.json({ success: false, error: 'missing_coords' }, { status: 400 })
  }

  const key = process.env.GOOGLE_MAPS_API_KEY
  if (key) {
    const g = await fromGoogle(originLat, originLng, destLat, destLng, mode, key)
    if (g) return NextResponse.json({ success: true, ...g })
  }
  try {
    const o = await fromOsrm(originLat, originLng, destLat, destLng, mode)
    if (!o) return NextResponse.json({ success: false, error: 'no_route' }, { status: 404 })
    return NextResponse.json({ success: true, ...o })
  } catch (err) {
    console.error('[maps/directions] OSRM failed:', err)
    return NextResponse.json({ success: false, error: 'directions_unavailable' }, { status: 502 })
  }
}
