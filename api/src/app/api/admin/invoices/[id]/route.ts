/**
 * GET   /api/admin/invoices/:id — detalle
 * PATCH /api/admin/invoices/:id — anular (status → 'voided')
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAdmin } from '@/lib/admin-middleware'
import { maybeOne, tx } from '@/lib/db'
import { isUuid } from '@/lib/uuid'

export const runtime = 'nodejs'

interface Row {
  id: string; series: string; correlative: number; document_type: string
  customer_id: string | null; customer_doc_type: string | null; customer_doc: string | null
  customer_name: string; customer_email: string | null; customer_address: string | null
  recharge_id: string | null; ride_id: string | null
  subtotal: string; igv: string; total: string; currency: string
  items: unknown; status: string; pdf_url: string | null; xml_url: string | null
  issued_by: string | null; issued_at: Date; voided_at: Date | null
  metadata: unknown; created_at: Date
}
function serialize(r: Row) {
  return {
    id: r.id, series: r.series, correlative: r.correlative,
    number: `${r.series}-${String(r.correlative).padStart(8, '0')}`,
    documentType: r.document_type,
    customerId: r.customer_id, customerDocType: r.customer_doc_type,
    customerDoc: r.customer_doc, customerName: r.customer_name,
    customerEmail: r.customer_email, customerAddress: r.customer_address,
    rechargeId: r.recharge_id, rideId: r.ride_id,
    subtotal: Number(r.subtotal), igv: Number(r.igv), total: Number(r.total), currency: r.currency,
    items: r.items, status: r.status, pdfUrl: r.pdf_url, xmlUrl: r.xml_url,
    issuedBy: r.issued_by, issuedAt: r.issued_at, voidedAt: r.voided_at,
    metadata: r.metadata, createdAt: r.created_at,
  }
}

export async function GET(req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const auth = await requireAdmin(req)
  if (!auth.ok) return auth.response
  const { id } = await params
  if (!isUuid(id)) {
    return NextResponse.json({ success: false, error: 'invalid_id' }, { status: 400 })
  }
  const row = await maybeOne<Row>(`SELECT * FROM invoices WHERE id = $1`, [id])
  if (!row) return NextResponse.json({ success: false, error: 'not_found' }, { status: 404 })
  return NextResponse.json({ success: true, invoice: serialize(row) })
}

export async function PATCH(req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  const auth = await requireAdmin(req)
  if (!auth.ok) return auth.response
  const { id } = await params
  if (!isUuid(id)) {
    return NextResponse.json({ success: false, error: 'invalid_id' }, { status: 400 })
  }

  let body: { status?: string; notes?: string } = {}
  try { body = await req.json() } catch {
    return NextResponse.json({ success: false, error: 'bad_json' }, { status: 400 })
  }

  if (body.status !== 'voided') {
    return NextResponse.json({ success: false, error: 'invalid_status_change' }, { status: 400 })
  }

  // Ronda 42 Bug#2: TOCTOU — SELECT status + credit_notes COUNT + UPDATE
  // deben correr atómicamente. Sin esto, un POST /credit-notes concurrente
  // entre el COUNT y el UPDATE deja la factura voided con notas de credito
  // existentes (invariante roto).
  // Ronda 42 Bug#1: usar el rowCount del UPDATE para responder 404/409 en
  // vez de non-null assertion sobre maybeOne (que puede devolver null).
  try {
    const updated = await tx(async (client) => {
      const cur = await client.query<{ status: string }>(
        `SELECT status FROM invoices WHERE id = $1 FOR UPDATE`,
        [id],
      )
      if (cur.rowCount === 0) throw { code: 'not_found' }
      if (cur.rows[0]!.status === 'voided') throw { code: 'already_voided' }

      const hasNotes = await client.query<{ count: string }>(
        `SELECT COUNT(*)::text AS count FROM credit_notes WHERE invoice_id = $1`,
        [id],
      )
      if (Number(hasNotes.rows[0]?.count ?? '0') > 0) {
        throw { code: 'has_credit_notes' }
      }

      const voidReasonJson = body.notes
        ? `jsonb_build_object('voidedBy', $2::text, 'voidReason', $3::text)`
        : `jsonb_build_object('voidedBy', $2::text)`
      const updParams: unknown[] = body.notes ? [id, auth.userId, body.notes] : [id, auth.userId]
      const res = await client.query<Row>(
        `UPDATE invoices
            SET status = 'voided',
                voided_at = NOW(),
                metadata = COALESCE(metadata, '{}'::jsonb) || ${voidReasonJson}
          WHERE id = $1
          RETURNING *`,
        updParams,
      )
      if (res.rowCount === 0) throw { code: 'not_found' }
      return res.rows[0]!
    })
    return NextResponse.json({ success: true, invoice: serialize(updated) })
  } catch (err) {
    const code = (err as { code?: string })?.code
    if (code === 'not_found') {
      return NextResponse.json({ success: false, error: 'not_found' }, { status: 404 })
    }
    if (code === 'already_voided') {
      return NextResponse.json({ success: false, error: 'already_voided' }, { status: 400 })
    }
    if (code === 'has_credit_notes') {
      return NextResponse.json({
        success: false,
        error: 'has_credit_notes',
        message: 'Esta factura ya tiene notas de crédito emitidas. Emite una nota de anulación desde Notas de Crédito.',
      }, { status: 400 })
    }
    console.error('[admin/invoices PATCH] error:', err)
    return NextResponse.json({ success: false, error: 'internal_error' }, { status: 500 })
  }
}
