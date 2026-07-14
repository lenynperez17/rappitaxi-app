/**
 * Tipos compartidos para el modulo SUNAT (SEE - Sistema de Emision Electronica).
 * Basado en UBL 2.1 + extensiones SUNAT (Catalogo Anexo 8 RS 097-2012).
 */

export type AmbienteSunat = 'inactivo' | 'beta' | 'produccion'

export type TipoComprobante = 'boleta' | 'factura'

/**
 * Catalogo SUNAT 09 - Codigo de tipo de motivo de la nota de credito.
 * 01 = Anulacion de la operacion
 * 02 = Anulacion por error en el RUC
 * 03 = Correccion por error en la descripcion
 * 04 = Descuento global
 * 05 = Descuento por item
 * 06 = Devolucion total
 * 07 = Devolucion por item
 * 08 = Bonificacion
 * 09 = Disminucion en el valor
 * 10 = Otros conceptos
 * 13 = Ajustes de operaciones de exportacion
 */
export type MotivoNotaCredito = '01' | '02' | '03' | '04' | '05' | '06' | '07' | '08' | '09' | '10' | '13'

export interface CreditNoteInput {
  /** Tipo del comprobante original (boleta/factura) — determina la serie del NC */
  tipoOriginal: TipoComprobante
  /** Numero del documento original (ej. F001-00000001) */
  documentoOriginal: string
  /** Codigo de tipo de documento original SUNAT (01=factura, 03=boleta) */
  tipoDocOriginalSunat: '01' | '03'
  /** Motivo de la nota de credito (Catalogo 09) */
  motivoCode: MotivoNotaCredito
  /** Descripcion textual del motivo */
  motivoDescripcion: string
  /** Serie y correlativo del NC (ej. FC01-1) */
  serie: string
  correlativo: number
  fechaEmision: Date

  emisorRuc: string
  emisorRazonSocial: string
  emisorNombreComercial?: string
  emisorDireccion: string
  emisorUbigeo: string

  receptorTipoDoc: TipoDocumentoReceptor
  receptorNumeroDoc: string
  receptorNombre: string
  receptorDireccion?: string

  items: InvoiceItem[]

  subtotal: number
  igv: number
  total: number
  moneda: 'PEN'
}

export type TipoDocumentoReceptor = 'DNI' | 'RUC' | 'CE' | 'PASAPORTE'

/**
 * Catalogo SUNAT 01 - Tipo de documento.
 * 01 = Factura, 03 = Boleta de venta, 07 = Nota de credito, 08 = Nota de debito
 */
export const SUNAT_TIPO_DOC_CODE: Record<TipoComprobante, '01' | '03'> = {
  factura: '01',
  boleta: '03',
}

/**
 * Catalogo SUNAT 06 - Tipo de documento de identidad del receptor.
 * 0 = Doc. Trib. no domiciliado, 1 = DNI, 4 = Carnet ext., 6 = RUC, 7 = Pasaporte
 */
export const SUNAT_TIPO_DOC_IDENTIDAD: Record<TipoDocumentoReceptor, '0' | '1' | '4' | '6' | '7'> = {
  DNI: '1',
  CE: '4',
  RUC: '6',
  PASAPORTE: '7',
}

/**
 * Catalogo SUNAT 07 - Tipo de afectacion IGV.
 * 10 = Gravado - Operacion onerosa
 */
export const TIPO_AFECTACION_IGV_GRAVADO = '10'

/** Tasa del IGV peruano: 18% */
export const IGV_RATE = 0.18

/** Codigo SUNAT para Soles peruanos */
export const MONEDA_PEN = 'PEN'

export interface CompanySettings {
  ruc: string
  razonSocial: string
  nombreComercial?: string
  direccionFiscal: string
  ubigeo: string
  ambienteSunat: AmbienteSunat
  serieBoleta: string
  serieFactura: string
  correlativoActualBoleta: number
  correlativoActualFactura: number
  // Series para Notas de Credito (Catalogo 01: tipo 07)
  serieNcBoleta?: string  // typically BC01 or B-NC
  serieNcFactura?: string  // typically FC01 or F-NC
  correlativoActualNcBoleta?: number
  correlativoActualNcFactura?: number
  certificadoStoragePath?: string
  igv?: number
}

export interface InvoiceItem {
  descripcion: string
  cantidad: number
  unidadMedida: string
  valorUnitario: number
  valorTotal: number
  igv: number
  total: number
  codigoTipoIgv: string
}

export interface UblInvoiceInput {
  tipo: TipoComprobante
  serie: string
  correlativo: number
  fechaEmision: Date

  emisorRuc: string
  emisorRazonSocial: string
  emisorNombreComercial?: string
  emisorDireccion: string
  emisorUbigeo: string

  receptorTipoDoc: TipoDocumentoReceptor
  receptorNumeroDoc: string
  receptorNombre: string
  receptorDireccion?: string

  items: InvoiceItem[]

  subtotal: number
  igv: number
  total: number
  moneda: 'PEN'
}

export interface SunatSendResult {
  success: boolean
  cdrZipBase64?: string
  cdrXml?: string
  responseCode?: string
  responseDescription?: string
  ticket?: string
  hashCpe?: string
  errorCode?: string
  errorMessage?: string
}

export interface SignedXmlResult {
  signedXml: string
  hashCpe: string // base64 del DigestValue
}
