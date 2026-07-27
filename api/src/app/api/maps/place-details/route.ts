/**
 * GET /api/maps/place-details?placeId=X
 * Obtiene coordenadas + dirección formateada de un place_id devuelto por autocomplete.
 * Backend en cascada: Nominatim (OSM) por defecto, fallback a Mapbox/Google si configurados.
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { ipRateLimit, keyedRateLimit } from '@/lib/rate-limit'

export const runtime = 'nodejs'
export const dynamic = 'force-dynamic'

interface OsmDetails {
  lat?: string
  lon?: string
  display_name?: string
  address?: Record<string, string>
  osm_id?: number | string
  osm_type?: string
  place_id?: number | string
}

export async function GET(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  // Ronda 147 FINANZAS: Place Details ~$17/1000 requests. Rate limit para
  // que attacker con JWT no queme quota Google Maps.
  const ipRl = ipRateLimit(req, 'maps-place-details', { max: 40, windowMs: 60_000 })
  if (!ipRl.ok) {
    return NextResponse.json({ success: false, error: 'rate_limited' }, { status: 429 })
  }
  const userRl = keyedRateLimit(`maps-place-details:${auth.userId}`, { max: 120, windowMs: 60_000 })
  if (!userRl.ok) {
    return NextResponse.json({ success: false, error: 'rate_limited' }, { status: 429 })
  }

  const placeId = req.nextUrl.searchParams.get('placeId')?.trim()
  if (!placeId) {
    return NextResponse.json({ success: false, error: 'missing_placeId' }, { status: 400 })
  }

  // Nominatim: autocomplete emite placeIds como "osm:<place_id>" (prefijo),
  // pero pueden llegar también "N123"/"W456"/"R789" (osm_id explícito) o
  // numéricos plain. Ronda 53 Bug#2: para numéricos plain usar /details
  // (place_id) NO /lookup (que requiere osm_id != place_id).
  // Ronda 262: los identificadores de Mapbox ('address.8248033810671360',
  // 'poi.123…') NO son de OSM y este endpoint no sabía resolverlos: caía por
  // todas las ramas y devolvía error. Como la app usaba esta vía cuando le
  // faltaba la coordenada, el destino se quedaba sin resolver y no se marcaba
  // la ruta. El cliente ya no necesita esta llamada (usa lat/lng de la propia
  // predicción), pero se resuelve igualmente por si alguna pantalla la usa.
  if (/^(address|poi|place|neighborhood|locality|district|region|country)\./i.test(placeId)) {
    const token = process.env.MAPBOX_ACCESS_TOKEN
    if (token) {
      try {
        const r = await fetch(
          `https://api.mapbox.com/geocoding/v5/mapbox.places/${encodeURIComponent(placeId)}.json` +
            `?access_token=${token}&country=pe&limit=1`,
          { signal: AbortSignal.timeout(6000) },
        )
        if (r.ok) {
          const d = await r.json() as {
            features?: Array<{ center?: [number, number]; place_name?: string; text?: string }>
          }
          const f = d.features?.[0]
          if (f?.center && f.center.length >= 2) {
            const [lon, la] = f.center
            return NextResponse.json({
              success: true,
              placeId,
              name: f.text ?? f.place_name ?? '',
              formattedAddress: f.place_name ?? '',
              lat: la,
              lng: lon,
            })
          }
        }
      } catch {
        // cae a la resolución OSM de abajo
      }
    }
  }

  try {
    let details: OsmDetails | null = null

    // Strip prefijo "osm:" del autocomplete
    const rawId = placeId.startsWith('osm:') ? placeId.slice(4) : placeId

    // Ruta A: "N123"/"W456"/"R789" → lookup con osm_ids
    if (/^[NWR]\d+$/i.test(rawId)) {
      const r = await fetch(
        `https://nominatim.openstreetmap.org/lookup?osm_ids=${encodeURIComponent(rawId)}&format=json&addressdetails=1&accept-language=es`,
        {
          headers: { 'User-Agent': 'RapiTeamApp/1.0 (support@rapiteam.local)' },
          // Ronda 214: sin timeout, Nominatim lento colgaba workers Next.js
          // minutos y agotaba el pool. Los otros endpoints (MP, autocomplete)
          // ya usan AbortSignal.timeout; este era la excepción.
          signal: AbortSignal.timeout(6_000),
        },
      )
      if (r.ok) {
        const arr = (await r.json()) as OsmDetails[]
        details = arr[0] ?? null
      }
    }

    // Ruta B: place_id numérico → /details endpoint (más confiable)
    if (!details && /^\d+$/.test(rawId)) {
      const r = await fetch(
        `https://nominatim.openstreetmap.org/details?place_id=${encodeURIComponent(rawId)}&format=json&addressdetails=1&accept-language=es`,
        {
          headers: { 'User-Agent': 'RapiTeamApp/1.0 (support@rapiteam.local)' },
          // Ronda 214: sin timeout, Nominatim lento colgaba workers Next.js
          // minutos y agotaba el pool. Los otros endpoints (MP, autocomplete)
          // ya usan AbortSignal.timeout; este era la excepción.
          signal: AbortSignal.timeout(6_000),
        },
      )
      if (r.ok) {
        const obj = (await r.json()) as {
          centroid?: { coordinates?: [number, number] }
          localname?: string
          address?: Record<string, string>
          osm_id?: number
        }
        if (obj?.centroid?.coordinates) {
          const [lonNum, latNum] = obj.centroid.coordinates
          details = {
            lat: String(latNum),
            lon: String(lonNum),
            display_name: obj.localname ?? '',
            address: obj.address ?? {},
            place_id: rawId,
          }
        }
      }
    }

    // Ruta C fallback: /search con placeId como query (raro pero por si acaso)
    if (!details) {
      const r = await fetch(
        `https://nominatim.openstreetmap.org/search?q=${encodeURIComponent(rawId)}&format=json&limit=1&addressdetails=1&accept-language=es`,
        {
          headers: { 'User-Agent': 'RapiTeamApp/1.0 (support@rapiteam.local)' },
          // Ronda 214: sin timeout, Nominatim lento colgaba workers Next.js
          // minutos y agotaba el pool. Los otros endpoints (MP, autocomplete)
          // ya usan AbortSignal.timeout; este era la excepción.
          signal: AbortSignal.timeout(6_000),
        },
      )
      if (r.ok) {
        const arr = (await r.json()) as OsmDetails[]
        details = arr[0] ?? null
      }
    }

    if (!details) {
      return NextResponse.json({ success: false, error: 'not_found' }, { status: 404 })
    }

    const lat = Number(details.lat)
    const lng = Number(details.lon)
    if (Number.isNaN(lat) || Number.isNaN(lng)) {
      return NextResponse.json({ success: false, error: 'no_coordinates' }, { status: 404 })
    }

    return NextResponse.json({
      success: true,
      placeId,
      name: details.display_name?.split(',')[0]?.trim() ?? '',
      formattedAddress: details.display_name ?? '',
      lat,
      lng,
      address: details.address ?? {},
    })
  } catch (e) {
    console.error('[maps/place-details]', e)
    return NextResponse.json({ success: false, error: 'internal_error' }, { status: 500 })
  }
}
