import { onCall, HttpsError } from 'firebase-functions/v2/https'
import * as admin from 'firebase-admin'
import { ensureAdmin, getUserFcmTokens } from '../helpers/adminHelpers'
import { NotificationService } from '../services/NotificationService'

const BLOCKING_RIDE_STATUSES = [
  'requested',
  'searching_driver',
  'accepted',
  'arrived',
  'in_progress',
  'driver_assigned',
]

/**
 * Suspends a user account. Sets isActive=false and adds an audit trail.
 * Refuses to suspend if the user has rides in progress — operator must
 * cancel those first to avoid stranded passengers/drivers.
 */
export const suspendUser = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Debes iniciar sesion')
  const adminUid = request.auth.uid
  await ensureAdmin(adminUid)

  const { userId, reason } = request.data ?? {}
  if (!userId || typeof userId !== 'string') {
    throw new HttpsError('invalid-argument', 'userId requerido')
  }
  const trimmedReason = typeof reason === 'string' ? reason.trim() : ''
  if (!trimmedReason) {
    throw new HttpsError('invalid-argument', 'reason requerido')
  }

  const firestore = admin.firestore()
  const userRef = firestore.collection('users').doc(userId)
  const userSnap = await userRef.get()
  if (!userSnap.exists) {
    throw new HttpsError('not-found', 'Usuario no encontrado')
  }

  // Guard: refuse if active rides exist (as passenger or driver)
  const [asPassenger, asDriver] = await Promise.all([
    firestore
      .collection('rides')
      .where('passengerId', '==', userId)
      .where('status', 'in', BLOCKING_RIDE_STATUSES)
      .limit(1)
      .get(),
    firestore
      .collection('rides')
      .where('driverId', '==', userId)
      .where('status', 'in', BLOCKING_RIDE_STATUSES)
      .limit(1)
      .get(),
  ])
  if (!asPassenger.empty || !asDriver.empty) {
    throw new HttpsError(
      'failed-precondition',
      'El usuario tiene viajes activos. Cancélalos primero antes de suspender.',
    )
  }

  const now = admin.firestore.FieldValue.serverTimestamp()
  await userRef.update({
    isActive: false,
    suspendedAt: now,
    suspendedByUid: adminUid,
    suspendedReason: trimmedReason,
    isOnline: false,
  })

  // Best-effort: notify the user that their account was suspended
  try {
    const tokens = await getUserFcmTokens(userId)
    if (tokens.length > 0) {
      await new NotificationService().sendToTokens(
        tokens,
        {
          title: 'Cuenta suspendida',
          body: `Tu cuenta fue suspendida: ${trimmedReason}`,
        },
        { type: 'account_suspended', reason: trimmedReason },
        'high',
      )
    }
  } catch (err) {
    console.warn('Could not send suspension push:', err)
  }

  return { ok: true, userId }
})

/**
 * Reactivates a previously suspended user account.
 */
export const reactivateUser = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Debes iniciar sesion')
  const adminUid = request.auth.uid
  await ensureAdmin(adminUid)

  const { userId } = request.data ?? {}
  if (!userId || typeof userId !== 'string') {
    throw new HttpsError('invalid-argument', 'userId requerido')
  }

  const userRef = admin.firestore().collection('users').doc(userId)
  const userSnap = await userRef.get()
  if (!userSnap.exists) {
    throw new HttpsError('not-found', 'Usuario no encontrado')
  }

  const now = admin.firestore.FieldValue.serverTimestamp()
  await userRef.update({
    isActive: true,
    reactivatedAt: now,
    reactivatedByUid: adminUid,
    suspendedAt: admin.firestore.FieldValue.delete(),
    suspendedReason: admin.firestore.FieldValue.delete(),
    suspendedByUid: admin.firestore.FieldValue.delete(),
  })

  return { ok: true, userId }
})

/**
 * Generates a password reset link for the target user and returns it
 * to the admin (who can then send it to the user via WhatsApp/email
 * manually). Firebase Auth does NOT send an email automatically from
 * the Admin SDK — we return the link string instead.
 *
 * For automated email sending, integrate SendGrid / email backend.
 */
export const sendPasswordResetForUser = onCall({ cors: true }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Debes iniciar sesion')
  const adminUid = request.auth.uid
  await ensureAdmin(adminUid)

  const { userId } = request.data ?? {}
  if (!userId || typeof userId !== 'string') {
    throw new HttpsError('invalid-argument', 'userId requerido')
  }

  const userSnap = await admin.firestore().collection('users').doc(userId).get()
  if (!userSnap.exists) {
    throw new HttpsError('not-found', 'Usuario no encontrado')
  }
  const userData = userSnap.data() ?? {}
  const email = userData.email
  if (!email || typeof email !== 'string') {
    throw new HttpsError('failed-precondition', 'Usuario sin email registrado')
  }

  try {
    const link = await admin.auth().generatePasswordResetLink(email)
    return { ok: true, email, link }
  } catch (err: any) {
    console.error('generatePasswordResetLink error:', err)
    throw new HttpsError('internal', err?.message ?? 'No se pudo generar el link')
  }
})
