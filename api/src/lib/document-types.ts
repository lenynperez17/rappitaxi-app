/**
 * Ronda 279 — el catálogo de documentos del conductor, en un solo sitio.
 *
 * POR QUÉ EXISTE
 * --------------
 * La lista de documentos estaba escrita a mano en catorce lugares de las tres
 * capas, y el subconjunto de "obligatorios para quedar verificado" tenía tres
 * representaciones independientes: un `Set` aquí, otro `Set` idéntico en
 * `drivers/me/upgrade`, y un literal dentro de una consulta SQL rematado con
 * `) = 5`. Mantener eso sincronizado a mano no es una tarea, es una apuesta.
 *
 * Ahora manda la tabla `driver_document_types` y esto es lo único que la lee.
 *
 * "OBLIGATORIO" IMPLICA "SE PIDE"
 * -------------------------------
 * Un tipo marcado obligatorio pero desactivado NO cuenta como obligatorio: no
 * se le pide al conductor, así que exigírselo lo dejaría sin poder verificarse
 * nunca. `getRequiredDocTypes` devuelve la intersección, no la columna suelta.
 */
import { query } from './db'

export interface DriverDocumentType {
  code: string
  label: string
  description: string
  enabled: boolean
  required: boolean
  sortOrder: number
}

interface Row {
  code: string
  label: string
  description: string
  enabled: boolean
  required: boolean
  sort_order: number
}

/**
 * Los cinco de siempre. Solo se usan si la consulta al catálogo falla: ante un
 * problema de base de datos preferimos seguir exigiendo lo de ayer a verificar
 * conductores sin pedirles nada.
 */
const FALLBACK_REQUIRED = ['dni_front', 'dni_back', 'license_front', 'license_back', 'soat']

/**
 * Caché de proceso muy corta. El catálogo se consulta en cada aprobación de
 * documento y en cada arranque de app; treinta segundos evitan el martilleo
 * sin que el administrador tenga que esperar para ver el efecto de un cambio.
 */
const CACHE_TTL_MS = 30_000
let cache: { at: number; types: DriverDocumentType[] } | null = null

/** Invalida la caché. Lo llama el panel al guardar un cambio. */
export function invalidateDocumentTypesCache(): void {
  cache = null
}

/** Todo el catálogo, activos y desactivados, en orden de presentación. */
export async function getDocumentTypes(): Promise<DriverDocumentType[]> {
  if (cache && Date.now() - cache.at < CACHE_TTL_MS) return cache.types

  const rows = await query<Row>(
    `SELECT code, label, description, enabled, required, sort_order
       FROM driver_document_types
      ORDER BY sort_order, code`,
  )
  const types = rows.map((r) => ({
    code: r.code,
    label: r.label,
    description: r.description,
    enabled: r.enabled,
    required: r.required,
    sortOrder: r.sort_order,
  }))
  cache = { at: Date.now(), types }
  return types
}

/** Los que la app debe mostrar al conductor. */
export async function getEnabledDocumentTypes(): Promise<DriverDocumentType[]> {
  return (await getDocumentTypes()).filter((t) => t.enabled)
}

/**
 * Los códigos que hacen falta para quedar verificado.
 *
 * Nunca devuelve una lista vacía a partir de un fallo: si la consulta revienta,
 * devuelve los cinco históricos. Una lista vacía significaría "verificado sin
 * documentos", que es exactamente el resultado que no queremos por accidente.
 */
export async function getRequiredDocTypes(): Promise<string[]> {
  try {
    const required = (await getDocumentTypes())
      .filter((t) => t.enabled && t.required)
      .map((t) => t.code)
    return required
  } catch (err) {
    console.error('[document-types] no se pudo leer el catálogo, uso el fallback:', err)
    return FALLBACK_REQUIRED
  }
}

/**
 * `true` si ese código existe en el catálogo.
 *
 * OJO: comprueba que EXISTA, no que esté activo, y es deliberado. `enabled`
 * dice qué se le PIDE al conductor desde la app; rechazar subidas por él
 * rompería a todo el que tenga instalada una versión anterior, que sigue
 * enviando los códigos de su época —`other`, sin ir más lejos— y se quedaría
 * sin poder completar su alta con un 400 que no puede entender ni arreglar.
 * Que un código sea válido lo garantiza además la clave foránea de la tabla;
 * esto solo permite dar un error claro antes de llegar a ella.
 */
export async function isKnownDocType(code: string): Promise<boolean> {
  try {
    return (await getDocumentTypes()).some((t) => t.code === code)
  } catch {
    // Ante un fallo de lectura no bloqueamos subidas: la FK ya impide que
    // entre un código inexistente.
    return true
  }
}
