/**
 * /api/drivers/me/documents
 * Auth: Bearer <access_token> (driver o dual)
 *
 * GET  → lista los documentos del driver con su estado.
 * POST → sube o reemplaza un documento (UPSERT sobre UNIQUE(driver_id, doc_type)).
 *        Body: { docType, fileUrl }
 *        Al reemplazar, el status vuelve a 'pending' para que admin revise
 *        de nuevo, y se limpia el rejection_reason previo. Registra
 *        notificación in-app para el driver.
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAuth } from '@/lib/auth-middleware'
import { maybeOne, query, tx } from '@/lib/db'

export const runtime = 'nodejs'

const ALLOWED_DOC_TYPES = new Set([
  'dni_front',
  'dni_back',
  'license_front',
  'license_back',
  'soat',
  'tarjeta_propiedad',
  'ownership',
  'selfie',
  'vehicle_photo',
  'other',
])

interface DocRow {
  id: string
  driver_id: string
  doc_type: string
  file_url: string
  status: string
  rejection_reason: string | null
  reviewed_by: string | null
  reviewed_at: Date | null
  expires_at: Date | null
  created_at: Date
  updated_at: Date
}

interface DocBody {
  docType?: unknown
  fileUrl?: unknown
}

function serialize(d: DocRow) {
  return {
    id: d.id,
    driverId: d.driver_id,
    docType: d.doc_type,
    fileUrl: d.file_url,
    status: d.status,
    rejectionReason: d.rejection_reason,
    reviewedBy: d.reviewed_by,
    reviewedAt: d.reviewed_at,
    expiresAt: d.expires_at,
    createdAt: d.created_at,
    updatedAt: d.updated_at,
  }
}

export async function GET(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response
  const driverId = auth.userId

  const rows = await query<DocRow>(
    `SELECT id, driver_id, doc_type, file_url, status, rejection_reason,
            reviewed_by, reviewed_at, expires_at, created_at, updated_at
       FROM driver_documents
      WHERE driver_id = $1
      ORDER BY doc_type ASC`,
    [driverId],
  )

  return NextResponse.json({
    success: true,
    documents: rows.map(serialize),
  })
}

export async function POST(req: NextRequest) {
  const auth = await requireAuth(req)
  if (!auth.ok) return auth.response
  const driverId = auth.userId

  let body: DocBody = {}
  try {
    body = (await req.json()) as DocBody
  } catch {
    return NextResponse.json(
      { success: false, error: 'bad_json' },
      { status: 400 },
    )
  }

  const user = await maybeOne<{ user_type: string }>(
    'SELECT user_type FROM users WHERE id = $1 AND deleted_at IS NULL',
    [driverId],
  )
  if (!user) {
    return NextResponse.json(
      { success: false, error: 'user_not_found' },
      { status: 404 },
    )
  }
  if (user.user_type !== 'driver' && user.user_type !== 'dual') {
    return NextResponse.json(
      { success: false, error: 'forbidden', message: 'Solo drivers' },
      { status: 403 },
    )
  }

  const docType = typeof body.docType === 'string' ? body.docType.trim() : ''
  const fileUrl = typeof body.fileUrl === 'string' ? body.fileUrl.trim() : ''

  if (!docType || !ALLOWED_DOC_TYPES.has(docType)) {
    return NextResponse.json(
      { success: false, error: 'invalid_doc_type' },
      { status: 400 },
    )
  }
  if (!fileUrl) {
    return NextResponse.json(
      { success: false, error: 'invalid_input', message: 'fileUrl requerido' },
      { status: 400 },
    )
  }
  // Validación light de URL — evitamos aceptar strings claramente inválidos.
  if (!/^https?:\/\//i.test(fileUrl) && !fileUrl.startsWith('/')) {
    return NextResponse.json(
      { success: false, error: 'invalid_file_url' },
      { status: 400 },
    )
  }

  try {
    const result = await tx(async (client) => {
      const upsert = await client.query<DocRow & { was_new: boolean }>(
        `INSERT INTO driver_documents
           (driver_id, doc_type, file_url, status)
         VALUES ($1, $2, $3, 'pending')
         ON CONFLICT (driver_id, doc_type) DO UPDATE SET
           file_url = EXCLUDED.file_url,
           status = 'pending',
           rejection_reason = NULL,
           reviewed_by = NULL,
           reviewed_at = NULL,
           updated_at = now()
         RETURNING id, driver_id, doc_type, file_url, status, rejection_reason,
                   reviewed_by, reviewed_at, expires_at, created_at, updated_at,
                   (xmax = 0) AS was_new`,
        [driverId, docType, fileUrl],
      )
      const row = upsert.rows[0]!
      const wasNew = row.was_new

      await client.query(
        `INSERT INTO notifications (user_id, type, title, body, data)
         VALUES ($1, $2, $3, $4, $5::jsonb)`,
        [
          driverId,
          'document_uploaded',
          wasNew ? 'Documento enviado' : 'Documento actualizado',
          `Tu documento (${docType}) fue enviado y está pendiente de revisión.`,
          JSON.stringify({ documentId: row.id, docType }),
        ],
      )

      return { row, wasNew }
    })

    return NextResponse.json({
      success: true,
      created: result.wasNew,
      document: serialize(result.row),
    })
  } catch (err) {
    console.error('[drivers/me/documents POST] error:', err)
    return NextResponse.json(
      { success: false, error: 'server_error' },
      { status: 500 },
    )
  }
}
