import { onCall, HttpsError } from 'firebase-functions/v2/https'
import * as admin from 'firebase-admin'
import { ensureAdmin, getUserFcmTokens } from '../helpers/adminHelpers'
import { NotificationService } from '../services/NotificationService'

const CANCELABLE_STATUSES = [
  'requested',
  'searching_driver',
  'accepted',
  'arrived',
  'in_progress',
  'driver_assigned',
]

/**
 * Cancels a ride from the admin panel.
 *
 * - Validates the ride is in a cancelable status
 * - Marks `status: 'cancelled'` with metadata (cancelledBy, reason, uid)
 * - Closes any active negotiation associated with the ride
 * - Sends push to driver (if assigned) and passenger (if not guest)
 * - If the ride was paid via MercadoPago, marks `refundPending: true`
 *   for manual processing (full refund automation requires
 *   MercadoPagoService.refund which is not implemented yet).
 */
export const cancelRideByAdmin = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Debes iniciar sesion')
  }
  const adminUid = request.auth.uid
  await ensureAdmin(adminUid)

  const { rideId, reason } = request.data ?? {}
  if (!rideId || typeof rideId !== 'string') {
    throw new HttpsError('invalid-argument', 'rideId requerido')
  }
  const trimmedReason = typeof reason === 'string' ? reason.trim() : ''
  if (!trimmedReason) {
    throw new HttpsError('invalid-argument', 'reason requerido')
  }

  const firestore = admin.firestore()
  const rideRef = firestore.collection('rides').doc(rideId)
  const rideSnap = await rideRef.get()
  if (!rideSnap.exists) {
    throw new HttpsError('not-found', 'Viaje no encontrado')
  }
  const ride = rideSnap.data() ?? {}
  const currentStatus = String(ride.status ?? '')
  if (!CANCELABLE_STATUSES.includes(currentStatus)) {
    throw new HttpsError(
      'failed-precondition',
      `Viaje en estado "${currentStatus}" no se puede cancelar`,
    )
  }

  const now = admin.firestore.FieldValue.serverTimestamp()
  const paymentStatus = String(ride.paymentStatus ?? '')
  const wasPaidViaMP = paymentStatus === 'paid' && ride.paymentMethod !== 'cash'

  const updatePayload: Record<string, any> = {
    status: 'cancelled',
    cancelledBy: 'admin',
    cancelledByUid: adminUid,
    cancelledAt: now,
    cancellationReason: trimmedReason,
  }
  if (wasPaidViaMP) {
    updatePayload.refundPending = true
    updatePayload.refundRequestedAt = now
  }

  await rideRef.update(updatePayload)

  // Close any active negotiation linked to this ride
  try {
    const negotiationsSnap = await firestore
      .collection('negotiations')
      .where('rideId', '==', rideId)
      .where('status', 'in', ['waiting', 'negotiating', 'accepted'])
      .get()
    if (!negotiationsSnap.empty) {
      const batch = firestore.batch()
      for (const doc of negotiationsSnap.docs) {
        batch.update(doc.ref, {
          status: 'cancelled',
          cancelledBy: 'admin',
          cancelledAt: now,
          cancellationReason: trimmedReason,
        })
      }
      await batch.commit()
    }
  } catch (err) {
    console.warn('Could not close negotiations for cancelled ride:', err)
  }

  // Notify driver and passenger via FCM
  const notif = new NotificationService()

  const driverId: string | undefined = ride.driverId
  if (driverId) {
    const driverTokens = await getUserFcmTokens(driverId)
    if (driverTokens.length > 0) {
      await notif.sendToTokens(
        driverTokens,
        {
          title: '❌ Viaje cancelado por administración',
          body: trimmedReason,
        },
        { type: 'ride_cancelled_by_admin', rideId, reason: trimmedReason },
        'high',
      )
    }
  }

  const isManualOrder = ride.isManualOrder === true
  const passengerId: string | undefined = ride.passengerId
  if (passengerId && !isManualOrder && passengerId !== adminUid) {
    const passengerTokens = await getUserFcmTokens(passengerId)
    if (passengerTokens.length > 0) {
      await notif.sendToTokens(
        passengerTokens,
        {
          title: '❌ Tu viaje fue cancelado',
          body: trimmedReason,
        },
        { type: 'ride_cancelled_by_admin', rideId, reason: trimmedReason },
        'high',
      )
    }
  }

  console.log(
    `✅ Ride ${rideId} cancelled by admin ${adminUid} — reason: "${trimmedReason}" — refundPending=${wasPaidViaMP}`,
  )

  return {
    ok: true,
    rideId,
    refundPending: wasPaidViaMP,
  }
})
