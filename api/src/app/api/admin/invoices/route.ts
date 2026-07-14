/**
 * GET  /api/admin/invoices?status=&type=&customerId=&search=&fromDate=&toDate=
 * POST /api/admin/invoices
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAdmin } from '@/lib/admin-middleware'
import { query, maybeOne } from '@/lib/db'

export const runtime = 'nodejs'

interface InvoiceRow {
  id: string
  series: string
  correlative: number
  document_type: string
  customer_id: string | null
  customer_doc_type: string | null
  customer_doc: string | null
  customer_name: string
  customer_email: string | null
  customer_address: string | null
  recharge_id: string | null
  ride_id: string | null
  subtotal: string
  igv: string
  total: string
  currency: string
  items: unknown
  status: string
  pdf_url: string | null
  xml_url: string | null
  issued_by: string | null
  issued_at: Date
  voided_at: Date | null
  metadata: unknown
  created_at: Date
  total_count: string
}

interface InvoiceItemInput {
  description?: string
  quantity?: number
  unitPrice?: number
  total?: number
}

const IGV_RATE = 0.18

function serialize(r: InvoiceRow) {
  return {
    id: r.id,
    series: r.series,
    correlative: r.correlative,
    number: `${r.series}-${String(r.correlative).padStart(8, '0')}`,
    documentType: r.document_type,
    customerId: r.customer_id,
    customerDocType: r.customer_doc_type,
    customerDoc: r.customer_doc,
    customerName: r.customer_name,
    customerEmail: r.customer_email,
    customerAddress: r.customer_address,
    rechargeId: r.recharge_id,
    rideId: r.ride_id,
    subtotal: Number(r.subtotal),
    igv: Number(r.igv),
    total: Number(r.total),
    currency: r.currency,
    items: r.items,
    status: r.status,
    pdfUrl: r.pdf_url,
    xmlUrl: r.xml_url,
    issuedBy: r.issued_by,
    issuedAt: r.issued_at,
    voidedAt: r.voided_at,
    metadata: r.metadata,
    createdAt: r.created_at,
  }
}

export async function GET(req: NextRequest) {
  const auth = await requireAdmin(req)
  if (!auth.ok) return auth.response

  const { searchParams } = new URL(req.url)
  const status = searchParams.get('status')
  const type = searchParams.get('type')
  const customerId = searchParams.get('customerId')
  const search = (searchParams.get('search') ?? '').trim().toLowerCase()
  const fromDate = searchParams.get('fromDate')
  const toDate = searchParams.get('toDate')
  const page = Math.max(1, Number(searchParams.get('page') ?? '1'))
  const pageSize = Math.min(100, Math.max(1, Number(searchParams.get('pageSize') ?? '50')))
  const offset = (page - 1) * pageSize

  const where: string[] = []
  const params: unknown[] = []
  if (status) { params.push(status); where.push(`status = $${params.length}`) }
  if (type) { params.push(type); where.push(`document_type = $${params.length}`) }
  if (customerId) { params.push(customerId); where.push(`customer_id = $${params.length}`) }
  if (fromDate) { params.push(fromDate); where.push(`issued_at >= $${params.length}`) }
  if (toDate) { params.push(toDate); where.push(`issued_at <= $${params.length}`) }
  if (search) {
    params.push(`%${search}%`)
    where.push(`(LOWER(customer_name) LIKE $${params.length} OR LOWER(customer_email) LIKE $${params.length} OR customer_doc LIKE $${params.length} OR series || '-' || correlative::text LIKE $${params.length})`)
  }
  const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : ''

  const rows = await query<InvoiceRow>(
    `SELECT *, COUNT(*) OVER() AS total_count
       FROM invoices
       ${whereSql}
       ORDER BY issued_at DESC
       LIMIT ${pageSize} OFFSET ${offset}`,
    params,
  )
  const total = rows.length ? Number(rows[0].total_count) : 0

  return NextResponse.json({
    success: true,
    invoices: rows.map(serialize),
    page, pageSize, total, totalPages: Math.ceil(total / pageSize),
  })
}

/**
 * Body: {
 *   documentType: 'receipt'|'invoice'|'boleta',
 *   customerId?: string,
 *   customerDocType?: 'DNI'|'RUC'|'CE'|'PASSPORT',
 *   customerDoc?: string,
 *   customerName: string,
 *   customerEmail?: string,
 *   customerAddress?: string,
 *   rechargeId?: string,
 *   rideId?: string,
 *   items: Array<{ description, quantity, unitPrice }>,
 *   includeIgv?: boolean (default true excepto receipt)
 * }
 */
