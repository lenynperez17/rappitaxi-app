import { NextRequest, NextResponse } from 'next/server'

/**
 * Middleware Next.js — inyecta headers CORS.
 * Permite orígenes del admin panel (localhost dev + panel-rapi-team.nyneln8n.com).
 */
const ALLOWED_ORIGINS = new Set([
  'http://localhost:5173',
  'http://localhost:5174',
  'http://localhost:4173',
  'https://panel-rapi-team.nynelmkt.com',
  'https://panel-rapi-team.nyneln8n.com',
  'https://admin.rapiteam.com',
])

// Ronda 62 Bug#1: solo emitir headers CORS si el origin está en whitelist.
// Antes: origen no permitido → ACAO='' + ACAC='true' (combinación inválida por
// spec; proxies/CDNs strip o rechazan). Además el preflight 204 hacia disallowed
// origins escondía el misconfig — mejor no emitir CORS y dejar al browser
// bloquearlo con un error explícito.
function corsHeaders(origin: string | null): Record<string, string> | null {
  if (!origin || !ALLOWED_ORIGINS.has(origin)) return null
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'GET,POST,PUT,PATCH,DELETE,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Access-Control-Allow-Credentials': 'true',
    'Access-Control-Max-Age': '86400',
    Vary: 'Origin',
  }
}

export function middleware(req: NextRequest) {
  const origin = req.headers.get('origin')
  const cors = corsHeaders(origin)

  // Preflight
  if (req.method === 'OPTIONS') {
    // Si origen no permitido → 403 explícito en vez de 204 con headers vacíos.
    // Requests same-origin no envían header Origin → dejamos pasar con 204 vacío.
    if (!origin) return new NextResponse(null, { status: 204 })
    if (!cors) return new NextResponse(null, { status: 403 })
    return new NextResponse(null, { status: 204, headers: cors })
  }

  const res = NextResponse.next()
  if (cors) {
    for (const [k, v] of Object.entries(cors)) {
      res.headers.set(k, v)
    }
  }
  return res
}

export const config = {
  matcher: '/api/:path*',
}
