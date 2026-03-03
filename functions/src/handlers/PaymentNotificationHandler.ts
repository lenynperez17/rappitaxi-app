import { NotificationService, TaxiNotificationFactory } from '../services/NotificationService';
import * as admin from 'firebase-admin';

export class PaymentNotificationHandler {
  constructor(
    private notificationService: NotificationService,
    private db: admin.firestore.Firestore
  ) {}

  /**
   * 💰 Manejar pago procesado
   */
  async handlePaymentProcessed(paymentId: string, paymentData: any): Promise<void> {
    console.log(`💰 Procesando pago: ${paymentId}`);

    try {
      const { tripId, userId, amount, status, paymentMethod } = paymentData;

      // Obtener datos del usuario
      const userDoc = await this.db.collection('users').doc(userId).get();
      const userData = userDoc.data();

      if (!userData) {
        throw new Error(`Usuario no encontrado: ${userId}`);
      }

      // Procesar según el estado del pago
      switch (status) {
        case 'completed':
        case 'success':
          await this.handlePaymentSuccess(paymentId, tripId, userData, amount, paymentMethod);
          break;
          
        case 'failed':
        case 'error':
          await this.handlePaymentFailed(paymentId, tripId, userData, amount, paymentData.failureReason);
          break;
          
        case 'refunded':
          await this.handlePaymentRefunded(paymentId, tripId, userData, amount);
          break;
          
        case 'pending':
          await this.handlePaymentPending(paymentId, tripId, userData, amount, paymentMethod);
          break;
          
        default:
          console.log(`ℹ️ Estado de pago ${status} no requiere notificación`);
      }

    } catch (error) {
      console.error(`❌ Error procesando pago ${paymentId}:`, error);
      throw error;
    }
  }

