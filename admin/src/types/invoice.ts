// Timestamp alias (Firebase retirado del panel)
type Timestamp = { seconds: number; nanoseconds: number } | Date | string

export type DocumentType = 'boleta' | 'factura' | 'nota_credito' | 'recibo_interno'
export type SunatStatus = 'pendiente' | 'enviado' | 'aceptado' | 'rechazado' | 'observado' | 'no_aplica'
export type InvoiceStatus = 'issued' | 'cancelled' | 'voided' | 'draft'

export interface InvoiceItem {
  descripcion: string
  cantidad: number
  unidadMedida: 'NIU' | 'ZZ' | 'SE'         // NIU = unidad SUNAT
  valorUnitario: number                      // Sin IGV
  valorTotal: number                         // Sin IGV (cantidad * valorUnitario)
  igv: number                                // 18% del valorTotal
  total: number                              // valorTotal + igv
  codigoTipoIgv?: '10' | '20' | '30' | '40'  // 10=Gravado IGV
}

export interface Invoice {
  id: string
  documentType: DocumentType
  serie: string                              // B001 boleta / F001 factura
  correlativo: number
  documentNumber: string                     // B001-00000001
  rechargeId: string

  // Emisor (Rapi Team SAC)
  emisorRuc: string
  emisorRazonSocial: string
  emisorNombreComercial?: string
  emisorDireccion: string
  emisorUbigeo?: string

  // Receptor (Conductor)
  receptorTipoDocumento: 'DNI' | 'RUC' | 'CE' | 'PASAPORTE'
  receptorNumeroDocumento: string
  receptorNombre: string
  receptorDireccion?: string                 // Requerido para factura
  receptorEmail?: string

  items: InvoiceItem[]

  // Totales (PEN)
  subtotal: number                           // Sin IGV
  igv: number                                // 18% del subtotal
  total: number
  moneda: 'PEN'

  // SUNAT
  estadoSunat: SunatStatus
  hashCpe?: string
  xmlSignedUrl?: string
  xmlSignedHash?: string
  cdrUrl?: string
  pdfUrl?: string
  ticketSunat?: string
  errorSunat?: string

  status: InvoiceStatus
  createdAt: Timestamp
  sunatProcessedAt?: Timestamp
  cancelledAt?: Timestamp
  cancelledBy?: string
  cancelReason?: string
}

export interface CompanySettings {
  ruc: string
  razonSocial: string
  nombreComercial?: string
  direccionFiscal: string
  ubigeo: string
  certificadoDigitalStoragePath?: string     // Storage path .pfx
  ambienteSunat: 'beta' | 'produccion' | 'inactivo'
  serieBoleta: string                        // 'B001'
  serieFactura: string                       // 'F001'
  correlativoActualBoleta: number
  correlativoActualFactura: number
  iva: number                                // 0.18
}
