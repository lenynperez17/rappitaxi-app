import * as admin from 'firebase-admin'
import { randomUUID } from 'crypto'
import {
  AmbienteSunat,
  CompanySettings,
  CreditNoteInput,
  IGV_RATE,
  MotivoNotaCredito,
  SUNAT_TIPO_DOC_CODE,
  TIPO_AFECTACION_IGV_GRAVADO,
  TipoComprobante,
  UblInvoiceInput,
} from '../utils/sunatTypes'
import { buildUnsignedInvoiceXml, buildXmlFilename } from '../utils/ublXmlBuilder'
import { buildUnsignedCreditNoteXml, buildCreditNoteFilename } from '../utils/ublCreditNoteBuilder'
import { extractCertFromP12, signUblXml } from '../utils/digitalSignature'
import { SunatService } from './SunatService'
import { generateInvoicePdf } from './PdfInvoiceService'

/**
 * Orquesta la emision de un comprobante electronico SUNAT.
 *
 * Flujo:
 *   1. Lee `companySettings/main` y `driverRecharges/{rechargeId}`
 *   2. Asigna correlativo atomicamente (transaccion)
 *   3. Construye Invoice UBL 2.1 (sin firma)
 *   4. Firma el XML con el .p12 (cargado de Storage en runtime)
 *   5. Si ambiente = 'inactivo' -> solo PDF interno
 *   6. Si ambiente = 'beta' o 'produccion' -> envia a SUNAT, recibe CDR
 *   7. Genera PDF y sube XML firmado + CDR + PDF a Storage
 *   8. Crea documento `invoices/{id}` con todas las URLs y datos del comprobante
 *   9. Actualiza la recarga con `invoiceId` e `invoiceNumber`
 */

interface EmitInput {
  rechargeId: string
  tipo: TipoComprobante
  adminUid: string
}

interface EmitResult {
  invoiceId: string
  documentNumber: string
  total: number
  subtotal: number
  igv: number
  estadoSunat: string
  pdfUrl?: string
  cdrUrl?: string
  xmlSignedUrl?: string
  hashCpe?: string
  errorMessage?: string
}

export class InvoiceService {
  private readonly db: admin.firestore.Firestore
  private readonly storage: admin.storage.Storage
  private readonly sunatService: SunatService

  constructor() {
    this.db = admin.firestore()
    this.storage = admin.storage()
    this.sunatService = new SunatService()
  }

  /**
   * Lee y descarga el certificado .p12 desde Cloud Storage.
   * Cachea en memoria por la vida util de la Cloud Function.
   */
  private certCache: Buffer | null = null
  private async getCertificateBuffer(storagePath: string): Promise<Buffer> {
    if (this.certCache) return this.certCache
    const bucket = this.storage.bucket()
    const file = bucket.file(storagePath)
    const [buffer] = await file.download()
    this.certCache = buffer
    return buffer
  }

