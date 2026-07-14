import axios from 'axios'
import JSZip from 'jszip'
import { AmbienteSunat, SunatSendResult } from '../utils/sunatTypes'

/**
 * Cliente SOAP para webservice de SUNAT (SEE - Sistema de Emision Electronica).
 *
 * Endpoints:
 * - Beta (homologacion): https://e-beta.sunat.gob.pe/ol-ti-itcpfegem-beta/billService
 * - Produccion:          https://e-factura.sunat.gob.pe/ol-ti-itcpfegem/billService
 *
 * Autenticacion: HTTP Basic Auth con `RUC + USUARIO_SECUNDARIO_SOL` y password SOL.
 *
 * Operacion principal: sendBill — envia ZIP con XML firmado, devuelve CDR (Constancia
 * de Recepcion) tambien en ZIP. Si la respuesta es asincrona, devuelve un ticket
 * que se consulta con getStatus.
 *
 * Codigos de respuesta SUNAT:
 *   0       - Aceptado
 *   1xxx    - Errores en envio (estructura, firma)
 *   2xxx    - Errores no contribuyente (datos)
 *   3xxx    - Errores tipo de comprobante
 *   4xxx    - Excepciones de procesamiento
 */

const ENDPOINTS: Record<Exclude<AmbienteSunat, 'inactivo'>, string> = {
  beta: 'https://e-beta.sunat.gob.pe/ol-ti-itcpfegem-beta/billService',
  produccion: 'https://e-factura.sunat.gob.pe/ol-ti-itcpfegem/billService',
}

const SOAP_ACTION_SEND_BILL = ''

interface SendBillInput {
  ambiente: Exclude<AmbienteSunat, 'inactivo'>
  ruc: string
  usuarioSol: string
  passwordSol: string
  /** Nombre base del archivo: RUC-TIPODOC-SERIE-CORRELATIVO (sin extension) */
  filename: string
  /** XML firmado en string */
  signedXml: string
}

/**
 * Empaqueta el XML firmado en un ZIP segun convencion SUNAT.
 *
 * Estructura del ZIP:
 *   {filename}.xml
 *
 * El nombre del ZIP debe ser {filename}.zip cuando se sube.
 */
async function zipXml(filename: string, signedXml: string): Promise<Buffer> {
  const zip = new JSZip()
  zip.file(`${filename}.xml`, signedXml)
  return zip.generateAsync({ type: 'nodebuffer', compression: 'DEFLATE' })
}

/**
 * Construye el sobre SOAP 1.1 para la operacion sendBill.
 */
function buildSoapEnvelope(filename: string, zipBase64: string): string {
  return `<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
               xmlns:ser="http://service.sunat.gob.pe"
               xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
  <soap:Header>
    <wsse:Security>
      <wsse:UsernameToken>
        <wsse:Username>__USERNAME__</wsse:Username>
        <wsse:Password>__PASSWORD__</wsse:Password>
      </wsse:UsernameToken>
    </wsse:Security>
  </soap:Header>
  <soap:Body>
    <ser:sendBill>
      <fileName>${filename}.zip</fileName>
      <contentFile>${zipBase64}</contentFile>
    </ser:sendBill>
  </soap:Body>
</soap:Envelope>`
}

/**
 * Reemplaza username/password en el envelope. Hacemos esto fuera del template
 * literal para evitar inyeccion accidental si el password contiene caracteres
 * especiales — los escapamos con XML entity escaping.
 */
function injectCredentials(envelope: string, username: string, password: string): string {
  const esc = (s: string) =>
    s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;')
  return envelope.replace('__USERNAME__', esc(username)).replace('__PASSWORD__', esc(password))
}

/**
 * Parsea la respuesta SOAP de SUNAT. La respuesta exitosa contiene applicationResponse
 * en base64 (otro ZIP con el CDR XML adentro). Si hay error, contiene faultcode/faultstring.
 */
