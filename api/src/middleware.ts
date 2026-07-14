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

function corsHeaders(origin: string | null): Record<string, string> {
  const allow = origin && ALLOWED_ORIGINS.has(origin) ? origin : ''
  return {
    'Access-Control-Allow-Origin': allow,
    'Access-Control-Allow-Methods': 'GET,POST,PUT,PATCH,DELETE,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Access-Control-Allow-Credentials': 'true',
    'Access-Control-Max-Age': '86400',
    Vary: 'Origin',
  }
}

export function middleware(req: NextRequest) {
  const origin = req.headers.get('origin')

  // Preflight
  if (req.method === 'OPTIONS') {
    return new NextResponse(null, { status: 204, headers: corsHeaders(origin) })
  }

  const res = NextResponse.next()
  const h = corsHeaders(origin)
  for (const [k, v] of Object.entries(h)) {
    if (v) res.headers.set(k, v)
  }
  return res
}

export const config = {
  matcher: '/api/:path*',
}
