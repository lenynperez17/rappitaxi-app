/**
 * SERVICIO DE TRACKING EN TIEMPO REAL - RAPITEAM
 * ===============================================
 * 
 * Funcionalidades principales:
 * - Actualización de ubicación del conductor cada 5 segundos
 * - Cálculo de ETA dinámico usando Google Directions API  
 * - Historial completo de ruta guardado en Firestore
 * - Emisión en tiempo real vía Socket.IO a pasajeros
 * - Cálculo de distancias y tiempo de viaje exacto
 * - Optimización de rutas en tiempo real según tráfico
 * - Detección de desvíos de ruta y alertas automáticas
 */

import { db } from '../config/firebase';
import { Timestamp, FieldValue } from 'firebase-admin/firestore';
import { logger } from '../utils/logger';
import { Client } from '@googlemaps/google-maps-services-js';
import { io } from '../server'; // Socket.IO instance
import axios from 'axios';

interface DriverLocation {
  driverId: string;
  latitude: number;
  longitude: number;
  accuracy: number;
  heading?: number; // Dirección en grados (0-360)
  speed?: number; // Velocidad en m/s
  timestamp: Date;
  address?: string;
}

interface RouteInfo {
  distance: number; // en metros
  duration: number; // en segundos
  polyline: string;
  steps: RouteStep[];
  waypoints?: LatLng[];
}

interface RouteStep {
  instruction: string;
  distance: number;
  duration: number;
  startLocation: LatLng;
  endLocation: LatLng;
  polyline: string;
}

interface LatLng {
  latitude: number;
  longitude: number;
}

interface TrackingSession {
  sessionId: string;
  rideId: string;
  driverId: string;
  passengerId: string;
  origin: LatLng;
  destination: LatLng;
  isActive: boolean;
  currentLocation: DriverLocation;
  plannedRoute: RouteInfo;
  actualRoute: DriverLocation[];
  estimatedArrival: Date;
  lastUpdate: Date;
  startedAt: Date;
  completedAt?: Date;
  totalDistance: number;
  totalDuration: number;
}

class TrackingService {
  
  private googleMaps: Client;
  private activeSessions: Map<string, TrackingSession> = new Map();
  
  // Configuración del servicio
  private readonly UPDATE_INTERVAL = 5000; // 5 segundos
  private readonly ETA_RECALC_INTERVAL = 30000; // 30 segundos  
  private readonly MAX_DEVIATION_METERS = 500; // Máximo desvío permitido
  private readonly SPEED_LIMIT_ALERTS = {
    city: 60, // km/h
    highway: 100 // km/h
  };

  constructor() {
    this.googleMaps = new Client({});
    this.initializePeriodicUpdates();
  }

