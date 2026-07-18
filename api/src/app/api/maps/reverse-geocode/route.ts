/**
 * GET /api/maps/reverse-geocode?lat=X&lng=Y
 *
 * Convierte lat/lng en una dirección legible (address string). Ronda 216:
 * el cliente Flutter necesita este endpoint para mostrar "Av. José Larco 350"
 * en vez de "Punto seleccionado (-12.12, -77.03)" cuando el user mueve el
 * marcador del mapa.
 *
 * Estrategia: Nominatim (OSM) — gratis, sin key, cubre Perú urbano bien.
 * Requires User-Agent identificando la app (política Nominatim).
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { ipRateLimit } from '@/lib/rate-limit'

export const runtime = 'nodejs'
export const dynamic = 'force-dynamic'

const NOMINATIM_URL = 'https://nominatim.openstreetmap.org/reverse'

export async function GET(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response

  // Rate limit por IP: 60/min es amplio (usuario mueve el marker con
  // debounce en cliente, típicamente <10/min por sesión).
  const rl = ipRateLimit(req, 'maps-reverse', { max: 60, windowMs: 60_000 })
  if (!rl.ok) {
    return NextResponse.json(
      { success: false, error: 'rate_limited' },
      { status: 429 },
    )
  }

  const { searchParams } = new URL(req.url)
  const latStr = searchParams.get('lat')
  const lngStr = searchParams.get('lng')
  const lat = Number(latStr)
  const lng = Number(lngStr)

  if (!isFinite(lat) || !isFinite(lng) || Math.abs(lat) > 90 || Math.abs(lng) > 180) {
    return NextResponse.json(
      { success: false, error: 'invalid_coordinates' },
      { status: 400 },
    )
  }

  try {
    const params = new URLSearchParams({
      lat: lat.toString(),
      lon: lng.toString(),
      format: 'json',
      addressdetails: '1',
      'accept-language': 'es',
      zoom: '18', // detail level: 18 = house/building
    })

    const r = await fetch(`${NOMINATIM_URL}?${params.toString()}`, {
      headers: { 'User-Agent': 'RapiTeamApp/1.0 (support@rapiteam.local)' },
      signal: AbortSignal.timeout(6000),
    })

    if (!r.ok) {
      // Nominatim caído — devolver coordenadas como fallback amigable
      console.warn('[maps/reverse-geocode] Nominatim HTTP', r.status)
      return NextResponse.json({
        success: true,
        provider: 'fallback',
        address: `${lat.toFixed(5)}, ${lng.toFixed(5)}`,
        lat, lng,
      })
    }

    const data = await r.json() as {
      display_name?: string
      address?: {
        house_number?: string
        road?: string
        neighbourhood?: string
        suburb?: string
        city?: string
        town?: string
        village?: string
        state?: string
        country?: string
      }
    }

    // Construir un address legible priorizando datos peruanos:
    //   "Av. José Larco 350, Miraflores, Lima"
    // en vez del display_name completo que suele ser muy largo.
    const addr = data.address ?? {}
    const road = addr.road ?? ''
    const number = addr.house_number ?? ''
    const district = addr.suburb ?? addr.neighbourhood ?? ''
    const city = addr.city ?? addr.town ?? addr.village ?? ''

    let compact = ''
    if (road) {
      compact = number ? `${road} ${number}` : road
      if (district && district !== road) compact += `, ${district}`
      if (city && city !== district) compact += `, ${city}`
    } else {
      // Sin road identificable, usar display_name (recortado)
      compact = (data.display_name ?? '').split(',').slice(0, 3).join(', ').trim()
    }

    if (!compact) compact = `${lat.toFixed(5)}, ${lng.toFixed(5)}`

    return NextResponse.json({
      success: true,
      provider: 'nominatim',
      address: compact,
      fullAddress: data.display_name ?? compact,
      lat, lng,
    })
  } catch (e) {
    console.warn('[maps/reverse-geocode] error:', e instanceof Error ? e.message : e)
    return NextResponse.json({
      success: true,
      provider: 'fallback',
      address: `${lat.toFixed(5)}, ${lng.toFixed(5)}`,
      lat, lng,
    })
  }
}
