import { Server, Socket } from 'socket.io';
import * as admin from 'firebase-admin';
import jwt from 'jsonwebtoken';
import { logger } from '@shared/utils/logger';
import negotiationService from '../negotiation/service';
import { chatService } from '../chat/service';
import { trackingService } from '../tracking/service';
import { AppError } from '@shared/middleware/error-handler';

// 🔐 Interfaces de autenticación
interface AuthenticatedSocket extends Socket {
  userId?: string;
  userRole?: 'passenger' | 'driver' | 'admin';
  userEmail?: string;
  deviceId?: string;
}

// 📊 Gestión de salas
interface RoomManager {
  rideRooms: Map<string, Set<string>>; // rideId -> Set<userId>
  userRooms: Map<string, Set<string>>; // userId -> Set<rideId>
  conversationRooms: Map<string, Set<string>>; // conversationId -> Set<userId>
  zoneRooms: Map<string, Set<string>>; // zoneId -> Set<userId>
}

// 🌍 Estado global
const roomManager: RoomManager = {
  rideRooms: new Map(),
  userRooms: new Map(),
  conversationRooms: new Map(),
  zoneRooms: new Map()
};

// 📍 Tracking de ubicaciones activas
const activeLocations = new Map<string, {
  latitude: number;
  longitude: number;
  heading?: number;
  speed?: number;
  accuracy?: number;
  timestamp: Date;
}>();

// ⏱️ Heartbeat para detectar desconexiones
const heartbeatIntervals = new Map<string, NodeJS.Timeout>();

/**
 * 🚀 Manejador principal de WebSocket
 */
