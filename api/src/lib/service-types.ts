/**
 * Ronda 280 — el catálogo de servicios (Express, Ejecutivo, VIP, Minivan).
 *
 * Es lo que cierra el circuito que nunca estuvo cerrado: qué servicios existen,
 * cuánto multiplican la tarifa, y **qué vehículos pueden atender cada uno**.
 * Antes esto vivía en un `enum` dentro de la pantalla del pasajero y no salía
 * del teléfono.
 */
import { query } from './db'

export interface RideServiceType {
  code: string
  label: string
  description: string
  priceMultiplier: number
  /** Vehículos que pueden atenderlo. Vacío = cualquiera. */
  vehicleTypes: string[]
  enabled: boolean
  sortOrder: number
}

interface Row {
  code: string
  label: string
  description: string
  price_multiplier: string
  vehicle_types: string[]
  enabled: boolean
  sort_order: number
}

const CACHE_TTL_MS = 30_000
let cache: { at: number; types: RideServiceType[] } | null = null

/** Invalida la caché. Lo llama el panel al guardar un cambio. */
export function invalidateServiceTypesCache(): void {
  cache = null
}

export async function getServiceTypes(): Promise<RideServiceType[]> {
  if (cache && Date.now() - cache.at < CACHE_TTL_MS) return cache.types

  const rows = await query<Row>(
    `SELECT code, label, description, price_multiplier, vehicle_types, enabled, sort_order
       FROM ride_service_types
      ORDER BY sort_order, code`,
  )
  const types = rows.map((r) => ({
    code: r.code,
    label: r.label,
    description: r.description,
    priceMultiplier: Number(r.price_multiplier),
    vehicleTypes: Array.isArray(r.vehicle_types) ? r.vehicle_types : [],
    enabled: r.enabled,
    sortOrder: r.sort_order,
  }))
  cache = { at: Date.now(), types }
  return types
}

/** Los que la app debe ofrecerle al pasajero. */
export async function getEnabledServiceTypes(): Promise<RideServiceType[]> {
  return (await getServiceTypes()).filter((t) => t.enabled)
}

/**
 * Los vehículos que pueden atender [code].
 *
 * `null` significa "no filtres": o el servicio no existe, o no restringe
 * vehículos, o no se pudo leer el catálogo. En los tres casos la decisión
 * correcta es avisar a todos los conductores, como se hacía hasta ahora —
 * dejar un viaje sin ofrecer a nadie es peor que ofrecérselo a alguien de más.
 */
export async function vehicleTypesForService(
  code: string | null | undefined,
): Promise<string[] | null> {
  if (!code) return null
  try {
    const t = (await getServiceTypes()).find((s) => s.code === code)
    if (!t || t.vehicleTypes.length === 0) return null
    return t.vehicleTypes
  } catch (err) {
    console.error('[service-types] no se pudo leer el catálogo:', err)
    return null
  }
}

/** `true` si ese servicio existe y está activo. */
export async function isServiceTypeEnabled(code: string): Promise<boolean> {
  try {
    return (await getServiceTypes()).some((t) => t.code === code && t.enabled)
  } catch {
    // Sin catálogo no bloqueamos la creación de viajes.
    return true
  }
}
