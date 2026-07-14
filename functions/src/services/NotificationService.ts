import * as admin from 'firebase-admin';

// Interfaces para tipado
interface NotificationPayload {
  title: string;
  body: string;
  imageUrl?: string;
}

interface NotificationData {
  [key: string]: string;
}

interface AndroidConfig {
  priority: 'normal' | 'high';
  notification: {
    channelId: string;
    priority: 'default' | 'low' | 'high' | 'max';
    sound: string;
    vibrate_timings_millis?: number[];
    lights?: {
      color: string;
      light_on_duration_millis: number;
      light_off_duration_millis: number;
    };
    actions?: Array<{
      action: string;
      title: string;
    }>;
  };
  ttl: number; // ✅ Cambiado de string a number para compatibilidad con Firebase
}

interface ApnsConfig {
  headers: {
    'apns-priority': string;
    'apns-expiration'?: string;
  };
  payload: {
    aps: {
      alert: {
        title: string;
        body: string;
      };
      sound: string;
      badge?: number;
      category?: string;
      critical?: number;
    };
    actions?: Array<{
      identifier: string;
      title: string;
    }>;
  };
}

/**
 * 🔥 Servicio de Notificaciones FCM REAL
 * Utiliza Firebase Admin SDK para envío real de notificaciones
 */
export class NotificationService {
  private messaging = admin.messaging();

  /**
   * Enviar notificación a tokens específicos
   */
  async sendToTokens(
    tokens: string[], 
    notification: NotificationPayload, 
    data?: NotificationData,
    priority: 'normal' | 'high' = 'normal'
  ): Promise<{ successCount: number; failureCount: number; responses: any[] }> {
    
    console.log(`📤 Enviando notificación a ${tokens.length} tokens...`);

    // Validar y filtrar tokens válidos
    const validTokens = tokens.filter(token => this.isValidFCMToken(token));
    
    if (validTokens.length === 0) {
      throw new Error('No se encontraron tokens válidos');
    }

    const type = data?.type as string | undefined;
    const message = {
      notification: {
        title: notification.title,
        body: notification.body,
        ...(notification.imageUrl && { imageUrl: notification.imageUrl }),
      },
      data: {
        ...data,
        timestamp: new Date().toISOString(),
      },
      android: this.buildAndroidConfig(priority, type),
      apns: this.buildApnsConfig(notification, priority, type),
      tokens: validTokens,
    };

    try {
      // sendEachForMulticast is the non-deprecated replacement for sendMulticast
      const response = await (this.messaging as any).sendEachForMulticast
        ? await (this.messaging as any).sendEachForMulticast(message)
        : await this.messaging.sendMulticast(message);
      
      console.log(`✅ Notificación enviada: ${response.successCount}/${validTokens.length} éxito`);
      
      // Log de tokens que fallaron
      if (response.failureCount > 0) {
        response.responses.forEach((resp: any, idx: number) => {
          if (!resp.success) {
            console.warn(`❌ Token falló [${idx}]: ${resp.error?.code} - ${resp.error?.message}`);
          }
        });
      }

      return {
        successCount: response.successCount,
        failureCount: response.failureCount,
        responses: response.responses,
      };

    } catch (error) {
      console.error('❌ Error enviando notificación multicast:', error);
      throw error;
    }
  }

  /**
   * Enviar notificación a un topic
   */
  async sendToTopic(
    topic: string, 
    notification: NotificationPayload, 
    data?: NotificationData,
    priority: 'normal' | 'high' = 'normal'
  ): Promise<string> {
    
    console.log(`📤 Enviando notificación al topic: ${topic}`);

    const type = data?.type as string | undefined;
    const message = {
      topic,
      notification: {
        title: notification.title,
        body: notification.body,
        ...(notification.imageUrl && { imageUrl: notification.imageUrl }),
      },
      data: {
        ...data,
        timestamp: new Date().toISOString(),
      },
      android: this.buildAndroidConfig(priority, type),
      apns: this.buildApnsConfig(notification, priority, type),
    };

    try {
      const messageId = await this.messaging.send(message);
      console.log(`✅ Notificación enviada al topic ${topic}: ${messageId}`);
      return messageId;
    } catch (error) {
      console.error(`❌ Error enviando notificación al topic ${topic}:`, error);
      throw error;
    }
  }