export const websocketHandler = (io: Server, socket: AuthenticatedSocket) => {
  logger.info(`Nueva conexión WebSocket: ${socket.id}`);

  // 🔐 Autenticar socket
  socket.on('authenticate', async (data: { token: string; deviceId?: string }) => {
    try {
      const decoded = jwt.verify(data.token, process.env.JWT_SECRET || 'rappitaxi_jwt_secret_2025') as any;
      
      socket.userId = decoded.userId;
      socket.userRole = decoded.role;
      socket.deviceId = data.deviceId || decoded.deviceId;

      // Unirse a sala personal
      socket.join(`user:${socket.userId}`);
      
      // Registrar en servicios
      chatService.registerConnection(socket.userId, socket);
      
      // Iniciar heartbeat
      startHeartbeat(socket);

      // Enviar confirmación
      socket.emit('authenticated', {
        success: true,
        userId: socket.userId,
        role: socket.userRole
      });

      logger.info(`Socket autenticado: ${socket.userId} (${socket.userRole})`);

      // Recuperar salas activas del usuario
      await rejoinUserRooms(io, socket);

    } catch (error) {
      socket.emit('auth:error', {
        error: 'Token inválido',
        code: 'INVALID_TOKEN'
      });
      socket.disconnect();
    }
  });

  // 🚗 EVENTOS DE VIAJE
  // ==================

  /**
   * Solicitar un viaje
   */
  socket.on('ride:request', async (data: {
    pickupLocation: { latitude: number; longitude: number; address: string };
    dropoffLocation: { latitude: number; longitude: number; address: string };
    vehicleType: string;
    paymentMethod: string;
    estimatedPrice?: number;
    negotiationType?: 'fixed' | 'negotiable';
  }) => {
    if (!socket.userId || socket.userRole !== 'passenger') {
      return socket.emit('error', { message: 'No autorizado' });
    }

    try {
      // Crear solicitud de viaje
      const rideRequest = await createRideRequest({
        passengerId: socket.userId,
        ...data
      });

      // Unirse a sala del viaje
      joinRideRoom(socket, rideRequest.id);

      // Buscar conductores cercanos
      const nearbyDrivers = await findNearbyDrivers(
        data.pickupLocation.latitude,
        data.pickupLocation.longitude,
        5000 // Radio de 5km
      );

      // Notificar a conductores cercanos
      nearbyDrivers.forEach(driver => {
        io.to(`user:${driver.id}`).emit('ride:new_request', {
          rideId: rideRequest.id,
          passenger: {
            id: socket.userId,
            name: rideRequest.passengerName,
            rating: rideRequest.passengerRating,
            totalRides: rideRequest.passengerTotalRides
          },
          pickup: data.pickupLocation,
          dropoff: data.dropoffLocation,
          distance: rideRequest.distance,
          estimatedTime: rideRequest.estimatedTime,
          vehicleType: data.vehicleType,
          paymentMethod: data.paymentMethod,
          estimatedPrice: data.estimatedPrice,
          negotiationType: data.negotiationType
        });
      });

      // Si es negociable, crear sesión de negociación
      if (data.negotiationType === 'negotiable') {
        const negotiationSession = await negotiationService.createNegotiationSession({
          rideRequestId: rideRequest.id,
          passengerId: socket.userId,
          passengerName: rideRequest.passengerName,
          pickupLocation: data.pickupLocation,
          dropoffLocation: data.dropoffLocation,
          basePrice: data.estimatedPrice || 0,
          expiresAt: new Date(Date.now() + 5 * 60 * 1000) // 5 minutos
        });

        socket.emit('negotiation:session_created', negotiationSession);
      }

      socket.emit('ride:request_created', rideRequest);
      
      logger.info(`Solicitud de viaje creada: ${rideRequest.id}`);
    } catch (error) {
      logger.error('Error creando solicitud de viaje:', error);
      socket.emit('error', { message: 'Error al crear solicitud' });
    }
  });

  /**
   * Conductor acepta solicitud
   */
  socket.on('ride:accept', async (data: { rideId: string }) => {
    if (!socket.userId || socket.userRole !== 'driver') {
      return socket.emit('error', { message: 'No autorizado' });
    }

    try {
      const ride = await acceptRide(data.rideId, socket.userId);
      
      // Unirse a sala del viaje
      joinRideRoom(socket, data.rideId);

      // Notificar a ambos
      io.to(`ride:${data.rideId}`).emit('ride:driver_assigned', {
        rideId: data.rideId,
        driver: ride.driver,
        estimatedArrival: ride.estimatedArrival
      });

      // Crear conversación de chat
      const conversation = await chatService.createConversation({
        rideId: data.rideId,
        passengerId: ride.passengerId,
        passengerName: ride.passengerName,
        driverId: socket.userId,
        driverName: ride.driver.name,
        driverAvatar: ride.driver.photoUrl
      });

      io.to(`ride:${data.rideId}`).emit('chat:conversation_created', conversation);

      logger.info(`Viaje aceptado: ${data.rideId} por conductor ${socket.userId}`);
    } catch (error) {
      logger.error('Error aceptando viaje:', error);
      socket.emit('error', { message: 'Error al aceptar viaje' });
    }
  });

  /**
   * Rechazar solicitud
   */
  socket.on('ride:reject', async (data: { rideId: string; reason?: string }) => {
    if (!socket.userId || socket.userRole !== 'driver') {
      return socket.emit('error', { message: 'No autorizado' });
    }

    try {
      await rejectRide(data.rideId, socket.userId, data.reason);
      
      socket.emit('ride:rejected', { rideId: data.rideId });
      
      logger.info(`Viaje rechazado: ${data.rideId} por conductor ${socket.userId}`);
    } catch (error) {
      logger.error('Error rechazando viaje:', error);
      socket.emit('error', { message: 'Error al rechazar viaje' });
    }
  });

  /**
   * Iniciar viaje
   */
  socket.on('ride:start', async (data: { rideId: string }) => {
    if (!socket.userId || socket.userRole !== 'driver') {
      return socket.emit('error', { message: 'No autorizado' });
    }

    try {
      const ride = await startRide(data.rideId);
      
      io.to(`ride:${data.rideId}`).emit('ride:started', {
        rideId: data.rideId,
        startedAt: ride.startedAt
      });

      // Enviar mensaje de sistema en chat
      await chatService.sendSystemMessage(
        ride.conversationId,
        '🚗 El viaje ha comenzado'
      );

      logger.info(`Viaje iniciado: ${data.rideId}`);
    } catch (error) {
      logger.error('Error iniciando viaje:', error);
      socket.emit('error', { message: 'Error al iniciar viaje' });
    }
  });

  /**
   * Completar viaje
   */
  socket.on('ride:complete', async (data: { 
    rideId: string; 
    finalLocation?: { latitude: number; longitude: number };
  }) => {
    if (!socket.userId || socket.userRole !== 'driver') {
      return socket.emit('error', { message: 'No autorizado' });
    }

    try {
      const ride = await completeRide(data.rideId, data.finalLocation);
      
      io.to(`ride:${data.rideId}`).emit('ride:completed', {
        rideId: data.rideId,
        completedAt: ride.completedAt,
        finalPrice: ride.finalPrice,
        distance: ride.actualDistance,
        duration: ride.actualDuration
      });

      // Cerrar conversación de chat
      await chatService.closeConversation(ride.conversationId);

      // Limpiar salas
      cleanupRideRoom(data.rideId);

      logger.info(`Viaje completado: ${data.rideId}`);
    } catch (error) {
      logger.error('Error completando viaje:', error);
      socket.emit('error', { message: 'Error al completar viaje' });
    }
  });

  /**
   * Cancelar viaje
   */
  socket.on('ride:cancel', async (data: { rideId: string; reason: string }) => {
    if (!socket.userId) {
      return socket.emit('error', { message: 'No autorizado' });
    }

    try {
      const ride = await cancelRide(data.rideId, socket.userId, data.reason);
      
      io.to(`ride:${data.rideId}`).emit('ride:cancelled', {
        rideId: data.rideId,
        cancelledBy: socket.userId,
        reason: data.reason,
        cancellationFee: ride.cancellationFee
      });

      // Cerrar conversación si existe
      if (ride.conversationId) {
        await chatService.sendSystemMessage(
          ride.conversationId,
          `❌ Viaje cancelado: ${data.reason}`
        );
        await chatService.closeConversation(ride.conversationId);
      }

      // Limpiar salas
      cleanupRideRoom(data.rideId);

      logger.info(`Viaje cancelado: ${data.rideId} por ${socket.userId}`);
    } catch (error) {
      logger.error('Error cancelando viaje:', error);
      socket.emit('error', { message: 'Error al cancelar viaje' });
    }
  });

  // 💰 EVENTOS DE NEGOCIACIÓN (InDrive)
  // ====================================

  /**
   * Hacer oferta (conductor)
   */
  socket.on('negotiation:make_offer', async (data: {
    sessionId: string;
    price: number;
    estimatedArrival: number;
    message?: string;
  }) => {
    if (!socket.userId || socket.userRole !== 'driver') {
      return socket.emit('error', { message: 'No autorizado' });
    }

    try {
      // Obtener información del conductor
      const driverDoc = await admin.firestore()
        .collection('users')
        .doc(socket.userId)
        .get();

      if (!driverDoc.exists) {
        throw new AppError('Conductor no encontrado', 404, 'DRIVER_NOT_FOUND');
      }

      const driverData = driverDoc.data();

      const offer = await negotiationService.makeOffer({
        sessionId: data.sessionId,
        driverId: socket.userId,
        driverName: driverData?.name || 'Conductor',
        driverRating: driverData?.driverData?.rating || 5.0,
        driverTotalRides: driverData?.driverData?.totalRides || 0,
        vehicleInfo: driverData?.driverData?.vehicleInfo,
        offeredPrice: data.price,
        estimatedArrival: data.estimatedArrival,
        message: data.message
      });

      // Notificar al pasajero
      const session = await negotiationService.getNegotiationSession(data.sessionId);
      io.to(`user:${session.passengerId}`).emit('negotiation:new_offer', offer);

      socket.emit('negotiation:offer_sent', offer);

      logger.info(`Oferta realizada en sesión ${data.sessionId} por ${socket.userId}`);
    } catch (error) {
      logger.error('Error haciendo oferta:', error);
      socket.emit('error', { message: 'Error al hacer oferta' });
    }
  });

  /**
   * Contraoferta (pasajero)
   */
  socket.on('negotiation:counter_offer', async (data: {
    sessionId: string;
    offerId: string;
    counterPrice: number;
    message?: string;
  }) => {
    if (!socket.userId || socket.userRole !== 'passenger') {
      return socket.emit('error', { message: 'No autorizado' });
    }

    try {
      const counterOffer = await negotiationService.makeCounterOffer({
        sessionId: data.sessionId,
        offerId: data.offerId,
        passengerId: socket.userId,
        counterPrice: data.counterPrice,
        message: data.message
      });

      // Notificar al conductor
      io.to(`user:${counterOffer.driverId}`).emit('negotiation:counter_offer', counterOffer);

      socket.emit('negotiation:counter_sent', counterOffer);

      logger.info(`Contraoferta en sesión ${data.sessionId}`);
    } catch (error) {
      logger.error('Error haciendo contraoferta:', error);
      socket.emit('error', { message: 'Error al hacer contraoferta' });
    }
  });

  /**
   * Aceptar oferta
   */
  socket.on('negotiation:accept_offer', async (data: {
    sessionId: string;
    offerId: string;
  }) => {
    if (!socket.userId || socket.userRole !== 'passenger') {
      return socket.emit('error', { message: 'No autorizado' });
    }

    try {
      const result = await negotiationService.acceptOffer({
        sessionId: data.sessionId,
        offerId: data.offerId,
        passengerId: socket.userId
      });

      // Notificar a ambos
      io.to(`user:${socket.userId}`).emit('negotiation:offer_accepted', result);
      io.to(`user:${result.offer.driverId}`).emit('negotiation:offer_accepted', result);

      // Crear sala del viaje
      const rideRoom = `ride:${result.ride.id}`;
      socket.join(rideRoom);
      io.sockets.sockets.get(`user:${result.offer.driverId}`)?.join(rideRoom);

      logger.info(`Oferta aceptada: ${data.offerId} en sesión ${data.sessionId}`);
    } catch (error) {
      logger.error('Error aceptando oferta:', error);
      socket.emit('error', { message: 'Error al aceptar oferta' });
    }
  });

  /**
   * Rechazar oferta
   */
  socket.on('negotiation:reject_offer', async (data: {
    sessionId: string;
    offerId: string;
    reason?: string;
  }) => {
    if (!socket.userId || socket.userRole !== 'passenger') {
      return socket.emit('error', { message: 'No autorizado' });
    }

    try {
      await negotiationService.rejectOffer({
        sessionId: data.sessionId,
        offerId: data.offerId,
        reason: data.reason
      });

      // Obtener oferta para notificar al conductor
      const offer = await negotiationService.getOffer(data.offerId);
      io.to(`user:${offer.driverId}`).emit('negotiation:offer_rejected', {
        offerId: data.offerId,
        reason: data.reason
      });

      socket.emit('negotiation:rejection_sent');

      logger.info(`Oferta rechazada: ${data.offerId}`);
    } catch (error) {
      logger.error('Error rechazando oferta:', error);
      socket.emit('error', { message: 'Error al rechazar oferta' });
    }
  });

  // 💬 EVENTOS DE CHAT
  // ==================

  /**
   * Enviar mensaje
   */
  socket.on('chat:send_message', async (data: {
    conversationId: string;
    content: string;
    type?: string;
    metadata?: any;
    replyTo?: string;
  }) => {
    if (!socket.userId) {
      return socket.emit('error', { message: 'No autorizado' });
    }

    try {
      // Obtener rol del usuario en la conversación
      const userDoc = await admin.firestore()
        .collection('users')
        .doc(socket.userId)
        .get();

      const userData = userDoc.data();
      const userRole = userData?.role as 'passenger' | 'driver';

      const message = await chatService.sendMessage({
        conversationId: data.conversationId,
        senderId: socket.userId,
        senderName: userData?.name || 'Usuario',
        senderRole: userRole,
        content: data.content,
        type: data.type as any,
        metadata: data.metadata,
        replyTo: data.replyTo
      });

      logger.info(`Mensaje enviado en conversación ${data.conversationId}`);
    } catch (error) {
      logger.error('Error enviando mensaje:', error);
      socket.emit('error', { message: 'Error al enviar mensaje' });
    }
  });

  /**
   * Marcar mensaje como leído
   */
  socket.on('chat:mark_read', async (data: { messageId: string }) => {
    if (!socket.userId) {
      return socket.emit('error', { message: 'No autorizado' });
    }

    try {
      await chatService.markAsRead({
        messageId: data.messageId,
        userId: socket.userId
      });
    } catch (error) {
      logger.error('Error marcando mensaje como leído:', error);
      socket.emit('error', { message: 'Error al marcar como leído' });
    }
  });

  /**
   * Estado de escritura
   */
  socket.on('chat:typing', async (data: {
    conversationId: string;
    isTyping: boolean;
  }) => {
    if (!socket.userId) {
      return socket.emit('error', { message: 'No autorizado' });
    }

    try {
      const userDoc = await admin.firestore()
        .collection('users')
        .doc(socket.userId)
        .get();

      const userData = userDoc.data();
      const userRole = userData?.role as 'passenger' | 'driver';

      await chatService.setTypingStatus({
        conversationId: data.conversationId,
        userId: socket.userId,
        userRole: userRole,
        isTyping: data.isTyping
      });
    } catch (error) {
      logger.error('Error actualizando estado de escritura:', error);
    }
  });

  // 📍 EVENTOS DE TRACKING GPS
  // ==========================

  /**
   * Actualizar ubicación
   */
  socket.on('tracking:update_location', async (data: {
    latitude: number;
    longitude: number;
    heading?: number;
    speed?: number;
    accuracy?: number;
  }) => {
    if (!socket.userId) {
      return socket.emit('error', { message: 'No autorizado' });
    }

    try {
      // Guardar ubicación
      const location = {
        ...data,
        timestamp: new Date()
      };

      activeLocations.set(socket.userId, location);

      // Si es conductor, actualizar en Firestore
      if (socket.userRole === 'driver') {
        await updateDriverLocation(socket.userId, location);

        // Notificar a pasajeros en viajes activos
        const activeRides = await getDriverActiveRides(socket.userId);
        activeRides.forEach(ride => {
          io.to(`ride:${ride.id}`).emit('driver:location_update', {
            rideId: ride.id,
            driverId: socket.userId,
            location
          });
        });
      }

      // Si es pasajero con viaje activo, notificar al conductor
      if (socket.userRole === 'passenger') {
        const activeRide = await getPassengerActiveRide(socket.userId);
        if (activeRide) {
          io.to(`ride:${activeRide.id}`).emit('passenger:location_update', {
            rideId: activeRide.id,
            passengerId: socket.userId,
            location
          });
        }
      }

      socket.emit('tracking:location_updated');

      logger.debug(`Ubicación actualizada para ${socket.userId}`);
    } catch (error) {
      logger.error('Error actualizando ubicación:', error);
      socket.emit('error', { message: 'Error al actualizar ubicación' });
    }
  });

  /**
   * Compartir viaje
   */
  socket.on('tracking:share_trip', async (data: { rideId: string }) => {
    if (!socket.userId || socket.userRole !== 'passenger') {
      return socket.emit('error', { message: 'No autorizado' });
    }

    try {
      const shareCode = await generateShareCode(data.rideId);
      const shareUrl = `${process.env.APP_URL}/track/${shareCode}`;

      socket.emit('tracking:share_url', {
        rideId: data.rideId,
        shareCode,
        shareUrl
      });

      logger.info(`Viaje compartido: ${data.rideId} con código ${shareCode}`);
    } catch (error) {
      logger.error('Error compartiendo viaje:', error);
      socket.emit('error', { message: 'Error al compartir viaje' });
    }
  });

  // 🔔 EVENTOS DE NOTIFICACIONES
  // =============================

  /**
   * Suscribirse a notificaciones
   */
  socket.on('notifications:subscribe', async (data: {
    topics?: string[];
    fcmToken?: string;
  }) => {
    if (!socket.userId) {
      return socket.emit('error', { message: 'No autorizado' });
    }

    try {
      // Guardar token FCM si se proporciona
      if (data.fcmToken) {
        await saveFCMToken(socket.userId, data.fcmToken, socket.deviceId);
      }

      // Suscribirse a temas
      if (data.topics) {
        for (const topic of data.topics) {
          socket.join(`topic:${topic}`);
        }
      }

      socket.emit('notifications:subscribed');

      logger.info(`Usuario ${socket.userId} suscrito a notificaciones`);
    } catch (error) {
      logger.error('Error suscribiendo a notificaciones:', error);
      socket.emit('error', { message: 'Error al suscribir' });
    }
  });

  // 🚪 EVENTOS DE SALA
  // ==================

  /**
   * Unirse a sala
   */
  socket.on('room:join', async (data: { room: string }) => {
    socket.join(data.room);
    socket.emit('room:joined', { room: data.room });
    logger.debug(`Socket ${socket.id} unido a sala ${data.room}`);
  });

  /**
   * Salir de sala
   */
  socket.on('room:leave', async (data: { room: string }) => {
    socket.leave(data.room);
    socket.emit('room:left', { room: data.room });
    logger.debug(`Socket ${socket.id} salió de sala ${data.room}`);
  });

  // 🆘 EVENTOS DE EMERGENCIA
  // ========================

  /**
   * Alerta de emergencia
   */
  socket.on('emergency:alert', async (data: {
    rideId?: string;
    location: { latitude: number; longitude: number };
    type: 'panic' | 'accident' | 'medical' | 'security';
    message?: string;
  }) => {
    if (!socket.userId) {
      return socket.emit('error', { message: 'No autorizado' });
    }

    try {
      const emergency = await createEmergencyAlert({
        userId: socket.userId,
        userRole: socket.userRole!,
        rideId: data.rideId,
        location: data.location,
        type: data.type,
        message: data.message
      });

      // Notificar a administradores
      io.to('role:admin').emit('emergency:new_alert', emergency);

      // Si hay viaje activo, notificar al otro participante
      if (data.rideId) {
        io.to(`ride:${data.rideId}`).emit('emergency:alert_triggered', emergency);
      }

      // Notificar a contactos de emergencia
      await notifyEmergencyContacts(socket.userId, emergency);

      socket.emit('emergency:alert_sent', emergency);

      logger.warn(`⚠️ Alerta de emergencia: ${emergency.id} de ${socket.userId}`);
    } catch (error) {
      logger.error('Error creando alerta de emergencia:', error);
      socket.emit('error', { message: 'Error al enviar alerta' });
    }
  });

  // 💓 HEARTBEAT
  // ============

  socket.on('heartbeat', () => {
    socket.emit('heartbeat:ack', { timestamp: Date.now() });
  });

  // 🔌 DESCONEXIÓN
  // ==============

  socket.on('disconnect', () => {
    if (socket.userId) {
      // Limpiar ubicación activa
      activeLocations.delete(socket.userId);

      // Limpiar heartbeat
      const interval = heartbeatIntervals.get(socket.userId);
      if (interval) {
        clearInterval(interval);
        heartbeatIntervals.delete(socket.userId);
      }

      // Actualizar estado offline si es conductor
      if (socket.userRole === 'driver') {
        updateDriverOnlineStatus(socket.userId, false);
      }

      // Limpiar salas de usuario
      cleanupUserRooms(socket.userId);

      logger.info(`Socket desconectado: ${socket.userId}`);
    } else {
      logger.info(`Socket desconectado: ${socket.id}`);
    }
  });
};

