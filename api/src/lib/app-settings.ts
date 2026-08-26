/**
 * Ronda 279 — leer la configuración del panel desde el servidor.
 *
 * De los catorce ajustes que el panel guarda, uno solo se leía: la comisión.
 * Los otros trece se editaban, se guardaban con su mensaje de éxito, y no
 * cambiaban nada. Los más engañosos eran los que por casualidad coincidían con
 * la constante escrita en el código —retiro mínimo S/ 20, cargo S/ 2—: parecen
 * funcionar hasta que alguien los cambia.
 *
 * Esto es lo que los hace de verdad. Cada lector pide su valor por defecto, y
 * ese valor por defecto es siempre el comportamiento anterior: un ajuste que
 * falte, o una base de datos que no responda, deja el sistema como estaba y no
 * lo rompe.
 */
import { query } from './db'

interface Row {
  key: string
  value: unknown
}

/**
 * Caché de proceso de treinta segundos. Estos ajustes se consultan en caminos
 * calientes (crear viaje, retirar, registrarse) y cambian rara vez; media
 * docena de consultas por minuto no aporta nada frente al martilleo que
 * evita. Treinta segundos es también lo que tarda el administrador en ver el
 * efecto de un cambio, que es tolerable para configuración.
 */
const CACHE_TTL_MS = 30_000
let cache: { at: number; values: Map<string, unknown> } | null = null

/** Invalida la caché. Lo llama el panel al guardar. */
export function invalidateSettingsCache(): void {
  cache = null
}

async function loadAll(): Promise<Map<string, unknown>> {
  if (cache && Date.now() - cache.at < CACHE_TTL_MS) return cache.values
  const rows = await query<Row>('SELECT key, value FROM app_settings')
  const values = new Map(rows.map((r) => [r.key, r.value]))
  cache = { at: Date.now(), values }
  return values
}

/** Número del ajuste [key], o [fallback] si falta, es ilegible o es negativo. */
export async function settingNumber(key: string, fallback: number): Promise<number> {
  try {
    const values = await loadAll()
    if (!values.has(key)) return fallback
    const raw = values.get(key)
    const n = typeof raw === 'number' ? raw : Number(raw)
    if (!Number.isFinite(n) || n < 0) return fallback
    return n
  } catch (err) {
    console.error(`[app-settings] no se pudo leer ${key}:`, err)
    return fallback
  }
}

/** Booleano del ajuste [key], tolerando `true`, `"true"` y `1`. */
export async function settingBool(key: string, fallback: boolean): Promise<boolean> {
  try {
    const values = await loadAll()
    if (!values.has(key)) return fallback
    const raw = values.get(key)
    if (typeof raw === 'boolean') return raw
    if (typeof raw === 'number') return raw !== 0
    if (typeof raw === 'string') {
      const v = raw.trim().toLowerCase()
      if (v === 'true' || v === '1') return true
      if (v === 'false' || v === '0') return false
    }
    return fallback
  } catch (err) {
    console.error(`[app-settings] no se pudo leer ${key}:`, err)
    return fallback
  }
}

/** Texto del ajuste [key], o [fallback] si falta o está vacío. */
export async function settingString(key: string, fallback: string): Promise<string> {
  try {
    const values = await loadAll()
    const raw = values.get(key)
    if (typeof raw === 'string' && raw.trim().length > 0) return raw
    return fallback
  } catch (err) {
    console.error(`[app-settings] no se pudo leer ${key}:`, err)
    return fallback
  }
}
