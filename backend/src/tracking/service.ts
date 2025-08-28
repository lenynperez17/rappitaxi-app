import { EventEmitter } from 'events';
import * as admin from 'firebase-admin';
import axios from 'axios';
import crypto from 'crypto';
import { logger } from '@shared/utils/logger';
import { AppError } from '@shared/middleware/error-handler';

// 🗺️ Google Maps Configuration
const GOOGLE_MAPS_API_KEY = process.env.GOOGLE_MAPS_API_KEY || 'YOUR_API_KEY';
const GOOGLE_MAPS_BASE_URL = 'https://maps.googleapis.com/maps/api';

// 📍 Interfaces de ubicación
export interface Location {
  latitude: number;
  longitude: number;
  heading?: number;  // Dirección en grados (0-360)
  speed?: number;    // Velocidad en km/h
  accuracy?: number; // Precisión en metros
  altitude?: number; // Altitud en metros
  timestamp: Date;
}

// 🚗 Estado del conductor
export interface DriverLocation extends Location {
  driverId: string;
  isOnline: boolean;
  isAvailable: boolean;
  currentRideId?: string;
  vehicleInfo: {
    licensePlate: string;
    type: string;
    color: string;
  };
  lastUpdated: Date;
}

// 🎯 Información de ruta
export interface RouteInfo {
  distance: number;        // Distancia en metros
  duration: number;        // Duración en segundos
  distanceText: string;    // "5.2 km"
  durationText: string;    // "15 mins"
  polyline: string;        // Encoded polyline para dibujar ruta
  steps: RouteStep[];      // Pasos detallados
  bounds: {
    northeast: { lat: number; lng: number };
    southwest: { lat: number; lng: number };
  };
}

// 📋 Paso de navegación
export interface RouteStep {
  instruction: string;      // "Gira a la derecha en Av. Principal"
  distance: number;
  duration: number;
  startLocation: { lat: number; lng: number };
  endLocation: { lat: number; lng: number };
  maneuver?: string;       // "turn-right", "turn-left", etc.
}

// 🎫 Viaje compartido
export interface SharedTrip {
  shareCode: string;
  rideId: string;
  passengerId: string;
  passengerName: string;
  driverId: string;
  driverName: string;
  driverPhoto?: string;
  vehicleInfo: {
    make: string;
    model: string;
    color: string;
    licensePlate: string;
  };
  currentLocation?: Location;
  pickupLocation: Location & { address: string };
  dropoffLocation: Location & { address: string };
  route?: RouteInfo;
  status: string;
  estimatedArrival?: Date;
  sharedAt: Date;
  expiresAt: Date;
}

// 🌍 Zona geográfica
export interface GeoZone {
  id: string;
  name: string;
  type: 'circle' | 'polygon';
  center?: { lat: number; lng: number };
  radius?: number; // Para tipo circle, en metros
  coordinates?: Array<{ lat: number; lng: number }>; // Para tipo polygon
  surgeMultiplier?: number;
  restrictions?: string[];
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date;
}

// 📊 Métricas de tracking
export interface TrackingMetrics {
  totalDistance: number;    // Distancia total recorrida en metros
  totalDuration: number;    // Tiempo total en segundos
  averageSpeed: number;     // Velocidad promedio en km/h
  maxSpeed: number;         // Velocidad máxima alcanzada
  idleTime: number;         // Tiempo detenido en segundos
  routeEfficiency: number;  // Eficiencia de ruta (0-1)
}

/**
 * 🚀 Servicio de Tracking GPS
 */
export class TrackingService extends EventEmitter {
  private activeTracking: Map<string, NodeJS.Timeout> = new Map();
  private locationHistory: Map<string, Location[]> = new Map();
  private sharedTrips: Map<string, SharedTrip> = new Map();
  private geoZones: Map<string, GeoZone> = new Map();

