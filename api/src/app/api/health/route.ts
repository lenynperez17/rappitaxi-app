/**
 * GET /api/health
 * Verifica que el servidor + Postgres estén OK.
 */
import { NextResponse } from 'next/server'
import { healthCheck as pgHealth } from '@/lib/db'

export const runtime = 'nodejs'
export const dynamic = 'force-dynamic'

export async function GET() {
  const db = await pgHealth()
  // /health es público. NO exponer info interna (version, git hash, dep
  // versions) que ayude a un atacante a enumerar vulnerabilidades conocidas.
  // Solo `ok` y `service` bastan para monitores externos + LB.
  return NextResponse.json({
    ok: db.ok,
    service: 'rapi-team-api',
  })
}
