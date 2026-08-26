/**
 * GET/PATCH /api/admin/service-types — los servicios que se le ofrecen al
 * pasajero (Express, Ejecutivo, VIP, Minivan).
 *
 * Ronda 281. La ronda 280 creó el catálogo `ride_service_types`, lo expuso en
 * `/api/config/app` y enseñó a la app a pintarlo — pero se quedó sin el
 * interruptor en el panel. Resultado: Minivan existía, estaba desactivada, y no
 * había forma de encenderla salvo entrando a la base de datos a mano. Esto es
 * esa forma.
 *
 * POR QUÉ NO ESTÁ EN /api/admin/settings
 * --------------------------------------
 * Igual que el catálogo de documentos: `SettingsPage` guarda cada ajuste como
 * un valor suelto (texto, número o sí/no). Una lista de servicios con
 * multiplicador y vehículos por fila se guardaría serializada como texto y
 * quedaría corrupta.
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAdmin } from '@/lib/admin-middleware'
import { query, tx } from '@/lib/db'
import { getServiceTypes, invalidateServiceTypesCache } from '@/lib/service-types'

export const runtime = 'nodejs'
export const dynamic = 'force-dynamic'

/**
 * Los vehículos que un servicio puede pedir. Es la lista del alta de conductor
 * más `taxi`, que no está en ese desplegable pero sí en las fichas reales de
 * dos conductores.
 */
const VEHICULOS_VALIDOS = new Set(['car', 'taxi', 'moto', 'moto_taxi', 'van', 'truck', 'bicycle'])

export async function GET(req: NextRequest) {
  const auth = await requireAdmin(req)
  if (!auth.ok) return auth.response

  // Se salta la caché: el panel tiene que ver lo que acaba de guardar.
  invalidateServiceTypesCache()
  const types = await getServiceTypes()

  // Cuántos viajes se han pedido de cada servicio. El administrador necesita
  // saberlo antes de desactivar uno: desactivarlo no borra el historial, pero
  // deja de ofrecerse desde ese momento.
  const counts = await query<{ service_type: string; total: string }>(
    `SELECT service_type, COUNT(*)::text AS total
       FROM rides WHERE service_type IS NOT NULL GROUP BY service_type`,
  )
  const byType = new Map(counts.map((c) => [c.service_type, Number(c.total)]))

  // Cuántos conductores activos hay de cada tipo de vehículo. Sin esto, activar
  // Minivan parece inofensivo y en realidad crea viajes que nadie recibe.
  const fleet = await query<{ vehicle_type: string; total: string }>(
    `SELECT vehicle_type, COUNT(*)::text AS total
       FROM driver_vehicles WHERE is_active = true GROUP BY vehicle_type`,
  )
  const byVehicle = new Map(fleet.map((f) => [f.vehicle_type, Number(f.total)]))

  return NextResponse.json({
    success: true,
    serviceTypes: types.map((t) => ({
      ...t,
      ridesCount: byType.get(t.code) ?? 0,
      // Conductores con un vehículo que puede atender este servicio.
      driversAvailable: t.vehicleTypes.length === 0
        ? [...byVehicle.values()].reduce((a, b) => a + b, 0)
        : t.vehicleTypes.reduce((sum, v) => sum + (byVehicle.get(v) ?? 0), 0),
    })),
  })
}

interface UpdateItem {
  code?: unknown
  enabled?: unknown
  priceMultiplier?: unknown
  label?: unknown
  description?: unknown
  vehicleTypes?: unknown
  sortOrder?: unknown
}

