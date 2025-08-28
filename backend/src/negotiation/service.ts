import admin from 'firebase-admin';
import { v4 as uuidv4 } from 'uuid';
import { EventEmitter } from 'events';
import { io } from '../index';

const db = admin.firestore();
const messaging = admin.messaging();

interface NegotiationOffer {
  id: string;
  negotiationId: string;
  driverId: string;
  driverInfo: {
    name: string;
    photo: string;
    rating: number;
    totalRides: number;
    vehicle: {
      model: string;
      plate: string;
      color: string;
      type: string;
    };
    location: {
      lat: number;
      lng: number;
    };
    estimatedArrival: number; // minutos
  };
  offeredPrice: number;
  originalPrice: number;
  discount: number;
  status: 'pending' | 'accepted' | 'rejected' | 'expired' | 'countered';
  createdAt: Date;
  expiresAt: Date;
  counterOffers: Array<{
    price: number;
    byPassenger: boolean;
    timestamp: Date;
  }>;
}

interface NegotiationSession {
  id: string;
  passengerId: string;
  passengerInfo: {
    name: string;
    photo: string;
    rating: number;
  };
  pickup: {
    lat: number;
    lng: number;
    address: string;
  };
  destination: {
    lat: number;
    lng: number;
    address: string;
  };
  suggestedPrice: number;
  distance: number; // km
  duration: number; // minutos
  vehicleType: string;
  status: 'active' | 'completed' | 'expired' | 'cancelled';
  offers: NegotiationOffer[];
  acceptedOffer: NegotiationOffer | null;
  createdAt: Date;
  expiresAt: Date;
  timerExtended: boolean;
}

class NegotiationService extends EventEmitter {
  private activeSessions: Map<string, NegotiationSession> = new Map();
  private driverOffers: Map<string, Set<string>> = new Map(); // driverId -> Set of negotiationIds
  private timers: Map<string, NodeJS.Timeout> = new Map();

  constructor() {
    super();
    this.initializeListeners();
    this.restoreActiveSessions();
  }

  // Inicializar listeners de eventos
  private initializeListeners() {
    // Limpiar sesiones expiradas cada minuto
    setInterval(() => {
      this.cleanupExpiredSessions();
    }, 60000);
  }

  // Restaurar sesiones activas desde Firestore
  private async restoreActiveSessions() {
    try {
      const sessions = await db.collection('negotiations')
        .where('status', '==', 'active')
        .get();

      sessions.forEach(doc => {
        const session = doc.data() as NegotiationSession;
        this.activeSessions.set(session.id, session);
        this.startSessionTimer(session.id);
      });

      console.log(`✅ Restauradas ${sessions.size} sesiones de negociación activas`);
    } catch (error) {
      console.error('Error restaurando sesiones:', error);
    }
  }

  // Crear nueva sesión de negociación
  async createNegotiationSession(data: {
    passengerId: string;
    pickup: { lat: number; lng: number; address: string };
    destination: { lat: number; lng: number; address: string };
    suggestedPrice: number;
    distance: number;
    duration: number;
    vehicleType: string;
  }): Promise<NegotiationSession> {
    try {
      // Obtener información del pasajero
      const passengerDoc = await db.collection('users').doc(data.passengerId).get();
      if (!passengerDoc.exists) {
        throw new Error('Pasajero no encontrado');
      }
      const passengerData = passengerDoc.data()!;

      // Crear sesión
      const session: NegotiationSession = {
        id: uuidv4(),
        passengerId: data.passengerId,
        passengerInfo: {
          name: passengerData.name,
          photo: passengerData.profilePhoto || '',
          rating: passengerData.stats?.rating || 0
        },
        pickup: data.pickup,
        destination: data.destination,
        suggestedPrice: data.suggestedPrice,
        distance: data.distance,
        duration: data.duration,
        vehicleType: data.vehicleType,
        status: 'active',
        offers: [],
        acceptedOffer: null,
        createdAt: new Date(),
        expiresAt: new Date(Date.now() + 5 * 60 * 1000), // 5 minutos
        timerExtended: false
      };

      // Guardar en memoria y Firestore
      this.activeSessions.set(session.id, session);
      await db.collection('negotiations').doc(session.id).set(session);

      // Iniciar timer de expiración
      this.startSessionTimer(session.id);

      // Notificar a conductores cercanos
      await this.notifyNearbyDrivers(session);

      // Emitir evento WebSocket
      io.to(`passenger-${data.passengerId}`).emit('negotiation:created', session);

      console.log(`✅ Sesión de negociación creada: ${session.id}`);
      return session;

    } catch (error: any) {
      console.error('Error creando sesión de negociación:', error);
      throw error;
    }
  }