async function parseSendBillResponse(soapXml: string, filename: string): Promise<SunatSendResult> {
  // Detectar fault
  const faultCodeMatch = soapXml.match(/<faultcode[^>]*>([^<]+)<\/faultcode>/)
  if (faultCodeMatch) {
    const faultStringMatch = soapXml.match(/<faultstring[^>]*>([^<]+)<\/faultstring>/)
    return {
      success: false,
      errorCode: faultCodeMatch[1],
      errorMessage: faultStringMatch ? faultStringMatch[1] : 'Error SUNAT desconocido',
    }
  }

  // Extraer applicationResponse (base64 del ZIP del CDR)
  const appRespMatch = soapXml.match(/<applicationResponse[^>]*>([^<]+)<\/applicationResponse>/)
  if (!appRespMatch) {
    return {
      success: false,
      errorMessage: 'Respuesta SUNAT no contiene applicationResponse',
    }
  }
  const cdrZipBase64 = appRespMatch[1].trim()

  // Descomprimir ZIP del CDR para extraer el XML R-{filename}.xml
  try {
    const zipBuffer = Buffer.from(cdrZipBase64, 'base64')
    const zip = await JSZip.loadAsync(zipBuffer)
    const cdrFilename = `R-${filename}.xml`
    const cdrFile = zip.file(cdrFilename)
    if (!cdrFile) {
      // Buscar cualquier XML adentro
      const xmlFiles = Object.keys(zip.files).filter((k) => k.endsWith('.xml'))
      if (xmlFiles.length === 0) {
        return { success: true, cdrZipBase64, errorMessage: 'CDR vacio' }
      }
      const cdrXml = await zip.file(xmlFiles[0])!.async('string')
      return parseCdrXml(cdrXml, cdrZipBase64)
    }
    const cdrXml = await cdrFile.async('string')
    return parseCdrXml(cdrXml, cdrZipBase64)
  } catch (err: any) {
    return { success: false, errorMessage: `Error parseando CDR ZIP: ${err.message}` }
  }
}

function parseCdrXml(cdrXml: string, cdrZipBase64: string): SunatSendResult {
  const codeMatch = cdrXml.match(/<cbc:ResponseCode[^>]*>([^<]+)<\/cbc:ResponseCode>/)
  const descMatch = cdrXml.match(/<cbc:Description[^>]*>([^<]+)<\/cbc:Description>/)
  const code = codeMatch ? codeMatch[1] : ''
  const desc = descMatch ? descMatch[1] : ''
  // Codigo 0 = aceptado. >= 4000 = error.
  const accepted = code === '0'
  return {
    success: accepted,
    cdrZipBase64,
    cdrXml,
    responseCode: code,
    responseDescription: desc,
    errorCode: accepted ? undefined : code,
    errorMessage: accepted ? undefined : desc,
  }
}

export class SunatService {
  /**
   * Envia un comprobante firmado a SUNAT y procesa la Constancia de Recepcion.
   */
  async sendBill(input: SendBillInput): Promise<SunatSendResult> {
    if (input.ambiente === 'inactivo' as any) {
      throw new Error('Ambiente SUNAT esta inactivo')
    }
    const endpoint = ENDPOINTS[input.ambiente]
    const username = `${input.ruc}${input.usuarioSol}`

    const zipBuffer = await zipXml(input.filename, input.signedXml)
    const zipBase64 = zipBuffer.toString('base64')

    const envelope = injectCredentials(
      buildSoapEnvelope(input.filename, zipBase64),
      username,
      input.passwordSol,
    )

    try {
      const response = await axios.post(endpoint, envelope, {
        headers: {
          'Content-Type': 'text/xml;charset=UTF-8',
          SOAPAction: SOAP_ACTION_SEND_BILL,
        },
        timeout: 60_000,
        maxBodyLength: Infinity,
        maxContentLength: Infinity,
        validateStatus: () => true, // procesar cualquier status code
      })
      return parseSendBillResponse(response.data, input.filename)
    } catch (err: any) {
      return {
        success: false,
        errorCode: err.code || 'NETWORK_ERROR',
        errorMessage: err.message || 'Error de red al contactar SUNAT',
      }
    }
  }

  /**
   * Consulta el estado de un ticket asincrono (resumen diario, comunicaciones de baja).
   * Para sendBill normal de boletas/facturas, NO se usa ticket — la respuesta es sincrona.
   */
  async getStatus(input: {
    ambiente: Exclude<AmbienteSunat, 'inactivo'>
    ruc: string
    usuarioSol: string
    passwordSol: string
    ticket: string
  }): Promise<SunatSendResult> {
    const endpoint = ENDPOINTS[input.ambiente]
    const username = `${input.ruc}${input.usuarioSol}`
    const envelope = `<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
               xmlns:ser="http://service.sunat.gob.pe"
               xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
  <soap:Header>
    <wsse:Security>
      <wsse:UsernameToken>
        <wsse:Username>__USERNAME__</wsse:Username>
        <wsse:Password>__PASSWORD__</wsse:Password>
      </wsse:UsernameToken>
    </wsse:Security>
  </soap:Header>
  <soap:Body>
    <ser:getStatus>
      <ticket>${input.ticket}</ticket>
    </ser:getStatus>
  </soap:Body>
</soap:Envelope>`
    const withCreds = injectCredentials(envelope, username, input.passwordSol)
    try {
      const response = await axios.post(endpoint, withCreds, {
        headers: { 'Content-Type': 'text/xml;charset=UTF-8' },
        timeout: 30_000,
        validateStatus: () => true,
      })
      return parseSendBillResponse(response.data, `ticket-${input.ticket}`)
    } catch (err: any) {
      return { success: false, errorMessage: err.message }
    }
  }
}