export async function PATCH(req: NextRequest) {
  const auth = await requireAdmin(req)
  if (!auth.ok) return auth.response

  let body: { updates?: UpdateItem[]; allowZeroEnabled?: boolean } = {}
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ success: false, error: 'bad_json' }, { status: 400 })
  }

  const updates = Array.isArray(body.updates) ? body.updates : []
  if (updates.length === 0) {
    return NextResponse.json({ success: false, error: 'no_updates' }, { status: 400 })
  }

  const existing = await getServiceTypes()
  const known = new Map(existing.map((t) => [t.code, t]))

  // Validación previa completa: nada se escribe si algo viene mal. Un PATCH a
  // medias sobre los servicios dejaría precios que nadie pidió.
  const clean: {
    code: string; enabled: boolean; priceMultiplier: number
    label: string; description: string; vehicleTypes: string[]; sortOrder: number
  }[] = []

  for (const u of updates) {
    const code = typeof u.code === 'string' ? u.code : ''
    const current = known.get(code)
    if (!current) {
      return NextResponse.json(
        { success: false, error: 'unknown_service_type', code },
        { status: 400 },
      )
    }

    let priceMultiplier = current.priceMultiplier
    if (u.priceMultiplier !== undefined) {
      const n = Number(u.priceMultiplier)
      // El mismo rango que acepta la restricción de la tabla. Se comprueba aquí
      // para poder decir qué pasó, en vez de devolver un error de base de datos.
      if (!Number.isFinite(n) || n <= 0 || n > 10) {
        return NextResponse.json(
          {
            success: false,
            error: 'invalid_multiplier',
            code,
            message: 'El multiplicador debe estar entre 0 y 10. Ej: 1.4 = 40% más caro.',
          },
          { status: 400 },
        )
      }
      priceMultiplier = Math.round(n * 100) / 100
    }

    let vehicleTypes = current.vehicleTypes
    if (u.vehicleTypes !== undefined) {
      if (!Array.isArray(u.vehicleTypes)) {
        return NextResponse.json(
          { success: false, error: 'invalid_vehicle_types', code },
          { status: 400 },
        )
      }
      const lista = u.vehicleTypes.filter((v): v is string => typeof v === 'string')
      const desconocido = lista.find((v) => !VEHICULOS_VALIDOS.has(v))
      if (desconocido) {
        return NextResponse.json(
          {
            success: false,
            error: 'unknown_vehicle_type',
            code,
            message: `Tipo de vehículo desconocido: ${desconocido}.`,
          },
          { status: 400 },
        )
      }
      vehicleTypes = lista
    }

    clean.push({
      code,
      enabled: typeof u.enabled === 'boolean' ? u.enabled : current.enabled,
      priceMultiplier,
      label: typeof u.label === 'string' && u.label.trim() ? u.label.trim() : current.label,
      description: typeof u.description === 'string' ? u.description : current.description,
      vehicleTypes,
      sortOrder: typeof u.sortOrder === 'number' && Number.isFinite(u.sortOrder)
        ? Math.trunc(u.sortOrder)
        : current.sortOrder,
    })
  }

  // Cómo queda el catálogo entero después de aplicar esto.
  const resulting = new Map(existing.map((t) => [t.code, { ...t }]))
  for (const c of clean) resulting.set(c.code, { ...resulting.get(c.code)!, ...c })

  if ([...resulting.values()].every((t) => !t.enabled) && body.allowZeroEnabled !== true) {
    return NextResponse.json(
      {
        success: false,
        error: 'zero_enabled_services',
        message:
          'Te quedarías sin ningún servicio activo: el pasajero no podría pedir ' +
          'ningún viaje. Confirma si es lo que quieres.',
        needsConfirmation: true,
      },
      { status: 409 },
    )
  }

  try {
    await tx(async (client) => {
      for (const c of clean) {
        await client.query(
          `UPDATE ride_service_types
              SET enabled = $2, price_multiplier = $3, label = $4, description = $5,
                  vehicle_types = $6::text[], sort_order = $7, updated_at = now()
            WHERE code = $1`,
          [c.code, c.enabled, c.priceMultiplier, c.label, c.description, c.vehicleTypes, c.sortOrder],
        )
      }
    })
  } catch (err) {
    console.error('[admin/service-types PATCH] error:', err)
    return NextResponse.json({ success: false, error: 'update_failed' }, { status: 500 })
  }

  invalidateServiceTypesCache()
  return NextResponse.json({ success: true, updated: clean.length })
}
