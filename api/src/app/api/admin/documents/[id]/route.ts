/**
 * PATCH /api/admin/documents/:id
 *   Body: { status: 'approved' | 'rejected' | 'expired', rejectionReason?: string }
 *
 *   Aprobar, rechazar o expirar un documento del driver. Setea reviewed_by
 *   al admin actual y reviewed_at=now(). Cuando TODOS los documentos requeridos
 *   quedan approved, marca users.is_verified=true automáticamente.
 */
import { NextRequest, NextResponse } from 'next/server'
import { isUuid } from '@/lib/uuid'
import { requireAdmin } from '@/lib/admin-middleware'
import { getClientIp } from '@/lib/auth-middleware'
import { maybeOne, query, tx } from '@/lib/db'

export const runtime = 'nodejs'

// Documentos requeridos para que un driver quede verificado.
// Ajustar según política real de Rapi Team.
const REQUIRED_DOC_TYPES = new Set([
  'dni_front',
  'dni_back',
  'license_front',
  'license_back',
  'soat',
])

const ALLOWED_STATUS = new Set(['approved', 'rejected', 'expired'])

interface DocumentRow {
  id: string
  driver_id: string
  doc_type: string
  file_url: string
  status: string
  rejection_reason: string | null
  reviewed_by: string | null
  reviewed_at: Date | null
  expires_at: Date | null
  metadata: Record<string, unknown> | null
  created_at: Date
  updated_at: Date
}

export async function PATCH(req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  const auth = await requireAdmin(req)
  if (!auth.ok) return auth.response
  const { id } = await ctx.params
  if (!isUuid(id)) {
    return NextResponse.json({ success: false, error: 'invalid_id' }, { status: 400 })
  }

  let body: { status?: string; rejectionReason?: string; expiresAt?: string }
  try {
    body = await req.json()
  } catch {
    return NextResponse.json({ success: false, error: 'bad_json' }, { status: 400 })
  }

  const newStatus = body.status?.trim()
  if (!newStatus || !ALLOWED_STATUS.has(newStatus)) {
    return NextResponse.json({ success: false, error: 'invalid_status' }, { status: 400 })
  }

  // rejected requiere razón (para que el driver sepa qué corregir)
  if (newStatus === 'rejected' && !body.rejectionReason?.trim()) {
    return NextResponse.json(
      { success: false, error: 'rejection_reason_required', message: 'Debes indicar el motivo de rechazo' },
      { status: 400 },
    )
  }

  try {
    const result = await tx(async (client) => {
      // Cargar el documento y su driver
      const docRes = await client.query<DocumentRow>(
        `SELECT * FROM driver_documents WHERE id = $1 FOR UPDATE`,
        [id],
      )
      const doc = docRes.rows[0]
      if (!doc) throw { code: 'not_found' }

      const updated = await client.query<DocumentRow>(
        `UPDATE driver_documents
            SET status = $1,
                rejection_reason = $2,
                reviewed_by = $3,
                reviewed_at = now(),
                expires_at = COALESCE($4::timestamptz, expires_at),
                updated_at = now()
          WHERE id = $5
          RETURNING *`,
        [
          newStatus,
          newStatus === 'rejected' ? body.rejectionReason!.trim() : null,
          auth.userId,
          body.expiresAt ?? null,
          id,
        ],
      )
      const updatedDoc = updated.rows[0]!

      // Si TODOS los documentos requeridos del driver están approved,
      // auto-verificar al driver.
      // Ronda 131 SECURITY/LEGAL: filtrar por expires_at. Un documento
      // aprobado en 2024 con expires_at=2025 seguía contando como válido
      // años después → driver con SOAT vencido queda is_verified=true, y en
      // un siniestro no hay cobertura + expone al operador a responsabilidad
      // civil/penal. NULL en expires_at = documento sin vencimiento (ok).
      const requiredList = Array.from(REQUIRED_DOC_TYPES)
      const approvedRes = await client.query<{ doc_type: string }>(
        `SELECT doc_type FROM driver_documents
          WHERE driver_id = $1 AND status = 'approved'
            AND doc_type = ANY($2::text[])
            AND (expires_at IS NULL OR expires_at > now())`,
        [doc.driver_id, requiredList],
      )
      const approvedTypes = new Set(approvedRes.rows.map((r) => r.doc_type))
      const allApproved = requiredList.every((t) => approvedTypes.has(t))

      let driverVerified: boolean | null = null
      if (allApproved) {
        await client.query(
          `UPDATE users SET is_verified = true, updated_at = now() WHERE id = $1`,
          [doc.driver_id],
        )
        driverVerified = true
      } else if (
        (newStatus === 'rejected' || newStatus === 'expired') &&
        REQUIRED_DOC_TYPES.has(doc.doc_type)
      ) {
        // Ronda 67: solo desverificar cuando el documento rechazado/expirado
        // ES uno de los REQUERIDOS. Antes: rechazar un doc opcional
        // (vehicle_photo, etc) apagaba is_verified aunque los 5 requeridos
        // siguieran approved → driver quedaba "no verificado" sin razón.
        await client.query(
          `UPDATE users SET is_verified = false, updated_at = now() WHERE id = $1`,
          [doc.driver_id],
        )
        driverVerified = false
      }

      // Notificar al driver
      const title = newStatus === 'approved'
        ? 'Documento aprobado'
        : newStatus === 'rejected'
          ? 'Documento rechazado'
          : 'Documento expirado'
      const notifBody = newStatus === 'rejected'
        ? `Tu documento (${doc.doc_type}) fue rechazado: ${body.rejectionReason}`
        : newStatus === 'approved'
          ? `Tu documento (${doc.doc_type}) fue aprobado. ${driverVerified ? 'Ya eres un conductor verificado.' : ''}`
          : `Tu documento (${doc.doc_type}) expiró. Debes subirlo de nuevo.`
      await client.query(
        `INSERT INTO notifications (user_id, type, title, body, data)
         VALUES ($1, 'document_review', $2, $3, $4::jsonb)`,
        [
          doc.driver_id,
          title,
          notifBody,
          JSON.stringify({
            documentId: id,
            docType: doc.doc_type,
            status: newStatus,
            driverVerified,
          }),
        ],
      )

      return { doc: updatedDoc, driverVerified }
    })

    // Auditoría fuera de la tx
    await query(
      `INSERT INTO auth_events (user_id, event_type, provider, ip_address, user_agent, metadata)
       VALUES ($1, 'admin_document_review', 'admin', $2, $3, $4::jsonb)`,
      [
        result.doc.driver_id,
        getClientIp(req),
        req.headers.get('user-agent'),
        JSON.stringify({
          documentId: id,
          docType: result.doc.doc_type,
          newStatus,
          reviewedBy: auth.userId,
          driverVerified: result.driverVerified,
        }),
      ],
    )

    return NextResponse.json({
      success: true,
      document: {
        id: result.doc.id,
        driverId: result.doc.driver_id,
        docType: result.doc.doc_type,
        status: result.doc.status,
        rejectionReason: result.doc.rejection_reason,
        reviewedBy: result.doc.reviewed_by,
        reviewedAt: result.doc.reviewed_at,
        expiresAt: result.doc.expires_at,
        updatedAt: result.doc.updated_at,
      },
      driverVerified: result.driverVerified,
    })
  } catch (err) {
    if ((err as { code?: string })?.code === 'not_found') {
      return NextResponse.json({ success: false, error: 'not_found' }, { status: 404 })
    }
    console.error('[admin/documents/PATCH] error:', err)
    return NextResponse.json({ success: false, error: 'server_error' }, { status: 500 })
  }
}