  /**
   * INICIAR TRACKING DE UN VIAJE
   * ============================
   */
  async startTracking(
    rideId: string,
    driverId: string,
    passengerId: string,
    origin: LatLng,
    destination: LatLng,
    initialDriverLocation: DriverLocation
  ): Promise<{ sessionId: string; success: boolean }> {
    
    try {
      logger.info(`📍 Iniciando tracking para viaje ${rideId}`, {
        driverId,
        passengerId,
        origin,
        destination
      });

      // 1. CALCULAR RUTA INICIAL
      const plannedRoute = await this.calculateRoute(origin, destination);
      
      if (!plannedRoute) {
        throw new Error('No se pudo calcular la ruta inicial');
      }

      // 2. CREAR SESIÓN DE TRACKING
      const sessionId = `tracking_${rideId}_${Date.now()}`;
      const estimatedArrival = new Date(Date.now() + plannedRoute.duration * 1000);

      const trackingSession: TrackingSession = {
        sessionId,
        rideId,
        driverId,
        passengerId,
        origin,
        destination,
        isActive: true,
        currentLocation: initialDriverLocation,
        plannedRoute,
        actualRoute: [initialDriverLocation],
        estimatedArrival,
        lastUpdate: new Date(),
        startedAt: new Date(),
        totalDistance: 0,
        totalDuration: 0
      };

      // 3. GUARDAR EN FIRESTORE
      await db.collection('tracking_sessions').doc(sessionId).set({
        ...trackingSession,
        startedAt: Timestamp.now(),
        lastUpdate: Timestamp.now(),
        currentLocation: {
          ...trackingSession.currentLocation,
          timestamp: Timestamp.now()
        }
      });

      // 4. GUARDAR EN MEMORIA PARA ACCESO RÁPIDO
      this.activeSessions.set(sessionId, trackingSession);

      // 5. ACTUALIZAR VIAJE CON INFORMACIÓN DE TRACKING
      await db.collection('rides').doc(rideId).update({
        trackingSessionId: sessionId,
        trackingStartedAt: Timestamp.now(),
        plannedRoute: {
          distance: plannedRoute.distance,
          duration: plannedRoute.duration,
          polyline: plannedRoute.polyline
        },
        estimatedArrival: Timestamp.fromDate(estimatedArrival),
        trackingActive: true
      });

      // 6. NOTIFICAR AL PASAJERO VÍA SOCKET.IO
      await this.emitTrackingUpdate(sessionId, 'tracking_started', {
        sessionId,
        rideId,
        plannedRoute,
        estimatedArrival,
        currentLocation: initialDriverLocation
      });

      logger.info(`✅ Tracking iniciado exitosamente: ${sessionId}`, {
        estimatedDuration: plannedRoute.duration,
        plannedDistance: plannedRoute.distance
      });

      return { sessionId, success: true };

    } catch (error) {
      logger.error('❌ Error iniciando tracking:', error);
      throw new Error(`Error iniciando tracking: ${error.message}`);
    }
  }

  /**
   * ACTUALIZAR UBICACIÓN DEL CONDUCTOR
   * ==================================
   */
  async updateDriverLocation(
    driverId: string,
    latitude: number,
    longitude: number,
    rideId?: string,
    accuracy?: number,
    heading?: number,
    speed?: number
  ): Promise<void> {
    
    try {
      const timestamp = new Date();
      
      // Obtener dirección usando geocoding reverso
      const address = await this.getAddressFromCoordinates(latitude, longitude);

      const locationUpdate: DriverLocation = {
        driverId,
        latitude,
        longitude,
        accuracy: accuracy || 10,
        heading,
        speed,
        timestamp,
        address
      };

      // 1. ACTUALIZAR UBICACIÓN GENERAL DEL CONDUCTOR
      await db.collection('drivers').doc(driverId).update({
        currentLocation: {
          latitude,
          longitude,
          accuracy: accuracy || 10,
          timestamp: Timestamp.now(),
          address
        },
        lastLocationUpdate: Timestamp.now(),
        isOnline: true
      });

      // 2. SI HAY UN VIAJE ACTIVO, ACTUALIZAR TRACKING
      if (rideId) {
        const trackingSession = Array.from(this.activeSessions.values())
          .find(session => session.rideId === rideId && session.driverId === driverId);

        if (trackingSession) {
          await this.updateTrackingSession(trackingSession.sessionId, locationUpdate);
        }
      }

      // 3. EMITIR ACTUALIZACIÓN EN TIEMPO REAL
      io.to(`driver_${driverId}`).emit('location_updated', locationUpdate);
      
      if (rideId) {
        io.to(`ride_${rideId}`).emit('driver_location_updated', locationUpdate);
      }

      // 4. GUARDAR EN HISTORIAL DE UBICACIONES
      await this.saveLocationHistory(driverId, locationUpdate, rideId);

      logger.debug(`📍 Ubicación actualizada para conductor ${driverId}`, {
        lat: latitude,
        lng: longitude,
        rideId,
        address: address?.substring(0, 50)
      });

    } catch (error) {
      logger.error('Error actualizando ubicación del conductor:', error);
    }
  }