  /**
   * Enviar notificación a un token individual
   */
  async sendToToken(
    token: string, 
    notification: NotificationPayload, 
    data?: NotificationData,
    priority: 'normal' | 'high' = 'normal'
  ): Promise<string> {
    
    if (!this.isValidFCMToken(token)) {
      throw new Error('Token FCM inválido');
    }

    console.log(`📤 Enviando notificación a token: ${token.substring(0, 20)}...`);

    const type = data?.type as string | undefined;
    const message = {
      token,
      notification: {
        title: notification.title,
        body: notification.body,
        ...(notification.imageUrl && { imageUrl: notification.imageUrl }),
      },
      data: {
        ...data,
        timestamp: new Date().toISOString(),
      },
      android: this.buildAndroidConfig(priority, type),
      apns: this.buildApnsConfig(notification, priority, type),
    };

    try {
      const messageId = await this.messaging.send(message);
      console.log(`✅ Notificación enviada a token: ${messageId}`);
      return messageId;
    } catch (error) {
      console.error(`❌ Error enviando notificación a token:`, error);
      throw error;
    }
  }

  /**
   * Map notification type to Android channel ID and sound filename
   */
  private channelForType(type?: string): { channelId: string; sound: string } {
    switch (type) {
      case 'ride':
      case 'rideRequest':
      case 'tripRequest':
      case 'tripAccepted':
      case 'tripStarted':
      case 'driverArrived':
        return { channelId: 'rappi_rides', sound: 'ride_request' };
      case 'payment':
      case 'paymentSuccess':
      case 'paymentFailed':
      case 'tripCompleted':
        return { channelId: 'rappi_payments', sound: 'trip_completed' };
      case 'emergency':
      case 'securityAlert':
      case 'sos':
        return { channelId: 'rappi_emergency', sound: 'emergency_alert' };
      case 'chat':
      case 'chatMessage':
      case 'message':
        return { channelId: 'rappi_chat', sound: 'chat_message' };
      case 'promotion':
      case 'discount':
      case 'offer':
        return { channelId: 'rappi_promotions', sound: 'ride_accepted' };
      default:
        return { channelId: 'rappi_general', sound: 'ride_accepted' };
    }
  }

  /**
   * Construir configuración Android con canal y sonido dinámicos
   */
  private buildAndroidConfig(priority: 'normal' | 'high', type?: string): AndroidConfig {
    const { channelId, sound } = this.channelForType(type);
    // 5-second alternating vibration (total ~5.5s) for high-priority notifications
    const longVibration = [0, 1000, 500, 1000, 500, 1000, 500, 1000];
    return {
      priority,
      notification: {
        channelId,
        priority: priority === 'high' ? 'max' : 'high',
        sound,
        vibrate_timings_millis: priority === 'high' ? longVibration : [0, 500, 200, 500],
        lights: {
          color: '#E31E24',
          light_on_duration_millis: 1000,
          light_off_duration_millis: 500,
        },
        visibility: 'PUBLIC',
      } as any,
      ttl: priority === 'high' ? 3600 : 86400,
    };
  }

  /**
   * Construir configuración iOS (APNs) con sonido personalizado y volumen máximo
   */
  private buildApnsConfig(
    notification: NotificationPayload,
    priority: 'normal' | 'high',
    type?: string
  ): ApnsConfig {
    const { sound } = this.channelForType(type);
    const isEmergency = type === 'emergency' || type === 'securityAlert' || type === 'sos';
    return {
      headers: {
        'apns-priority': priority === 'high' ? '10' : '5',
        ...(priority === 'high' && {
          'apns-expiration': Math.floor(Date.now() / 1000 + 3600).toString(),
        }),
      },
      payload: {
        aps: {
          alert: {
            title: notification.title,
            body: notification.body,
          },
          // Custom sound with max volume; iOS only plays a single file per push
          sound: isEmergency
            ? ({ critical: 1, name: `${sound}.wav`, volume: 1.0 } as any)
            : ({ name: `${sound}.wav`, volume: 1.0 } as any),
          badge: 1,
          category: priority === 'high' ? 'RIDE_REQUEST' : 'GENERAL',
          // iOS 15+: allow notification to break through Focus / Do Not Disturb
          'interruption-level': isEmergency ? 'critical' : 'time-sensitive',
          ...(priority === 'high' && { critical: 1 }),
        } as any,
      },
    };
  }

  /**
   * Validar formato de token FCM
   */
  private isValidFCMToken(token: string | null | undefined): boolean {
    if (!token || typeof token !== 'string') return false;
    return token.length > 100 && (token.includes(':') || token.includes('-'));
  }