// 🛠️ FUNCIONES AUXILIARES
// ========================

/**
 * Iniciar heartbeat para detectar desconexiones
 */
function startHeartbeat(socket: AuthenticatedSocket): void {
  if (!socket.userId) return;

  // Limpiar heartbeat anterior si existe
  const existingInterval = heartbeatIntervals.get(socket.userId);
  if (existingInterval) {
    clearInterval(existingInterval);
  }

  // Crear nuevo heartbeat cada 30 segundos
  const interval = setInterval(() => {
    socket.emit('heartbeat:ping');
  }, 30000);

  heartbeatIntervals.set(socket.userId, interval);
}

/**
 * Reunirse a salas activas del usuario
 */
async function rejoinUserRooms(io: Server, socket: AuthenticatedSocket): Promise<void> {
  if (!socket.userId) return;

  try {
    // Obtener viajes activos
    if (socket.userRole === 'passenger') {
      const activeRide = await getPassengerActiveRide(socket.userId);
      if (activeRide) {
        socket.join(`ride:${activeRide.id}`);
        socket.emit('room:rejoined', { room: `ride:${activeRide.id}` });
      }
    } else if (socket.userRole === 'driver') {
      const activeRides = await getDriverActiveRides(socket.userId);
      activeRides.forEach(ride => {
        socket.join(`ride:${ride.id}`);
        socket.emit('room:rejoined', { room: `ride:${ride.id}` });
      });
    }

    // Obtener conversaciones activas
    const conversations = await chatService.getUserConversations(socket.userId, socket.userRole);
    conversations.forEach(conv => {
      if (conv.isActive) {
        socket.join(`conversation:${conv.id}`);
        socket.emit('room:rejoined', { room: `conversation:${conv.id}` });
      }
    });

    logger.info(`Usuario ${socket.userId} reunido a salas activas`);
  } catch (error) {
    logger.error('Error reuniendo a salas:', error);
  }
}