  /**
   * CALCULAR RUTA USANDO GOOGLE DIRECTIONS API
   * ==========================================
   */
  async calculateRoute(
    origin: LatLng,
    destination: LatLng,
    waypoints?: LatLng[],
    optimizeWaypoints: boolean = false,
    avoidTolls: boolean = false
  ): Promise<RouteInfo | null> {
    
    try {
      const request: any = {
        origin: `${origin.latitude},${origin.longitude}`,
        destination: `${destination.latitude},${destination.longitude}`,
        mode: 'driving',
        departure_time: 'now', // Para información de tráfico en tiempo real
        traffic_model: 'best_guess',
        key: process.env.GOOGLE_MAPS_API_KEY,
        language: 'es',
        region: 'pe'
      };

      // Agregar waypoints si se proporcionan
      if (waypoints && waypoints.length > 0) {
        request.waypoints = waypoints.map(wp => `${wp.latitude},${wp.longitude}`);
        request.optimize = optimizeWaypoints;
      }

      // Opciones de evitar
      const avoidOptions = [];
      if (avoidTolls) avoidOptions.push('tolls');
      if (avoidOptions.length > 0) {
        request.avoid = avoidOptions.join('|');
      }

      const response = await this.googleMaps.directions({ params: request });

      if (response.data.routes && response.data.routes.length > 0) {
        const route = response.data.routes[0];
        const leg = route.legs[0];

        const routeInfo: RouteInfo = {
          distance: leg.distance.value, // metros
          duration: leg.duration_in_traffic?.value || leg.duration.value, // segundos
          polyline: route.overview_polyline.points,
          steps: leg.steps.map(step => ({
            instruction: step.html_instructions.replace(/<[^>]*>/g, ''),
            distance: step.distance.value,
            duration: step.duration.value,
            startLocation: {
              latitude: step.start_location.lat,
              longitude: step.start_location.lng
            },
            endLocation: {
              latitude: step.end_location.lat,
              longitude: step.end_location.lng
            },
            polyline: step.polyline.points
          }))
        };

        if (waypoints && route.waypoint_order) {
          routeInfo.waypoints = route.waypoint_order.map(index => waypoints[index]);
        }

        return routeInfo;
      }

      return null;

    } catch (error) {
      logger.error('Error calculando ruta:', error);
      return null;
    }
  }

  /**
   * CALCULAR ETA DINÁMICO
   * ====================
   */
  async calculateDynamicETA(
    currentLocation: LatLng,
    destination: LatLng,
    considerTraffic: boolean = true
  ): Promise<{ eta: Date; duration: number; distance: number }> {
    
    try {
      const routeInfo = await this.calculateRoute(currentLocation, destination);
      
      if (!routeInfo) {
        // Fallback: cálculo estimado basado en distancia
        const distance = this.calculateHaversineDistance(currentLocation, destination);
        const estimatedDuration = (distance / 1000) * 2.5 * 60; // ~40 km/h promedio en ciudad
        
        return {
          eta: new Date(Date.now() + estimatedDuration * 1000),
          duration: estimatedDuration,
          distance: distance
        };
      }

      const eta = new Date(Date.now() + routeInfo.duration * 1000);

      return {
        eta,
        duration: routeInfo.duration,
        distance: routeInfo.distance
      };

    } catch (error) {
      logger.error('Error calculando ETA dinámico:', error);
      
      // Fallback calculation
      const distance = this.calculateHaversineDistance(currentLocation, destination);
      const estimatedDuration = (distance / 1000) * 3 * 60; // 20 km/h promedio conservador
      
      return {
        eta: new Date(Date.now() + estimatedDuration * 1000),
        duration: estimatedDuration,
        distance: distance
      };
    }
  }