  async emit(input: EmitInput): Promise<EmitResult> {
    const { rechargeId, tipo, adminUid } = input

    // 1. Cargar settings y recarga
    const settingsSnap = await this.db.collection('companySettings').doc('main').get()
    if (!settingsSnap.exists) {
      throw new Error('companySettings/main no existe — configure los datos fiscales primero')
    }
    const settings = settingsSnap.data() as CompanySettings

    const rechargeRef = this.db.collection('driverRecharges').doc(rechargeId)
    const rechargeSnap = await rechargeRef.get()
    if (!rechargeSnap.exists) {
      throw new Error(`Recarga ${rechargeId} no existe`)
    }
    const recharge = rechargeSnap.data()!
    if (recharge.invoiceId) {
      throw new Error('La recarga ya tiene un comprobante emitido')
    }
    if (recharge.status !== 'approved') {
      throw new Error('Solo se emiten comprobantes para recargas aprobadas')
    }

    // 2. Validacion: factura solo si receptor tiene RUC
    if (tipo === 'factura' && recharge.driverDocumentType !== 'RUC') {
      throw new Error('Para emitir factura, el conductor debe tener tipo de documento RUC')
    }

    // 3. Calcular subtotal/igv/total a partir del grossAmount
    // El monto bruto incluye IGV — invertimos: subtotal = total / 1.18
    const total = Number(recharge.grossAmount)
    const subtotal = Math.round((total / (1 + IGV_RATE)) * 100) / 100
    const igv = Math.round((total - subtotal) * 100) / 100

    // 4. Asignar correlativo atomicamente y crear stub del invoice
    const invoiceRef = this.db.collection('invoices').doc()
    let documentNumber = ''
    let correlativo = 0
    const settingsRef = this.db.collection('companySettings').doc('main')

    await this.db.runTransaction(async (tx) => {
      const sSnap = await tx.get(settingsRef)
      const s = (sSnap.data() ?? settings) as CompanySettings
      if (tipo === 'boleta') {
        correlativo = (s.correlativoActualBoleta ?? 0) + 1
        documentNumber = `${s.serieBoleta || 'B001'}-${String(correlativo).padStart(8, '0')}`
        tx.update(settingsRef, { correlativoActualBoleta: correlativo })
      } else {
        correlativo = (s.correlativoActualFactura ?? 0) + 1
        documentNumber = `${s.serieFactura || 'F001'}-${String(correlativo).padStart(8, '0')}`
        tx.update(settingsRef, { correlativoActualFactura: correlativo })
      }
      // Stub para que la transaccion lo deje reservado
      tx.set(invoiceRef, {
        documentType: tipo,
        serie: tipo === 'boleta' ? s.serieBoleta : s.serieFactura,
        correlativo,
        documentNumber,
        rechargeId,
        status: 'processing',
        estadoSunat: 'pendiente',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        emittedBy: adminUid,
      })
    })

    // 5. Construir invoice UBL
    const ublInput: UblInvoiceInput = {
      tipo,
      serie: tipo === 'boleta' ? settings.serieBoleta || 'B001' : settings.serieFactura || 'F001',
      correlativo,
      fechaEmision: new Date(),

      emisorRuc: settings.ruc,
      emisorRazonSocial: settings.razonSocial,
      emisorNombreComercial: settings.nombreComercial,
      emisorDireccion: settings.direccionFiscal,
      emisorUbigeo: settings.ubigeo,

      receptorTipoDoc: (recharge.driverDocumentType || 'DNI') as any,
      receptorNumeroDoc: recharge.driverDocumentNumber || '00000000',
      receptorNombre: recharge.driverName || 'CLIENTE FINAL',
      receptorDireccion: recharge.driverAddress,

      items: [
        {
          descripcion: 'Recarga de creditos Rapi Team',
          cantidad: 1,
          unidadMedida: 'NIU',
          valorUnitario: subtotal,
          valorTotal: subtotal,
          igv,
          total,
          codigoTipoIgv: TIPO_AFECTACION_IGV_GRAVADO,
        },
      ],

      subtotal,
      igv,
      total,
      moneda: 'PEN',
    }

    const filename = buildXmlFilename(settings.ruc, tipo, ublInput.serie, correlativo)
    const ambiente: AmbienteSunat = settings.ambienteSunat || 'inactivo'

    let signedXml = ''
    let hashCpe = ''
    let estadoSunat = ambiente === 'inactivo' ? 'no_aplica' : 'pendiente'
    let cdrUrl: string | undefined
    let xmlSignedUrl: string | undefined
    let errorMessage: string | undefined
    let responseDescription: string | undefined

    if (ambiente !== 'inactivo' && settings.certificadoStoragePath) {
      try {
        // 6. Construir XML sin firmar
        const unsignedXml = buildUnsignedInvoiceXml(ublInput)

        // 7. Firmar
        // Trim secrets — firebase functions:secrets:set agrega un \n al final del valor
        const certPassword = (process.env.SUNAT_CERT_PASSWORD || '').trim()
        if (!certPassword) throw new Error('SUNAT_CERT_PASSWORD no configurada')
        const p12Buffer = await this.getCertificateBuffer(settings.certificadoStoragePath)
        const cert = extractCertFromP12(p12Buffer, certPassword)
        const signed = signUblXml(unsignedXml, cert)
        signedXml = signed.signedXml
        hashCpe = signed.hashCpe

        // 8. Subir XML firmado a Storage
        xmlSignedUrl = await this.uploadToStorage(
          `invoices/${invoiceRef.id}/${filename}.xml`,
          Buffer.from(signedXml, 'utf-8'),
          'application/xml',
        )

        // 9. Enviar a SUNAT
        const usuarioSol = (process.env.SUNAT_SOL_USER || '').trim()
        const passwordSol = (process.env.SUNAT_SOL_PASSWORD || '').trim()
        if (!usuarioSol || !passwordSol) {
          throw new Error('Credenciales SOL no configuradas (SUNAT_SOL_USER / SUNAT_SOL_PASSWORD)')
        }

        const result = await this.sunatService.sendBill({
          ambiente,
          ruc: settings.ruc,
          usuarioSol,
          passwordSol,
          filename,
          signedXml,
        })

        if (result.success && result.cdrZipBase64) {
          estadoSunat = 'aceptado'
          responseDescription = result.responseDescription
          cdrUrl = await this.uploadToStorage(
            `invoices/${invoiceRef.id}/R-${filename}.zip`,
            Buffer.from(result.cdrZipBase64, 'base64'),
            'application/zip',
          )
        } else {
          estadoSunat = 'rechazado'
          errorMessage = `${result.errorCode || ''}: ${result.errorMessage || ''}`.trim()
        }
      } catch (err: any) {
        console.error('Error en flujo SUNAT:', err)
        estadoSunat = 'error_local'
        errorMessage = err.message || String(err)
      }
    }

    // 10. Generar PDF (siempre, sea ambiente activo o no)
    const pdfBuffer = await generateInvoicePdf({
      invoice: ublInput,
      hashCpe: hashCpe || 'N/A',
      ambiente,
      documentNumber,
      estadoSunat,
    })
    const pdfUrl = await this.uploadToStorage(
      `invoices/${invoiceRef.id}/${filename}.pdf`,
      pdfBuffer,
      'application/pdf',
    )

    // 11. Actualizar el invoice doc con todos los datos finales
    const finalInvoice: any = {
      documentType: tipo,
      serie: ublInput.serie,
      correlativo,
      documentNumber,
      rechargeId,

      emisorRuc: settings.ruc,
      emisorRazonSocial: settings.razonSocial,
      emisorNombreComercial: settings.nombreComercial || null,
      emisorDireccion: settings.direccionFiscal,
      emisorUbigeo: settings.ubigeo,

      receptorTipoDocumento: ublInput.receptorTipoDoc,
      receptorNumeroDocumento: ublInput.receptorNumeroDoc,
      receptorNombre: ublInput.receptorNombre,
      receptorEmail: recharge.driverEmail || null,

      items: ublInput.items,
      subtotal,
      igv,
      total,
      moneda: 'PEN',

      ambienteSunat: ambiente,
      estadoSunat,
      hashCpe: hashCpe || null,
      xmlSignedUrl: xmlSignedUrl || null,
      cdrUrl: cdrUrl || null,
      pdfUrl,
      errorSunat: errorMessage || null,
      responseDescription: responseDescription || null,

      status: estadoSunat === 'aceptado' ? 'issued' : estadoSunat === 'rechazado' ? 'rejected' : 'issued',
      sunatProcessedAt: ambiente !== 'inactivo' ? admin.firestore.FieldValue.serverTimestamp() : null,
    }

    await invoiceRef.update(finalInvoice)
    await rechargeRef.update({
      invoiceId: invoiceRef.id,
      invoiceNumber: documentNumber,
      invoiceUrl: pdfUrl,
    })

    return {
      invoiceId: invoiceRef.id,
      documentNumber,
      total,
      subtotal,
      igv,
      estadoSunat,
      pdfUrl,
      cdrUrl,
      xmlSignedUrl,
      hashCpe,
      errorMessage,
    }
  }

