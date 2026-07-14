import { create } from 'xmlbuilder2'
import {
  CreditNoteInput,
  SUNAT_TIPO_DOC_IDENTIDAD,
  IGV_RATE,
  MONEDA_PEN,
} from './sunatTypes'

/**
 * Builder UBL 2.1 para Nota de Credito (Tipo de documento 07 — Catalogo 01).
 *
 * Diferencias clave con Invoice:
 * - Elemento raiz es <CreditNote> con namespace
 *   urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2
 * - Tiene <cbc:DiscrepancyResponse> con codigo de motivo (Catalogo 09)
 * - Tiene <cac:BillingReference> que apunta al documento original anulado
 * - Lineas se llaman <cac:CreditNoteLine> (no InvoiceLine)
 * - <cbc:CreditedQuantity> en lugar de <cbc:InvoicedQuantity>
 *
 * Filename SUNAT: RUC-07-SERIE-CORRELATIVO.xml (07 = nota de credito)
 */

const NS = {
  cn: 'urn:oasis:names:specification:ubl:schema:xsd:CreditNote-2',
  cac: 'urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2',
  cbc: 'urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2',
  ds: 'http://www.w3.org/2000/09/xmldsig#',
  ext: 'urn:oasis:names:specification:ubl:schema:xsd:CommonExtensionComponents-2',
}

function fmt(num: number): string {
  return num.toFixed(2)
}

function dateOnly(d: Date): string {
  return d.toISOString().slice(0, 10)
}

function timeOnly(d: Date): string {
  return d.toISOString().slice(11, 19)
}

/** Filename SUNAT: RUC-07-SERIE-CORRELATIVO */
export function buildCreditNoteFilename(ruc: string, serie: string, correlativo: number): string {
  return `${ruc}-07-${serie}-${correlativo}`
}

/**
 * Construye el XML UBL 2.1 de Nota de Credito sin firmar.
 */
