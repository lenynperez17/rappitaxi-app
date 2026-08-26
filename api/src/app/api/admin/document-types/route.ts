/**
 * GET/PATCH /api/admin/document-types — qué documentos se le piden al conductor.
 *
 * Ronda 279. Lo pidió el dueño: "quieren activar y desactivar qué documentos
 * pedir y que en la app aparezca y desaparezca según lo que el admin escoja".
 *
 * POR QUÉ NO ESTÁ EN /api/admin/settings
 * --------------------------------------
 * `SettingsPage` solo sabe pintar textos, números y sí/no, y guarda cada
 * ajuste como un valor suelto. Una lista de documentos con dos interruptores
 * cada uno no cabe ahí: se guardaría como texto plano y quedaría corrupta.
 *
 * LA SALVAGUARDA
 * --------------
 * No se permite dejar CERO documentos obligatorios sin decirlo explícitamente.
 * Sin obligatorios, la comprobación de verificación se cumple sola y cualquier
 * conductor quedaría verificado sin haber subido nada.
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAdmin } from '@/lib/admin-middleware'
import { query, tx } from '@/lib/db'
import { getDocumentTypes, invalidateDocumentTypesCache } from '@/lib/document-types'

export const runtime = 'nodejs'
export const dynamic = 'force-dynamic'

export async function GET(req: NextRequest) {
  const auth = await requireAdmin(req)
  if (!auth.ok) return auth.response

  // Se salta la caché: el panel tiene que ver lo que acaba de guardar.
  invalidateDocumentTypesCache()
  const types = await getDocumentTypes()

  // Cuántos documentos hay subidos de cada tipo. El administrador necesita
  // saberlo antes de desactivar algo: desactivar un tipo con documentos ya
  // subidos no los borra, pero deja de pedirlo a partir de ese momento.
  const counts = await query<{ doc_type: string; total: string }>(
    `SELECT doc_type, COUNT(*)::text AS total FROM driver_documents GROUP BY doc_type`,
  )
  const byType = new Map(counts.map((c) => [c.doc_type, Number(c.total)]))

  return NextResponse.json({
    success: true,
    documentTypes: types.map((t) => ({ ...t, uploadedCount: byType.get(t.code) ?? 0 })),
  })
}

interface UpdateItem {
  code?: unknown
  enabled?: unknown
  required?: unknown
  label?: unknown
  description?: unknown
  sortOrder?: unknown
}

export async function PATCH(req: NextRequest) {
  const auth = await requireAdmin(req)
  if (!auth.ok) return auth.response

  let body: { updates?: UpdateItem[]; allowZeroRequired?: boolean } = {}
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ success: false, error: 'bad_json' }, { status: 400 })
  }

  const updates = Array.isArray(body.updates) ? body.updates : []
  if (updates.length === 0) {
    return NextResponse.json({ success: false, error: 'no_updates' }, { status: 400 })
  }

  const existing = await getDocumentTypes()
  const known = new Map(existing.map((t) => [t.code, t]))

  // Validación previa: nada se escribe si algo viene mal. Un PATCH a medias
  // sobre el catálogo dejaría la verificación en un estado que nadie pidió.
  const clean: {
    code: string
    enabled: boolean
    required: boolean
    label: string
    description: string
    sortOrder: number
  }[] = []

  for (const u of updates) {
    const code = typeof u.code === 'string' ? u.code : ''
    const current = known.get(code)
    if (!current) {
      return NextResponse.json(
        { success: false, error: 'unknown_document_type', code },
        { status: 400 },
      )
    }
    const label = typeof u.label === 'string' && u.label.trim() ? u.label.trim() : current.label
    const sortOrder =
      typeof u.sortOrder === 'number' && Number.isFinite(u.sortOrder)
        ? Math.trunc(u.sortOrder)
        : current.sortOrder
    clean.push({
      code,
      enabled: typeof u.enabled === 'boolean' ? u.enabled : current.enabled,
      required: typeof u.required === 'boolean' ? u.required : current.required,
      label,
      description: typeof u.description === 'string' ? u.description : current.description,
      sortOrder,
    })
  }

  // Cómo queda el catálogo entero después de aplicar esto.
  const resulting = new Map(existing.map((t) => [t.code, { ...t }]))
  for (const c of clean) resulting.set(c.code, { ...resulting.get(c.code)!, ...c })
  const requiredAfter = [...resulting.values()].filter((t) => t.enabled && t.required)

  if (requiredAfter.length === 0 && body.allowZeroRequired !== true) {
    return NextResponse.json(
      {
        success: false,
        error: 'zero_required_documents',
        message:
          'Te quedarías sin ningún documento obligatorio: cualquier conductor ' +
          'quedaría verificado sin subir nada. Confirma si es lo que quieres.',
        needsConfirmation: true,
      },
      { status: 409 },
    )
  }

  try {
    await tx(async (client) => {
      for (const c of clean) {
        await client.query(
          `UPDATE driver_document_types
              SET enabled = $2, required = $3, label = $4, description = $5,
                  sort_order = $6, updated_at = now()
            WHERE code = $1`,
          [c.code, c.enabled, c.required, c.label, c.description, c.sortOrder],
        )
      }
    })
  } catch (err) {
    console.error('[admin/document-types PATCH] error:', err)
    return NextResponse.json({ success: false, error: 'update_failed' }, { status: 500 })
  }

  invalidateDocumentTypesCache()
  return NextResponse.json({ success: true, updated: clean.length })
}
