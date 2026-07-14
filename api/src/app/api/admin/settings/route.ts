/**
 * GET/PATCH /api/admin/settings — configuración global (tabla app_settings).
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAdmin } from '@/lib/admin-middleware'
import { query } from '@/lib/db'

export const runtime = 'nodejs'
export const dynamic = 'force-dynamic'

interface SettingRow {
  key: string
  value: unknown
  description: string | null
  updated_at: Date
}

export async function GET(req: NextRequest) {
  const auth = await requireAdmin(req)
  if (!auth.ok) return auth.response
  const rows = await query<SettingRow>(
    `SELECT key, value, description, updated_at FROM app_settings ORDER BY key`,
  )
  return NextResponse.json({
    success: true,
    settings: rows.map((r) => ({
      key: r.key, value: r.value, description: r.description, updatedAt: r.updated_at,
    })),
  })
}

export async function PATCH(req: NextRequest) {
  const auth = await requireAdmin(req)
  if (!auth.ok) return auth.response
  let body: { updates?: Record<string, unknown> } = {}
  try { body = await req.json() } catch {
    return NextResponse.json({ success: false, error: 'bad_json' }, { status: 400 })
  }
  const updates = body.updates ?? {}
  const entries = Object.entries(updates)
  if (entries.length === 0) {
    return NextResponse.json({ success: false, error: 'no_updates' }, { status: 400 })
  }
  for (const [key, value] of entries) {
    await query(
      `INSERT INTO app_settings (key, value, updated_by, updated_at)
       VALUES ($1, $2::jsonb, $3, now())
       ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_by = EXCLUDED.updated_by, updated_at = now()`,
      [key, JSON.stringify(value), auth.userId],
    )
  }
  return NextResponse.json({ success: true, updated: entries.length })
}
