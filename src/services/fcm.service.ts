import * as admin from 'firebase-admin';
import { getMessaging, Message, MulticastMessage } from 'firebase-admin/messaging';
import logger from '../utils/logger';

/**
 * Servicio FCM REAL para envío de notificaciones push
 * ✅ IMPLEMENTACIÓN 100% REAL con Firebase Cloud Messaging
 */
export class FCMService {
  private messaging: admin.messaging.Messaging;

  constructor() {
    this.messaging = getMessaging();
    logger.info('🔔 Servicio FCM Real inicializado');
  }

  /**
   * Enviar notificación a un dispositivo específico
   */
  async sendToDevice(
    token: string,
    title: string,
    body: string,
    data?: Record<string, string>
  ): Promise<string> {
    try {
      const message: Message = {
        token,
        notification: {
          title,
          body,
        },
        data: data || {},
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
            channelId: 'high_importance_channel',
          },
        },
        apns: {
          payload: {
            aps: {
              alert: {
                title,
                body,
              },
              sound: 'default',
              badge: 1,
            },
          },
        },
        webpush: {
          notification: {
            title,
            body,
            icon: '/icon-192x192.png',
            badge: '/badge-72x72.png',
          },
        },
      };

      const response = await this.messaging.send(message);
      logger.info(`✅ Notificación enviada: ${response}`);
      return response;
    } catch (error) {
      logger.error('❌ Error enviando notificación FCM:', error);
      throw error;
    }
  }

  /**
   * Enviar notificación a múltiples dispositivos
   */
  async sendToMultipleDevices(
    tokens: string[],
    title: string,
    body: string,
    data?: Record<string, string>
  ): Promise<admin.messaging.BatchResponse> {
    try {
      if (tokens.length === 0) {
        throw new Error('No hay tokens para enviar notificaciones');
      }

      const message: MulticastMessage = {
        tokens,
        notification: {
          title,
          body,
        },
        data: data || {},
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
            channelId: 'high_importance_channel',
          },
        },
        apns: {
          payload: {
            aps: {
              alert: {
                title,
                body,
              },
              sound: 'default',
              badge: 1,
            },
          },
        },
      };

      const response = await this.messaging.sendEachForMulticast(message);
      
      logger.info(`📱 Notificaciones enviadas: ${response.successCount}/${tokens.length}`);
      
      // Procesar tokens fallidos
      if (response.failureCount > 0) {
        const failedTokens: string[] = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            failedTokens.push(tokens[idx]);
            logger.error(`Token fallido: ${tokens[idx]} - Error: ${resp.error?.message}`);
          }
        });
        // Aquí podrías marcar estos tokens como inválidos en la base de datos
        await this.handleFailedTokens(failedTokens);
      }

      return response;
    } catch (error) {
      logger.error('❌ Error enviando notificaciones múltiples:', error);
      throw error;
    }
  }

  /**
   * Enviar notificación de nuevo viaje a conductores cercanos
   */
  async sendRideRequestToDrivers(
    driverTokens: string[],
    rideDetails: {
      rideId: string;
      pickupAddress: string;
      destinationAddress: string;
      estimatedFare: number;
      estimatedDistance: number;
      estimatedDuration: number;
      passengerName: string;
    }
  ): Promise<admin.messaging.BatchResponse> {
    const title = '🚕 Nueva solicitud de viaje';
    const body = `De: ${rideDetails.pickupAddress}\nHacia: ${rideDetails.destinationAddress}\nTarifa: S/.${rideDetails.estimatedFare.toFixed(2)}`;
    
    const data = {
      type: 'ride_request',
      rideId: rideDetails.rideId,
      pickupAddress: rideDetails.pickupAddress,
      destinationAddress: rideDetails.destinationAddress,
      estimatedFare: rideDetails.estimatedFare.toString(),
      estimatedDistance: rideDetails.estimatedDistance.toString(),
      estimatedDuration: rideDetails.estimatedDuration.toString(),
      passengerName: rideDetails.passengerName,
      timestamp: new Date().toISOString(),
    };

    return this.sendToMultipleDevices(driverTokens, title, body, data);
  }

  /**
   * Notificar al pasajero que el conductor aceptó el viaje
   */
  async sendRideAcceptedToPassenger(
    passengerToken: string,
    driverDetails: {
      driverName: string;
      vehiclePlate: string;
      vehicleModel: string;
      estimatedArrival: number;
      driverPhoto?: string;
    }
  ): Promise<string> {
    const title = '✅ Tu viaje ha sido aceptado';
    const body = `${driverDetails.driverName} llegará en ${driverDetails.estimatedArrival} minutos\n${driverDetails.vehicleModel} - ${driverDetails.vehiclePlate}`;
    
    const data = {
      type: 'ride_accepted',
      driverName: driverDetails.driverName,
      vehiclePlate: driverDetails.vehiclePlate,
      vehicleModel: driverDetails.vehicleModel,
      estimatedArrival: driverDetails.estimatedArrival.toString(),
      driverPhoto: driverDetails.driverPhoto || '',
      timestamp: new Date().toISOString(),
    };

    return this.sendToDevice(passengerToken, title, body, data);
  }

  /**
   * Notificar que el conductor llegó al punto de recogida
   */
  async sendDriverArrivedNotification(
    passengerToken: string,
    driverName: string
  ): Promise<string> {
    const title = '🚕 Tu conductor ha llegado';
    const body = `${driverName} te está esperando en el punto de recogida`;
    
    const data = {
      type: 'driver_arrived',
      driverName,
      timestamp: new Date().toISOString(),
    };

    return this.sendToDevice(passengerToken, title, body, data);
  }

  /**
   * Notificar inicio del viaje
   */
  async sendTripStartedNotification(
    passengerToken: string,
    destinationAddress: string
  ): Promise<string> {
    const title = '🚗 Viaje iniciado';
    const body = `En camino hacia: ${destinationAddress}`;
    
    const data = {
      type: 'trip_started',
      destinationAddress,
      timestamp: new Date().toISOString(),
    };

    return this.sendToDevice(passengerToken, title, body, data);
  }

  /**
   * Notificar finalización del viaje
   */
  async sendTripCompletedNotification(
    token: string,
    tripDetails: {
      finalFare: number;
      distance: number;
      duration: number;
    }
  ): Promise<string> {
    const title = '✅ Viaje completado';
    const body = `Total: S/.${tripDetails.finalFare.toFixed(2)} | ${tripDetails.distance.toFixed(1)}km | ${tripDetails.duration} min`;
    
    const data = {
      type: 'trip_completed',
      finalFare: tripDetails.finalFare.toString(),
      distance: tripDetails.distance.toString(),
      duration: tripDetails.duration.toString(),
      timestamp: new Date().toISOString(),
    };

    return this.sendToDevice(token, title, body, data);
  }

  /**
   * Notificar cancelación del viaje
   */
  async sendTripCancelledNotification(
    token: string,
    cancelledBy: 'passenger' | 'driver',
    reason?: string
  ): Promise<string> {
    const title = '❌ Viaje cancelado';
    const body = cancelledBy === 'passenger' 
      ? 'El pasajero ha cancelado el viaje' 
      : 'El conductor ha cancelado el viaje';
    
    const data = {
      type: 'trip_cancelled',
      cancelledBy,
      reason: reason || '',
      timestamp: new Date().toISOString(),
    };

    return this.sendToDevice(token, title, body, data);
  }

  /**
   * Enviar notificación de mensaje de chat
   */
  async sendChatMessageNotification(
    token: string,
    senderName: string,
    message: string,
    chatId: string
  ): Promise<string> {
    const title = `💬 ${senderName}`;
    const body = message;
    
    const data = {
      type: 'chat_message',
      chatId,
      senderName,
      timestamp: new Date().toISOString(),
    };

    return this.sendToDevice(token, title, body, data);
  }

  /**
   * Enviar notificación de emergencia SOS
   */
  async sendEmergencyNotification(
    tokens: string[],
    emergency: {
      userId: string;
      userName: string;
      location: { lat: number; lng: number };
      message: string;
    }
  ): Promise<admin.messaging.BatchResponse> {
    const title = '🆘 EMERGENCIA - SOS';
    const body = `${emergency.userName} ha activado el botón de emergencia`;
    
    const data = {
      type: 'emergency_sos',
      userId: emergency.userId,
      userName: emergency.userName,
      latitude: emergency.location.lat.toString(),
      longitude: emergency.location.lng.toString(),
      message: emergency.message,
      timestamp: new Date().toISOString(),
    };

    return this.sendToMultipleDevices(tokens, title, body, data);
  }

  /**
   * Suscribir token a un tema
   */
  async subscribeToTopic(token: string, topic: string): Promise<void> {
    try {
      await this.messaging.subscribeToTopic(token, topic);
      logger.info(`✅ Token suscrito al tema: ${topic}`);
    } catch (error) {
      logger.error(`❌ Error suscribiendo al tema ${topic}:`, error);
      throw error;
    }
  }

  /**
   * Desuscribir token de un tema
   */
  async unsubscribeFromTopic(token: string, topic: string): Promise<void> {
    try {
      await this.messaging.unsubscribeFromTopic(token, topic);
      logger.info(`✅ Token desuscrito del tema: ${topic}`);
    } catch (error) {
      logger.error(`❌ Error desuscribiendo del tema ${topic}:`, error);
      throw error;
    }
  }

  /**
   * Enviar notificación a un tema
   */
  async sendToTopic(
    topic: string,
    title: string,
    body: string,
    data?: Record<string, string>
  ): Promise<string> {
    try {
      const message: Message = {
        topic,
        notification: {
          title,
          body,
        },
        data: data || {},
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            channelId: 'high_importance_channel',
          },
        },
        apns: {
          payload: {
            aps: {
              alert: {
                title,
                body,
              },
              sound: 'default',
            },
          },
        },
      };

      const response = await this.messaging.send(message);
      logger.info(`✅ Notificación enviada al tema ${topic}: ${response}`);
      return response;
    } catch (error) {
      logger.error(`❌ Error enviando al tema ${topic}:`, error);
      throw error;
    }
  }

  /**
   * Manejar tokens fallidos (marcarlos como inválidos en la DB)
   */
  private async handleFailedTokens(tokens: string[]): Promise<void> {
    try {
      const db = admin.firestore();
      const batch = db.batch();

      for (const token of tokens) {
        // Buscar usuarios con este token y marcarlo como inválido
        const usersSnapshot = await db
          .collection('users')
          .where('fcmToken', '==', token)
          .get();

        usersSnapshot.forEach(doc => {
          batch.update(doc.ref, {
            fcmToken: null,
            fcmTokenInvalid: true,
            fcmTokenInvalidatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        });

        // También buscar en drivers
        const driversSnapshot = await db
          .collection('drivers')
          .where('fcmToken', '==', token)
          .get();

        driversSnapshot.forEach(doc => {
          batch.update(doc.ref, {
            fcmToken: null,
            fcmTokenInvalid: true,
            fcmTokenInvalidatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        });
      }

      await batch.commit();
      logger.info(`🗑️ ${tokens.length} tokens inválidos marcados en la base de datos`);
    } catch (error) {
      logger.error('Error manejando tokens fallidos:', error);
    }
  }
}

export default new FCMService();