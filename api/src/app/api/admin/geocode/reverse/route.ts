/**
 * GET /api/admin/geocode/reverse?lat=&lng=
 * Proxy a Nominatim para obtener la dirección de un punto (click en el mapa).
 * Sólo admin.
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAdmin } from '@/lib/admin-middleware'
import { ipRateLimit } from '@/lib/rate-limit'

export const runtime = 'nodejs'

interface NominatimResponse {
  display_name?: string
  address?: Record<string, string>
}

export async function GET(req: NextRequest) {
  // Auth PRIMERO — sin esto, attacker no-auth podía burnar 30 req/min por IP
  // y provocar 429 a admins legítimos en la misma IP corporativa.
  const auth = await requireAdmin(req)
  if (!auth.ok) return auth.response

  // Nominatim policy: ≤ 1 req/s por origen. Bucket 30 req/min por IP.
  const rl = ipRateLimit(req, 'geocode-reverse', { max: 30, windowMs: 60_000 })
  if (!rl.ok) {
    return NextResponse.json(
      { success: false, error: 'rate_limited', message: 'Demasiadas consultas al geocodificador.' },
      { status: 429 },
    )
  }

  const { searchParams } = new URL(req.url)
  const lat = Number(searchParams.get('lat'))
  const lng = Number(searchParams.get('lng'))
  if (!isFinite(lat) || !isFinite(lng)) {
    return NextResponse.json({ success: false, error: 'coords_invalid' }, { status: 400 })
  }

  try {
    const r = await fetch(
      `https://nominatim.openstreetmap.org/reverse?format=json&lat=${lat}&lon=${lng}&addressdetails=1&accept-language=es`,
      {
        headers: { 'User-Agent': 'RapiTeamAdmin/1.0 (contact: facturacion.rapiteam@gmail.com)' },
        signal: AbortSignal.timeout(6000),
      },
    )
    // Ronda 63: verificar r.ok antes de r.json(). Nominatim puede devolver
    // 403/429/503 con body HTML → SyntaxError. Además si retorna JSON de error
    // con status parseable, evitar responder success con fallback "lat,lng"
    // engañando al admin.
    if (!r.ok) {
      return NextResponse.json(
        { success: false, error: 'upstream_error', status: r.status },
        { status: 502 },
      )
    }
    const data = (await r.json()) as NominatimResponse & { error?: string }
    if (data.error || (!data.address && !data.display_name)) {
      return NextResponse.json(
        { success: false, error: 'no_address_found', message: data.error ?? 'sin resultados' },
        { status: 404 },
      )
    }
    const road = data.address?.road
    const houseNumber = data.address?.house_number
    const suburb = data.address?.suburb ?? data.address?.neighbourhood
    const city = data.address?.city ?? data.address?.state
    const parts = [road && houseNumber ? `${road} ${houseNumber}` : road, suburb, city].filter(Boolean)
    const address = parts.length > 0 ? parts.join(', ') : data.display_name ?? `${lat},${lng}`

    return NextResponse.json({
      success: true,
      address,
      displayName: data.display_name ?? null,
      raw: data.address ?? null,
    })
  } catch (err) {
    return NextResponse.json(
      { success: false, error: 'reverse_failed', message: err instanceof Error ? err.message : 'error' },
      { status: 502 },
    )
  }
}
