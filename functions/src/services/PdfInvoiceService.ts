import PDFDocument from 'pdfkit'
import * as QRCode from 'qrcode'
import { UblInvoiceInput, SUNAT_TIPO_DOC_CODE } from '../utils/sunatTypes'

/**
 * Genera el PDF visualizable del comprobante electronico SUNAT.
 *
 * Formato A4 (612 x 792 pt) con cabecera, datos emisor/receptor,
 * tabla de items, totales, codigo QR y leyenda obligatoria.
 *
 * El QR contiene los datos requeridos por SUNAT (RS 097-2012/SUNAT Anexo 6):
 *   RUC|TIPODOC|SERIE|CORRELATIVO|MTO_IGV|MTO_TOTAL|FECHA_EMISION|TIPO_DOC_REC|NUM_DOC_REC|HASH_CPE
 */

interface PdfInput {
  invoice: UblInvoiceInput
  hashCpe: string
  ambiente: 'beta' | 'produccion' | 'inactivo'
  documentNumber: string // SERIE-CORRELATIVO ya formateado (ej. B001-00000001)
  estadoSunat?: string
}

export async function generateInvoicePdf(input: PdfInput): Promise<Buffer> {
  const { invoice, hashCpe, documentNumber, ambiente, estadoSunat } = input
  const tipoDocCode = SUNAT_TIPO_DOC_CODE[invoice.tipo]

  // Datos del QR - separados por |
  const qrData = [
    invoice.emisorRuc,
    tipoDocCode,
    invoice.serie,
    String(invoice.correlativo),
    invoice.igv.toFixed(2),
    invoice.total.toFixed(2),
    invoice.fechaEmision.toISOString().slice(0, 10),
    String(invoice.receptorTipoDoc === 'DNI' ? 1 : invoice.receptorTipoDoc === 'RUC' ? 6 : 4),
    invoice.receptorNumeroDoc,
    hashCpe,
  ].join('|')

  const qrBuffer = await QRCode.toBuffer(qrData, { width: 150, margin: 1 })

  return new Promise<Buffer>((resolve, reject) => {
    const chunks: Buffer[] = []
    const doc = new PDFDocument({ size: 'A4', margin: 40 })
    doc.on('data', (chunk) => chunks.push(chunk))
    doc.on('end', () => resolve(Buffer.concat(chunks)))
    doc.on('error', reject)

    // === CABECERA ===
    // Marca de agua si esta en beta
    if (ambiente === 'beta') {
      doc
        .save()
        .fillColor('#cccccc')
        .fontSize(60)
        .opacity(0.15)
        .rotate(-30, { origin: [300, 400] })
        .text('HOMOLOGACION', 100, 350, { align: 'center', width: 400 })
        .restore()
    }

    doc.fillColor('#000').opacity(1)

    // Logo y datos emisor (izquierda)
    doc.fontSize(18).font('Helvetica-Bold').text(invoice.emisorRazonSocial, 40, 40, { width: 300 })
    if (invoice.emisorNombreComercial) {
      doc.fontSize(10).font('Helvetica').text(invoice.emisorNombreComercial, 40, 65)
    }
    doc.fontSize(9).font('Helvetica')
    doc.text(`RUC: ${invoice.emisorRuc}`, 40, 80)
    doc.text(invoice.emisorDireccion, 40, 92, { width: 300 })

    // Recuadro con tipo y numero de comprobante (derecha)
    doc.rect(380, 40, 175, 75).stroke()
    doc.fontSize(11).font('Helvetica-Bold').text(`R.U.C. ${invoice.emisorRuc}`, 380, 48, { width: 175, align: 'center' })
    const tipoLabel = invoice.tipo === 'factura' ? 'FACTURA ELECTRONICA' : 'BOLETA DE VENTA ELECTRONICA'
    doc.text(tipoLabel, 380, 70, { width: 175, align: 'center' })
    doc.fontSize(13).text(documentNumber, 380, 92, { width: 175, align: 'center' })

    // === DATOS GENERALES ===
    let y = 140
    doc.fontSize(9).font('Helvetica')
    doc.text(`Fecha de emision: ${invoice.fechaEmision.toISOString().slice(0, 10)}`, 40, y)
    doc.text(`Moneda: Soles (PEN)`, 40, y + 12)

    // === DATOS RECEPTOR ===
    y += 40
    doc.fontSize(10).font('Helvetica-Bold').text('CLIENTE', 40, y)
    y += 14
    doc.fontSize(9).font('Helvetica')
    doc.text(`${invoice.receptorTipoDoc}: ${invoice.receptorNumeroDoc}`, 40, y)
    doc.text(`Razon social: ${invoice.receptorNombre}`, 40, y + 12)
    if (invoice.receptorDireccion) {
      doc.text(`Direccion: ${invoice.receptorDireccion}`, 40, y + 24, { width: 500 })
    }

    // === TABLA DE ITEMS ===
    y += 60
    const tableTop = y
    const colX = { qty: 40, desc: 100, unit: 360, igv: 430, total: 500 }
    doc.fontSize(9).font('Helvetica-Bold')
    doc.rect(40, tableTop, 515, 18).fill('#f0f0f0').stroke()
    doc.fillColor('#000')
    doc.text('Cantidad', colX.qty, tableTop + 5)
    doc.text('Descripcion', colX.desc, tableTop + 5)
    doc.text('V. Unitario', colX.unit, tableTop + 5)
    doc.text('IGV', colX.igv, tableTop + 5)
    doc.text('Total', colX.total, tableTop + 5)

    y = tableTop + 22
    doc.font('Helvetica')
    invoice.items.forEach((item) => {
      doc.text(String(item.cantidad), colX.qty, y)
      doc.text(item.descripcion, colX.desc, y, { width: 250 })
      doc.text(item.valorUnitario.toFixed(2), colX.unit, y)
      doc.text(item.igv.toFixed(2), colX.igv, y)
      doc.text(item.total.toFixed(2), colX.total, y)
      y += 16
    })

    doc.moveTo(40, y).lineTo(555, y).stroke()
    y += 10

    // === TOTALES ===
    doc.font('Helvetica-Bold')
    doc.text('Subtotal:', 400, y, { width: 60, align: 'right' })
    doc.text(`S/ ${invoice.subtotal.toFixed(2)}`, 470, y, { width: 80, align: 'right' })
    y += 14
    doc.text('IGV (18%):', 400, y, { width: 60, align: 'right' })
    doc.text(`S/ ${invoice.igv.toFixed(2)}`, 470, y, { width: 80, align: 'right' })
    y += 14
    doc.fontSize(11)
    doc.text('TOTAL:', 400, y, { width: 60, align: 'right' })
    doc.text(`S/ ${invoice.total.toFixed(2)}`, 470, y, { width: 80, align: 'right' })

    // === QR + HASH ===
    y += 50
    doc.image(qrBuffer, 40, y, { width: 100, height: 100 })
    doc.fontSize(8).font('Helvetica')
    doc.text(`Hash CPE: ${hashCpe}`, 150, y + 10, { width: 400 })
    doc.text(
      'Representacion impresa del Comprobante Electronico.',
      150,
      y + 30,
      { width: 400 },
    )
    doc.text(
      'Consulte la validez en: https://www.sunat.gob.pe/cl-ti-itmrconsmcppl/jcrS00Alias',
      150,
      y + 45,
      { width: 400 },
    )
    if (estadoSunat) {
      doc.text(`Estado SUNAT: ${estadoSunat.toUpperCase()}`, 150, y + 65, { width: 400 })
    }

    // === FOOTER ===
    doc
      .fontSize(7)
      .fillColor('#666')
      .text(
        `Generado por Rapi Team Admin Panel - ${new Date().toISOString()}`,
        40,
        780,
        { width: 515, align: 'center' },
      )

    doc.end()
  })
}
