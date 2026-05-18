import { Server as SocketIOServer, Socket } from 'socket.io';
import admin from 'firebase-admin';
import { logger } from '../utils/logger';
import EmergencyService from './emergency.service';

interface LocationUpdate {
  rideId: string;
  lat: number;
  lng: number;
  driverId?: string;
  passengerId?: string;
  heading?: number;
  speed?: number;
  accuracy?: number;
}

interface ChatMessage {
  rideId: string;
  message: string;
  senderId: string;
  senderType: 'driver' | 'passenger';
  timestamp?: Date;
  type?: 'text' | 'image' | 'audio' | 'location';
}

interface EmergencyTrigger {
  userId: string;
  location: {
    lat: number;
    lng: number;
    address?: string;
  };
  rideId?: string;
  audioUrl?: string;
}

export class SocketService {
  private io: SocketIOServer;
  private db = admin.firestore();
  private activeConnections: Map<string, Socket> = new Map();
  private userSockets: Map<string, string> = new Map(); // userId -> socketId
  private emergencyService: EmergencyService;

  constructor(io: SocketIOServer) {
    this.io = io;
    this.emergencyService = new EmergencyService(io);
  }

  public initialize(): void {
    this.io.on('connection', (socket) => {
      logger.info(`📱 Socket connected: ${socket.id}`);
      
      // Almacenar conexión activa
      this.activeConnections.set(socket.id, socket);

      // Autenticación del socket
      socket.on('authenticate', async (data: { userId: string, userType: 'driver' | 'passenger' | 'admin' }) => {
        const { userId, userType } = data;
        
        // Asociar socket con usuario
        this.userSockets.set(userId, socket.id);
        socket.data.userId = userId;
        socket.data.userType = userType;
        
        // Unir a salas según el tipo de usuario
        socket.join(`user-${userId}`);
        
        if (userType === 'admin') {
          socket.join('admins');
          logger.info(`👨‍💼 Admin ${userId} connected`);
        } else if (userType === 'driver') {
          socket.join('drivers');
          // Actualizar estado online del conductor
          await this.updateDriverStatus(userId, true);
          logger.info(`🚗 Driver ${userId} connected`);
        } else {
          socket.join('passengers');
          logger.info(`👤 Passenger ${userId} connected`);
        }
        
        socket.emit('authenticated', { success: true });
      });

      // TRACKING EN TIEMPO REAL
      socket.on('update-location', async (data: LocationUpdate) => {
        try {
          const { rideId, lat, lng, driverId, heading, speed, accuracy } = data;
          
          logger.debug(`📍 Location update for ride ${rideId}: ${lat}, ${lng}`);
          
          // Actualizar ubicación en Firestore
          const locationData: any = {
            currentLocation: new admin.firestore.GeoPoint(lat, lng),
            lastLocationUpdate: admin.firestore.FieldValue.serverTimestamp()
          };
          
          if (heading !== undefined) locationData.heading = heading;
          if (speed !== undefined) locationData.speed = speed;
          if (accuracy !== undefined) locationData.accuracy = accuracy;
          
          await this.db.collection('rides').doc(rideId).update(locationData);
          
          // Si es conductor, actualizar también su ubicación en el perfil
          if (driverId) {
            await this.db.collection('users').doc(driverId).update({
              currentLocation: new admin.firestore.GeoPoint(lat, lng),
              lastSeen: admin.firestore.FieldValue.serverTimestamp()
            });
          }
          
          // Emitir ubicación a todos los participantes del viaje
          this.io.to(`ride-${rideId}`).emit('driver-location', {
            lat,
            lng,
            heading,
            speed,
            accuracy,
            timestamp: new Date()
          });
          
          // Emitir también a la sala del pasajero específico
          const rideDoc = await this.db.collection('rides').doc(rideId).get();
          const rideData = rideDoc.data();
          if (rideData?.passengerId) {
            this.io.to(`passenger-${rideData.passengerId}`).emit('driver-location', {
              rideId,
              lat,
              lng,
              heading,
              speed,
              timestamp: new Date()
            });
          }
        } catch (error) {
          logger.error('Error updating location:', error);
          socket.emit('location-error', { message: 'Error actualizando ubicación' });
        }
      });

      // CHAT EN TIEMPO REAL
      socket.on('send-message', async (data: ChatMessage) => {
        try {
          const { rideId, message, senderId, senderType, type = 'text' } = data;
          
          logger.info(`💬 New message in ride ${rideId} from ${senderId}`);
          
          // Guardar mensaje en Firestore
          const messageData = {
            text: message,
            senderId,
            senderType,
            type,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            delivered: false,
            read: false
          };
          
          const messageRef = await this.db
            .collection('chats')
            .doc(rideId)
            .collection('messages')
            .add(messageData);
          
          // Actualizar último mensaje del chat
          await this.db.collection('chats').doc(rideId).set({
            lastMessage: message,
            lastMessageTime: admin.firestore.FieldValue.serverTimestamp(),
            lastMessageSender: senderId,
            unreadCount: admin.firestore.FieldValue.increment(1)
          }, { merge: true });
          
          // Emitir mensaje a todos los participantes del viaje
          this.io.to(`ride-${rideId}`).emit('new-message', {
            id: messageRef.id,
            ...messageData,
            timestamp: new Date()
          });
          
          // Notificar al receptor específico
          const rideDoc = await this.db.collection('rides').doc(rideId).get();
          const rideData = rideDoc.data();
          
          const receiverId = senderType === 'driver' 
            ? rideData?.passengerId 
            : rideData?.driverId;
          
          if (receiverId) {
            // Emitir notificación al receptor
            this.io.to(`user-${receiverId}`).emit('new-message', {
              rideId,
              message,
              senderId,
              senderType,
              timestamp: new Date()
            });
            
            // Marcar como entregado
            await messageRef.update({
              delivered: true,
              deliveredAt: admin.firestore.FieldValue.serverTimestamp()
            });
          }
        } catch (error) {
          logger.error('Error sending message:', error);
          socket.emit('message-error', { message: 'Error enviando mensaje' });
        }
      });

      // INDICADOR DE ESCRITURA
      socket.on('typing', async (data: { rideId: string, isTyping: boolean }) => {
        const { rideId, isTyping } = data;
        const userId = socket.data.userId;
        
        // Emitir estado de escritura a otros participantes
        socket.to(`ride-${rideId}`).emit('typing-status', {
          userId,
          isTyping,
          timestamp: new Date()
        });
      });

      // SOS EMERGENCY
      socket.on('sos-trigger', async (data: EmergencyTrigger) => {
        try {
          logger.error('🚨 SOS TRIGGERED:', data);
          
          const result = await this.emergencyService.triggerSOS(
            data.userId,
            data.location,
            data.rideId,
            data.audioUrl
          );
          
          // Notificar a todos los administradores
          this.io.to('admins').emit('emergency-alert', {
            ...data,
            emergencyId: result.emergencyId,
            timestamp: new Date()
          });
          
          // Confirmar al usuario que activó SOS
          socket.emit('sos-activated', {
            success: true,
            emergencyId: result.emergencyId,
            message: 'Emergencia activada. Ayuda en camino.'
          });
          
        } catch (error) {
          logger.error('Error triggering SOS:', error);
          socket.emit('sos-error', { 
            message: 'Error activando emergencia. Llama al 911 directamente.' 
          });
        }
      });

      // ACTUALIZACIÓN DE UBICACIÓN DE EMERGENCIA
      socket.on('emergency-location-update', async (data: { emergencyId: string, lat: number, lng: number }) => {
        try {
          await this.emergencyService.updateEmergencyLocation(
            data.emergencyId,
            {
              lat: data.lat,
              lng: data.lng,
              timestamp: new Date()
            }
          );
          
          // Notificar a admins
          this.io.to('admins').emit('emergency-location-update', data);
        } catch (error) {
          logger.error('Error updating emergency location:', error);
        }
      });

      // UNIRSE A SALA DE VIAJE
      socket.on('join-ride', (rideId: string) => {
        socket.join(`ride-${rideId}`);
        logger.info(`🚗 Socket ${socket.id} joined ride: ${rideId}`);
        
        // Notificar a otros participantes
        socket.to(`ride-${rideId}`).emit('user-joined', {
          userId: socket.data.userId,
          userType: socket.data.userType
        });
      });

      // DEJAR SALA DE VIAJE
      socket.on('leave-ride', (rideId: string) => {
        socket.leave(`ride-${rideId}`);
        logger.info(`🚗 Socket ${socket.id} left ride: ${rideId}`);
        
        // Notificar a otros participantes
        socket.to(`ride-${rideId}`).emit('user-left', {
          userId: socket.data.userId,
          userType: socket.data.userType
        });
      });

      // SOLICITUD DE VIAJE EN TIEMPO REAL
      socket.on('new-ride-request', async (data: any) => {
        const { pickupLat, pickupLng, destinationLat, destinationLng, passengerId } = data;
        
        // Buscar conductores cercanos
        const nearbyDrivers = await this.findNearbyDrivers(pickupLat, pickupLng, 5000);
        
        // Notificar a cada conductor cercano
        nearbyDrivers.forEach(driver => {
          const driverSocketId = this.userSockets.get(driver.id);
          if (driverSocketId) {
            this.io.to(driverSocketId).emit('ride-request', {
              passengerId,
              pickup: { lat: pickupLat, lng: pickupLng },
              destination: { lat: destinationLat, lng: destinationLng },
              distance: driver.distance,
              timestamp: new Date()
            });
          }
        });
        
        socket.emit('drivers-notified', {
          count: nearbyDrivers.length,
          drivers: nearbyDrivers.map(d => ({ id: d.id, distance: d.distance }))
        });
      });

      // ACEPTACIÓN DE VIAJE
      socket.on('accept-ride', async (data: { rideId: string, driverId: string }) => {
        const { rideId, driverId } = data;
        
        try {
          // Actualizar viaje en Firestore
          await this.db.collection('rides').doc(rideId).update({
            status: 'accepted',
            driverId,
            acceptedAt: admin.firestore.FieldValue.serverTimestamp()
          });
          
          // Obtener datos del viaje
          const rideDoc = await this.db.collection('rides').doc(rideId).get();
          const rideData = rideDoc.data();
          
          // Notificar al pasajero
          if (rideData?.passengerId) {
            const passengerSocketId = this.userSockets.get(rideData.passengerId);
            if (passengerSocketId) {
              this.io.to(passengerSocketId).emit('ride-accepted', {
                rideId,
                driverId,
                driverInfo: await this.getDriverInfo(driverId)
              });
            }
          }
          
          socket.emit('ride-accept-success', { rideId });
        } catch (error) {
          logger.error('Error accepting ride:', error);
          socket.emit('ride-accept-error', { message: 'Error aceptando viaje' });
        }
      });

      // INICIO DE VIAJE
      socket.on('start-ride', async (rideId: string) => {
        try {
          await this.db.collection('rides').doc(rideId).update({
            status: 'in_progress',
            startedAt: admin.firestore.FieldValue.serverTimestamp()
          });
          
          // Notificar a todos en la sala del viaje
          this.io.to(`ride-${rideId}`).emit('ride-started', {
            rideId,
            timestamp: new Date()
          });
        } catch (error) {
          logger.error('Error starting ride:', error);
          socket.emit('ride-start-error', { message: 'Error iniciando viaje' });
        }
      });

      // FINALIZACIÓN DE VIAJE
      socket.on('complete-ride', async (data: { rideId: string, finalFare: number }) => {
        try {
          await this.db.collection('rides').doc(rideId).update({
            status: 'completed',
            finalFare: data.finalFare,
            completedAt: admin.firestore.FieldValue.serverTimestamp()
          });
          
          // Notificar a todos en la sala del viaje
          this.io.to(`ride-${data.rideId}`).emit('ride-completed', {
            rideId: data.rideId,
            finalFare: data.finalFare,
            timestamp: new Date()
          });
        } catch (error) {
          logger.error('Error completing ride:', error);
          socket.emit('ride-complete-error', { message: 'Error completando viaje' });
        }
      });

      // CANCELACIÓN DE VIAJE
      socket.on('cancel-ride', async (data: { rideId: string, reason?: string }) => {
        try {
          await this.db.collection('rides').doc(data.rideId).update({
            status: 'cancelled',
            cancelReason: data.reason,
            cancelledBy: socket.data.userId,
            cancelledAt: admin.firestore.FieldValue.serverTimestamp()
          });
          
          // Notificar a todos en la sala del viaje
          this.io.to(`ride-${data.rideId}`).emit('ride-cancelled', {
            rideId: data.rideId,
            reason: data.reason,
            cancelledBy: socket.data.userId,
            timestamp: new Date()
          });
        } catch (error) {
          logger.error('Error cancelling ride:', error);
          socket.emit('ride-cancel-error', { message: 'Error cancelando viaje' });
        }
      });

      // LLAMADA DE VOZ
      socket.on('call-request', async (data: { rideId: string, from: string, to: string }) => {
        const targetSocketId = this.userSockets.get(data.to);
        if (targetSocketId) {
          this.io.to(targetSocketId).emit('incoming-call', {
            from: data.from,
            rideId: data.rideId
          });
        }
      });

      socket.on('call-answer', async (data: { rideId: string, from: string, to: string, answer: any }) => {
        const targetSocketId = this.userSockets.get(data.to);
        if (targetSocketId) {
          this.io.to(targetSocketId).emit('call-answered', {
            from: data.from,
            answer: data.answer
          });
        }
      });

      socket.on('call-reject', async (data: { rideId: string, from: string, to: string }) => {
        const targetSocketId = this.userSockets.get(data.to);
        if (targetSocketId) {
          this.io.to(targetSocketId).emit('call-rejected', {
            from: data.from
          });
        }
      });

      socket.on('call-end', async (data: { rideId: string, from: string, to: string }) => {
        const targetSocketId = this.userSockets.get(data.to);
        if (targetSocketId) {
          this.io.to(targetSocketId).emit('call-ended', {
            from: data.from
          });
        }
      });

      // ICE CANDIDATES PARA WEBRTC
      socket.on('ice-candidate', async (data: { rideId: string, to: string, candidate: any }) => {
        const targetSocketId = this.userSockets.get(data.to);
        if (targetSocketId) {
          this.io.to(targetSocketId).emit('ice-candidate', {
            from: socket.data.userId,
            candidate: data.candidate
          });
        }
      });

      // DESCONEXIÓN
      socket.on('disconnect', async () => {
        logger.info(`📴 Socket disconnected: ${socket.id}`);
        
        // Limpiar referencias
        this.activeConnections.delete(socket.id);
        
        if (socket.data.userId) {
          this.userSockets.delete(socket.data.userId);
          
          // Si es conductor, actualizar estado offline
          if (socket.data.userType === 'driver') {
            await this.updateDriverStatus(socket.data.userId, false);
          }
        }
      });

      // PING PARA MANTENER CONEXIÓN
      socket.on('ping', () => {
        socket.emit('pong', { timestamp: new Date() });
      });
    });

    logger.info('🔗 Socket.IO service initialized with full functionality');
  }