  /**
   * ✅ Manejar pago exitoso
   */
  private async handlePaymentSuccess(
    paymentId: string, 
    tripId: string, 
    userData: any, 
    amount: number, 
    paymentMethod: string
  ): Promise<void> {
    
    console.log(`✅ Pago exitoso: ${paymentId} - S/ ${amount}`);

    if (userData.fcmToken) {
      const { notification, data } = TaxiNotificationFactory.createPaymentConfirmation(
        amount,
        this.formatPaymentMethod(paymentMethod)
      );

      await this.notificationService.sendToToken(
        userData.fcmToken,
        notification,
        {
          ...data,
          payment_id: paymentId,
          trip_id: tripId,
          status: 'success',
        }
      );
    }

    // Si hay tripId, también notificar al conductor
    if (tripId) {
      await this.notifyDriverOfPayment(tripId, amount, 'success');
    }

    // Log del pago exitoso
    await this.db.collection('payment_notifications').add({
      paymentId,
      tripId,
      userId: userData.uid || userData.id,
      type: 'payment_success',
      amount,
      paymentMethod,
      notified: true,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  /**
   * ❌ Manejar pago fallido
   */
  private async handlePaymentFailed(
    paymentId: string, 
    tripId: string, 
    userData: any, 
    amount: number, 
    failureReason?: string
  ): Promise<void> {
    
    console.log(`❌ Pago fallido: ${paymentId} - ${failureReason}`);

    if (userData.fcmToken) {
      const notification = {
        title: '❌ Error en el pago',
        body: `No se pudo procesar tu pago de S/ ${amount.toFixed(2)}\n${failureReason || 'Intenta con otro método de pago'}`,
      };

      const data = {
        type: 'payment_failed',
        payment_id: paymentId,
        trip_id: tripId,
        amount: amount.toString(),
        failure_reason: failureReason || 'Error desconocido',
        status: 'failed',
      };

      await this.notificationService.sendToToken(
        userData.fcmToken,
        notification,
        data,
        'high' // Alta prioridad para fallos de pago
      );
    }

    // Log del fallo de pago
    await this.db.collection('payment_notifications').add({
      paymentId,
      tripId,
      userId: userData.uid || userData.id,
      type: 'payment_failed',
      amount,
      failureReason,
      notified: true,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  /**
   * 💸 Manejar reembolso
   */
  private async handlePaymentRefunded(
    paymentId: string, 
    tripId: string, 
    userData: any, 
    amount: number
  ): Promise<void> {
    
    console.log(`💸 Reembolso procesado: ${paymentId} - S/ ${amount}`);

    if (userData.fcmToken) {
      const notification = {
        title: '💸 Reembolso procesado',
        body: `Se ha procesado tu reembolso de S/ ${amount.toFixed(2)}\nEl dinero aparecerá en tu cuenta en 3-5 días hábiles`,
      };

      const data = {
        type: 'payment_refunded',
        payment_id: paymentId,
        trip_id: tripId,
        amount: amount.toString(),
        status: 'refunded',
      };

      await this.notificationService.sendToToken(
        userData.fcmToken,
        notification,
        data
      );
    }

    // Log del reembolso
    await this.db.collection('payment_notifications').add({
      paymentId,
      tripId,
      userId: userData.uid || userData.id,
      type: 'payment_refunded',
      amount,
      notified: true,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  /**
   * ⏳ Manejar pago pendiente
   */
  private async handlePaymentPending(
    paymentId: string, 
    tripId: string, 
    userData: any, 
    amount: number, 
    paymentMethod: string
  ): Promise<void> {
    
    console.log(`⏳ Pago pendiente: ${paymentId} - S/ ${amount}`);

    if (userData.fcmToken) {
      const notification = {
        title: '⏳ Pago en proceso',
        body: `Tu pago de S/ ${amount.toFixed(2)} está siendo procesado\nTe notificaremos cuando se complete`,
      };

      const data = {
        type: 'payment_pending',
        payment_id: paymentId,
        trip_id: tripId,
        amount: amount.toString(),
        payment_method: paymentMethod,
        status: 'pending',
      };

      await this.notificationService.sendToToken(
        userData.fcmToken,
        notification,
        data
      );
    }
  }

  /**
   * Notificar al conductor sobre el estado del pago
   */
  private async notifyDriverOfPayment(
    tripId: string, 
    amount: number, 
    status: 'success' | 'failed'
  ): Promise<void> {
    try {
      // Obtener datos del viaje y conductor
      const tripDoc = await this.db.collection('rides').doc(tripId).get();
      const tripData = tripDoc.data();

      if (!tripData || !tripData.driverId) {
        return; // No hay conductor asignado
      }

      const driverDoc = await this.db.collection('users').doc(tripData.driverId).get();
      const driverData = driverDoc.data();

      if (!driverData?.fcmToken) {
        return; // Conductor sin token FCM
      }

      let notification;
      let data;

      if (status === 'success') {
        const driverEarnings = amount * 0.8; // 80% para el conductor
        
        notification = {
          title: '💰 Pago recibido',
          body: `Pago del viaje completado\nTus ganancias: S/ ${driverEarnings.toFixed(2)}`,
        };

        data = {
          type: 'driver_payment_received',
          trip_id: tripId,
          total_amount: amount.toString(),
          driver_earnings: driverEarnings.toString(),
          status: 'success',
        };
      } else {
        notification = {
          title: '⚠️ Problema con el pago',
          body: 'Hubo un problema con el pago del viaje\nTe notificaremos cuando se resuelva',
        };

        data = {
          type: 'driver_payment_issue',
          trip_id: tripId,
          amount: amount.toString(),
          status: 'failed',
        };
      }

      await this.notificationService.sendToToken(
        driverData.fcmToken,
        notification,
        data
      );

    } catch (error) {
      console.error(`❌ Error notificando conductor sobre pago:`, error);
    }
  }

  /**
   * Formatear método de pago para mostrar al usuario
   */
  private formatPaymentMethod(method: string): string {
    const methods: Record<string, string> = {
      'credit_card': 'Tarjeta de Crédito',
      'debit_card': 'Tarjeta de Débito',
      'cash': 'Efectivo',
      'yape': 'Yape',
      'plin': 'Plin',
      'bank_transfer': 'Transferencia Bancaria',
      'wallet': 'Billetera Digital',
    };

    return methods[method] || method;
  }

  /**
   * Enviar recordatorio de pago pendiente
   */
  async sendPaymentReminder(tripId: string, userId: string): Promise<void> {
    try {
      const userDoc = await this.db.collection('users').doc(userId).get();
      const userData = userDoc.data();

      if (!userData?.fcmToken) {
        return;
      }

      const tripDoc = await this.db.collection('rides').doc(tripId).get();
      const tripData = tripDoc.data();

      if (!tripData) {
        return;
      }

      const notification = {
        title: '💳 Pago pendiente',
        body: `Tienes un pago pendiente de S/ ${tripData.finalFare?.toFixed(2) || '0.00'}\n¡Completa tu pago ahora!`,
      };

      const data = {
        type: 'payment_reminder',
        trip_id: tripId,
        amount: tripData.finalFare?.toString() || '0',
        urgency: 'high',
      };

      await this.notificationService.sendToToken(
        userData.fcmToken,
        notification,
        data,
        'high'
      );

      // Log del recordatorio
      await this.db.collection('payment_reminders').add({
        tripId,
        userId,
        amount: tripData.finalFare || 0,
        sent: true,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`📨 Recordatorio de pago enviado para viaje ${tripId}`);

    } catch (error) {
      console.error(`❌ Error enviando recordatorio de pago:`, error);
      throw error;
    }
  }

  /**
   * Manejar promoción o descuento aplicado
   */
  async handlePromotionApplied(
    userId: string, 
    promotionData: any
  ): Promise<void> {
    try {
      const userDoc = await this.db.collection('users').doc(userId).get();
      const userData = userDoc.data();

      if (!userData?.fcmToken) {
        return;
      }

      const notification = {
        title: '🎉 ¡Descuento aplicado!',
        body: `${promotionData.title}\nAhorro: S/ ${promotionData.discount?.toFixed(2) || '0.00'}`,
      };

      const data = {
        type: 'promotion_applied',
        promotion_id: promotionData.id,
        discount_amount: promotionData.discount?.toString() || '0',
        promotion_type: promotionData.type || 'discount',
      };

      await this.notificationService.sendToToken(
        userData.fcmToken,
        notification,
        data
      );

      console.log(`🎉 Notificación de promoción enviada a usuario ${userId}`);

    } catch (error) {
      console.error(`❌ Error enviando notificación de promoción:`, error);
    }
  }
}