import { onCall, HttpsError } from 'firebase-functions/v2/https'
import * as admin from 'firebase-admin'
import { NotificationService } from '../services/NotificationService'

/**
 * Documentos REQUERIDOS para aprobar un conductor.
 * Debe coincidir con app/lib/screens/driver/documents_screen.dart#requiredDocTypes
 * (los con required:true)
 */
const REQUIRED_DOC_IDS = [
  'license',
  'id_card',
  'vehicle_registration',
  'insurance',
  'technical_review',
  'background_check',
]

const DOC_NAMES_ES: Record<string, string> = {
  license: 'Licencia de Conducir',
  id_card: 'Documento de Identidad',
  vehicle_registration: 'Tarjeta de Propiedad',
  insurance: 'SOAT',
  technical_review: 'Revisión Técnica',
  background_check: 'Antecedentes Policiales',
  bank_account: 'Certificación Bancaria',
}

async function ensureAdmin(uid: string) {
  const snap = await admin.firestore().collection('users').doc(uid).get()
  const data = snap.data()
  if (!data?.isAdmin && data?.userType !== 'admin') {
    throw new HttpsError('permission-denied', 'Solo administradores')
  }
}

async function getDriverTokens(driverId: string): Promise<string[]> {
  const userSnap = await admin.firestore().collection('users').doc(driverId).get()
  if (!userSnap.exists) return []
  const data = userSnap.data() ?? {}
  // El modelo puede usar varios paths según versión
  const tokens: string[] = []
  if (Array.isArray(data.fcmTokens)) tokens.push(...data.fcmTokens)
  if (typeof data.fcmToken === 'string' && data.fcmToken) tokens.push(data.fcmToken)
  if (data.deviceTokens && typeof data.deviceTokens === 'object') {
    tokens.push(...(Object.values(data.deviceTokens) as string[]))
  }
  return [...new Set(tokens.filter((t) => typeof t === 'string' && t.length > 0))]
}

/**
 * Aprueba a un conductor: marca todos sus documentos en estado approved
 * (si quedaban en pending), actualiza users/{uid} con driverStatus='approved'
 * y documentVerified=true, y envía push notif.
 */
export const approveDriver = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Debes iniciar sesion')
  await ensureAdmin(request.auth.uid)

  const { driverId } = request.data ?? {}
  if (!driverId || typeof driverId !== 'string') {
    throw new HttpsError('invalid-argument', 'driverId requerido')
  }

  const db = admin.firestore()
  const userRef = db.collection('users').doc(driverId)
  const userSnap = await userRef.get()
  if (!userSnap.exists) throw new HttpsError('not-found', 'Conductor no encontrado')

  // Verificar que tenga todos los documentos REQUERIDOS aprobados
  const docsSnap = await db.collection('drivers').doc(driverId).collection('documents').get()
  const docsMap = new Map<string, any>()
  docsSnap.docs.forEach((d) => docsMap.set(d.id, d.data()))

  const missing: string[] = []
  for (const docId of REQUIRED_DOC_IDS) {
    const doc = docsMap.get(docId)
    if (!doc || doc.status !== 'approved') {
      missing.push(DOC_NAMES_ES[docId] ?? docId)
    }
  }
  if (missing.length > 0) {
    throw new HttpsError(
      'failed-precondition',
      `Faltan documentos por aprobar: ${missing.join(', ')}`,
    )
  }

  // Patch user
  await userRef.update({
    driverStatus: 'approved',
    documentVerified: true,
    isVerified: true,
    approvedAt: admin.firestore.FieldValue.serverTimestamp(),
    approvedBy: request.auth.uid,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  })

  // Send push notif
  try {
    const tokens = await getDriverTokens(driverId)
    if (tokens.length > 0) {
      const notif = new NotificationService()
      await notif.sendToTokens(
        tokens,
        {
          title: '✅ Cuenta aprobada',
          body: 'Tu cuenta de conductor fue aprobada. Ya puedes empezar a aceptar viajes.',
        },
        { type: 'driver_approved', driverId },
        'high',
      )
    }
  } catch (err) {
    console.warn('Notification fail (non-blocking):', err)
  }

  return { ok: true, driverId }
})

/**
 * Aprueba un documento individual del conductor.
 * (El admin puede aprobar uno por uno; cuando todos los requeridos estén
 * approved, puede llamar a approveDriver.)
 */
export const approveDriverDocument = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Debes iniciar sesion')
  await ensureAdmin(request.auth.uid)

  const { driverId, docId } = request.data ?? {}
  if (!driverId || !docId) {
    throw new HttpsError('invalid-argument', 'driverId y docId requeridos')
  }

  const docRef = admin.firestore()
    .collection('drivers').doc(driverId)
    .collection('documents').doc(docId)
  const docSnap = await docRef.get()
  if (!docSnap.exists) {
    throw new HttpsError('not-found', 'Documento no encontrado o no subido')
  }

  await docRef.update({
    status: 'approved',
    rejectionReason: admin.firestore.FieldValue.delete(),
    approvedAt: admin.firestore.FieldValue.serverTimestamp(),
    approvedBy: request.auth.uid,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  })

  return { ok: true, docId }
})

/**
 * Rechaza un documento. Envía push notif al conductor con el motivo.
 */
export const rejectDriverDocument = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Debes iniciar sesion')
  await ensureAdmin(request.auth.uid)

  const { driverId, docId, reason } = request.data ?? {}
  if (!driverId || !docId || !reason || typeof reason !== 'string') {
    throw new HttpsError('invalid-argument', 'driverId, docId y reason requeridos')
  }

  const docRef = admin.firestore()
    .collection('drivers').doc(driverId)
    .collection('documents').doc(docId)
  const docSnap = await docRef.get()
  if (!docSnap.exists) {
    throw new HttpsError('not-found', 'Documento no encontrado')
  }

  await docRef.update({
    status: 'rejected',
    rejectionReason: reason.trim().slice(0, 500),
    rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
    rejectedBy: request.auth.uid,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  })

  // Send push notif al conductor
  try {
    const tokens = await getDriverTokens(driverId)
    if (tokens.length > 0) {
      const docName = DOC_NAMES_ES[docId] ?? docId
      const notif = new NotificationService()
      await notif.sendToTokens(
        tokens,
        {
          title: `❌ ${docName} rechazado`,
          body: `Motivo: ${reason}. Resubir desde la app para volver a revisar.`,
        },
        { type: 'document_rejected', driverId, docId, reason },
        'high',
      )
    }
  } catch (err) {
    console.warn('Notification fail (non-blocking):', err)
  }

  return { ok: true, docId }
})