  /**
   * 📍 Actualizar ubicación del conductor
   */
  async updateDriverLocation(driverId: string, location: Location): Promise<void> {
    try {
      const driverLocation: DriverLocation = {
        ...location,
        driverId,
        isOnline: true,
        isAvailable: true,
        lastUpdated: new Date(),
        vehicleInfo: await this.getDriverVehicleInfo(driverId)
      };

      // Guardar en Firestore con geohash para consultas eficientes
      const geohash = this.generateGeohash(location.latitude, location.longitude);
      
      await admin.firestore()
        .collection('driver_locations')
        .doc(driverId)
        .set({
          ...driverLocation,
          geohash,
          geopoint: new admin.firestore.GeoPoint(location.latitude, location.longitude)
        });

      // Guardar en historial
      this.addToLocationHistory(driverId, location);

      // Verificar si está en alguna zona
      await this.checkZoneEntry(driverId, location);

      // Emitir evento
      this.emit('driver:location_updated', driverLocation);

      logger.debug(`Ubicación actualizada para conductor ${driverId}`);
    } catch (error) {
      logger.error('Error actualizando ubicación del conductor:', error);
      throw error;
    }
  }

  /**
   * 🔍 Buscar conductores cercanos
   */
  async findNearbyDrivers(
    location: { latitude: number; longitude: number },
    radiusInMeters: number = 5000,
    vehicleType?: string
  ): Promise<DriverLocation[]> {
    try {
      // Calcular bounds para búsqueda eficiente
      const bounds = this.calculateBounds(location.latitude, location.longitude, radiusInMeters);
      
      let query = admin.firestore()
        .collection('driver_locations')
        .where('isOnline', '==', true)
        .where('isAvailable', '==', true)
        .where('geopoint', '>=', new admin.firestore.GeoPoint(bounds.minLat, bounds.minLng))
        .where('geopoint', '<=', new admin.firestore.GeoPoint(bounds.maxLat, bounds.maxLng));

      if (vehicleType) {
        query = query.where('vehicleInfo.type', '==', vehicleType);
      }

      const driversSnapshot = await query.get();
      const nearbyDrivers: DriverLocation[] = [];

      // Filtrar por distancia exacta
      for (const doc of driversSnapshot.docs) {
        const driverData = doc.data() as DriverLocation;
        const distance = this.calculateDistance(
          location.latitude,
          location.longitude,
          driverData.latitude,
          driverData.longitude
        );

        if (distance <= radiusInMeters) {
          nearbyDrivers.push({
            ...driverData,
            distance // Agregar distancia para ordenamiento
          } as any);
        }
      }

      // Ordenar por distancia
      nearbyDrivers.sort((a: any, b: any) => a.distance - b.distance);

      logger.info(`Encontrados ${nearbyDrivers.length} conductores en ${radiusInMeters}m`);
      return nearbyDrivers;
    } catch (error) {
      logger.error('Error buscando conductores cercanos:', error);
      throw error;
    }
  }

  /**
   * 🗺️ Calcular ruta entre dos puntos
   */
  async calculateRoute(
    origin: { latitude: number; longitude: number },
    destination: { latitude: number; longitude: number },
    waypoints?: Array<{ latitude: number; longitude: number }>,
    mode: 'driving' | 'walking' | 'bicycling' = 'driving'
  ): Promise<RouteInfo> {
    try {
      const originStr = `${origin.latitude},${origin.longitude}`;
      const destStr = `${destination.latitude},${destination.longitude}`;
      
      let waypointsStr = '';
      if (waypoints && waypoints.length > 0) {
        waypointsStr = waypoints
          .map(wp => `${wp.latitude},${wp.longitude}`)
          .join('|');
      }

      const url = `${GOOGLE_MAPS_BASE_URL}/directions/json`;
      const params: any = {
        origin: originStr,
        destination: destStr,
        mode,
        key: GOOGLE_MAPS_API_KEY,
        alternatives: false,
        units: 'metric',
        language: 'es'
      };

      if (waypointsStr) {
        params.waypoints = `optimize:true|${waypointsStr}`;
      }

      const response = await axios.get(url, { params });

      if (response.data.status !== 'OK') {
        throw new AppError('No se pudo calcular la ruta', 400, 'ROUTE_CALCULATION_ERROR');
      }

      const route = response.data.routes[0];
      const leg = route.legs[0];

      const routeInfo: RouteInfo = {
        distance: leg.distance.value,
        duration: leg.duration.value,
        distanceText: leg.distance.text,
        durationText: leg.duration.text,
        polyline: route.overview_polyline.points,
        bounds: route.bounds,
        steps: leg.steps.map((step: any) => ({
          instruction: step.html_instructions.replace(/<[^>]*>/g, ''), // Remover HTML
          distance: step.distance.value,
          duration: step.duration.value,
          startLocation: step.start_location,
          endLocation: step.end_location,
          maneuver: step.maneuver
        }))
      };

      logger.info(`Ruta calculada: ${routeInfo.distanceText} en ${routeInfo.durationText}`);
      return routeInfo;
    } catch (error) {
      logger.error('Error calculando ruta:', error);
      throw error;
    }
  }

