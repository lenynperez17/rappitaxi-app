/**
 * POST /api/admin/drivers/:id/documents
 *   Content-Type: multipart/form-data
 *   Fields: docType (string), file (blob) — sube el archivo Y registra el
 *   documento para el driver en un solo request. Storage queda con
 *   user_id=driverId para que el propio driver pueda ver su archivo desde
 *   la app.
 *
 *   Idéntico a /api/drivers/me/documents pero opera sobre otro driver_id.
 *   Útil para drivers creados manualmente desde el panel que aún no
 *   instalaron la app.
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAdmin } from '@/lib/admin-middleware'
import { getClientIp } from '@/lib/auth-middleware'
import { maybeOne, query, tx } from '@/lib/db'
import { saveBuffer, sniffMime, isMimeAllowed, ALLOWED_SCOPES, type StorageScope } from '@/lib/storage'

export const runtime = 'nodejs'

const ALLOWED_DOC_TYPES = new Set([
  'dni_front', 'dni_back', 'license_front', 'license_back', 'soat',
  'tarjeta_propiedad', 'ownership', 'selfie', 'vehicle_photo', 'other',
])

// Mapa docType → StorageScope (mismo que usa el flow del app móvil).
const DOC_TO_SCOPE: Record<string, StorageScope> = {
  dni_front: 'identity_front',
  dni_back: 'identity_back',
  license_front: 'driver_license',
  license_back: 'driver_license',
  soat: 'soat',
  tarjeta_propiedad: 'vehicle_registration',
  ownership: 'vehicle_registration',
  selfie: 'profile_photo',
  vehicle_photo: 'vehicle_photo',
  other: 'misc',
}

const MAX_SIZE_MB = 15
const MAX_SIZE = MAX_SIZE_MB * 1024 * 1024

interface DocRow {
  id: string
  driver_id: string
  doc_type: string
  file_url: string
  status: string
  created_at: Date
  updated_at: Date
}

export async function POST(req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  const auth = await requireAdmin(req)
  if (!auth.ok) return auth.response
  const { id: driverId } = await ctx.params
  if (!driverId || !/^[A-Za-z0-9_-]{6,80}$/.test(driverId)) {
    return NextResponse.json({ success: false, error: 'invalid_driver_id' }, { status: 400 })
  }

  const driver = await maybeOne<{ id: string; user_type: string }>(
    'SELECT id, user_type FROM users WHERE id = $1 AND deleted_at IS NULL',
    [driverId],
  )
  if (!driver) return NextResponse.json({ success: false, error: 'driver_not_found' }, { status: 404 })

  let form: FormData
  try { form = await req.formData() } catch {
    return NextResponse.json({ success: false, error: 'bad_multipart' }, { status: 400 })
  }

  const docType = String(form.get('docType') ?? '').trim()
  if (!ALLOWED_DOC_TYPES.has(docType)) {
    return NextResponse.json({ success: false, error: 'invalid_doc_type' }, { status: 400 })
  }
  const scope = DOC_TO_SCOPE[docType]
  if (!scope || !ALLOWED_SCOPES.has(scope)) {
    return NextResponse.json({ success: false, error: 'no_scope_mapping' }, { status: 400 })
  }

  const file = form.get('file')
  if (!(file instanceof File) || file.size === 0) {
    return NextResponse.json({ success: false, error: 'missing_file' }, { status: 400 })
  }
  if (file.size > MAX_SIZE) {
    return NextResponse.json({
      success: false, error: 'file_too_large',
      message: `Máximo ${MAX_SIZE_MB} MB`,
    }, { status: 413 })
  }

  const buf = Buffer.from(await file.arrayBuffer())
  const sniffedMime = sniffMime(buf)
  if (!sniffedMime || !isMimeAllowed(sniffedMime)) {
    return NextResponse.json({
      success: false, error: 'mime_not_allowed',
      message: 'Formato no soportado. Usa JPG/PNG/WebP/HEIC/PDF.',
    }, { status: 415 })
  }

  // Guardar el archivo con user_id=driverId (no el admin) para que el driver
  // pueda descargarlo desde la app como si él lo hubiera subido.
  const saved = await saveBuffer(scope, driverId, buf, sniffedMime)
  const isPublic = scope === 'profile_photo' || scope === 'vehicle_photo'
  const fileUrl = `/api/media/${saved.key}`

  try {
    const result = await tx(async (client) => {
      await client.query(
        `INSERT INTO storage_files (user_id, scope, storage_key, mime, size_bytes, sha256_hex, is_public)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [driverId, scope, saved.key, sniffedMime, saved.size, saved.sha256, isPublic],
      )

      const upsert = await client.query<DocRow & { was_new: boolean }>(
        `INSERT INTO driver_documents (driver_id, doc_type, file_url, status)
         VALUES ($1, $2, $3, 'pending')
         ON CONFLICT (driver_id, doc_type) DO UPDATE SET
           file_url = EXCLUDED.file_url,
           status = 'pending',
           rejection_reason = NULL,
           reviewed_by = NULL,
           reviewed_at = NULL,
           updated_at = now()
         RETURNING id, driver_id, doc_type, file_url, status, created_at, updated_at,
                   (xmax = 0) AS was_new`,
        [driverId, docType, fileUrl],
      )
      return upsert.rows[0]!
    })

    await query(
      `INSERT INTO notifications (user_id, type, title, body, data)
       VALUES ($1, 'document_uploaded', 'Documento cargado por admin', $2, $3::jsonb)`,
      [
        driverId,
        `El admin subió tu documento (${docType}). Está pendiente de revisión.`,
        JSON.stringify({ documentId: result.id, docType, uploadedByAdmin: true }),
      ],
    )

    await query(
      `INSERT INTO auth_events (user_id, event_type, provider, ip_address, user_agent, metadata)
       VALUES ($1, 'admin_upload_document', 'admin', $2, $3, $4::jsonb)`,
      [
        driverId, getClientIp(req), req.headers.get('user-agent'),
        JSON.stringify({ uploadedBy: auth.userId, docType, wasNew: result.was_new, sizeBytes: saved.size, mime: sniffedMime }),
      ],
    )

    return NextResponse.json({
      success: true,
      created: result.was_new,
      document: {
        id: result.id, driverId: result.driver_id, docType: result.doc_type,
        fileUrl: result.file_url, status: result.status,
        createdAt: result.created_at, updatedAt: result.updated_at,
      },
    })
  } catch (err) {
    console.error('[admin/drivers/:id/documents POST] error:', err)
    return NextResponse.json({ success: false, error: 'server_error' }, { status: 500 })
  }
}
