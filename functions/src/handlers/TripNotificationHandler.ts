import { NotificationService, TaxiNotificationFactory } from '../services/NotificationService';
import * as admin from 'firebase-admin';

export class TripNotificationHandler {
  constructor(
    private notificationService: NotificationService,
    private db: admin.firestore.Firestore
  ) {}

  /**
   * 🚗 Manejar nuevo viaje creado
   * Envía notificación a conductores disponibles en el área
   */
  async handleNewTrip(tripId: string, tripData: any): Promise<void> {
    console.log(`🚗 Procesando nuevo viaje: ${tripId}`);

    try {
      // Skip rides that already have a driver assigned (created by acceptDriverOffer)
      if (tripData.driverId && tripData.status === 'accepted') {
        console.log(`✅ Viaje ${tripId} ya tiene conductor asignado (${tripData.driverId}), saltando notificación`);
        return;
      }

      // Obtener información del pasajero
      const passengerDoc = await this.db.collection('users').doc(tripData.passengerId).get();
      const passengerData = passengerDoc.data();

      if (!passengerData) {
        throw new Error(`Pasajero no encontrado: ${tripData.passengerId}`);
      }

      // Buscar conductores disponibles en el área
      const availableDrivers = await this.findAvailableDriversInArea(
        tripData.pickupLocation.lat,
        tripData.pickupLocation.lng,
        tripData.radiusKm || 5
      );

      if (availableDrivers.length === 0) {
        console.warn(`⚠️ No se encontraron conductores disponibles para el viaje ${tripId}`);
        
        // Actualizar estado del viaje
        await this.db.collection('rides').doc(tripId).update({
          status: 'no_drivers_available',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Notificar al pasajero
        if (passengerData.fcmToken) {
          const { notification, data } = TaxiNotificationFactory.createTripStatusUpdate(
            'no_drivers_available',
            'No hay conductores disponibles en tu área. Intenta nuevamente en unos minutos.'
          );

          await this.notificationService.sendToToken(
            passengerData.fcmToken,
            notification,
            { ...data, trip_id: tripId }
          );
        }

        return;
      }

      console.log(`📍 Encontrados ${availableDrivers.length} conductores disponibles`);

      // Crear notificación para conductores
      const { notification, data } = TaxiNotificationFactory.createRideRequest(
        passengerData.name || 'Pasajero',
        tripData.pickupAddress || 'Ubicación no especificada',
        tripData.destinationAddress || 'Destino no especificado',
        tripData.estimatedFare || 0
      );

      // Obtener tokens de conductores disponibles
      const driverTokens = availableDrivers
        .map(driver => driver.fcmToken)
        .filter(token => token && typeof token === 'string');

      if (driverTokens.length === 0) {
        console.warn(`⚠️ No se encontraron tokens FCM válidos para conductores`);
        return;
      }

      // Enviar notificaciones a conductores (prioridad alta)
      const result = await this.notificationService.sendToTokens(
        driverTokens,
        notification,
        {
          ...data,
          trip_id: tripId,
          passenger_id: tripData.passengerId,
          pickup_lat: tripData.pickupLocation.lat.toString(),
          pickup_lng: tripData.pickupLocation.lng.toString(),
          destination_lat: tripData.destinationLocation?.lat?.toString() || '',
          destination_lng: tripData.destinationLocation?.lng?.toString() || '',
        },
        'high' // Prioridad alta para solicitudes de viaje
      );

      // Actualizar estado del viaje
      await this.db.collection('rides').doc(tripId).update({
        status: 'searching_driver',
        notificationsSent: result.successCount,
        driversNotified: availableDrivers.map(d => d.id),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`✅ Notificaciones enviadas a ${result.successCount} conductores para viaje ${tripId}`);

    } catch (error) {
      console.error(`❌ Error procesando nuevo viaje ${tripId}:`, error);
      throw error;
    }
  }

  /**
   * 🔄 Manejar cambio de estado del viaje
   */
  async handleTripStatusChange(
    tripId: string, 
    oldStatus: string, 
    newStatus: string, 
    tripData: any
  ): Promise<void> {
    console.log(`🔄 Cambio de estado viaje ${tripId}: ${oldStatus} → ${newStatus}`);

    try {
      switch (newStatus) {
        case 'driver_assigned':
          await this.handleDriverAssigned(tripId, tripData);
          break;
          
        case 'driver_arrived':
          await this.handleDriverArrived(tripId, tripData);
          break;
          
        case 'trip_started':
          await this.handleTripStarted(tripId, tripData);
          break;
          
        case 'trip_completed':
          await this.handleTripCompleted(tripId, tripData);
          break;
          
        case 'trip_cancelled':
          await this.handleTripCancelled(tripId, tripData, oldStatus);
          break;
          
        default:
          console.log(`ℹ️ Estado ${newStatus} no requiere notificación automática`);
      }

    } catch (error) {
      console.error(`❌ Error manejando cambio de estado ${oldStatus} → ${newStatus}:`, error);
      throw error;
    }
  }

  /**
   * Manejar conductor asignado
   */
  private async handleDriverAssigned(tripId: string, tripData: any): Promise<void> {
    const [passengerDoc, driverDoc] = await Promise.all([
      this.db.collection('users').doc(tripData.passengerId).get(),
      this.db.collection('users').doc(tripData.driverId).get(),
    ]);

    const passengerData = passengerDoc.data();
    const driverData = driverDoc.data();

    if (!passengerData || !driverData) {
      throw new Error('Datos de pasajero o conductor no encontrados');
    }

    // Notificar al pasajero
    if (passengerData.fcmToken) {
      const { notification, data } = TaxiNotificationFactory.createTripStatusUpdate(
        'driver_assigned',
        `${driverData.name} será tu conductor\nPlaca: ${driverData.licensePlate}\nETA: ${tripData.estimatedArrivalTime || 'Calculando...'}`
      );

      await this.notificationService.sendToToken(
        passengerData.fcmToken,
        notification,
        {
          ...data,
          trip_id: tripId,
          driver_id: tripData.driverId,
          driver_name: driverData.name,
          license_plate: driverData.licensePlate,
        },
        'high'
      );
    }

    // Notificar al conductor
    if (driverData.fcmToken) {
      const { notification, data } = TaxiNotificationFactory.createTripStatusUpdate(
        'trip_assigned',
        `Viaje asignado\nPasajero: ${passengerData.name}\nRecogida: ${tripData.pickupAddress}`
      );

      await this.notificationService.sendToToken(
        driverData.fcmToken,
        notification,
        {
          ...data,
          trip_id: tripId,
          passenger_id: tripData.passengerId,
          passenger_name: passengerData.name,
        },
        'high'
      );
    }
  }

  /**
   * Manejar conductor llegó
   */
  private async handleDriverArrived(tripId: string, tripData: any): Promise<void> {
    const [passengerDoc, driverDoc] = await Promise.all([
      this.db.collection('users').doc(tripData.passengerId).get(),
      this.db.collection('users').doc(tripData.driverId).get(),
    ]);

    const passengerData = passengerDoc.data();
    const driverData = driverDoc.data();

    if (!passengerData || !driverData) {
      throw new Error('Datos de pasajero o conductor no encontrados');
    }

    // Notificar al pasajero que el conductor llegó
    if (passengerData.fcmToken) {
      const { notification, data } = TaxiNotificationFactory.createDriverArrived(
        driverData.name,
        driverData.licensePlate
      );

      await this.notificationService.sendToToken(
        passengerData.fcmToken,
        notification,
        {
          ...data,
          trip_id: tripId,
          driver_id: tripData.driverId,
        },
        'high'
      );
    }
  }

  /**
   * Manejar viaje iniciado
   */
  private async handleTripStarted(tripId: string, tripData: any): Promise<void> {
    const passengerDoc = await this.db.collection('users').doc(tripData.passengerId).get();
    const passengerData = passengerDoc.data();

    if (passengerData?.fcmToken) {
      const { notification, data } = TaxiNotificationFactory.createTripStatusUpdate(
        'trip_started',
        `Tu viaje ha comenzado\nDestino: ${tripData.destinationAddress}`
      );

      await this.notificationService.sendToToken(
        passengerData.fcmToken,
        notification,
        {
          ...data,
          trip_id: tripId,
          estimated_duration: tripData.estimatedDuration?.toString() || '',
        }
      );
    }
  }

  /**
   * Manejar viaje completado
   */
  private async handleTripCompleted(tripId: string, tripData: any): Promise<void> {
    const [passengerDoc, driverDoc] = await Promise.all([
      this.db.collection('users').doc(tripData.passengerId).get(),
      this.db.collection('users').doc(tripData.driverId).get(),
    ]);

    const passengerData = passengerDoc.data();
    const driverData = driverDoc.data();

    // Notificar al pasajero
    if (passengerData?.fcmToken) {
      const { notification, data } = TaxiNotificationFactory.createTripStatusUpdate(
        'trip_completed',
        `¡Viaje completado!\nTarifa: S/ ${tripData.finalFare?.toFixed(2) || '0.00'}\n¡Gracias por usar RappiTeam!`
      );

      await this.notificationService.sendToToken(
        passengerData.fcmToken,
        notification,
        {
          ...data,
          trip_id: tripId,
          final_fare: tripData.finalFare?.toString() || '0',
        }
      );
    }

    // Notificar al conductor
    if (driverData?.fcmToken) {
      const { notification, data } = TaxiNotificationFactory.createTripStatusUpdate(
        'trip_completed',
        `Viaje completado exitosamente\nGanancia: S/ ${(tripData.finalFare * 0.8)?.toFixed(2) || '0.00'}`
      );

      await this.notificationService.sendToToken(
        driverData.fcmToken,
        notification,
        {
          ...data,
          trip_id: tripId,
          driver_earnings: ((tripData.finalFare || 0) * 0.8).toString(),
        }
      );
    }
  }

  /**
   * Manejar viaje cancelado
   */
  private async handleTripCancelled(tripId: string, tripData: any, oldStatus: string): Promise<void> {
    const cancelledBy = tripData.cancelledBy || 'system';
    const reason = tripData.cancellationReason || 'No especificada';

    // Notificar a pasajero y conductor según quién canceló
    const [passengerDoc, driverDoc] = await Promise.all([
      this.db.collection('users').doc(tripData.passengerId).get(),
      tripData.driverId ? this.db.collection('users').doc(tripData.driverId).get() : Promise.resolve(null),
    ]);

    const passengerData = passengerDoc.data();
    const driverData = driverDoc?.data();

    if (cancelledBy === 'passenger' && driverData?.fcmToken) {
      // Notificar al conductor que el pasajero canceló
      const { notification, data } = TaxiNotificationFactory.createTripStatusUpdate(
        'trip_cancelled',
        `Viaje cancelado por el pasajero\nMotivo: ${reason}`
      );

      await this.notificationService.sendToToken(
        driverData.fcmToken,
        notification,
        {
          ...data,
          trip_id: tripId,
          cancelled_by: cancelledBy,
          reason,
        }
      );
    } else if (cancelledBy === 'driver' && passengerData?.fcmToken) {
      // Notificar al pasajero que el conductor canceló
      const { notification, data } = TaxiNotificationFactory.createTripStatusUpdate(
        'trip_cancelled',
        `Tu viaje fue cancelado\nMotivo: ${reason}\nBuscando nuevo conductor...`
      );

      await this.notificationService.sendToToken(
        passengerData.fcmToken,
        notification,
        {
          ...data,
          trip_id: tripId,
          cancelled_by: cancelledBy,
          reason,
        }
      );
    }
  }

  /**
   * Buscar conductores disponibles en el área
   */
  private async findAvailableDriversInArea(
    lat: number, 
    lng: number, 
    radiusKm: number
  ): Promise<any[]> {
    try {
      // Query para conductores online y disponibles
      const driversQuery = await this.db
        .collection('users')
        .where('userType', '==', 'driver')
        .where('isOnline', '==', true)
        .where('status', '==', 'available')
        .where('fcmToken', '!=', null)
        .get();

      const availableDrivers: any[] = [];

      driversQuery.forEach((doc) => {
        const driverData = doc.data();
        
        if (driverData.currentLocation) {
          const distance = this.calculateDistance(
            lat, lng,
            driverData.currentLocation.lat,
            driverData.currentLocation.lng
          );

          if (distance <= radiusKm) {
            availableDrivers.push({
              id: doc.id,
              ...driverData,
              distanceKm: distance,
            });
          }
        }
      });

      // Ordenar por distancia (más cerca primero)
      availableDrivers.sort((a, b) => a.distanceKm - b.distanceKm);

      return availableDrivers.slice(0, 10); // Máximo 10 conductores
    } catch (error) {
      console.error('❌ Error buscando conductores disponibles:', error);
      return [];
    }
  }

  /**
   * Calcular distancia entre dos puntos (fórmula de Haversine)
   */
  private calculateDistance(lat1: number, lng1: number, lat2: number, lng2: number): number {
    const R = 6371; // Radio de la Tierra en km
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLng = (lng2 - lng1) * Math.PI / 180;
    const a = 
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * 
      Math.sin(dLng / 2) * Math.sin(dLng / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }
}