  /**
   * ⏱️ Calcular ETA (Tiempo Estimado de Llegada)
   */
  async calculateETA(
    origin: { latitude: number; longitude: number },
    destination: { latitude: number; longitude: number },
    considerTraffic: boolean = true
  ): Promise<{ eta: Date; durationInMinutes: number; trafficInfo?: string }> {
    try {
      const url = `${GOOGLE_MAPS_BASE_URL}/distancematrix/json`;
      const params: any = {
        origins: `${origin.latitude},${origin.longitude}`,
        destinations: `${destination.latitude},${destination.longitude}`,
        mode: 'driving',
        units: 'metric',
        language: 'es',
        key: GOOGLE_MAPS_API_KEY
      };

      if (considerTraffic) {
        params.traffic_model = 'best_guess';
        params.departure_time = 'now';
      }

      const response = await axios.get(url, { params });

      if (response.data.status !== 'OK') {
        throw new AppError('No se pudo calcular ETA', 400, 'ETA_CALCULATION_ERROR');
      }

      const element = response.data.rows[0].elements[0];
      
      if (element.status !== 'OK') {
        throw new AppError('Destino no alcanzable', 400, 'DESTINATION_UNREACHABLE');
      }

      const duration = considerTraffic && element.duration_in_traffic
        ? element.duration_in_traffic.value
        : element.duration.value;

      const eta = new Date(Date.now() + duration * 1000);
      const durationInMinutes = Math.ceil(duration / 60);

      const result = {
        eta,
        durationInMinutes,
        trafficInfo: considerTraffic && element.duration_in_traffic
          ? this.getTrafficLevel(element.duration.value, element.duration_in_traffic.value)
          : undefined
      };

      logger.info(`ETA calculado: ${durationInMinutes} minutos`);
      return result;
    } catch (error) {
      logger.error('Error calculando ETA:', error);
      throw error;
    }
  }

  /**
   * 🎯 Iniciar tracking de viaje
   */
  async startTripTracking(
    rideId: string,
    driverId: string,
    passengerId: string,
    pickupLocation: Location & { address: string },
    dropoffLocation: Location & { address: string }
  ): Promise<void> {
    try {
      // Calcular ruta inicial
      const route = await this.calculateRoute(pickupLocation, dropoffLocation);

      // Crear documento de tracking
      const tracking = {
        rideId,
        driverId,
        passengerId,
        pickupLocation,
        dropoffLocation,
        route,
        currentLocation: null,
        status: 'active',
        startedAt: new Date(),
        estimatedArrival: new Date(Date.now() + route.duration * 1000),
        metrics: {
          totalDistance: 0,
          totalDuration: 0,
          averageSpeed: 0,
          maxSpeed: 0,
          idleTime: 0,
          routeEfficiency: 1
        } as TrackingMetrics
      };

      await admin.firestore()
        .collection('trip_tracking')
        .doc(rideId)
        .set(tracking);

      // Iniciar actualización periódica (cada 5 segundos)
      const intervalId = setInterval(async () => {
        await this.updateTripProgress(rideId);
      }, 5000);

      this.activeTracking.set(rideId, intervalId);

      logger.info(`Tracking iniciado para viaje ${rideId}`);
    } catch (error) {
      logger.error('Error iniciando tracking:', error);
      throw error;
    }
  }

