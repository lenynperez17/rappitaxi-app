import { NotificationService, TaxiNotificationFactory } from '../services/NotificationService';
import * as admin from 'firebase-admin';

export class EmergencyNotificationHandler {
  constructor(
    private notificationService: NotificationService,
    private db: admin.firestore.Firestore
  ) {}

  /**
   * 🚨 Manejar emergencia activada
   * CRÍTICO: Máxima prioridad y velocidad de respuesta
   */
  async handleEmergency(emergencyId: string, emergencyData: any): Promise<void> {
    console.log(`🚨 EMERGENCIA CRÍTICA: ${emergencyId}`);

    const startTime = Date.now();

    try {
      const { 
        userId, 
        tripId, 
        type, 
        location, 
        description,
        userType // 'passenger' o 'driver'
      } = emergencyData;

      // 1. Obtener datos del usuario que activó la emergencia
      const userDoc = await this.db.collection('users').doc(userId).get();
      const userData = userDoc.data();

      if (!userData) {
        throw new Error(`Usuario de emergencia no encontrado: ${userId}`);
      }

      // 2. Obtener datos del viaje si existe
      let tripData = null;
      let otherUserData = null;

      if (tripId) {
        const tripDoc = await this.db.collection('rides').doc(tripId).get();
        tripData = tripDoc.data();

        if (tripData) {
          // Obtener datos de la otra persona (conductor o pasajero)
          const otherUserId = userType === 'passenger' ? tripData.driverId : tripData.passengerId;
          if (otherUserId) {
            const otherUserDoc = await this.db.collection('users').doc(otherUserId).get();
            otherUserData = otherUserDoc.data();
          }
        }
      }

      // 3. Enviar notificaciones inmediatas según el tipo
      switch (type) {
        case 'sos_button':
          await this.handleSOSActivated(emergencyId, userData, otherUserData, tripData, location);
          break;
          
        case 'panic_button':
          await this.handlePanicAlert(emergencyId, userData, otherUserData, tripData, location);
          break;
          
        case 'unsafe_driver':
          await this.handleUnsafeDriverReport(emergencyId, userData, tripData, description);
          break;
          
        case 'unsafe_passenger':
          await this.handleUnsafePassengerReport(emergencyId, userData, tripData, description);
          break;
          
        case 'accident':
          await this.handleAccidentReport(emergencyId, userData, otherUserData, tripData, location);
          break;
          
        default:
          await this.handleGenericEmergency(emergencyId, userData, otherUserData, type, location);
      }

      // 4. Notificar a autoridades y soporte si es crítico
      if (this.isCriticalEmergency(type)) {
        await this.notifyAuthorities(emergencyId, emergencyData, userData, tripData);
        await this.notifySupport(emergencyId, emergencyData, userData);
      }

      // 5. Registrar tiempo de respuesta
      const responseTime = Date.now() - startTime;
      console.log(`⚡ Emergencia ${emergencyId} procesada en ${responseTime}ms`);

      // 6. Log de la emergencia
      await this.logEmergencyResponse(emergencyId, emergencyData, responseTime);

    } catch (error) {
      const responseTime = Date.now() - startTime;
      console.error(`❌ ERROR CRÍTICO procesando emergencia ${emergencyId} (${responseTime}ms):`, error);
      
      // Log crítico del error
      await this.db.collection('critical_emergency_errors').add({
        emergencyId,
        error: error instanceof Error ? error.message : String(error),
        responseTime,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      throw error;
    }
  }

  /**
   * 🆘 Manejar activación de botón SOS
   */
  private async handleSOSActivated(
    emergencyId: string,
    userData: any,
    otherUserData: any,
    tripData: any,
    location: string
  ): Promise<void> {
    
    console.log(`🆘 Botón SOS activado por ${userData.name}`);

    // Notificar a la otra persona del viaje (si existe)
    if (otherUserData?.fcmToken) {
      const { notification, data } = TaxiNotificationFactory.createEmergencyAlert(
        location,
        tripData?.id || 'unknown'
      );

      await this.notificationService.sendToToken(
        otherUserData.fcmToken,
        {
          ...notification,
          body: `⚠️ ${userData.name} activó el botón SOS\nUbicación: ${location}\n¡Contacta a las autoridades si es necesario!`
        },
        {
          ...data,
          emergency_id: emergencyId,
          emergency_type: 'sos_button',
          reporter_name: userData.name,
        },
        'high'
      );
    }

    // Notificar a contactos de emergencia del usuario
    await this.notifyEmergencyContacts(userData, emergencyId, 'sos_button', location);
  }

  /**
   * 😰 Manejar alerta de pánico
   */
  private async handlePanicAlert(
    emergencyId: string,
    userData: any,
    otherUserData: any,
    tripData: any,
    location: string
  ): Promise<void> {
    
    console.log(`😰 Alerta de pánico activada por ${userData.name}`);

    // Similar al SOS pero con mayor urgencia
    if (otherUserData?.fcmToken) {
      const notification = {
        title: '🚨 ALERTA DE PÁNICO',
        body: `${userData.name} activó una alerta de pánico\nUbicación: ${location}\n¡CONTACTA INMEDIATAMENTE A EMERGENCIAS!`,
      };

      const data = {
        type: 'panic_alert',
        emergency_id: emergencyId,
        trip_id: tripData?.id || '',
        location,
        reporter_id: userData.uid || userData.id,
        reporter_name: userData.name,
        urgency: 'critical',
      };

      await this.notificationService.sendToToken(
        otherUserData.fcmToken,
        notification,
        data,
        'high'
      );
    }

    // Auto-llamada a emergencias (si está configurado)
    await this.triggerEmergencyCall(userData, location, 'panic_alert');
    
    // Notificar contactos de emergencia
    await this.notifyEmergencyContacts(userData, emergencyId, 'panic_alert', location);
  }

  /**
   * 🚫 Manejar reporte de conductor inseguro
   */
  private async handleUnsafeDriverReport(
    emergencyId: string,
    userData: any,
    tripData: any,
    description: string
  ): Promise<void> {
    
    console.log(`🚫 Reporte de conductor inseguro: ${emergencyId}`);

    // Notificar al equipo de seguridad
    await this.notifySecurityTeam(emergencyId, {
      type: 'unsafe_driver_report',
      reporter: userData,
      trip: tripData,
      description,
      driverId: tripData?.driverId,
    });

    // Confirmación al pasajero
    if (userData.fcmToken) {
      const notification = {
        title: '🛡️ Reporte recibido',
        body: 'Tu reporte de seguridad ha sido recibido\nNuestro equipo lo revisará inmediatamente',
      };

      const data = {
        type: 'safety_report_confirmation',
        emergency_id: emergencyId,
        trip_id: tripData?.id || '',
        report_type: 'unsafe_driver',
      };

      await this.notificationService.sendToToken(
        userData.fcmToken,
        notification,
        data
      );
    }
  }

  /**
   * 🚫 Manejar reporte de pasajero inseguro
   */
  private async handleUnsafePassengerReport(
    emergencyId: string,
    userData: any,
    tripData: any,
    description: string
  ): Promise<void> {
    
    console.log(`🚫 Reporte de pasajero inseguro: ${emergencyId}`);

    // Similar al reporte de conductor pero desde la perspectiva del conductor
    await this.notifySecurityTeam(emergencyId, {
      type: 'unsafe_passenger_report',
      reporter: userData,
      trip: tripData,
      description,
      passengerId: tripData?.passengerId,
    });

    // Confirmación al conductor
    if (userData.fcmToken) {
      const notification = {
        title: '🛡️ Reporte enviado',
        body: 'Tu reporte de seguridad ha sido registrado\nSigue las instrucciones de seguridad',
      };

      const data = {
        type: 'safety_report_confirmation',
        emergency_id: emergencyId,
        trip_id: tripData?.id || '',
        report_type: 'unsafe_passenger',
      };

      await this.notificationService.sendToToken(
        userData.fcmToken,
        notification,
        data
      );
    }
  }

  /**
   * 🚗 Manejar reporte de accidente
   */
  private async handleAccidentReport(
    emergencyId: string,
    userData: any,
    otherUserData: any,
    tripData: any,
    location: string
  ): Promise<void> {
    
    console.log(`🚗 Reporte de accidente: ${emergencyId}`);

    // Notificar a ambas partes si están disponibles
    const notification = {
      title: '🚗 Accidente reportado',
      body: `Se reportó un accidente en el viaje\nUbicación: ${location}\n¿Necesitas asistencia médica?`,
    };

    const data = {
      type: 'accident_report',
      emergency_id: emergencyId,
      trip_id: tripData?.id || '',
      location,
      reporter_id: userData.uid || userData.id,
    };

    if (otherUserData?.fcmToken) {
      await this.notificationService.sendToToken(
        otherUserData.fcmToken,
        notification,
        data,
        'high'
      );
    }

    // Auto-notificar servicios de emergencia
    await this.notifyEmergencyServices(emergencyId, 'accident', location, userData);
    
    // Notificar seguros (si aplica)
    await this.notifyInsurance(tripData, location, userData);
  }

  /**
   * ⚠️ Manejar emergencia genérica
   */
  private async handleGenericEmergency(
    emergencyId: string,
    userData: any,
    otherUserData: any,
    type: string,
    location: string
  ): Promise<void> {
    
    console.log(`⚠️ Emergencia genérica tipo ${type}: ${emergencyId}`);

    if (otherUserData?.fcmToken) {
      const notification = {
        title: '⚠️ Alerta de emergencia',
        body: `${userData.name} reportó una situación de emergencia\nUbicación: ${location}`,
      };

      const data = {
        type: 'generic_emergency',
        emergency_id: emergencyId,
        emergency_type: type,
        location,
        reporter_id: userData.uid || userData.id,
      };

      await this.notificationService.sendToToken(
        otherUserData.fcmToken,
        notification,
        data,
        'high'
      );
    }
  }

  /**
   * Determinar si la emergencia es crítica
   */
  private isCriticalEmergency(type: string): boolean {
    const criticalTypes = ['sos_button', 'panic_button', 'accident', 'medical_emergency'];
    return criticalTypes.includes(type);
  }

  /**
   * Notificar a autoridades
   */
  private async notifyAuthorities(
    emergencyId: string,
    emergencyData: any,
    userData: any,
    tripData: any
  ): Promise<void> {
    try {
      // En un entorno real, esto integraría con APIs de servicios de emergencia
      console.log(`🚔 Notificando autoridades para emergencia ${emergencyId}`);

      // Log para autoridades
      await this.db.collection('authority_notifications').add({
        emergencyId,
        emergencyData,
        userData: {
          id: userData.uid || userData.id,
          name: userData.name,
          phone: userData.phone,
        },
        tripData: tripData ? {
          id: tripData.id,
          driverId: tripData.driverId,
          passengerId: tripData.passengerId,
        } : null,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        status: 'notified',
      });

    } catch (error) {
      console.error('❌ Error notificando autoridades:', error);
    }
  }

  /**
   * Notificar equipo de soporte
   */
  private async notifySupport(
    emergencyId: string,
    emergencyData: any,
    userData: any
  ): Promise<void> {
    try {
      // Notificar al topic de soporte de emergencias
      await this.notificationService.sendToTopic(
        'emergency-support',
        {
          title: `🚨 Emergencia ${emergencyData.type}`,
          body: `Usuario: ${userData.name}\nID: ${emergencyId}\nUbicación: ${emergencyData.location || 'No disponible'}`,
        },
        {
          emergency_id: emergencyId,
          emergency_type: emergencyData.type,
          user_id: userData.uid || userData.id,
          priority: 'critical',
        },
        'high'
      );

    } catch (error) {
      console.error('❌ Error notificando soporte:', error);
    }
  }

  /**
   * Notificar contactos de emergencia del usuario
   */
  private async notifyEmergencyContacts(
    userData: any,
    emergencyId: string,
    type: string,
    location: string
  ): Promise<void> {
    try {
      if (!userData.emergencyContacts || !Array.isArray(userData.emergencyContacts)) {
        return;
      }

      for (const contact of userData.emergencyContacts) {
        if (contact.phone) {
          // En un entorno real, enviarías SMS
          console.log(`📱 SMS a contacto de emergencia: ${contact.phone}`);
          
          // Log del contacto notificado
          await this.db.collection('emergency_contact_notifications').add({
            emergencyId,
            contactName: contact.name,
            contactPhone: contact.phone,
            userId: userData.uid || userData.id,
            userName: userData.name,
            emergencyType: type,
            location,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }

    } catch (error) {
      console.error('❌ Error notificando contactos de emergencia:', error);
    }
  }

  /**
   * Notificar equipo de seguridad
   */
  private async notifySecurityTeam(emergencyId: string, reportData: any): Promise<void> {
    try {
      await this.notificationService.sendToTopic(
        'security-team',
        {
          title: `🛡️ Reporte de Seguridad`,
          body: `Tipo: ${reportData.type}\nReportado por: ${reportData.reporter.name}\nID: ${emergencyId}`,
        },
        {
          emergency_id: emergencyId,
          report_type: reportData.type,
          reporter_id: reportData.reporter.uid || reportData.reporter.id,
          trip_id: reportData.trip?.id || '',
          priority: 'high',
        },
        'high'
      );

    } catch (error) {
      console.error('❌ Error notificando equipo de seguridad:', error);
    }
  }

  /**
   * Trigger de llamada automática a emergencias
   */
  private async triggerEmergencyCall(
    userData: any,
    location: string,
    type: string
  ): Promise<void> {
    try {
      // En un entorno real, esto activaría un sistema de llamada automática
      console.log(`📞 Llamada automática a emergencias para ${userData.name}`);

      // Log de la llamada automática
      await this.db.collection('emergency_calls').add({
        userId: userData.uid || userData.id,
        userName: userData.name,
        phone: userData.phone,
        location,
        emergencyType: type,
        callTriggered: true,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

    } catch (error) {
      console.error('❌ Error activando llamada de emergencia:', error);
    }
  }

  /**
   * Notificar servicios de emergencia
   */
  private async notifyEmergencyServices(
    emergencyId: string,
    type: string,
    location: string,
    userData: any
  ): Promise<void> {
    try {
      // Log para servicios de emergencia
      await this.db.collection('emergency_service_notifications').add({
        emergencyId,
        type,
        location,
        userId: userData.uid || userData.id,
        userName: userData.name,
        userPhone: userData.phone,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        status: 'pending_dispatch',
      });

      console.log(`🚑 Servicios de emergencia notificados: ${emergencyId}`);

    } catch (error) {
      console.error('❌ Error notificando servicios de emergencia:', error);
    }
  }

  /**
   * Notificar compañía de seguros
   */
  private async notifyInsurance(tripData: any, location: string, userData: any): Promise<void> {
    try {
      if (!tripData) return;

      // Log para seguros
      await this.db.collection('insurance_notifications').add({
        tripId: tripData.id,
        driverId: tripData.driverId,
        passengerId: tripData.passengerId,
        accidentLocation: location,
        reportedBy: userData.uid || userData.id,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        status: 'reported',
      });

      console.log(`🛡️ Seguros notificados para viaje ${tripData.id}`);

    } catch (error) {
      console.error('❌ Error notificando seguros:', error);
    }
  }

  /**
   * Log de respuesta de emergencia
   */
  private async logEmergencyResponse(
    emergencyId: string,
    emergencyData: any,
    responseTime: number
  ): Promise<void> {
    try {
      await this.db.collection('emergency_response_logs').add({
        emergencyId,
        type: emergencyData.type,
        userId: emergencyData.userId,
        tripId: emergencyData.tripId || null,
        location: emergencyData.location || null,
        responseTimeMs: responseTime,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        processed: true,
      });

    } catch (error) {
      console.error('❌ Error logging emergencia:', error);
    }
  }
}