  // FUNCIONES AUXILIARES
  
  private async updateDriverStatus(driverId: string, isOnline: boolean) {
    try {
      await this.db.collection('users').doc(driverId).update({
        isOnline,
        lastSeen: admin.firestore.FieldValue.serverTimestamp()
      });
    } catch (error) {
      logger.error(`Error updating driver status:`, error);
    }
  }

  private async findNearbyDrivers(lat: number, lng: number, radiusInMeters: number) {
    try {
      // Obtener conductores disponibles
      const driversSnapshot = await this.db.collection('users')
        .where('role', '==', 'driver')
        .where('isOnline', '==', true)
        .where('isAvailable', '==', true)
        .get();
      
      const nearbyDrivers = [];
      
      driversSnapshot.forEach(doc => {
        const driver = doc.data();
        if (driver.currentLocation) {
          const distance = this.calculateDistance(
            lat, lng,
            driver.currentLocation.latitude,
            driver.currentLocation.longitude
          );
          
          if (distance <= radiusInMeters) {
            nearbyDrivers.push({
              id: doc.id,
              distance,
              location: {
                lat: driver.currentLocation.latitude,
                lng: driver.currentLocation.longitude
              }
            });
          }
        }
      });
      
      return nearbyDrivers.sort((a, b) => a.distance - b.distance);
    } catch (error) {
      logger.error('Error finding nearby drivers:', error);
      return [];
    }
  }