  /**
   * 🔄 Actualizar progreso del viaje
   */
  private async updateTripProgress(rideId: string): Promise<void> {
    try {
      const trackingDoc = await admin.firestore()
        .collection('trip_tracking')
        .doc(rideId)
        .get();

      if (!trackingDoc.exists) {
        this.stopTripTracking(rideId);
        return;
      }

      const tracking = trackingDoc.data();
      
      // Obtener ubicación actual del conductor
      const driverLocationDoc = await admin.firestore()
        .collection('driver_locations')
        .doc(tracking.driverId)
        .get();

      if (!driverLocationDoc.exists) return;

      const currentLocation = driverLocationDoc.data() as Location;

      // Calcular nueva ETA
      const etaInfo = await this.calculateETA(
        currentLocation,
        tracking.dropoffLocation,
        true
      );

      // Actualizar métricas
      const metrics = this.updateTrackingMetrics(
        tracking.metrics,
        currentLocation,
        tracking.currentLocation
      );

      // Actualizar tracking
      await admin.firestore()
        .collection('trip_tracking')
        .doc(rideId)
        .update({
          currentLocation,
          estimatedArrival: etaInfo.eta,
          metrics,
          updatedAt: new Date()
        });

      // Emitir evento de actualización
      this.emit('trip:progress_updated', {
        rideId,
        currentLocation,
        estimatedArrival: etaInfo.eta,
        metrics
      });

      // Verificar si llegó al destino
      const distanceToDestination = this.calculateDistance(
        currentLocation.latitude,
        currentLocation.longitude,
        tracking.dropoffLocation.latitude,
        tracking.dropoffLocation.longitude
      );

      if (distanceToDestination < 50) { // Menos de 50 metros
        this.emit('trip:near_destination', { rideId });
      }

    } catch (error) {
      logger.error(`Error actualizando progreso del viaje ${rideId}:`, error);
    }
  }

  /**
   * 🛑 Detener tracking de viaje
   */
  async stopTripTracking(rideId: string): Promise<void> {
    const intervalId = this.activeTracking.get(rideId);
    if (intervalId) {
      clearInterval(intervalId);
      this.activeTracking.delete(rideId);
    }

    // Marcar como completado
    await admin.firestore()
      .collection('trip_tracking')
      .doc(rideId)
      .update({
        status: 'completed',
        completedAt: new Date()
      });

    logger.info(`Tracking detenido para viaje ${rideId}`);
  }