// GET del documento individual (para preview)
export async function GET(req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  const auth = await requireAdmin(req)
  if (!auth.ok) return auth.response
  const { id } = await ctx.params
  if (!isUuid(id)) {
    return NextResponse.json({ success: false, error: 'invalid_id' }, { status: 400 })
  }

  const doc = await maybeOne<DocumentRow & { driver_full_name: string | null; driver_email: string | null; driver_phone: string | null }>(
    `SELECT d.*, u.full_name AS driver_full_name, u.email AS driver_email, u.phone AS driver_phone
       FROM driver_documents d
       JOIN users u ON u.id = d.driver_id
      WHERE d.id = $1`,
    [id],
  )
  if (!doc) {
    return NextResponse.json({ success: false, error: 'not_found' }, { status: 404 })
  }
  return NextResponse.json({
    success: true,
    document: {
      id: doc.id,
      driverId: doc.driver_id,
      docType: doc.doc_type,
      fileUrl: doc.file_url,
      status: doc.status,
      rejectionReason: doc.rejection_reason,
      reviewedBy: doc.reviewed_by,
      reviewedAt: doc.reviewed_at,
      expiresAt: doc.expires_at,
      metadata: doc.metadata,
      createdAt: doc.created_at,
      updatedAt: doc.updated_at,
      driver: {
        id: doc.driver_id,
        fullName: doc.driver_full_name,
        email: doc.driver_email,
        phone: doc.driver_phone,
      },
    },
  })
}