  // Conductor hace una oferta
  async makeOffer(data: {
    negotiationId: string;
    driverId: string;
    offeredPrice: number;
  }): Promise<NegotiationOffer> {
    try {
      const session = this.activeSessions.get(data.negotiationId);
      if (!session) {
        throw new Error('Sesión de negociación no encontrada');
      }

      if (session.status !== 'active') {
        throw new Error('La sesión de negociación no está activa');
      }

      // Verificar si el conductor ya hizo una oferta
      const existingOffer = session.offers.find(o => o.driverId === data.driverId);
      if (existingOffer && existingOffer.status === 'pending') {
        throw new Error('Ya tienes una oferta activa en esta negociación');
      }

      // Obtener información del conductor
      const driverDoc = await db.collection('users').doc(data.driverId).get();
      if (!driverDoc.exists) {
        throw new Error('Conductor no encontrado');
      }
      const driverData = driverDoc.data()!;

      // Calcular tiempo estimado de llegada
      const estimatedArrival = await this.calculateETAToPickup(
        driverData.lastKnownLocation,
        session.pickup
      );

      // Crear oferta
      const offer: NegotiationOffer = {
        id: uuidv4(),
        negotiationId: data.negotiationId,
        driverId: data.driverId,
        driverInfo: {
          name: driverData.name,
          photo: driverData.profilePhoto || '',
          rating: driverData.stats?.rating || 0,
          totalRides: driverData.stats?.totalRides || 0,
          vehicle: {
            model: driverData.driverInfo?.vehicleInfo?.model || '',
            plate: driverData.driverInfo?.vehicleInfo?.plate || '',
            color: driverData.driverInfo?.vehicleInfo?.color || '',
            type: driverData.driverInfo?.vehicleInfo?.type || ''
          },
          location: driverData.lastKnownLocation || { lat: 0, lng: 0 },
          estimatedArrival
        },
        offeredPrice: data.offeredPrice,
        originalPrice: session.suggestedPrice,
        discount: ((session.suggestedPrice - data.offeredPrice) / session.suggestedPrice) * 100,
        status: 'pending',
        createdAt: new Date(),
        expiresAt: session.expiresAt,
        counterOffers: []
      };

      // Agregar oferta a la sesión
      session.offers.push(offer);
      session.offers.sort((a, b) => a.offeredPrice - b.offeredPrice); // Ordenar por precio

      // Actualizar en Firestore
      await db.collection('negotiations').doc(session.id).update({
        offers: session.offers,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // Registrar que el conductor hizo una oferta
      if (!this.driverOffers.has(data.driverId)) {
        this.driverOffers.set(data.driverId, new Set());
      }
      this.driverOffers.get(data.driverId)!.add(data.negotiationId);

      // Notificar al pasajero
      await this.notifyPassenger(session.passengerId, {
        title: '¡Nueva oferta recibida! 🚕',
        body: `${driverData.name} ofrece S/. ${data.offeredPrice.toFixed(2)}`,
        data: {
          type: 'new_offer',
          negotiationId: data.negotiationId,
          offerId: offer.id
        }
      });

      // Emitir evento WebSocket
      io.to(`passenger-${session.passengerId}`).emit('negotiation:new-offer', offer);
      io.to(`negotiation-${session.id}`).emit('offer:created', offer);

      // Si es la primera oferta, extender el timer automáticamente
      if (session.offers.length === 1 && !session.timerExtended) {
        await this.extendTimer(session.id);
      }

      console.log(`✅ Oferta creada: ${offer.id} para sesión ${session.id}`);
      return offer;

    } catch (error: any) {
      console.error('Error creando oferta:', error);
      throw error;
    }
  }

  // Pasajero hace una contraoferta
  async makeCounterOffer(data: {
    negotiationId: string;
    offerId: string;
    counterPrice: number;
  }): Promise<NegotiationOffer> {
    try {
      const session = this.activeSessions.get(data.negotiationId);
      if (!session) {
        throw new Error('Sesión de negociación no encontrada');
      }

      const offer = session.offers.find(o => o.id === data.offerId);
      if (!offer) {
        throw new Error('Oferta no encontrada');
      }

      if (offer.status !== 'pending') {
        throw new Error('Esta oferta ya no está disponible para contraoferta');
      }

      // Agregar contraoferta
      offer.counterOffers.push({
        price: data.counterPrice,
        byPassenger: true,
        timestamp: new Date()
      });
      offer.status = 'countered';

      // Actualizar en Firestore
      await db.collection('negotiations').doc(session.id).update({
        offers: session.offers,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // Notificar al conductor
      await this.notifyDriver(offer.driverId, {
        title: '¡Contraoferta recibida! 💰',
        body: `El pasajero propone S/. ${data.counterPrice.toFixed(2)}`,
        data: {
          type: 'counter_offer',
          negotiationId: data.negotiationId,
          offerId: offer.id
        }
      });

      // Emitir evento WebSocket
      io.to(`driver-${offer.driverId}`).emit('negotiation:counter-offer', {
        negotiationId: data.negotiationId,
        offerId: offer.id,
        counterPrice: data.counterPrice
      });

      console.log(`✅ Contraoferta realizada en oferta ${offer.id}`);
      return offer;

    } catch (error: any) {
      console.error('Error creando contraoferta:', error);
      throw error;
    }
  }

  // Aceptar una oferta
  async acceptOffer(data: {
    negotiationId: string;
    offerId: string;
    passengerId: string;
  }): Promise<{ ride: any; offer: NegotiationOffer }> {
    try {
      const session = this.activeSessions.get(data.negotiationId);
      if (!session) {
        throw new Error('Sesión de negociación no encontrada');
      }

      if (session.passengerId !== data.passengerId) {
        throw new Error('No autorizado para aceptar esta oferta');
      }

      const offer = session.offers.find(o => o.id === data.offerId);
      if (!offer) {
        throw new Error('Oferta no encontrada');
      }

      if (offer.status !== 'pending' && offer.status !== 'countered') {
        throw new Error('Esta oferta ya no está disponible');
      }

      // Marcar oferta como aceptada
      offer.status = 'accepted';
      session.acceptedOffer = offer;
      session.status = 'completed';

      // Rechazar todas las demás ofertas
      session.offers.forEach(o => {
        if (o.id !== offer.id && o.status === 'pending') {
          o.status = 'rejected';
        }
      });

      // Crear el viaje
      const ride = await this.createRideFromOffer(session, offer);

      // Actualizar en Firestore
      await db.collection('negotiations').doc(session.id).update({
        status: 'completed',
        acceptedOffer: offer,
        offers: session.offers,
        completedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // Limpiar de memoria
      this.activeSessions.delete(session.id);
      this.clearSessionTimer(session.id);

      // Notificar al conductor aceptado
      await this.notifyDriver(offer.driverId, {
        title: '¡Oferta aceptada! 🎉',
        body: 'Tu oferta ha sido aceptada. Dirígete al punto de recogida.',
        data: {
          type: 'offer_accepted',
          negotiationId: data.negotiationId,
          rideId: ride.id
        }
      });

      // Notificar a los conductores rechazados
      for (const rejectedOffer of session.offers) {
        if (rejectedOffer.id !== offer.id && rejectedOffer.status === 'rejected') {
          await this.notifyDriver(rejectedOffer.driverId, {
            title: 'Oferta no aceptada',
            body: 'El pasajero eligió otra oferta. ¡Sigue intentando!',
            data: {
              type: 'offer_rejected',
              negotiationId: data.negotiationId
            }
          });
        }
      }

      // Emitir eventos WebSocket
      io.to(`negotiation-${session.id}`).emit('negotiation:completed', {
        acceptedOffer: offer,
        ride
      });
      io.to(`driver-${offer.driverId}`).emit('offer:accepted', { offer, ride });
      io.to(`passenger-${session.passengerId}`).emit('ride:created', ride);

      console.log(`✅ Oferta ${offer.id} aceptada, viaje ${ride.id} creado`);
      return { ride, offer };

    } catch (error: any) {
      console.error('Error aceptando oferta:', error);
      throw error;
    }
  }

  // Rechazar una oferta
  async rejectOffer(data: {
    negotiationId: string;
    offerId: string;
    driverId?: string;
    passengerId?: string;
  }): Promise<void> {
    try {
      const session = this.activeSessions.get(data.negotiationId);
      if (!session) {
        throw new Error('Sesión de negociación no encontrada');
      }

      const offer = session.offers.find(o => o.id === data.offerId);
      if (!offer) {
        throw new Error('Oferta no encontrada');
      }

      // Verificar autorización
      if (data.driverId && offer.driverId !== data.driverId) {
        throw new Error('No autorizado para rechazar esta oferta');
      }
      if (data.passengerId && session.passengerId !== data.passengerId) {
        throw new Error('No autorizado para rechazar esta oferta');
      }

      // Marcar como rechazada
      offer.status = 'rejected';

      // Actualizar en Firestore
      await db.collection('negotiations').doc(session.id).update({
        offers: session.offers,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // Notificar a la parte correspondiente
      if (data.driverId) {
        // Conductor canceló su oferta
        await this.notifyPassenger(session.passengerId, {
          title: 'Oferta retirada',
          body: `${offer.driverInfo.name} retiró su oferta`,
          data: {
            type: 'offer_withdrawn',
            negotiationId: data.negotiationId,
            offerId: offer.id
          }
        });
        io.to(`passenger-${session.passengerId}`).emit('offer:withdrawn', offer);
      } else {
        // Pasajero rechazó la oferta
        await this.notifyDriver(offer.driverId, {
          title: 'Oferta rechazada',
          body: 'El pasajero rechazó tu oferta',
          data: {
            type: 'offer_rejected',
            negotiationId: data.negotiationId,
            offerId: offer.id
          }
        });
        io.to(`driver-${offer.driverId}`).emit('offer:rejected', offer);
      }

      console.log(`✅ Oferta ${offer.id} rechazada`);

    } catch (error: any) {
      console.error('Error rechazando oferta:', error);
      throw error;
    }
  }

  // Extender timer de negociación
  async extendTimer(negotiationId: string): Promise<void> {
    try {
      const session = this.activeSessions.get(negotiationId);
      if (!session) {
        throw new Error('Sesión no encontrada');
      }

      if (session.timerExtended) {
        throw new Error('El timer ya fue extendido');
      }

      // Extender 3 minutos más
      session.expiresAt = new Date(session.expiresAt.getTime() + 3 * 60 * 1000);
      session.timerExtended = true;

      // Actualizar timer
      this.clearSessionTimer(negotiationId);
      this.startSessionTimer(negotiationId);

      // Actualizar en Firestore
      await db.collection('negotiations').doc(negotiationId).update({
        expiresAt: session.expiresAt,
        timerExtended: true
      });

      // Notificar a todos los participantes
      io.to(`negotiation-${negotiationId}`).emit('timer:extended', {
        expiresAt: session.expiresAt
      });

      console.log(`✅ Timer extendido para sesión ${negotiationId}`);

    } catch (error: any) {
      console.error('Error extendiendo timer:', error);
      throw error;
    }
  }

  // Obtener sesión activa
  getActiveSession(negotiationId: string): NegotiationSession | undefined {
    return this.activeSessions.get(negotiationId);
  }

  // Obtener todas las ofertas de una sesión
  getSessionOffers(negotiationId: string): NegotiationOffer[] {
    const session = this.activeSessions.get(negotiationId);
    return session?.offers || [];
  }

  // Métodos privados auxiliares

  private startSessionTimer(sessionId: string) {
    const session = this.activeSessions.get(sessionId);
    if (!session) return;

    const timeUntilExpiry = session.expiresAt.getTime() - Date.now();
    if (timeUntilExpiry <= 0) {
      this.expireSession(sessionId);
      return;
    }

    const timer = setTimeout(() => {
      this.expireSession(sessionId);
    }, timeUntilExpiry);

    this.timers.set(sessionId, timer);
  }

  private clearSessionTimer(sessionId: string) {
    const timer = this.timers.get(sessionId);
    if (timer) {
      clearTimeout(timer);
      this.timers.delete(sessionId);
    }
  }

  private async expireSession(sessionId: string) {
    const session = this.activeSessions.get(sessionId);
    if (!session) return;

    session.status = 'expired';
    session.offers.forEach(offer => {
      if (offer.status === 'pending') {
        offer.status = 'expired';
      }
    });

    // Actualizar en Firestore
    await db.collection('negotiations').doc(sessionId).update({
      status: 'expired',
      offers: session.offers,
      expiredAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // Notificar a todos
    io.to(`negotiation-${sessionId}`).emit('negotiation:expired', session);

    // Limpiar
    this.activeSessions.delete(sessionId);
    this.clearSessionTimer(sessionId);

    console.log(`⏱️ Sesión ${sessionId} expirada`);
  }

  private async cleanupExpiredSessions() {
    const now = Date.now();
    for (const [sessionId, session] of this.activeSessions) {
      if (session.expiresAt.getTime() < now) {
        await this.expireSession(sessionId);
      }
    }
  }

  private async notifyNearbyDrivers(session: NegotiationSession) {
    try {
      // Buscar conductores cercanos (5km radio)
      const drivers = await db.collection('users')
        .where('role', '==', 'driver')
        .where('driverInfo.availability.isOnline', '==', true)
        .get();

      const nearbyDrivers = [];
      for (const doc of drivers.docs) {
        const driver = doc.data();
        if (driver.lastKnownLocation) {
          const distance = this.calculateDistance(
            driver.lastKnownLocation,
            session.pickup
          );
          if (distance <= 5) { // 5km radio
            nearbyDrivers.push(driver);
          }
        }
      }

      // Enviar notificación a cada conductor cercano
      for (const driver of nearbyDrivers) {
        if (driver.deviceTokens && driver.deviceTokens.length > 0) {
          await messaging.sendMulticast({
            tokens: driver.deviceTokens,
            notification: {
              title: '¡Nueva solicitud de viaje! 🚕',
              body: `${session.pickup.address} → ${session.destination.address}\nPrecio sugerido: S/. ${session.suggestedPrice.toFixed(2)}`
            },
            data: {
              type: 'new_negotiation',
              negotiationId: session.id,
              pickup: JSON.stringify(session.pickup),
              destination: JSON.stringify(session.destination)
            }
          });
        }

        // WebSocket notification
        io.to(`driver-${driver.uid}`).emit('negotiation:available', session);
      }

      console.log(`📢 Notificados ${nearbyDrivers.length} conductores cercanos`);

    } catch (error) {
      console.error('Error notificando conductores:', error);
    }
  }

  private async notifyPassenger(passengerId: string, notification: any) {
    try {
      const user = await db.collection('users').doc(passengerId).get();
      if (user.exists && user.data()?.deviceTokens) {
        await messaging.sendMulticast({
          tokens: user.data()!.deviceTokens,
          notification: {
            title: notification.title,
            body: notification.body
          },
          data: notification.data
        });
      }
    } catch (error) {
      console.error('Error notificando pasajero:', error);
    }
  }

  private async notifyDriver(driverId: string, notification: any) {
    try {
      const user = await db.collection('users').doc(driverId).get();
      if (user.exists && user.data()?.deviceTokens) {
        await messaging.sendMulticast({
          tokens: user.data()!.deviceTokens,
          notification: {
            title: notification.title,
            body: notification.body
          },
          data: notification.data
        });
      }
    } catch (error) {
      console.error('Error notificando conductor:', error);
    }
  }

  private calculateDistance(point1: any, point2: any): number {
    // Fórmula Haversine para calcular distancia
    const R = 6371; // Radio de la Tierra en km
    const dLat = this.toRad(point2.lat - point1.lat);
    const dLon = this.toRad(point2.lng - point1.lng);
    const lat1 = this.toRad(point1.lat);
    const lat2 = this.toRad(point2.lat);

    const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
      Math.sin(dLon/2) * Math.sin(dLon/2) * Math.cos(lat1) * Math.cos(lat2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
    return R * c;
  }

  private toRad(value: number): number {
    return value * Math.PI / 180;
  }

  private async calculateETAToPickup(driverLocation: any, pickup: any): Promise<number> {
    if (!driverLocation) return 15; // Default 15 minutos
    
    const distance = this.calculateDistance(driverLocation, pickup);
    // Estimación simple: 30 km/h velocidad promedio en ciudad
    const estimatedMinutes = Math.ceil((distance / 30) * 60);
    return Math.min(estimatedMinutes, 45); // Máximo 45 minutos
  }

  private async createRideFromOffer(session: NegotiationSession, offer: NegotiationOffer): Promise<any> {
    // Crear el viaje basado en la oferta aceptada
    const ride = {
      id: uuidv4(),
      passengerId: session.passengerId,
      driverId: offer.driverId,
      pickup: session.pickup,
      destination: session.destination,
      price: offer.offeredPrice,
      originalPrice: session.suggestedPrice,
      distance: session.distance,
      duration: session.duration,
      vehicleType: session.vehicleType,
      status: 'accepted',
      negotiationId: session.id,
      acceptedOfferId: offer.id,
      createdAt: new Date(),
      scheduledFor: null,
      startedAt: null,
      completedAt: null,
      cancelledAt: null,
      paymentMethod: 'cash', // Por defecto
      paymentStatus: 'pending',
      driverLocation: offer.driverInfo.location,
      estimatedArrival: offer.driverInfo.estimatedArrival,
      passengerRating: null,
      driverRating: null,
      route: [],
      events: [{
        type: 'ride_created',
        timestamp: new Date(),
        data: { negotiatedPrice: offer.offeredPrice }
      }]
    };

    // Guardar en Firestore
    await db.collection('rides').doc(ride.id).set(ride);

    // Actualizar estado del conductor
    await db.collection('users').doc(offer.driverId).update({
      'driverInfo.currentRide': ride.id,
      'driverInfo.availability.isOnline': false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    return ride;
  }
}

export default new NegotiationService();