export async function POST(req: NextRequest) {
  const auth = await requireAdmin(req)
  if (!auth.ok) return auth.response

  let body: {
    documentType?: string
    customerId?: string | null
    customerDocType?: string
    customerDoc?: string
    customerName?: string
    customerEmail?: string
    customerAddress?: string
    rechargeId?: string | null
    rideId?: string | null
    items?: InvoiceItemInput[]
    includeIgv?: boolean
  } = {}
  try { body = await req.json() } catch {
    return NextResponse.json({ success: false, error: 'bad_json' }, { status: 400 })
  }

  const allowedTypes = new Set(['receipt', 'invoice', 'boleta'])
  if (!body.documentType || !allowedTypes.has(body.documentType)) {
    return NextResponse.json({ success: false, error: 'invalid_document_type' }, { status: 400 })
  }
  if (!body.customerName || body.customerName.trim().length === 0) {
    return NextResponse.json({ success: false, error: 'customer_name_required' }, { status: 400 })
  }
  if (body.documentType === 'invoice' && (!body.customerDoc || body.customerDocType !== 'RUC')) {
    return NextResponse.json({ success: false, error: 'invoice_requires_ruc' }, { status: 400 })
  }

  // Validaciones de formato SUNAT — SIN esto, XML enviado a SUNAT es rechazado
  // y se generan contingencias fiscales.
  if (body.customerDoc && body.customerDocType) {
    const doc = body.customerDoc.trim()
    const dt = body.customerDocType
    if (dt === 'RUC') {
      // RUC: 11 dígitos, empieza con 10/15/17/20 + checksum mod-11
      if (!/^(10|15|17|20)\d{9}$/.test(doc)) {
        return NextResponse.json(
          { success: false, error: 'invalid_ruc', message: 'RUC debe tener 11 dígitos y empezar con 10, 15, 17 o 20' },
          { status: 400 },
        )
      }
      // Checksum mod-11 SUNAT
      const factors = [5, 4, 3, 2, 7, 6, 5, 4, 3, 2]
      let sum = 0
      for (let i = 0; i < 10; i++) sum += Number(doc[i]) * factors[i]!
      const check = (11 - (sum % 11)) % 10
      if (check !== Number(doc[10])) {
        return NextResponse.json(
          { success: false, error: 'invalid_ruc_checksum', message: 'Dígito verificador del RUC inválido' },
          { status: 400 },
        )
      }
    } else if (dt === 'DNI') {
      if (!/^\d{8}$/.test(doc)) {
        return NextResponse.json(
          { success: false, error: 'invalid_dni', message: 'DNI debe tener exactamente 8 dígitos' },
          { status: 400 },
        )
      }
    } else if (dt === 'CE') {
      if (!/^\d{9,12}$/.test(doc)) {
        return NextResponse.json(
          { success: false, error: 'invalid_ce', message: 'Carnet de extranjería debe tener entre 9 y 12 dígitos' },
          { status: 400 },
        )
      }
    }
  }
  if (!Array.isArray(body.items) || body.items.length === 0) {
    return NextResponse.json({ success: false, error: 'items_required' }, { status: 400 })
  }

  // Calcular montos
  const normalizedItems = body.items.map((it) => {
    const qty = Number(it.quantity ?? 1)
    const unitPrice = Number(it.unitPrice ?? 0)
    if (!isFinite(qty) || qty <= 0 || !isFinite(unitPrice) || unitPrice <= 0) {
      throw new Error('invalid_item')
    }
    return {
      description: (it.description ?? '').trim() || 'Servicio',
      quantity: qty,
      unitPrice,
      total: Number((qty * unitPrice).toFixed(2)),
    }
  })
  // Sistema de redondeo estable: si el usuario pasa precios YA con IGV,
  // subtotal = round(sum(items) / (1 + IGV)) y igv = round(subtotal * IGV) →
  // total efectivo = subtotal + igv (puede diferir 1 centavo del total tipeado).
  // Si NO incluye IGV, subtotal = sum(items) y total = subtotal (receipt).
  const includeIgv = body.includeIgv !== false && body.documentType !== 'receipt'
  const rawSum = normalizedItems.reduce((acc, it) => acc + it.total, 0)
  const subtotal = includeIgv ? Number((rawSum / (1 + IGV_RATE)).toFixed(2)) : Number(rawSum.toFixed(2))
  const igv = includeIgv ? Number((subtotal * IGV_RATE).toFixed(2)) : 0
  const total = Number((subtotal + igv).toFixed(2))

  // Serie según tipo
  const series =
    body.documentType === 'invoice' ? 'F001' :
    body.documentType === 'boleta' ? 'B001' :
    'R001'

  // Correlativo con retry para tolerar race conditions (dos admins emitiendo
  // al mismo tiempo). El UNIQUE (series, correlative) rechaza el segundo;
  // reintentamos con `max+1` hasta 3 veces.
  let created: InvoiceRow | null = null
  let lastError: unknown = null
  for (let attempt = 0; attempt < 3; attempt++) {
    const last = await maybeOne<{ max_correlative: number | null }>(
      `SELECT COALESCE(MAX(correlative), 0)::int AS max_correlative
         FROM invoices WHERE series = $1`,
      [series],
    )
    const correlative = (last?.max_correlative ?? 0) + 1
    try {
      created = await maybeOne<InvoiceRow>(
        `INSERT INTO invoices (
           series, correlative, document_type,
           customer_id, customer_doc_type, customer_doc, customer_name, customer_email, customer_address,
           recharge_id, ride_id,
           subtotal, igv, total, items,
           issued_by
         ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15::jsonb,$16)
         RETURNING *`,
        [
          series, correlative, body.documentType,
          body.customerId ?? null, body.customerDocType ?? null, body.customerDoc ?? null,
          body.customerName.trim(), body.customerEmail ?? null, body.customerAddress ?? null,
          body.rechargeId ?? null, body.rideId ?? null,
          subtotal, igv, total, JSON.stringify(normalizedItems),
          auth.userId,
        ],
      )
      break
    } catch (e) {
      lastError = e
      const code = (e as { code?: string }).code
      if (code !== '23505') throw e // no es unique violation → re-raise
      // duplicate correlative → reintentar
    }
  }
  if (!created) {
    console.error('[invoices POST] correlative collision after 3 retries:', lastError)
    return NextResponse.json({ success: false, error: 'insert_failed' }, { status: 500 })
  }

  return NextResponse.json({ success: true, invoice: serialize(created) }, { status: 201 })
}
