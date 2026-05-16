import { onCall, HttpsError } from 'firebase-functions/v2/https'
import * as admin from 'firebase-admin'

/**
 * Crea un viaje manualmente desde el panel admin.
 *
 * Dos modos:
 * - 'guest':      Cliente no registrado (llamada/WhatsApp). El admin pasa
 *                 nombre + teléfono. El passengerId queda como el adminUid
 *                 (placeholder) y los campos guestPassengerName/Phone +
 *                 isManualOrder se guardan en el ride.
 * - 'registered': Cliente con cuenta. Admin pasa passengerId real.
 *
 * El ride se escribe en `rides/{rideId}` con `status: 'requested'`. El
 * trigger existente `processNewTrip` (en functions/src/index.ts) detectará
 * el nuevo doc y disparará `TripNotificationHandler.handleNewTrip()` que
 * notifica a los conductores cercanos vía FCM.
 */
export const createManualRide = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Debes iniciar sesion')
  }
  const adminUid = request.auth.uid

  // Verificar admin
  const adminSnap = await admin.firestore().collection('users').doc(adminUid).get()
  const adminData = adminSnap.data()
  if (!adminData?.isAdmin && adminData?.userType !== 'admin') {
    throw new HttpsError('permission-denied', 'Solo administradores')
  }

  const {
    mode,
    passengerId,
    guestName,
    guestPhone,
    pickup,
    destination,
    fare,
    estimatedDistance,
    rideType,
    notes,
    paymentMethod,
  } = request.data ?? {}

  // Validaciones
  if (!mode || (mode !== 'guest' && mode !== 'registered')) {
    throw new HttpsError('invalid-argument', "mode debe ser 'guest' o 'registered'")
  }
  if (!pickup?.lat || !pickup?.lng || !pickup?.address) {
    throw new HttpsError('invalid-argument', 'pickup {lat, lng, address} requerido')
  }
  if (!destination?.lat || !destination?.lng || !destination?.address) {
    throw new HttpsError('invalid-argument', 'destination {lat, lng, address} requerido')
  }
  const fareNumber = Number(fare)
  if (!fareNumber || fareNumber <= 0) {
    throw new HttpsError('invalid-argument', 'fare > 0 requerido')
  }

  let finalPassengerId: string
  let passengerInfo: Record<string, any> = {}

  if (mode === 'registered') {
    if (!passengerId || typeof passengerId !== 'string') {
      throw new HttpsError('invalid-argument', 'passengerId requerido en modo registered')
    }
    const pSnap = await admin.firestore().collection('users').doc(passengerId).get()
    if (!pSnap.exists) {
      throw new HttpsError('not-found', 'Pasajero no encontrado')
    }
    finalPassengerId = passengerId
    const pData = pSnap.data() ?? {}
    passengerInfo = {
      name: pData.fullName ?? pData.name ?? '',
      phone: pData.phone ?? pData.phoneNumber ?? '',
      email: pData.email ?? '',
    }
  } else {
    // guest
    if (!guestName || typeof guestName !== 'string' || !guestName.trim()) {
      throw new HttpsError('invalid-argument', 'guestName requerido')
    }
    if (!guestPhone || typeof guestPhone !== 'string' || !guestPhone.trim()) {
      throw new HttpsError('invalid-argument', 'guestPhone requerido')
    }
    // En modo guest usamos el adminUid como passengerId placeholder.
    // TripNotificationHandler tolera esto porque siempre lee passenger data
    // de users/{passengerId} — y los admins existen en users.
    finalPassengerId = adminUid
    passengerInfo = {
      name: guestName.trim(),
      phone: guestPhone.trim(),
      isGuest: true,
    }
  }

  // Calcular distancia (Haversine) si no viene
  const distance = Number(estimatedDistance) > 0
    ? Number(estimatedDistance)
    : haversineMeters(pickup.lat, pickup.lng, destination.lat, destination.lng)

  // Crear ride doc
  const rideRef = admin.firestore().collection('rides').doc()
  const now = admin.firestore.FieldValue.serverTimestamp()
  const rideData = {
    passengerId: finalPassengerId,
    userId: finalPassengerId, // compatibilidad: algunos queries usan userId
    pickupLocation: { lat: pickup.lat, lng: pickup.lng },
    destinationLocation: { lat: destination.lat, lng: destination.lng },
    pickupAddress: pickup.address,
    destinationAddress: destination.address,
    status: 'requested',
    requestedAt: now,
    createdAt: now,
    estimatedDistance: distance,
    estimatedFare: fareNumber,
    paymentMethod: paymentMethod ?? 'cash',
    isPaidOutsideApp: true,
    rideType: rideType ?? 'express',
    passengerInfo,
    // Campos específicos de pedidos manuales
    isManualOrder: true,
    createdByAdmin: adminUid,
    adminNotes: notes ?? null,
    ...(mode === 'guest' && {
      guestPassengerName: guestName.trim(),
      guestPassengerPhone: guestPhone.trim(),
    }),
    // Radius más amplio para pedidos manuales (10km vs 5km default)
    radiusKm: 10,
  }

  await rideRef.set(rideData)

  console.log(`✅ Pedido manual creado: ${rideRef.id} (mode=${mode}, fare=S/${fareNumber})`)

  return {
    ok: true,
    rideId: rideRef.id,
    mode,
    estimatedDistance: distance,
  }
})

/**
 * Calcula la distancia en metros entre dos coordenadas GPS usando
 * la fórmula de Haversine.
 */
function haversineMeters(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371e3 // radio Tierra en metros
  const φ1 = (lat1 * Math.PI) / 180
  const φ2 = (lat2 * Math.PI) / 180
  const Δφ = ((lat2 - lat1) * Math.PI) / 180
  const Δλ = ((lon2 - lon1) * Math.PI) / 180
  const a =
    Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
    Math.cos(φ1) * Math.cos(φ2) * Math.sin(Δλ / 2) * Math.sin(Δλ / 2)
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  return Math.round(R * c)
}
