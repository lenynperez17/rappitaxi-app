/**
 * GET /api/maps/place-details?placeId=X
 * Obtiene coordenadas + dirección formateada de un place_id devuelto por autocomplete.
 * Backend en cascada: Nominatim (OSM) por defecto, fallback a Mapbox/Google si configurados.
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'

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

  const placeId = req.nextUrl.searchParams.get('placeId')?.trim()
  if (!placeId) {
    return NextResponse.json({ success: false, error: 'missing_placeId' }, { status: 400 })
  }

  // Nominatim: los placeId de nuestro autocomplete son osm_id o place_id de OSM
  // El detalle se obtiene con /lookup?osm_ids=... o con /details?place_id=...
  try {
    let details: OsmDetails | null = null

    // Intento 1: /details (más rico, requiere osm_type prefijo)
    // placeIds del autocomplete vienen como "N123", "W456", "R789" u osmId numérico
    let osmIds = ''
    if (/^[NWR]\d+$/i.test(placeId)) {
      osmIds = placeId
    } else if (/^\d+$/.test(placeId)) {
      osmIds = `N${placeId}`
    }

    if (osmIds) {
      const r = await fetch(
        `https://nominatim.openstreetmap.org/lookup?osm_ids=${encodeURIComponent(osmIds)}&format=json&addressdetails=1&accept-language=es`,
        { headers: { 'User-Agent': 'RapiTeamApp/1.0 (support@rapiteam.local)' } },
      )
      if (r.ok) {
        const arr = (await r.json()) as OsmDetails[]
        details = arr[0] ?? null
      }
    }

    // Fallback: /search con el placeId como query si nada funcionó
    if (!details) {
      const r = await fetch(
        `https://nominatim.openstreetmap.org/search?q=${encodeURIComponent(placeId)}&format=json&limit=1&addressdetails=1&accept-language=es`,
        { headers: { 'User-Agent': 'RapiTeamApp/1.0 (support@rapiteam.local)' } },
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
