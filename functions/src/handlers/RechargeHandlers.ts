import { onCall, HttpsError } from 'firebase-functions/v2/https'
import * as admin from 'firebase-admin'
import { defineSecret } from 'firebase-functions/params'
import { RechargeService } from '../services/RechargeService'
import { calculateRechargeBreakdown } from '../utils/mercadopagoFees'
import { InvoiceService } from '../services/InvoiceService'
import { SunatService } from '../services/SunatService'
import { AmbienteSunat, MotivoNotaCredito } from '../utils/sunatTypes'

// Secrets — requeridos en runtime para emisor SUNAT
const SUNAT_CERT_PASSWORD = defineSecret('SUNAT_CERT_PASSWORD')
const SUNAT_SOL_USER = defineSecret('SUNAT_SOL_USER')
const SUNAT_SOL_PASSWORD = defineSecret('SUNAT_SOL_PASSWORD')

/**
 * Cloud Function HTTPS callable para crear una recarga manual
 * (usada por el admin panel cuando paga el conductor en efectivo o transferencia).
 *
 * Solo administradores pueden invocarla. Verifica `isAdmin === true` o
 * `userType === 'admin'` en `users/{uid}`.
 */
export const createManualRecharge = onCall(
  { cors: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Debes iniciar sesion')
    }

    const adminUid = request.auth.uid
    const userSnap = await admin.firestore().collection('users').doc(adminUid).get()
    const userData = userSnap.data()
    if (!userData?.isAdmin && userData?.userType !== 'admin') {
      throw new HttpsError('permission-denied', 'Solo administradores')
    }

    const { driverId, grossAmount, paymentMethod = 'admin_manual' } = request.data ?? {}
    if (!driverId || typeof driverId !== 'string') {
      throw new HttpsError('invalid-argument', 'driverId requerido')
    }
    if (!grossAmount || typeof grossAmount !== 'number' || grossAmount <= 0) {
      throw new HttpsError('invalid-argument', 'grossAmount invalido')
    }

    // Get driver data
    const driverSnap = await admin.firestore().collection('users').doc(driverId).get()
    if (!driverSnap.exists) {
      throw new HttpsError('not-found', 'Conductor no encontrado')
    }
    const driver = driverSnap.data()!

    // Resolver tipo y numero de documento — el modelo es heterogeneo:
    // algunos drivers lo guardan top-level (`documentType`, `documentNumber`),
    // otros bajo `driverProfile.documentNumber` o `dni`. Default a DNI.
    const docNumber =
      driver.documentNumber ||
      driver.driverProfile?.documentNumber ||
      driver.dni ||
      '00000000'
    const docType: 'DNI' | 'RUC' | 'CE' | 'PASAPORTE' =
      driver.documentType ||
      (docNumber.length === 11 && docNumber.startsWith('20') ? 'RUC' : 'DNI')

    const service = new RechargeService()
    const recharge = await service.createApprovedRecharge({
      driverId,
      driverName: driver.fullName || driver.name || 'CLIENTE FINAL',
      driverEmail: driver.email || '',
      driverPhone: driver.phone || driver.phoneNumber,
      driverDocumentType: docType,
      driverDocumentNumber: docNumber,
      grossAmount,
      paymentMethod,
      createdBy: adminUid,
    })

    return {
      ok: true,
      rechargeId: recharge.id,
      breakdown: calculateRechargeBreakdown(grossAmount),
    }
  },
)

/**
 * Cloud Function HTTPS callable para emitir un comprobante (boleta o factura)
 * a partir de una recarga aprobada.
 *
 * Si `companySettings.ambienteSunat` es 'beta' o 'produccion', firma el XML
 * con el certificado .p12 y lo envia a SUNAT. Si es 'inactivo', genera solo
 * un PDF interno como pre-comprobante.
 */