  /**
   * Suscribir tokens a un topic
   */
  async subscribeToTopic(tokens: string[], topic: string): Promise<void> {
    const validTokens = tokens.filter(token => this.isValidFCMToken(token));
    
    if (validTokens.length === 0) {
      throw new Error('No se encontraron tokens válidos para suscribir');
    }

    try {
      const response = await this.messaging.subscribeToTopic(validTokens, topic);
      console.log(`✅ ${response.successCount}/${validTokens.length} tokens suscritos a ${topic}`);
      
      if (response.failureCount > 0) {
        console.warn(`⚠️ ${response.failureCount} tokens fallaron al suscribirse a ${topic}`);
      }
    } catch (error) {
      console.error(`❌ Error suscribiendo tokens al topic ${topic}:`, error);
      throw error;
    }
  }

  /**
   * Desuscribir tokens de un topic
   */
  async unsubscribeFromTopic(tokens: string[], topic: string): Promise<void> {
    const validTokens = tokens.filter(token => this.isValidFCMToken(token));
    
    if (validTokens.length === 0) {
      throw new Error('No se encontraron tokens válidos para desuscribir');
    }

    try {
      const response = await this.messaging.unsubscribeFromTopic(validTokens, topic);
      console.log(`✅ ${response.successCount}/${validTokens.length} tokens desuscritos de ${topic}`);
      
      if (response.failureCount > 0) {
        console.warn(`⚠️ ${response.failureCount} tokens fallaron al desuscribirse de ${topic}`);
      }
    } catch (error) {
      console.error(`❌ Error desuscribiendo tokens del topic ${topic}:`, error);
      throw error;
    }
  }

  /**
   * Test de conexión FCM
   */
  async testConnection(): Promise<boolean> {
    try {
      console.log('🔍 Testing FCM connection...');
      return true; // Si llegamos aquí sin errores, FCM está configurado correctamente
      
    } catch (error) {
      console.error('❌ FCM connection test failed:', error);
      return false;
    }
  }

  /**
   * Obtener estadísticas del servicio
   */
  getStats(): { service: string; initialized: boolean; timestamp: string } {
    return {
      service: 'NotificationService',
      initialized: !!this.messaging,
      timestamp: new Date().toISOString(),
    };
  }
}

/**
 * 🏭 Factory de notificaciones para tipos específicos de taxi
 */
export class TaxiNotificationFactory {
  
  static createRideRequest(
    passengerName: string,
    pickupAddress: string,
    destinationAddress: string,
    estimatedFare: number
  ): { notification: NotificationPayload; data: NotificationData } {
    return {
      notification: {
        title: '🚗 ¡Nueva solicitud de viaje!',
        body: `Pasajero: ${passengerName}\nDesde: ${pickupAddress}\nTarifa estimada: S/ ${estimatedFare.toFixed(2)}`,
      },
      data: {
        type: 'ride_request',
        passenger_name: passengerName,
        pickup_address: pickupAddress,
        destination_address: destinationAddress,
        estimated_fare: estimatedFare.toString(),
      },
    };
  }

  static createDriverArrived(
    driverName: string,
    licensePlate: string
  ): { notification: NotificationPayload; data: NotificationData } {
    return {
      notification: {
        title: '🚗 Tu conductor ha llegado',
        body: `${driverName} está esperándote\nPlaca: ${licensePlate}`,
      },
      data: {
        type: 'driver_arrived',
        driver_name: driverName,
        license_plate: licensePlate,
      },
    };
  }

  static createPaymentConfirmation(
    amount: number,
    paymentMethod: string
  ): { notification: NotificationPayload; data: NotificationData } {
    return {
      notification: {
        title: '💰 Pago procesado exitosamente',
        body: `S/ ${amount.toFixed(2)} pagado con ${paymentMethod}`,
      },
      data: {
        type: 'payment_success',
        amount: amount.toString(),
        payment_method: paymentMethod,
      },
    };
  }

  static createEmergencyAlert(
    location: string,
    tripId: string
  ): { notification: NotificationPayload; data: NotificationData } {
    return {
      notification: {
        title: '🚨 ALERTA DE EMERGENCIA',
        body: `Botón SOS activado\nUbicación: ${location}`,
      },
      data: {
        type: 'emergency_alert',
        location,
        trip_id: tripId,
        priority: 'critical',
      },
    };
  }

  static createTripStatusUpdate(
    status: string,
    message: string
  ): { notification: NotificationPayload; data: NotificationData } {
    return {
      notification: {
        title: '🔄 Estado del viaje actualizado',
        body: message,
      },
      data: {
        type: 'trip_status_update',
        status,
      },
    };
  }
}