  /**
   * FINALIZAR TRACKING DE VIAJE
   * ===========================
   */
  async stopTracking(sessionId: string, rideId: string): Promise<boolean> {
    try {
      const session = this.activeSessions.get(sessionId);
      
      if (!session) {
        logger.warn(`Sesión de tracking no encontrada: ${sessionId}`);
        return false;
      }

      // 1. MARCAR COMO COMPLETADA
      session.isActive = false;
      session.completedAt = new Date();
      session.totalDuration = (session.completedAt.getTime() - session.startedAt.getTime()) / 1000;
      session.totalDistance = this.calculateTotalDistance(session.actualRoute);

      // 2. ACTUALIZAR EN FIRESTORE
      await db.collection('tracking_sessions').doc(sessionId).update({
        isActive: false,
        completedAt: Timestamp.now(),
        totalDuration: session.totalDuration,
        totalDistance: session.totalDistance
      });

      // 3. ACTUALIZAR VIAJE
      await db.collection('rides').doc(rideId).update({
        trackingActive: false,
        trackingCompletedAt: Timestamp.now(),
        actualDistance: session.totalDistance,
        actualDuration: session.totalDuration
      });

      // 4. EMITIR EVENTO DE FINALIZACIÓN
      await this.emitTrackingUpdate(sessionId, 'tracking_completed', {
        sessionId,
        rideId,
        totalDistance: session.totalDistance,
        totalDuration: session.totalDuration,
        completedAt: session.completedAt
      });

      // 5. REMOVER DE MEMORIA
      this.activeSessions.delete(sessionId);

      logger.info(`✅ Tracking finalizado: ${sessionId}`, {
        totalDistance: session.totalDistance,
        totalDuration: session.totalDuration
      });

      return true;

    } catch (error) {
      logger.error('Error finalizando tracking:', error);
      return false;
    }
  }

  /**
   * OBTENER POLYLINE DE RUTA PARA MOSTRAR EN MAPA
   * =============================================
   */
  async getRoutePolyline(origin: LatLng, destination: LatLng): Promise<string | null> {
    try {
      const routeInfo = await this.calculateRoute(origin, destination);
      return routeInfo?.polyline || null;
    } catch (error) {
      logger.error('Error obteniendo polyline de ruta:', error);
      return null;
    }
  }

  /**
   * OBTENER INFORMACIÓN COMPLETA DE TRACKING
   * ========================================
   */
  async getTrackingInfo(sessionId: string): Promise<TrackingSession | null> {
    try {
      // Buscar primero en memoria
      const sessionInMemory = this.activeSessions.get(sessionId);
      if (sessionInMemory) {
        return sessionInMemory;
      }

      // Buscar en Firestore
      const sessionDoc = await db.collection('tracking_sessions').doc(sessionId).get();
      
      if (!sessionDoc.exists) {
        return null;
      }

      const data = sessionDoc.data();
      return {
        ...data,
        startedAt: data.startedAt.toDate(),
        lastUpdate: data.lastUpdate.toDate(),
        completedAt: data.completedAt?.toDate()
      } as TrackingSession;

    } catch (error) {
      logger.error('Error obteniendo información de tracking:', error);
      return null;
    }
  }

  /**
   * OBTENER TRACKING ACTIVO POR VIAJE
   * =================================
   */
  async getActiveTrackingByRide(rideId: string): Promise<TrackingSession | null> {
    try {
      // Buscar en sesiones activas
      for (const session of this.activeSessions.values()) {
        if (session.rideId === rideId && session.isActive) {
          return session;
        }
      }

      // Buscar en Firestore
      const sessionsSnapshot = await db.collection('tracking_sessions')
        .where('rideId', '==', rideId)
        .where('isActive', '==', true)
        .limit(1)
        .get();

      if (sessionsSnapshot.empty) {
        return null;
      }

      const sessionDoc = sessionsSnapshot.docs[0];
      const data = sessionDoc.data();
      
      return {
        ...data,
        startedAt: data.startedAt.toDate(),
        lastUpdate: data.lastUpdate.toDate()
      } as TrackingSession;

    } catch (error) {
      logger.error('Error obteniendo tracking activo por viaje:', error);
      return null;
    }
  }