/**
 * Gestión de salas de viaje
 */
function joinRideRoom(socket: AuthenticatedSocket, rideId: string): void {
  if (!socket.userId) return;

  socket.join(`ride:${rideId}`);
  
  // Actualizar gestión de salas
  if (!roomManager.rideRooms.has(rideId)) {
    roomManager.rideRooms.set(rideId, new Set());
  }
  roomManager.rideRooms.get(rideId)!.add(socket.userId);

  if (!roomManager.userRooms.has(socket.userId)) {
    roomManager.userRooms.set(socket.userId, new Set());
  }
  roomManager.userRooms.get(socket.userId)!.add(rideId);
}

function cleanupRideRoom(rideId: string): void {
  const users = roomManager.rideRooms.get(rideId);
  if (users) {
    users.forEach(userId => {
      const userRides = roomManager.userRooms.get(userId);
      if (userRides) {
        userRides.delete(rideId);
      }
    });
    roomManager.rideRooms.delete(rideId);
  }
}

function cleanupUserRooms(userId: string): void {
  const rides = roomManager.userRooms.get(userId);
  if (rides) {
    rides.forEach(rideId => {
      const rideUsers = roomManager.rideRooms.get(rideId);
      if (rideUsers) {
        rideUsers.delete(userId);
      }
    });
    roomManager.userRooms.delete(userId);
  }
}

