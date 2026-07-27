/**
 * GET/PATCH /api/admin/settings — configuración global (tabla app_settings).
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAdmin } from '@/lib/admin-middleware'
import { query, tx } from '@/lib/db'

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
  // Ronda 214 SECURITY: whitelist de keys admisibles. Antes admin (o cuenta
  // comprometida) podía setear cualquier key — desde commission_rate:0
  // hasta insertar 10.000 keys basura para degradar performance de la tabla
  // sin auditoría estructurada. Cada key acá debe corresponder a un setting
  // realmente usado por el runtime; añadir explícitamente al agregar features.
  const ALLOWED_SETTING_KEYS = new Set([
    // Ronda 263: `rides.commission_percent` es el ajuste que el panel MUESTRA
    // (es el que tiene descripción legible), pero NO estaba en esta lista
    // blanca: el administrador lo editaba, pulsaba Guardar y el servidor lo
    // descartaba en silencio. Además el código de comisión leía el otro
    // (`commission_rate`), así que había dos valores distintos y ninguno
    // hacía lo que el panel daba a entender. Ahora `commission_percent` es la
    // fuente única y sí se puede guardar.
    'rides.commission_percent',
    'rides.commission_rate',
    'rides.surge_cap',
    'rides.max_search_radius_km',
    'rides.min_price',
    'rides.max_price',
    'rides.cancel_fee',
    'wallet.min_recharge',
    'wallet.max_recharge',
    'wallet.min_withdrawal',
    'wallet.max_withdrawal',
    'wallet.withdrawal_fee',
    'sunat.igv_rate',
    'sunat.default_series_invoice',
    'sunat.default_series_boleta',
    'sunat.emitter_ruc',
    'sunat.emitter_business_name',
    'notifications.push_enabled',
    'notifications.sms_enabled',
    'notifications.email_enabled',
    'emergency.contact_notification_enabled',
    'emergency.admin_notification_enabled',
    'maps.provider_cascade',
    'maps.cache_ttl_hours',
    'app.min_supported_version_ios',
    'app.min_supported_version_android',
    'app.maintenance_mode',
    'app.maintenance_message',
  ])
  const invalidKeys = entries
    .map(([k]) => k)
    .filter((k) => !ALLOWED_SETTING_KEYS.has(k))
  if (invalidKeys.length > 0) {
    return NextResponse.json(
      {
        success: false,
        error: 'unknown_setting_keys',
        message: `Keys no permitidas: ${invalidKeys.join(', ')}. Agrégala a la whitelist si es intencional.`,
        invalidKeys,
      },
      { status: 400 },
    )
  }
  // Ronda 31 Bug#2: multi-key upsert atómico. Antes cada key corría con
  // su propio await query() → si la conexión caía a la mitad, dejaba
  // config en estado inconsistente (ej. commission_rate updated pero
  // surge_cap no). Con tx() → all-or-nothing.
  try {
    await tx(async (client) => {
      for (const [key, value] of entries) {
        await client.query(
          `INSERT INTO app_settings (key, value, updated_by, updated_at)
           VALUES ($1, $2::jsonb, $3, now())
           ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_by = EXCLUDED.updated_by, updated_at = now()`,
          [key, JSON.stringify(value), auth.userId],
        )
      }
    })
  } catch (err) {
    console.error('[admin/settings PATCH] error:', err)
    return NextResponse.json({ success: false, error: 'update_failed' }, { status: 500 })
  }
  return NextResponse.json({ success: true, updated: entries.length })
}