  // ============================================================================
  // MÉTODOS PRIVADOS Y AUXILIARES
  // ============================================================================

  private async updateTrackingSession(sessionId: string, newLocation: DriverLocation): Promise<void> {
    try {
      const session = this.activeSessions.get(sessionId);
      if (!session || !session.isActive) return;

      // Actualizar ubicación actual
      session.currentLocation = newLocation;
      session.lastUpdate = new Date();
      session.actualRoute.push(newLocation);

      // Verificar si hay desvío significativo de la ruta
      const deviation = await this.checkRouteDeviation(session, newLocation);
      if (deviation.hasDeviated) {
        await this.handleRouteDeviation(session, deviation);
      }

      // Recalcular ETA cada 30 segundos
      const timeSinceLastETA = Date.now() - session.lastUpdate.getTime();
      if (timeSinceLastETA >= this.ETA_RECALC_INTERVAL) {
        const newETA = await this.calculateDynamicETA(
          { latitude: newLocation.latitude, longitude: newLocation.longitude },
          session.destination
        );
        session.estimatedArrival = newETA.eta;
      }

      // Actualizar en Firestore
      await db.collection('tracking_sessions').doc(sessionId).update({
        currentLocation: {
          ...newLocation,
          timestamp: Timestamp.now()
        },
        lastUpdate: Timestamp.now(),
        estimatedArrival: Timestamp.fromDate(session.estimatedArrival),
        actualRoute: FieldValue.arrayUnion({
          ...newLocation,
          timestamp: Timestamp.now()
        })
      });

      // Emitir actualización en tiempo real
      await this.emitTrackingUpdate(sessionId, 'location_updated', {
        sessionId,
        currentLocation: newLocation,
        estimatedArrival: session.estimatedArrival,
        deviation: deviation.hasDeviated ? deviation : undefined
      });

    } catch (error) {
      logger.error('Error actualizando sesión de tracking:', error);
    }
  }

  private async checkRouteDeviation(session: TrackingSession, currentLocation: DriverLocation): Promise<{
    hasDeviated: boolean;
    deviationDistance?: number;
    suggestedAction?: string;
  }> {
    try {
      // Simplificado: verificar distancia a la ruta planificada
      // En producción, usar algoritmos más sofisticados
      
      const distanceToDestination = this.calculateHaversineDistance(
        { latitude: currentLocation.latitude, longitude: currentLocation.longitude },
        session.destination
      );

      const originalDistanceToDestination = session.plannedRoute.distance;
      const deviationThreshold = this.MAX_DEVIATION_METERS;

      if (distanceToDestination > originalDistanceToDestination + deviationThreshold) {
        return {
          hasDeviated: true,
          deviationDistance: distanceToDestination - originalDistanceToDestination,
          suggestedAction: 'Recalcular ruta'
        };
      }

      return { hasDeviated: false };

    } catch (error) {
      logger.error('Error verificando desvío de ruta:', error);
      return { hasDeviated: false };
    }
  }

  private async handleRouteDeviation(session: TrackingSession, deviation: any): Promise<void> {
    try {
      logger.warn(`🛣️ Desvío de ruta detectado en sesión ${session.sessionId}`, deviation);

      // Recalcular ruta desde la ubicación actual
      const newRoute = await this.calculateRoute(
        { latitude: session.currentLocation.latitude, longitude: session.currentLocation.longitude },
        session.destination
      );

      if (newRoute) {
        session.plannedRoute = newRoute;
        session.estimatedArrival = new Date(Date.now() + newRoute.duration * 1000);

        // Actualizar en Firestore
        await db.collection('tracking_sessions').doc(session.sessionId).update({
          plannedRoute: newRoute,
          estimatedArrival: Timestamp.fromDate(session.estimatedArrival),
          routeRecalculated: true,
          lastRouteRecalculation: Timestamp.now()
        });

        // Notificar al pasajero
        await this.emitTrackingUpdate(session.sessionId, 'route_recalculated', {
          newRoute,
          newETA: session.estimatedArrival,
          reason: 'Desvío de ruta detectado'
        });
      }

    } catch (error) {
      logger.error('Error manejando desvío de ruta:', error);
    }
  }