// 📦 Funciones de base de datos (simplificadas)
// ==============================================

async function createRideRequest(data: any): Promise<any> {
  // Implementación real iría aquí
  return { id: 'ride_' + Date.now(), ...data };
}

async function findNearbyDrivers(lat: number, lng: number, radius: number): Promise<any[]> {
  // Implementación con geohashing o consulta geoespacial
  return [];
}

async function acceptRide(rideId: string, driverId: string): Promise<any> {
  // Implementación real
  return { id: rideId, driver: { id: driverId, name: 'Conductor' } };
}

async function rejectRide(rideId: string, driverId: string, reason?: string): Promise<void> {
  // Implementación real
}

async function startRide(rideId: string): Promise<any> {
  // Implementación real
  return { id: rideId, startedAt: new Date() };
}

async function completeRide(rideId: string, finalLocation?: any): Promise<any> {
  // Implementación real
  return { id: rideId, completedAt: new Date() };
}

async function cancelRide(rideId: string, userId: string, reason: string): Promise<any> {
  // Implementación real
  return { id: rideId };
}

async function updateDriverLocation(driverId: string, location: any): Promise<void> {
  // Actualizar en Firestore
  await admin.firestore()
    .collection('driver_locations')
    .doc(driverId)
    .set(location, );
}