export const emitirComprobante = onCall(
  {
    cors: true,
    secrets: [SUNAT_CERT_PASSWORD, SUNAT_SOL_USER, SUNAT_SOL_PASSWORD],
    memory: '512MiB',
    timeoutSeconds: 120,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Debes iniciar sesion')
    }

    const adminUid = request.auth.uid
    const adminSnap = await admin.firestore().collection('users').doc(adminUid).get()
    const adminData = adminSnap.data()
    if (!adminData?.isAdmin && adminData?.userType !== 'admin') {
      throw new HttpsError('permission-denied', 'Solo administradores')
    }

    const { rechargeId, tipo } = request.data ?? {}
    if (!rechargeId || !tipo || !['boleta', 'factura'].includes(tipo)) {
      throw new HttpsError('invalid-argument', 'rechargeId y tipo (boleta|factura) requeridos')
    }

    try {
      const service = new InvoiceService()
      const result = await service.emit({
        rechargeId,
        tipo,
        adminUid,
      })
      return {
        ok: result.estadoSunat !== 'rechazado' && result.estadoSunat !== 'error_local',
        ...result,
      }
    } catch (err: any) {
      console.error('Error en emitirComprobante:', err)
      throw new HttpsError('internal', err.message || 'Error al emitir comprobante')
    }
  },
)

/**
 * Cloud Function HTTPS callable para consultar el estado de un ticket asincrono
 * de SUNAT (resumen diario, comunicacion de baja).
 */
export const consultarEstadoSunat = onCall(
  {
    cors: true,
    secrets: [SUNAT_SOL_USER, SUNAT_SOL_PASSWORD],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Debes iniciar sesion')
    }
    const adminUid = request.auth.uid
    const adminSnap = await admin.firestore().collection('users').doc(adminUid).get()
    const adminData = adminSnap.data()
    if (!adminData?.isAdmin && adminData?.userType !== 'admin') {
      throw new HttpsError('permission-denied', 'Solo administradores')
    }

    const { ticket } = request.data ?? {}
    if (!ticket) {
      throw new HttpsError('invalid-argument', 'ticket requerido')
    }

    const settingsSnap = await admin.firestore().collection('companySettings').doc('main').get()
    const settings = settingsSnap.data() || {}
    const ambiente: AmbienteSunat = settings.ambienteSunat || 'inactivo'
    if (ambiente === 'inactivo') {
      throw new HttpsError('failed-precondition', 'Ambiente SUNAT esta inactivo')
    }

    const sunat = new SunatService()
    const result = await sunat.getStatus({
      ambiente,
      ruc: settings.ruc,
      usuarioSol: (process.env.SUNAT_SOL_USER || '').trim(),
      passwordSol: (process.env.SUNAT_SOL_PASSWORD || '').trim(),
      ticket,
    })

    return result
  },
)

/**
 * Cloud Function HTTPS callable para emitir una Nota de Credito que anule o
 * ajuste un comprobante (boleta o factura) ya aceptado por SUNAT.
 *
 * Motivo por defecto: '01' (Anulacion de la operacion).
 */
export const emitirNotaCredito = onCall(
  {
    cors: true,
    secrets: [SUNAT_CERT_PASSWORD, SUNAT_SOL_USER, SUNAT_SOL_PASSWORD],
    memory: '512MiB',
    timeoutSeconds: 120,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Debes iniciar sesion')
    }
    const adminUid = request.auth.uid
    const adminSnap = await admin.firestore().collection('users').doc(adminUid).get()
    const adminData = adminSnap.data()
    if (!adminData?.isAdmin && adminData?.userType !== 'admin') {
      throw new HttpsError('permission-denied', 'Solo administradores')
    }

    const { invoiceId, motivoCode = '01', motivoDescripcion = 'Anulacion de la operacion' } = request.data ?? {}
    if (!invoiceId) {
      throw new HttpsError('invalid-argument', 'invoiceId requerido')
    }
    const validCodes: MotivoNotaCredito[] = ['01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '13']
    if (!validCodes.includes(motivoCode)) {
      throw new HttpsError('invalid-argument', `motivoCode invalido. Debe ser uno de ${validCodes.join(', ')}`)
    }

    try {
      const service = new InvoiceService()
      const result = await service.emitCreditNote({
        invoiceId,
        motivoCode,
        motivoDescripcion,
        adminUid,
      })
      return {
        ok: result.estadoSunat === 'aceptado',
        ...result,
      }
    } catch (err: any) {
      console.error('Error en emitirNotaCredito:', err)
      throw new HttpsError('internal', err.message || 'Error al emitir nota de credito')
    }
  },
)
