/**
 * GET /api/config/app — configuración que la app móvil necesita al arrancar.
 *
 * POR QUÉ EXISTE (ronda 279)
 * --------------------------
 * El panel de administración guardaba 14 ajustes en `app_settings` y la app no
 * leía NINGUNO. No es que estuvieran mal cableados: no existía el cable. El
 * modo mantenimiento, los interruptores de registro, la tarifa mínima y los
 * mínimos de billetera se editaban, se guardaban, y no cambiaban nada.
 * `modern_splash_screen.dart` incluso tenía escrito el hueco:
 *
 *     // TODO(node-migration): reemplazar con endpoint /api/settings/app-config
 *     const bool isMaintenanceMode = false;
 *
 * Éste es ese endpoint.
 *
 * PÚBLICO A PROPÓSITO
 * -------------------
 * Sin autenticación: la app lo consulta en el splash, ANTES de saber si hay
 * sesión —el modo mantenimiento tiene que poder bloquear también a quien no ha
 * entrado— y la pantalla de registro necesita saber si el alta está abierta.
 * Nada de lo que devuelve es privado: son parámetros comerciales y datos de la
 * empresa que ya aparecen en las boletas y en la ficha de las tiendas.
 *
 * TOLERANTE A FALLOS POR CONTRATO
 * -------------------------------
 * Cada valor se lee con un valor por defecto igual al comportamiento de hoy.
 * Si un ajuste falta en la tabla, o alguien guarda basura, el endpoint
 * responde con el valor por defecto en vez de romperse: un error aquí
 * bloquearía el arranque de la app para todo el mundo.
 */
import { NextResponse } from 'next/server'
import { query } from '@/lib/db'
import { getEnabledDocumentTypes } from '@/lib/document-types'

export const runtime = 'nodejs'
export const dynamic = 'force-dynamic'

interface SettingRow {
  key: string
  value: unknown
}

/** Lee un booleano tolerando `true`, `"true"` y `1`. */
function asBool(value: unknown, fallback: boolean): boolean {
  if (typeof value === 'boolean') return value
  if (typeof value === 'number') return value !== 0
  if (typeof value === 'string') {
    const v = value.trim().toLowerCase()
    if (v === 'true' || v === '1') return true
    if (v === 'false' || v === '0') return false
  }
  return fallback
}

/** Lee un número finito; descarta NaN, Infinity y negativos donde no aplican. */
function asNumber(value: unknown, fallback: number, { min }: { min?: number } = {}): number {
  const n = typeof value === 'number' ? value : Number(value)
  if (!Number.isFinite(n)) return fallback
  if (min !== undefined && n < min) return fallback
  return n
}

function asString(value: unknown, fallback: string): string {
  if (typeof value === 'string' && value.trim().length > 0) return value
  return fallback
}

export async function GET() {
  let rows: SettingRow[] = []
  try {
    rows = await query<SettingRow>(`SELECT key, value FROM app_settings`)
  } catch (err) {
    // La app arranca igual con los valores por defecto. Preferimos una app que
    // funciona con la configuración de fábrica a una app que no abre.
    console.error('[config/app] no se pudo leer app_settings:', err)
  }

  const s = new Map(rows.map((r) => [r.key, r.value]))

  // Los documentos que la app debe pedirle al conductor. Si la consulta falla
  // se devuelve lista vacía y la app usa su lista de siempre: mejor pedir de
  // más que quedarse sin poder registrar conductores.
  let documents: Awaited<ReturnType<typeof getEnabledDocumentTypes>> = []
  try {
    documents = await getEnabledDocumentTypes()
  } catch (err) {
    console.error('[config/app] no se pudo leer el catálogo de documentos:', err)
  }

  const config = {
    maintenanceMode: asBool(s.get('maintenance_mode'), false),
    registration: {
      driverEnabled: asBool(s.get('registration.driver_enabled'), true),
      passengerEnabled: asBool(s.get('registration.passenger_enabled'), true),
    },
    rides: {
      minFare: asNumber(s.get('rides.min_fare'), 5, { min: 0 }),
      maxDistanceKm: asNumber(s.get('rides.max_distance_km'), 50, { min: 1 }),
      negotiable: asBool(s.get('rides.negotiable'), true),
      // Ronda 279 · fase 4. Se despliega en 0 = el comportamiento de hoy
      // (un conductor con S/0 exactos sí puede aceptar). Subirlo es decisión
      // del dueño desde el panel, no un cambio de código.
      minBalanceToAccept: asNumber(s.get('rides.min_balance_to_accept'), 0, { min: 0 }),
    },
    wallet: {
      minRecharge: asNumber(s.get('wallet.min_recharge'), 5, { min: 0 }),
      minWithdrawal: asNumber(s.get('wallet.min_withdrawal'), 20, { min: 0 }),
      withdrawalFee: asNumber(s.get('wallet.withdrawal_fee'), 2, { min: 0 }),
    },
    company: {
      name: asString(s.get('company.name'), 'Rapi Team'),
      ruc: asString(s.get('company.ruc'), ''),
      address: asString(s.get('company.address'), ''),
      supportEmail: asString(s.get('company.support_email'), 'facturacion.rapiteam@gmail.com'),
    },
    documents: documents.map((d) => ({
      code: d.code,
      label: d.label,
      description: d.description,
      required: d.required,
      sortOrder: d.sortOrder,
    })),
  }

  return NextResponse.json(
    { success: true, config },
    {
      headers: {
        // Un minuto de caché. Suficiente para que un pico de arranques no
        // castigue la base, y lo bastante corto para que activar el modo
        // mantenimiento surta efecto casi al instante.
        'Cache-Control': 'public, max-age=60, stale-while-revalidate=300',
      },
    },
  )
}