  private async emitTrackingUpdate(sessionId: string, eventType: string, data: any): Promise<void> {
    try {
      const session = this.activeSessions.get(sessionId);
      if (!session) return;

      // Emitir a todos los participantes del viaje
      io.to(`ride_${session.rideId}`).emit('tracking_update', {
        type: eventType,
        sessionId,
        rideId: session.rideId,
        timestamp: new Date(),
        ...data
      });

      // Emitir específicamente al pasajero
      io.to(`user_${session.passengerId}`).emit('driver_tracking', {
        type: eventType,
        sessionId,
        ...data
      });

    } catch (error) {
      logger.error('Error emitiendo actualización de tracking:', error);
    }
  }

  private async saveLocationHistory(
    driverId: string, 
    location: DriverLocation, 
    rideId?: string
  ): Promise<void> {
    try {
      const historyDoc = {
        driverId,
        ...location,
        timestamp: Timestamp.now(),
        rideId: rideId || null,
        createdAt: Timestamp.now()
      };

      await db.collection('location_history').add(historyDoc);

    } catch (error) {
      logger.error('Error guardando historial de ubicaciones:', error);
    }
  }

  private async getAddressFromCoordinates(lat: number, lng: number): Promise<string | undefined> {
    try {
      const response = await this.googleMaps.reverseGeocode({
        params: {
          latlng: `${lat},${lng}`,
          key: process.env.GOOGLE_MAPS_API_KEY!,
          language: 'es',
          region: 'pe'
        }
      });

      if (response.data.results && response.data.results.length > 0) {
        return response.data.results[0].formatted_address;
      }

    } catch (error) {
      logger.error('Error obteniendo dirección:', error);
    }

    return undefined;
  }

  private calculateHaversineDistance(point1: LatLng, point2: LatLng): number {
    const R = 6371000; // Radio de la Tierra en metros
    const φ1 = point1.latitude * Math.PI / 180;
    const φ2 = point2.latitude * Math.PI / 180;
    const Δφ = (point2.latitude - point1.latitude) * Math.PI / 180;
    const Δλ = (point2.longitude - point1.longitude) * Math.PI / 180;

    const a = Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
              Math.cos(φ1) * Math.cos(φ2) *
              Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

    return R * c;
  }

  private calculateTotalDistance(route: DriverLocation[]): number {
    if (route.length < 2) return 0;

    let totalDistance = 0;
    for (let i = 1; i < route.length; i++) {
      totalDistance += this.calculateHaversineDistance(
        { latitude: route[i-1].latitude, longitude: route[i-1].longitude },
        { latitude: route[i].latitude, longitude: route[i].longitude }
      );
    }

    return totalDistance;
  }

  private initializePeriodicUpdates(): void {
    // Limpiar sesiones inactivas cada 5 minutos
    setInterval(() => {
      this.cleanupInactiveSessions();
    }, 300000);

    logger.info('📍 Servicio de tracking inicializado con actualizaciones periódicas');
  }

  private async cleanupInactiveSessions(): Promise<void> {
    try {
      const now = Date.now();
      const inactiveThreshold = 600000; // 10 minutos

      for (const [sessionId, session] of this.activeSessions.entries()) {
        if (now - session.lastUpdate.getTime() > inactiveThreshold) {
          logger.info(`🧹 Limpiando sesión inactiva: ${sessionId}`);
          
          await this.stopTracking(sessionId, session.rideId);
        }
      }

    } catch (error) {
      logger.error('Error limpiando sesiones inactivas:', error);
    }
  }
}

export default new TrackingService();
export { TrackingService, DriverLocation, RouteInfo, TrackingSession, LatLng };