export function buildUnsignedCreditNoteXml(input: CreditNoteInput): string {
  const documentId = `${input.serie}-${input.correlativo}`
  const tipoDocReceptor = SUNAT_TIPO_DOC_IDENTIDAD[input.receptorTipoDoc]

  const root = create({ version: '1.0', encoding: 'UTF-8', standalone: false }).ele('CreditNote', {
    xmlns: NS.cn,
    'xmlns:cac': NS.cac,
    'xmlns:cbc': NS.cbc,
    'xmlns:ds': NS.ds,
    'xmlns:ext': NS.ext,
  })

  // 1. UBLExtensions placeholder
  root
    .ele('ext:UBLExtensions')
    .ele('ext:UBLExtension')
    .ele('ext:ExtensionContent')

  // 2. Cabecera
  root.ele('cbc:UBLVersionID').txt('2.1').up()
  root.ele('cbc:CustomizationID').txt('2.0').up()
  root.ele('cbc:ID').txt(documentId).up()
  root.ele('cbc:IssueDate').txt(dateOnly(input.fechaEmision)).up()
  root.ele('cbc:IssueTime').txt(timeOnly(input.fechaEmision)).up()
  root
    .ele('cbc:Note', { languageLocaleID: '1000' })
    .dat(input.motivoDescripcion.toUpperCase())
    .up()
  root.ele('cbc:DocumentCurrencyCode').txt(MONEDA_PEN).up()
  root.ele('cbc:LineCountNumeric').txt(String(input.items.length)).up()

  // 3. cac:DiscrepancyResponse — motivo de la nota de credito
  const discrepancy = root.ele('cac:DiscrepancyResponse')
  discrepancy.ele('cbc:ReferenceID').txt(input.documentoOriginal).up()
  discrepancy.ele('cbc:ResponseCode').txt(input.motivoCode).up()
  discrepancy.ele('cbc:Description').dat(input.motivoDescripcion).up()

  // 4. cac:BillingReference — referencia al documento original
  const billing = root.ele('cac:BillingReference')
  const invoiceDocRef = billing.ele('cac:InvoiceDocumentReference')
  invoiceDocRef.ele('cbc:ID').txt(input.documentoOriginal).up()
  invoiceDocRef.ele('cbc:DocumentTypeCode').txt(input.tipoDocOriginalSunat).up()

  // 5. cac:Signature
  const signature = root.ele('cac:Signature')
  signature.ele('cbc:ID').txt(input.emisorRuc).up()
  const sigParty = signature.ele('cac:SignatoryParty')
  sigParty.ele('cac:PartyIdentification').ele('cbc:ID').txt(input.emisorRuc).up()
  sigParty.ele('cac:PartyName').ele('cbc:Name').dat(input.emisorRazonSocial).up()
  signature
    .ele('cac:DigitalSignatureAttachment')
    .ele('cac:ExternalReference')
    .ele('cbc:URI')
    .txt(`#SignatureSP-${input.emisorRuc}`)
    .up()

  // 6. Emisor
  const supplier = root.ele('cac:AccountingSupplierParty').ele('cac:Party')
  supplier
    .ele('cac:PartyIdentification')
    .ele('cbc:ID', { schemeID: '6' })
    .txt(input.emisorRuc)
    .up()
  if (input.emisorNombreComercial) {
    supplier.ele('cac:PartyName').ele('cbc:Name').dat(input.emisorNombreComercial).up()
  }
  const supplierLegal = supplier.ele('cac:PartyLegalEntity')
  supplierLegal.ele('cbc:RegistrationName').dat(input.emisorRazonSocial).up()
  const supplierAddr = supplierLegal.ele('cac:RegistrationAddress')
  supplierAddr.ele('cbc:ID').txt(input.emisorUbigeo).up()
  supplierAddr.ele('cbc:AddressTypeCode').txt('0000').up()
  supplierAddr.ele('cbc:CityName').txt('LIMA').up()
  supplierAddr.ele('cbc:CountrySubentity').txt('LIMA').up()
  supplierAddr.ele('cbc:District').txt('SAN MARTIN DE PORRES').up()
  supplierAddr.ele('cac:AddressLine').ele('cbc:Line').dat(input.emisorDireccion).up()
  supplierAddr
    .ele('cac:Country')
    .ele('cbc:IdentificationCode', {
      listID: 'ISO 3166-1',
      listAgencyName: 'United Nations Economic Commission for Europe',
      listName: 'Country',
    })
    .txt('PE')
    .up()

  // 7. Receptor
  const customer = root.ele('cac:AccountingCustomerParty').ele('cac:Party')
  customer
    .ele('cac:PartyIdentification')
    .ele('cbc:ID', { schemeID: tipoDocReceptor })
    .txt(input.receptorNumeroDoc)
    .up()
  const customerLegal = customer.ele('cac:PartyLegalEntity')
  customerLegal.ele('cbc:RegistrationName').dat(input.receptorNombre).up()
  if (input.receptorDireccion) {
    customerLegal
      .ele('cac:RegistrationAddress')
      .ele('cac:AddressLine')
      .ele('cbc:Line')
      .dat(input.receptorDireccion)
      .up()
  }

  // 8. cac:TaxTotal
  const taxTotal = root.ele('cac:TaxTotal')
  taxTotal.ele('cbc:TaxAmount', { currencyID: MONEDA_PEN }).txt(fmt(input.igv)).up()
  const taxSubtotal = taxTotal.ele('cac:TaxSubtotal')
  taxSubtotal.ele('cbc:TaxableAmount', { currencyID: MONEDA_PEN }).txt(fmt(input.subtotal)).up()
  taxSubtotal.ele('cbc:TaxAmount', { currencyID: MONEDA_PEN }).txt(fmt(input.igv)).up()
  const taxCategory = taxSubtotal.ele('cac:TaxCategory')
  taxCategory.ele('cbc:Percent').txt(String(IGV_RATE * 100)).up()
  taxCategory.ele('cbc:TaxExemptionReasonCode').txt('10').up()
  const taxScheme = taxCategory.ele('cac:TaxScheme')
  taxScheme.ele('cbc:ID').txt('1000').up()
  taxScheme.ele('cbc:Name').txt('IGV').up()
  taxScheme.ele('cbc:TaxTypeCode').txt('VAT').up()

  // 9. cac:LegalMonetaryTotal
  const monetary = root.ele('cac:LegalMonetaryTotal')
  monetary.ele('cbc:LineExtensionAmount', { currencyID: MONEDA_PEN }).txt(fmt(input.subtotal)).up()
  monetary.ele('cbc:TaxInclusiveAmount', { currencyID: MONEDA_PEN }).txt(fmt(input.total)).up()
  monetary.ele('cbc:PayableAmount', { currencyID: MONEDA_PEN }).txt(fmt(input.total)).up()

  // 10. cac:CreditNoteLine (uno por item)
  input.items.forEach((item, i) => {
    const line = root.ele('cac:CreditNoteLine')
    line.ele('cbc:ID').txt(String(i + 1)).up()
    line.ele('cbc:CreditedQuantity', { unitCode: item.unidadMedida }).txt(String(item.cantidad)).up()
    line.ele('cbc:LineExtensionAmount', { currencyID: MONEDA_PEN }).txt(fmt(item.valorTotal)).up()

    const pricing = line.ele('cac:PricingReference').ele('cac:AlternativeConditionPrice')
    pricing.ele('cbc:PriceAmount', { currencyID: MONEDA_PEN }).txt(fmt(item.total)).up()
    pricing.ele('cbc:PriceTypeCode').txt('01').up()

    const lineTax = line.ele('cac:TaxTotal')
    lineTax.ele('cbc:TaxAmount', { currencyID: MONEDA_PEN }).txt(fmt(item.igv)).up()
    const lineSub = lineTax.ele('cac:TaxSubtotal')
    lineSub.ele('cbc:TaxableAmount', { currencyID: MONEDA_PEN }).txt(fmt(item.valorTotal)).up()
    lineSub.ele('cbc:TaxAmount', { currencyID: MONEDA_PEN }).txt(fmt(item.igv)).up()
    const lineCat = lineSub.ele('cac:TaxCategory')
    lineCat.ele('cbc:Percent').txt(String(IGV_RATE * 100)).up()
    lineCat.ele('cbc:TaxExemptionReasonCode').txt(item.codigoTipoIgv).up()
    const lineScheme = lineCat.ele('cac:TaxScheme')
    lineScheme.ele('cbc:ID').txt('1000').up()
    lineScheme.ele('cbc:Name').txt('IGV').up()
    lineScheme.ele('cbc:TaxTypeCode').txt('VAT').up()

    const itemNode = line.ele('cac:Item')
    itemNode.ele('cbc:Description').dat(item.descripcion).up()

    line.ele('cac:Price').ele('cbc:PriceAmount', { currencyID: MONEDA_PEN }).txt(fmt(item.valorUnitario)).up()
  })

  return root.end({ prettyPrint: false })
}
