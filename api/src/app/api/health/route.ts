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
  return NextResponse.json({
    ok: db.ok,
    service: 'rapi-team-api',
    version: '0.1.0',
    time: new Date().toISOString(),
    db,
  })
}