  /**
   * 🔗 Compartir viaje
   */
  async shareTrip(rideId: string): Promise<{ shareCode: string; shareUrl: string }> {
    try {
      // Obtener información del viaje
      const rideDoc = await admin.firestore()
        .collection('rides')
        .doc(rideId)
        .get();

      if (!rideDoc.exists) {
        throw new AppError('Viaje no encontrado', 404, 'RIDE_NOT_FOUND');
      }

      const ride = rideDoc.data();
      
      // Generar código único
      const shareCode = this.generateShareCode();
      
      // Crear objeto de viaje compartido
      const sharedTrip: SharedTrip = {
        shareCode,
        rideId,
        passengerId: ride.passengerId,
        passengerName: ride.passengerName,
        driverId: ride.driverId,
        driverName: ride.driverName,
        driverPhoto: ride.driverPhoto,
        vehicleInfo: ride.vehicleInfo,
        pickupLocation: ride.pickupLocation,
        dropoffLocation: ride.dropoffLocation,
        status: ride.status,
        sharedAt: new Date(),
        expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000) // 24 horas
      };

      // Guardar en Firestore
      await admin.firestore()
        .collection('shared_trips')
        .doc(shareCode)
        .set(sharedTrip);

      // Guardar en cache local
      this.sharedTrips.set(shareCode, sharedTrip);

      const shareUrl = `${process.env.APP_URL || 'https://rappitaxi.com'}/track/${shareCode}`;

      logger.info(`Viaje ${rideId} compartido con código ${shareCode}`);

      return { shareCode, shareUrl };
    } catch (error) {
      logger.error('Error compartiendo viaje:', error);
      throw error;
    }
  }

  /**
   * 🔍 Obtener viaje compartido
   */
  async getSharedTrip(shareCode: string): Promise<SharedTrip> {
    try {
      // Verificar cache primero
      if (this.sharedTrips.has(shareCode)) {
        return this.sharedTrips.get(shareCode)!;
      }

      // Buscar en Firestore
      const sharedTripDoc = await admin.firestore()
        .collection('shared_trips')
        .doc(shareCode)
        .get();

      if (!sharedTripDoc.exists) {
        throw new AppError('Código de compartir inválido', 404, 'INVALID_SHARE_CODE');
      }

      const sharedTrip = sharedTripDoc.data() as SharedTrip;

      // Verificar expiración
      if (sharedTrip.expiresAt < new Date()) {
        throw new AppError('El enlace ha expirado', 410, 'SHARE_LINK_EXPIRED');
      }

      // Obtener ubicación actual del conductor
      const driverLocationDoc = await admin.firestore()
        .collection('driver_locations')
        .doc(sharedTrip.driverId)
        .get();

      if (driverLocationDoc.exists) {
        sharedTrip.currentLocation = driverLocationDoc.data() as Location;
      }

      // Obtener ruta actualizada
      if (sharedTrip.currentLocation) {
        sharedTrip.route = await this.calculateRoute(
          sharedTrip.currentLocation,
          sharedTrip.dropoffLocation
        );
      }

      // Actualizar cache
      this.sharedTrips.set(shareCode, sharedTrip);

      return sharedTrip;
    } catch (error) {
      logger.error('Error obteniendo viaje compartido:', error);
      throw error;
    }
  }

  /**
   * 🌐 Crear zona geográfica
   */
  async createGeoZone(data: {
    name: string;
    type: 'circle' | 'polygon';
    center?: { lat: number; lng: number };
    radius?: number;
    coordinates?: Array<{ lat: number; lng: number }>;
    surgeMultiplier?: number;
    restrictions?: string[];
  }): Promise<GeoZone> {
    try {
      const zoneId = crypto.randomBytes(16).toString('hex');
      const geoZone: GeoZone = {
        id: zoneId,
        name: data.name,
        type: data.type,
        center: data.center,
        radius: data.radius,
        coordinates: data.coordinates,
        surgeMultiplier: data.surgeMultiplier || 1,
        restrictions: data.restrictions || [],
        isActive: true,
        createdAt: new Date(),
        updatedAt: new Date()
      };

      await admin.firestore()
        .collection('geo_zones')
        .doc(zoneId)
        .set(geoZone);

      this.geoZones.set(zoneId, geoZone);

      logger.info(`Zona geográfica creada: ${zoneId} - ${data.name}`);
      return geoZone;
    } catch (error) {
      logger.error('Error creando zona:', error);
      throw error;
    }
  }

  /**
   * 🔍 Verificar entrada a zona
   */
  private async checkZoneEntry(userId: string, location: Location): Promise<void> {
    for (const [zoneId, zone] of this.geoZones) {
      if (!zone.isActive) continue;

      const isInZone = zone.type === 'circle'
        ? this.isPointInCircle(location, zone.center!, zone.radius!)
        : this.isPointInPolygon(location, zone.coordinates!);

      if (isInZone) {
        this.emit('zone:entered', {
          userId,
          zoneId,
          zone,
          location
        });

        logger.info(`Usuario ${userId} entró en zona ${zone.name}`);
      }
    }
  }

  /**
   * 📊 Obtener métricas de viaje
   */
  async getTripMetrics(rideId: string): Promise<TrackingMetrics> {
    try {
      const trackingDoc = await admin.firestore()
        .collection('trip_tracking')
        .doc(rideId)
        .get();

      if (!trackingDoc.exists) {
        throw new AppError('Tracking no encontrado', 404, 'TRACKING_NOT_FOUND');
      }

      return trackingDoc.data()!.metrics as TrackingMetrics;
    } catch (error) {
      logger.error('Error obteniendo métricas:', error);
      throw error;
    }
  }

  /**
   * 🗺️ Geocodificación reversa (obtener dirección de coordenadas)
   */
  async reverseGeocode(
    latitude: number,
    longitude: number
  ): Promise<{ address: string; placeId: string; components: any }> {
    try {
      const url = `${GOOGLE_MAPS_BASE_URL}/geocode/json`;
      const params = {
        latlng: `${latitude},${longitude}`,
        key: GOOGLE_MAPS_API_KEY,
        language: 'es'
      };

      const response = await axios.get(url, { params });

      if (response.data.status !== 'OK' || response.data.results.length === 0) {
        throw new AppError('No se pudo obtener dirección', 400, 'GEOCODING_ERROR');
      }

      const result = response.data.results[0];
      
      return {
        address: result.formatted_address,
        placeId: result.place_id,
        components: result.address_components
      };
    } catch (error) {
      logger.error('Error en geocodificación reversa:', error);
      throw error;
    }
  }

  // 🔧 FUNCIONES AUXILIARES
  // ========================

  /**
   * Calcular distancia entre dos puntos (Haversine)
   */
  private calculateDistance(
    lat1: number,
    lon1: number,
    lat2: number,
    lon2: number
  ): number {
    const R = 6371000; // Radio de la Tierra en metros
    const φ1 = (lat1 * Math.PI) / 180;
    const φ2 = (lat2 * Math.PI) / 180;
    const Δφ = ((lat2 - lat1) * Math.PI) / 180;
    const Δλ = ((lon2 - lon1) * Math.PI) / 180;

    const a = Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
      Math.cos(φ1) * Math.cos(φ2) *
      Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
    
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

    return R * c; // Distancia en metros
  }

  /**
   * Calcular bounds para búsqueda
   */
  private calculateBounds(
    lat: number,
    lng: number,
    radiusInMeters: number
  ): { minLat: number; maxLat: number; minLng: number; maxLng: number } {
    const latDelta = (radiusInMeters / 111320); // 1 grado lat = 111.32 km
    const lngDelta = radiusInMeters / (111320 * Math.cos(lat * Math.PI / 180));

    return {
      minLat: lat - latDelta,
      maxLat: lat + latDelta,
      minLng: lng - lngDelta,
      maxLng: lng + lngDelta
    };
  }

  /**
   * Generar geohash simple (para indexación)
   */
  private generateGeohash(lat: number, lng: number, precision: number = 7): string {
    // Implementación simplificada de geohash
    const base32 = '0123456789bcdefghjkmnpqrstuvwxyz';
    let hash = '';
    let bits = 0;
    let bit = 0;
    let ch = 0;
    
    const minLat = -90, maxLat = 90;
    const minLng = -180, maxLng = 180;
    
    let tempMinLat = minLat, tempMaxLat = maxLat;
    let tempMinLng = minLng, tempMaxLng = maxLng;
    
    while (hash.length < precision) {
      if (bits % 2 === 0) {
        const mid = (tempMinLng + tempMaxLng) / 2;
        if (lng > mid) {
          ch |= (1 << (4 - bit));
          tempMinLng = mid;
        } else {
          tempMaxLng = mid;
        }
      } else {
        const mid = (tempMinLat + tempMaxLat) / 2;
        if (lat > mid) {
          ch |= (1 << (4 - bit));
          tempMinLat = mid;
        } else {
          tempMaxLat = mid;
        }
      }
      
      bits++;
      bit++;
      
      if (bit === 5) {
        hash += base32[ch];
        bit = 0;
        ch = 0;
      }
    }
    
    return hash;
  }

  /**
   * Generar código de compartir único
   */
  private generateShareCode(): string {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    let code = '';
    for (let i = 0; i < 6; i++) {
      code += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return code;
  }

  /**
   * Determinar nivel de tráfico
   */
  private getTrafficLevel(normalDuration: number, trafficDuration: number): string {
    const ratio = trafficDuration / normalDuration;
    
    if (ratio <= 1.1) return 'Tráfico ligero';
    if (ratio <= 1.3) return 'Tráfico moderado';
    if (ratio <= 1.5) return 'Tráfico pesado';
    return 'Tráfico muy pesado';
  }

  /**
   * Verificar si punto está en círculo
   */
  private isPointInCircle(
    point: { latitude: number; longitude: number },
    center: { lat: number; lng: number },
    radius: number
  ): boolean {
    const distance = this.calculateDistance(
      point.latitude,
      point.longitude,
      center.lat,
      center.lng
    );
    return distance <= radius;
  }

  /**
   * Verificar si punto está en polígono
   */
  private isPointInPolygon(
    point: { latitude: number; longitude: number },
    polygon: Array<{ lat: number; lng: number }>
  ): boolean {
    let inside = false;
    const x = point.latitude;
    const y = point.longitude;

    for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      const xi = polygon[i].lat;
      const yi = polygon[i].lng;
      const xj = polygon[j].lat;
      const yj = polygon[j].lng;

      const intersect = ((yi > y) !== (yj > y)) &&
        (x < (xj - xi) * (y - yi) / (yj - yi) + xi);

      if (intersect) inside = !inside;
    }

    return inside;
  }

  /**
   * Obtener información del vehículo del conductor
   */
  private async getDriverVehicleInfo(driverId: string): Promise<any> {
    const driverDoc = await admin.firestore()
      .collection('users')
      .doc(driverId)
      .get();

    if (!driverDoc.exists) {
      return {
        licensePlate: 'UNKNOWN',
        type: 'standard',
        color: 'unknown'
      };
    }

    const driverData = driverDoc.data();
    return driverData?.driverData?.vehicleInfo || {
      licensePlate: 'UNKNOWN',
      type: 'standard',
      color: 'unknown'
    };
  }

  /**
   * Agregar ubicación al historial
   */
  private addToLocationHistory(userId: string, location: Location): void {
    if (!this.locationHistory.has(userId)) {
      this.locationHistory.set(userId, []);
    }

    const history = this.locationHistory.get(userId)!;
    history.push(location);

    // Mantener solo las últimas 100 ubicaciones
    if (history.length > 100) {
      history.shift();
    }
  }

  /**
   * Actualizar métricas de tracking
   */
  private updateTrackingMetrics(
    currentMetrics: TrackingMetrics,
    newLocation: Location,
    previousLocation?: Location
  ): TrackingMetrics {
    const metrics = { ...currentMetrics };

    if (previousLocation) {
      // Calcular distancia recorrida
      const distance = this.calculateDistance(
        previousLocation.latitude,
        previousLocation.longitude,
        newLocation.latitude,
        newLocation.longitude
      );
      metrics.totalDistance += distance;

      // Calcular tiempo transcurrido
      const timeDiff = (newLocation.timestamp.getTime() - previousLocation.timestamp.getTime()) / 1000;
      metrics.totalDuration += timeDiff;

      // Actualizar velocidad
      if (newLocation.speed) {
        metrics.maxSpeed = Math.max(metrics.maxSpeed, newLocation.speed);
        
        // Calcular promedio ponderado
        const totalTime = metrics.totalDuration;
        metrics.averageSpeed = (metrics.averageSpeed * (totalTime - timeDiff) + newLocation.speed * timeDiff) / totalTime;
      }

      // Detectar tiempo detenido (velocidad < 5 km/h)
      if (!newLocation.speed || newLocation.speed < 5) {
        metrics.idleTime += timeDiff;
      }
    }

    return metrics;
  }

  /**
   * Obtener historial de ubicaciones
   */
  getLocationHistory(userId: string): Location[] {
    return this.locationHistory.get(userId) || [];
  }

  /**
   * Limpiar recursos
   */
  cleanup(): void {
    // Detener todos los trackings activos
    for (const [rideId, intervalId] of this.activeTracking) {
      clearInterval(intervalId);
    }
    this.activeTracking.clear();
    this.locationHistory.clear();
    this.sharedTrips.clear();
    this.geoZones.clear();

    logger.info('Servicio de tracking limpiado');
  }
}

// Exportar instancia única
export const trackingService = new TrackingService();