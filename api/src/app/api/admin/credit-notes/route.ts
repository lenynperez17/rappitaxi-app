/**
 * GET  /api/admin/credit-notes?status=&invoiceId=&search=&fromDate=&toDate=
 * POST /api/admin/credit-notes
 *   Body: { invoiceId, reason, reasonNotes?, amount?  }
 *   Si no se pasa amount, se anula el total de la factura.
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAdmin } from '@/lib/admin-middleware'
import { query, tx } from '@/lib/db'

export const runtime = 'nodejs'

interface CreditNoteRow {
  id: string
  series: string
  correlative: number
  invoice_id: string
  reason: string
  reason_notes: string | null
  amount: string
  status: string
  pdf_url: string | null
  xml_url: string | null
  issued_by: string | null
  issued_at: Date
  metadata: unknown
  created_at: Date
  total_count?: string
  invoice_number?: string
  invoice_customer?: string
}

function serialize(r: CreditNoteRow) {
  return {
    id: r.id,
    series: r.series,
    correlative: r.correlative,
    number: `${r.series}-${String(r.correlative).padStart(8, '0')}`,
    invoiceId: r.invoice_id,
    invoiceNumber: r.invoice_number,
    invoiceCustomer: r.invoice_customer,
    reason: r.reason,
    reasonNotes: r.reason_notes,
    amount: Number(r.amount),
    status: r.status,
    pdfUrl: r.pdf_url,
    xmlUrl: r.xml_url,
    issuedBy: r.issued_by,
    issuedAt: r.issued_at,
    metadata: r.metadata,
    createdAt: r.created_at,
  }
}

export async function GET(req: NextRequest) {
  const auth = await requireAdmin(req)
  if (!auth.ok) return auth.response

  const { searchParams } = new URL(req.url)
  const status = searchParams.get('status')
  const invoiceId = searchParams.get('invoiceId')
  const search = (searchParams.get('search') ?? '').trim().toLowerCase()
  const fromDate = searchParams.get('fromDate')
  const toDate = searchParams.get('toDate')
  const page = Math.max(1, Number(searchParams.get('page') ?? '1'))
  const pageSize = Math.min(100, Math.max(1, Number(searchParams.get('pageSize') ?? '50')))
  const offset = (page - 1) * pageSize

  const where: string[] = []
  const params: unknown[] = []
  if (status) { params.push(status); where.push(`cn.status = $${params.length}`) }
  if (invoiceId) { params.push(invoiceId); where.push(`cn.invoice_id = $${params.length}`) }
  if (fromDate) { params.push(fromDate); where.push(`cn.issued_at >= $${params.length}`) }
  if (toDate) { params.push(toDate); where.push(`cn.issued_at <= $${params.length}`) }
  if (search) {
    params.push(`%${search}%`)
    where.push(`(LOWER(i.customer_name) LIKE $${params.length} OR cn.series || '-' || cn.correlative::text LIKE $${params.length})`)
  }
  const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : ''

  const rows = await query<CreditNoteRow>(
    `SELECT cn.*,
            i.series || '-' || LPAD(i.correlative::text, 8, '0') AS invoice_number,
            i.customer_name AS invoice_customer,
            COUNT(*) OVER() AS total_count
       FROM credit_notes cn
       LEFT JOIN invoices i ON i.id = cn.invoice_id
       ${whereSql}
       ORDER BY cn.issued_at DESC
       LIMIT ${pageSize} OFFSET ${offset}`,
    params,
  )
  const total = rows.length ? Number(rows[0].total_count) : 0

  return NextResponse.json({
    success: true,
    creditNotes: rows.map(serialize),
    page, pageSize, total, totalPages: Math.ceil(total / pageSize),
  })
}

export async function POST(req: NextRequest) {
  const auth = await requireAdmin(req)
  if (!auth.ok) return auth.response

  let body: {
    invoiceId?: string
    reason?: string
    reasonNotes?: string
    amount?: number
  } = {}
  try { body = await req.json() } catch {
    return NextResponse.json({ success: false, error: 'bad_json' }, { status: 400 })
  }

  if (!body.invoiceId) {
    return NextResponse.json({ success: false, error: 'invoice_id_required' }, { status: 400 })
  }
  const allowedReasons = new Set(['anulacion', 'devolucion', 'descuento_global', 'descuento_item', 'ajuste_precio', 'otros'])
  if (!body.reason || !allowedReasons.has(body.reason)) {
    return NextResponse.json({ success: false, error: 'invalid_reason' }, { status: 400 })
  }

  // B#8: TODO el chequeo de sum + insert va dentro de una transacción con
  // `FOR UPDATE` sobre la factura. Sin esto, dos admins pueden pasar el check
  // "sum + amount <= total" concurrentemente y crear notas que en total excedan.
  const series = 'FC01'
  let created: CreditNoteRow | null = null
  let invoiceTotalOut = 0
  let attemptError: unknown = null

  try {
    for (let attempt = 0; attempt < 3; attempt++) {
      try {
        const outcome = await tx(async (client) => {
          const invRes = await client.query<{ id: string; total: string; document_type: string; status: string }>(
            `SELECT id, total, document_type, status
               FROM invoices WHERE id = $1
               FOR UPDATE`,
            [body.invoiceId],
          )
          const invoice = invRes.rows[0]
          if (!invoice) throw { httpStatus: 404, error: 'invoice_not_found' }
          if (invoice.status === 'voided') throw { httpStatus: 400, error: 'invoice_voided' }
          if (invoice.document_type === 'receipt') throw { httpStatus: 400, error: 'receipts_no_credit_notes' }

          const invoiceTotal = Number(invoice.total)
          const amt = body.amount != null ? Number(body.amount) : invoiceTotal
          if (!isFinite(amt) || amt <= 0 || amt > invoiceTotal) {
            throw { httpStatus: 400, error: 'invalid_amount' }
          }

          const sumRes = await client.query<{ acc: string }>(
            `SELECT COALESCE(SUM(amount), 0)::text AS acc
               FROM credit_notes WHERE invoice_id = $1`,
            [body.invoiceId],
          )
          const alreadyIssued = Number(sumRes.rows[0]?.acc ?? '0')
          if (alreadyIssued + amt > invoiceTotal + 0.01) {
            throw {
              httpStatus: 400,
              error: 'exceeds_invoice_total',
              message: `La suma de notas de crédito (${(alreadyIssued + amt).toFixed(2)}) excede el total de la factura (${invoiceTotal.toFixed(2)}).`,
            }
          }

          const lastRes = await client.query<{ max_correlative: number | null }>(
            `SELECT COALESCE(MAX(correlative), 0)::int AS max_correlative
               FROM credit_notes WHERE series = $1`,
            [series],
          )
          const correlative = (lastRes.rows[0]?.max_correlative ?? 0) + 1

          const insRes = await client.query<CreditNoteRow>(
            `INSERT INTO credit_notes (
               series, correlative, invoice_id, reason, reason_notes, amount, issued_by
             ) VALUES ($1,$2,$3,$4,$5,$6,$7)
             RETURNING *`,
            [series, correlative, body.invoiceId, body.reason, body.reasonNotes ?? null, amt, auth.userId],
          )
          return { row: insRes.rows[0]!, invoiceTotal, amt }
        })
        created = outcome.row
        invoiceTotalOut = outcome.invoiceTotal
        // Mantener contrato original: `amount` sale como number aunque la
        // fila lo tenga como string.
        break
      } catch (e) {
        attemptError = e
        const code = (e as { code?: string }).code
        // 23505 = correlative collision → retry
        if (code === '23505') continue
        throw e
      }
    }
  } catch (e) {
    const known = e as { httpStatus?: number; error?: string; message?: string }
    if (known?.httpStatus) {
      return NextResponse.json(
        { success: false, error: known.error, message: known.message },
        { status: known.httpStatus },
      )
    }
    console.error('[credit-notes POST] tx failed:', e)
    return NextResponse.json({ success: false, error: 'insert_failed' }, { status: 500 })
  }

  if (!created) {
    console.error('[credit-notes POST] correlative collision after retries:', attemptError)
    return NextResponse.json({ success: false, error: 'insert_failed' }, { status: 500 })
  }
  const amount = Number(created.amount)
  const invoiceTotal = invoiceTotalOut

  // Si es anulación total, marcar la factura como voided
  if (body.reason === 'anulacion' && amount === invoiceTotal) {
    await query(
      `UPDATE invoices SET status = 'voided', voided_at = NOW() WHERE id = $1`,
      [body.invoiceId],
    )
  }

  return NextResponse.json({ success: true, creditNote: serialize(created) }, { status: 201 })
}
