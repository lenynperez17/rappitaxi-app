import * as forge from 'node-forge'
import { SignedXml } from 'xml-crypto'
import * as crypto from 'crypto'
import { SignedXmlResult } from './sunatTypes'

/**
 * Firma digital de XML UBL para SUNAT.
 *
 * SUNAT exige firma XAdES-BES enveloped con:
 *  - Algoritmo de digest: SHA-256 (http://www.w3.org/2001/04/xmlenc#sha256)
 *  - Algoritmo de firma: RSA-SHA256 (http://www.w3.org/2001/04/xmldsig-more#rsa-sha256)
 *  - Canonicalizacion: C14N (http://www.w3.org/TR/2001/REC-xml-c14n-20010315)
 *  - Transform enveloped: http://www.w3.org/2000/09/xmldsig#enveloped-signature
 *
 * La firma va dentro de <ext:UBLExtensions>/<ext:UBLExtension>/<ext:ExtensionContent>
 * (ya creado vacio por ublXmlBuilder).
 */

interface CertData {
  /** Clave privada en formato PEM */
  privateKeyPem: string
  /** Certificado X509 en formato PEM (sin BEGIN/END headers, solo base64) */
  certificateBase64: string
}

/**
 * Extrae la clave privada y el certificado de un archivo .p12 / .pfx.
 *
 * Compatible con certificados SUNAT emitidos por RENIEC y otras CAs peruanas
 * que usan algoritmos legacy (RC2-40-CBC). Por eso usamos node-forge en vez
 * de openssl, ya que openssl 3.x los rechaza por defecto.
 */
export function extractCertFromP12(p12Buffer: Buffer, password: string): CertData {
  const p12Asn1 = forge.asn1.fromDer(p12Buffer.toString('binary'))
  const p12 = forge.pkcs12.pkcs12FromAsn1(p12Asn1, false, password)

  // Buscar el shrouded keybag con la private key
  const keyBags = p12.getBags({ bagType: forge.pki.oids.pkcs8ShroudedKeyBag })
  const keyBagArr = keyBags[forge.pki.oids.pkcs8ShroudedKeyBag] || []
  if (keyBagArr.length === 0) {
    throw new Error('No se encontro la clave privada en el .p12')
  }
  const privateKey = keyBagArr[0].key
  if (!privateKey) {
    throw new Error('Clave privada vacia en el .p12')
  }

  // Buscar el cert bag
  const certBags = p12.getBags({ bagType: forge.pki.oids.certBag })
  const certBagArr = certBags[forge.pki.oids.certBag] || []
  if (certBagArr.length === 0) {
    throw new Error('No se encontro certificado en el .p12')
  }
  // Si hay multiples certs (cadena), el primero suele ser el end-entity
  const cert = certBagArr[0].cert
  if (!cert) {
    throw new Error('Certificado vacio en el .p12')
  }

  const privateKeyPem = forge.pki.privateKeyToPem(privateKey)
  const certPem = forge.pki.certificateToPem(cert)
  // Extract base64 contents only (remove BEGIN/END markers and newlines)
  const certificateBase64 = certPem
    .replace(/-----BEGIN CERTIFICATE-----/g, '')
    .replace(/-----END CERTIFICATE-----/g, '')
    .replace(/\s+/g, '')

  return { privateKeyPem, certificateBase64 }
}

/**
 * Firma un XML UBL 2.1 con el cert y devuelve el XML firmado + hash CPE.
 *
 * El hash CPE (DigestValue de la firma) es lo que se imprime en el PDF
 * y en el codigo QR como huella unica del comprobante.
 */
export function signUblXml(unsignedXml: string, cert: CertData): SignedXmlResult {
  const sig = new SignedXml({
    privateKey: cert.privateKeyPem,
    publicCert: `-----BEGIN CERTIFICATE-----\n${cert.certificateBase64}\n-----END CERTIFICATE-----`,
    signatureAlgorithm: 'http://www.w3.org/2001/04/xmldsig-more#rsa-sha256',
    canonicalizationAlgorithm: 'http://www.w3.org/TR/2001/REC-xml-c14n-20010315',
  })

  // Reference con URI="" (documento entero) + enveloped-signature.
  // SUNAT NO permite atributo Id en <Invoice>, asi que pasamos isEmptyUri:true
  // para que xml-crypto NO inyecte Id="_0" al elemento raiz.
  sig.addReference({
    xpath: '/*',
    digestAlgorithm: 'http://www.w3.org/2001/04/xmlenc#sha256',
    transforms: [
      'http://www.w3.org/2000/09/xmldsig#enveloped-signature',
      'http://www.w3.org/TR/2001/REC-xml-c14n-20010315',
    ],
    isEmptyUri: true,
  })

  // Computar la firma — la insertamos manualmente luego dentro de ext:ExtensionContent
  sig.computeSignature(unsignedXml, {
    location: {
      reference:
        "//*[local-name(.)='UBLExtensions']/*[local-name(.)='UBLExtension'][1]/*[local-name(.)='ExtensionContent']",
      action: 'append',
    },
    prefix: 'ds',
  })

  const signedXml = sig.getSignedXml()

  // Extraer el DigestValue (hash CPE) del XML firmado
  const digestMatch = signedXml.match(/<ds:DigestValue>([^<]+)<\/ds:DigestValue>/)
  const hashCpe = digestMatch ? digestMatch[1] : ''

  return { signedXml, hashCpe }
}

/**
 * Calcula el hash SHA-256 del CDR (Constancia de Recepcion) de SUNAT.
 * Util para verificacion de integridad.
 */
export function sha256Hex(buffer: Buffer): string {
  return crypto.createHash('sha256').update(buffer).digest('hex')
}