  private calculateDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
    const R = 6371e3; // Radio de la tierra en metros
    const φ1 = lat1 * Math.PI / 180;
    const φ2 = lat2 * Math.PI / 180;
    const Δφ = (lat2 - lat1) * Math.PI / 180;
    const Δλ = (lon2 - lon1) * Math.PI / 180;

    const a = Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
      Math.cos(φ1) * Math.cos(φ2) *
      Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

    return R * c;
  }

  private async getDriverInfo(driverId: string) {
    try {
      const driverDoc = await this.db.collection('users').doc(driverId).get();
      const driver = driverDoc.data();
      return driver ? {
        id: driverId,
        name: driver.name,
        photoUrl: driver.photoUrl,
        rating: driver.rating,
        vehicle: driver.vehicle
      } : null;
    } catch (error) {
      logger.error('Error getting driver info:', error);
      return null;
    }
  }

  // MÉTODOS PÚBLICOS
  
  public emitToRoom(room: string, event: string, data: any): void {
    this.io.to(room).emit(event, data);
  }

  public emitToSocket(socketId: string, event: string, data: any): void {
    this.io.to(socketId).emit(event, data);
  }

  public emitToUser(userId: string, event: string, data: any): void {
    const socketId = this.userSockets.get(userId);
    if (socketId) {
      this.io.to(socketId).emit(event, data);
    }
  }

  public broadcastToAdmins(event: string, data: any): void {
    this.io.to('admins').emit(event, data);
  }

  public getActiveConnections(): number {
    return this.activeConnections.size;
  }

  public isUserOnline(userId: string): boolean {
    return this.userSockets.has(userId);
  }
}