  /**
   * Emite una Nota de Credito que anula (o ajusta) un comprobante previamente emitido.
   *
   * Flujo:
   *   1. Lee el invoice original — debe estar 'aceptado' por SUNAT
   *   2. Asigna correlativo de NC atomicamente
   *   3. Construye CreditNote UBL 2.1 con BillingReference al original
   *   4. Firma el XML con .p12
   *   5. Envia a SUNAT (sendBill, igual que invoice)
   *   6. Genera PDF de la NC
   *   7. Crea documento `creditNotes/{id}` en Firestore
   *   8. Marca el invoice original como 'cancelled' con `cancellationNoteId`
   */
  async emitCreditNote(input: {
    invoiceId: string
    motivoCode: MotivoNotaCredito
    motivoDescripcion: string
    adminUid: string
  }): Promise<{
    creditNoteId: string
    documentNumber: string
    estadoSunat: string
    pdfUrl: string
    cdrUrl?: string
    xmlSignedUrl?: string
    hashCpe?: string
    errorMessage?: string
  }> {
    const { invoiceId, motivoCode, motivoDescripcion, adminUid } = input

    // 1. Cargar settings y comprobante original
    const settingsSnap = await this.db.collection('companySettings').doc('main').get()
    if (!settingsSnap.exists) throw new Error('companySettings/main no existe')
    const settings = settingsSnap.data() as CompanySettings

    const originalRef = this.db.collection('invoices').doc(invoiceId)
    const originalSnap = await originalRef.get()
    if (!originalSnap.exists) throw new Error(`Invoice ${invoiceId} no existe`)
    const original = originalSnap.data()!
    if (original.estadoSunat !== 'aceptado') {
      throw new Error('Solo se anulan comprobantes aceptados por SUNAT')
    }
    if (original.cancellationNoteId) {
      throw new Error('El comprobante ya tiene una nota de credito asociada')
    }

    const tipoOriginal = original.documentType as TipoComprobante
    const tipoDocOriginalSunat = SUNAT_TIPO_DOC_CODE[tipoOriginal]

    // 2. Asignar correlativo NC atomicamente
    const ncRef = this.db.collection('creditNotes').doc()
    const settingsRef = this.db.collection('companySettings').doc('main')
    let ncSerie = ''
    let ncCorrelativo = 0
    let ncDocumentNumber = ''

    await this.db.runTransaction(async (tx) => {
      const sSnap = await tx.get(settingsRef)
      const s = (sSnap.data() ?? settings) as CompanySettings
      if (tipoOriginal === 'boleta') {
        ncSerie = s.serieNcBoleta || 'BC01'
        ncCorrelativo = (s.correlativoActualNcBoleta ?? 0) + 1
        tx.update(settingsRef, { correlativoActualNcBoleta: ncCorrelativo, serieNcBoleta: ncSerie })
      } else {
        ncSerie = s.serieNcFactura || 'FC01'
        ncCorrelativo = (s.correlativoActualNcFactura ?? 0) + 1
        tx.update(settingsRef, { correlativoActualNcFactura: ncCorrelativo, serieNcFactura: ncSerie })
      }
      ncDocumentNumber = `${ncSerie}-${String(ncCorrelativo).padStart(8, '0')}`
      tx.set(ncRef, {
        documentType: 'nota_credito',
        serie: ncSerie,
        correlativo: ncCorrelativo,
        documentNumber: ncDocumentNumber,
        relatedInvoiceId: invoiceId,
        relatedDocumentNumber: original.documentNumber,
        motivoCode,
        motivoDescripcion,
        status: 'processing',
        estadoSunat: 'pendiente',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        emittedBy: adminUid,
      })
    })

    // 3. Construir input del builder UBL
    const ncInput: CreditNoteInput = {
      tipoOriginal,
      documentoOriginal: original.documentNumber,
      tipoDocOriginalSunat,
      motivoCode,
      motivoDescripcion,
      serie: ncSerie,
      correlativo: ncCorrelativo,
      fechaEmision: new Date(),

      emisorRuc: settings.ruc,
      emisorRazonSocial: settings.razonSocial,
      emisorNombreComercial: settings.nombreComercial,
      emisorDireccion: settings.direccionFiscal,
      emisorUbigeo: settings.ubigeo,

      receptorTipoDoc: original.receptorTipoDocumento,
      receptorNumeroDoc: original.receptorNumeroDocumento,
      receptorNombre: original.receptorNombre,

      items: original.items,

      subtotal: original.subtotal,
      igv: original.igv,
      total: original.total,
      moneda: 'PEN',
    }

    const filename = buildCreditNoteFilename(settings.ruc, ncSerie, ncCorrelativo)
    const ambiente: AmbienteSunat = settings.ambienteSunat || 'inactivo'

    let signedXml = ''
    let hashCpe = ''
    let estadoSunat = ambiente === 'inactivo' ? 'no_aplica' : 'pendiente'
    let cdrUrl: string | undefined
    let xmlSignedUrl: string | undefined
    let errorMessage: string | undefined

    if (ambiente !== 'inactivo' && settings.certificadoStoragePath) {
      try {
        const unsignedXml = buildUnsignedCreditNoteXml(ncInput)
        const certPassword = (process.env.SUNAT_CERT_PASSWORD || '').trim()
        if (!certPassword) throw new Error('SUNAT_CERT_PASSWORD no configurada')
        const p12Buffer = await this.getCertificateBuffer(settings.certificadoStoragePath)
        const cert = extractCertFromP12(p12Buffer, certPassword)
        const signed = signUblXml(unsignedXml, cert)
        signedXml = signed.signedXml
        hashCpe = signed.hashCpe

        xmlSignedUrl = await this.uploadToStorage(
          `creditNotes/${ncRef.id}/${filename}.xml`,
          Buffer.from(signedXml, 'utf-8'),
          'application/xml',
        )

        const usuarioSol = (process.env.SUNAT_SOL_USER || '').trim()
        const passwordSol = (process.env.SUNAT_SOL_PASSWORD || '').trim()
        if (!usuarioSol || !passwordSol) throw new Error('Credenciales SOL no configuradas')

        const result = await this.sunatService.sendBill({
          ambiente,
          ruc: settings.ruc,
          usuarioSol,
          passwordSol,
          filename,
          signedXml,
        })

        if (result.success && result.cdrZipBase64) {
          estadoSunat = 'aceptado'
          cdrUrl = await this.uploadToStorage(
            `creditNotes/${ncRef.id}/R-${filename}.zip`,
            Buffer.from(result.cdrZipBase64, 'base64'),
            'application/zip',
          )
        } else {
          estadoSunat = 'rechazado'
          errorMessage = `${result.errorCode || ''}: ${result.errorMessage || ''}`.trim()
        }
      } catch (err: any) {
        estadoSunat = 'error_local'
        errorMessage = err.message || String(err)
      }
    }

    // 4. Generar PDF de la NC (reutilizamos el PDF del invoice como representacion)
    // Para nota de credito hacemos un PDF simple inline aqui
    const pdfBuffer = await generateInvoicePdf({
      invoice: {
        tipo: tipoOriginal,
        serie: ncSerie,
        correlativo: ncCorrelativo,
        fechaEmision: new Date(),
        emisorRuc: settings.ruc,
        emisorRazonSocial: settings.razonSocial,
        emisorNombreComercial: settings.nombreComercial,
        emisorDireccion: settings.direccionFiscal,
        emisorUbigeo: settings.ubigeo,
        receptorTipoDoc: original.receptorTipoDocumento,
        receptorNumeroDoc: original.receptorNumeroDocumento,
        receptorNombre: `[NC] ${original.receptorNombre}`,
        items: original.items,
        subtotal: original.subtotal,
        igv: original.igv,
        total: original.total,
        moneda: 'PEN',
      },
      hashCpe: hashCpe || 'N/A',
      ambiente,
      documentNumber: `NC ${ncDocumentNumber} → anula ${original.documentNumber}`,
      estadoSunat,
    })
    const pdfUrl = await this.uploadToStorage(
      `creditNotes/${ncRef.id}/${filename}.pdf`,
      pdfBuffer,
      'application/pdf',
    )

    // 5. Update creditNote doc + invoice original
    await ncRef.update({
      ambienteSunat: ambiente,
      estadoSunat,
      hashCpe: hashCpe || null,
      xmlSignedUrl: xmlSignedUrl || null,
      cdrUrl: cdrUrl || null,
      pdfUrl,
      errorSunat: errorMessage || null,
      status: estadoSunat === 'aceptado' ? 'issued' : 'rejected',
      sunatProcessedAt: ambiente !== 'inactivo' ? admin.firestore.FieldValue.serverTimestamp() : null,
      emisorRuc: settings.ruc,
      emisorRazonSocial: settings.razonSocial,
      receptorTipoDocumento: original.receptorTipoDocumento,
      receptorNumeroDocumento: original.receptorNumeroDocumento,
      receptorNombre: original.receptorNombre,
      items: original.items,
      subtotal: original.subtotal,
      igv: original.igv,
      total: original.total,
    })

    if (estadoSunat === 'aceptado') {
      await originalRef.update({
        status: 'cancelled',
        cancellationNoteId: ncRef.id,
        cancellationNoteNumber: ncDocumentNumber,
        cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
      })
    }

    return {
      creditNoteId: ncRef.id,
      documentNumber: ncDocumentNumber,
      estadoSunat,
      pdfUrl,
      cdrUrl,
      xmlSignedUrl,
      hashCpe,
      errorMessage,
    }
  }

  /**
   * Sube un archivo al bucket privado y devuelve URL de descarga via Firebase
   * Storage download token. No requiere firmar blobs (evita IAM signBlob).
   *
   * El URL resultante tiene formato:
   *   https://firebasestorage.googleapis.com/v0/b/{bucket}/o/{encoded-path}?alt=media&token={uuid}
   * y persiste mientras el archivo exista. Solo quien conoce el token puede leerlo.
   */
  private async uploadToStorage(path: string, buffer: Buffer, contentType: string): Promise<string> {
    const bucket = this.storage.bucket()
    const file = bucket.file(path)
    const downloadToken = randomUUID()
    await file.save(buffer, {
      contentType,
      metadata: {
        cacheControl: 'private, max-age=3600',
        metadata: {
          // Firebase Storage usa este metadata para autorizar descargas con token
          firebaseStorageDownloadTokens: downloadToken,
        },
      },
    })
    const encodedPath = encodeURIComponent(path)
    return `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodedPath}?alt=media&token=${downloadToken}`
  }
}
