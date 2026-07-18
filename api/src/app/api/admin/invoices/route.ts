/**
 * GET  /api/admin/invoices?status=&type=&customerId=&search=&fromDate=&toDate=
 * POST /api/admin/invoices
 */
import { NextRequest, NextResponse } from 'next/server'
import { requireAdmin } from '@/lib/admin-middleware'
import { query, tx } from '@/lib/db'

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
  // Ronda 27 Bug#1: NaN-safe pagination (?page=abc no debe romper el endpoint)
  const pageRaw = Number(searchParams.get('page') ?? '1')
  const page = Number.isFinite(pageRaw) ? Math.max(1, Math.floor(pageRaw)) : 1
  const pageSizeRaw = Number(searchParams.get('pageSize') ?? '50')
  const pageSize = Number.isFinite(pageSizeRaw) ? Math.min(100, Math.max(1, Math.floor(pageSizeRaw))) : 50
  const offset = (page - 1) * pageSize

  const where: string[] = []
  const params: unknown[] = []
  if (status) { params.push(status); where.push(`status = $${params.length}`) }
  if (type) { params.push(type); where.push(`document_type = $${params.length}`) }
  if (customerId) { params.push(customerId); where.push(`customer_id = $${params.length}`) }
  if (fromDate) { params.push(fromDate); where.push(`issued_at >= $${params.length}::date`) }
  // Ronda 168 SUNAT: toDate como 'YYYY-MM-DD' se cast a TIMESTAMP 00:00:00,
  // así issued_at <= toDate excluía TODAS las facturas emitidas ese día.
  // Reportes mensuales (PLE 14.1, declaración) sub-declaraban sistemáticamente
  // el último día del período → sub-declaración fiscal. Usar `< toDate + 1 day`.
  if (toDate) { params.push(toDate); where.push(`issued_at < ($${params.length}::date + interval '1 day')`) }
  if (search) {
    params.push(`%${search}%`)
    // Ronda 27 Bug#2: aplicar LOWER() a series||'-'||correlative — el search
    // patron es lowercase pero series es MAYUSCULA (F001, B001, R001), así
    // que sin LOWER el LIKE nunca matcheaba. Bug: buscar "F001-00000123" no
    // encontraba la factura correspondiente.
    where.push(`(LOWER(customer_name) LIKE $${params.length} OR LOWER(customer_email) LIKE $${params.length} OR LOWER(customer_doc) LIKE $${params.length} OR LOWER(series || '-' || correlative::text) LIKE $${params.length})`)
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

  // Ronda 214: validación EAGER en vez de throw dentro de .map — antes el
  // throw se propagaba como 500 "internal_error" en vez de 400 "invalid_item".
  // El admin veía "error interno del servidor" al enviar quantity=0.
  const normalizedItems: Array<{
    description: string; quantity: number; unitPrice: number; total: number
  }> = []
  for (const it of body.items) {
    const qty = Number(it.quantity ?? 1)
    const unitPrice = Number(it.unitPrice ?? 0)
    if (!isFinite(qty) || qty <= 0 || !isFinite(unitPrice) || unitPrice <= 0) {
      return NextResponse.json(
        {
          success: false,
          error: 'invalid_item',
          message: `Item inválido: quantity=${it.quantity}, unitPrice=${it.unitPrice}. Ambos deben ser > 0.`,
        },
        { status: 400 },
      )
    }
    normalizedItems.push({
      description: (it.description ?? '').trim() || 'Servicio',
      quantity: qty,
      unitPrice,
      total: Number((qty * unitPrice).toFixed(2)),
    })
  }
  // Ronda 152 SUNAT: derivar IGV de la resta rawSum-subtotal, NO re-multiplicar
  // el subtotal redondeado por IGV_RATE. Con precios "redondos" (ej. unitPrice
  // 100 IGV-incluido → subtotal=84.75, subtotal*0.18=15.255 round→15.26, pero
  // rawSum-subtotal=15.25). El descuadre de 1 centavo hace que
  // montoImporteVenta != Σ item.montoTotal → SUNAT rechaza con error 2019
  // ("monto total no cuadra") y el correlativo queda gastado.
  const includeIgv = body.includeIgv !== false && body.documentType !== 'receipt'
  const rawSum = Number(normalizedItems.reduce((acc, it) => acc + it.total, 0).toFixed(2))
  const subtotal = includeIgv ? Number((rawSum / (1 + IGV_RATE)).toFixed(2)) : rawSum
  const igv = includeIgv ? Number((rawSum - subtotal).toFixed(2)) : 0
  const total = includeIgv ? rawSum : subtotal

  // Serie según tipo
  const series =
    body.documentType === 'invoice' ? 'F001' :
    body.documentType === 'boleta' ? 'B001' :
    'R001'

  // Ronda 214 SUNAT CRÍTICO: advisory lock por serie. Antes el patrón era
  // "SELECT MAX correlative + retry si UNIQUE viola" — bajo 4+ admins
  // concurrentes se agota en el 3er intento y devuelve 500. El correlativo
  // queda gastado (row inserted en INSERT que rechazó UNIQUE, no) → gaps
  // en la serie que SUNAT rechaza en la declaración mensual. Ahora
  // serializamos con advisory_xact_lock(hash('sunat_invoices'), hash(series))
  // — bajo lock, MAX(correlative)+1 es determinístico. UNIQUE queda como
  // safety net por si dos procesos hicieran corrupción concurrente.
  // Narrowing local: la validación de línea 176 garantiza que customerName
  // no es undefined/empty aquí, pero TS lo pierde en la closure del tx.
  const customerName = body.customerName!.trim()

  let created: InvoiceRow | null = null
  try {
    created = await tx(async (client) => {
      // Namespace 'sunat_invoices' (hash int stable) + hash(series) → único
      // slot por serie. Otras tx tocando misma serie esperan aquí.
      await client.query(
        `SELECT pg_advisory_xact_lock(hashtext('sunat_invoices'), hashtext($1))`,
        [series],
      )
      const last = await client.query<{ max_correlative: number | null }>(
        `SELECT COALESCE(MAX(correlative), 0)::int AS max_correlative
           FROM invoices WHERE series = $1`,
        [series],
      )
      const correlative = (last.rows[0]?.max_correlative ?? 0) + 1
      const insertRes = await client.query<InvoiceRow>(
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
          customerName, body.customerEmail ?? null, body.customerAddress ?? null,
          body.rechargeId ?? null, body.rideId ?? null,
          subtotal, igv, total, JSON.stringify(normalizedItems),
          auth.userId,
        ],
      )
      return insertRes.rows[0]!
    })
  } catch (e) {
    console.error('[invoices POST] error emitiendo factura:', e)
    return NextResponse.json({ success: false, error: 'insert_failed' }, { status: 500 })
  }

  return NextResponse.json({ success: true, invoice: serialize(created) }, { status: 201 })
}