async function updateDriverOnlineStatus(driverId: string, isOnline: boolean): Promise<void> {
  await admin.firestore()
    .collection('users')
    .doc(driverId)
    .update({
      'driverData.isOnline': isOnline,
      updatedAt: new Date()
    });
}

async function getPassengerActiveRide(passengerId: string): Promise<any> {
  const ridesQuery = await admin.firestore()
    .collection('rides')
    .where('passengerId', '==', passengerId)
    .where('status', 'in', ['requested', 'accepted', 'arrived', 'in_progress'])
    .orderBy('createdAt', 'desc')
    .limit(1)
    .get();

  return ridesQuery.empty ? null : { id: ridesQuery.docs[0].id, ...ridesQuery.docs[0].data() };
}

async function getDriverActiveRides(driverId: string): Promise<any[]> {
  const ridesQuery = await admin.firestore()
    .collection('rides')
    .where('driverId', '==', driverId)
    .where('status', 'in', ['accepted', 'arrived', 'in_progress'])
    .get();

  return ridesQuery.docs.map(doc => ({ id: doc.id, ...doc.data() }));
}

async function generateShareCode(rideId: string): Promise<string> {
  // Generar código único de compartir
  return Buffer.from(rideId).toString('base64').slice(0, 8);
}

async function saveFCMToken(userId: string, token: string, deviceId?: string): Promise<void> {
  await admin.firestore()
    .collection('fcm_tokens')
    .doc(userId)
    .set({
      tokens: admin.firestore.FieldValue.arrayUnion({
        token,
        deviceId,
        createdAt: new Date()
      })
    }, );
}

async function createEmergencyAlert(data: any): Promise<any> {
  const alertId = 'emergency_' + Date.now();
  const alert = {
    id: alertId,
    ...data,
    createdAt: new Date(),
    status: 'active'
  };

  await admin.firestore()
    .collection('emergencies')
    .doc(alertId)
    .set(alert);

  return alert;
}

async function notifyEmergencyContacts(userId: string, emergency: any): Promise<void> {
  // Implementación de notificación a contactos de emergencia
  logger.info(`Notificando contactos de emergencia para ${userId}`);
}