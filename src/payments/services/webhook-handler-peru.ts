import * as crypto from 'crypto';
import * as admin from 'firebase-admin';
import { Request, Response } from 'express';
import { logger } from '@shared/utils/logger';
import { AppError } from '@shared/middleware/error-handler';
import { PaymentStatus } from '@shared/types';
import { mercadoPagoService } from '@/config/mercadopago.config';

/**
 * 🇵🇪 WEBHOOK HANDLER MERCADOPAGO PERÚ - SEGURO Y COMPLETO
 * ======================================================
 * 
 * Maneja webhooks de MercadoPago con validación de firmas,
 * procesamiento específico para Perú, y actualización en tiempo real.
 * 
 * Características:
 * ✅ Validación de firmas webhook (crítico para seguridad)
 * ✅ Manejo de todos los estados de pago MercadoPago
 * ✅ Procesamiento de comisiones para conductores (80/20)
 * ✅ Logging detallado y alertas
 * ✅ Idempotencia (previene procesamiento duplicado)
 * ✅ Analytics en tiempo real
 * ✅ Notificaciones a usuarios
 */

interface WebhookData {
  id: number;
  live_mode: boolean;
  type: string;
  date_created: string;
  application_id: number;
  user_id: string;
  version: number;
  api_version: string;
  action: string;
  data: {
    id: string;
  };
}

interface PaymentWebhookResult {
  success: boolean;
  paymentId?: string;
  status?: PaymentStatus;
  amount?: number;
  transactionId?: string;
  data?: any;
  error?: string;
}

/**
 * Procesar webhook de MercadoPago con validación de seguridad
 */
export async function processMercadoPagoWebhook(
  req: Request, 
  res: Response
): Promise<void> {
  const startTime = Date.now();
  const webhookId = `webhook_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  
  try {
    logger.info('🔔 Webhook MercadoPago recibido', {
      webhookId,
      userAgent: req.get('User-Agent'),
      ip: req.ip,
      contentType: req.get('Content-Type')
    });

    // 1. Validar headers obligatorios
    const xSignature = req.get('x-signature');
    const xRequestId = req.get('x-request-id');
    
    if (!xSignature || !xRequestId) {
      throw new AppError('Headers de seguridad faltantes', 400, 'MISSING_SECURITY_HEADERS');
    }

    // 2. Extraer timestamp de la firma
    const ts = extractTimestamp(xSignature);
    if (!ts) {
      throw new AppError('Timestamp inválido en signature', 400, 'INVALID_TIMESTAMP');
    }

    // 3. Validar que el webhook no sea demasiado antiguo (5 minutos)
    const webhookAge = Date.now() - parseInt(ts) * 1000;
    if (webhookAge > 300000) { // 5 minutos en ms
      throw new AppError('Webhook demasiado antiguo', 400, 'WEBHOOK_TOO_OLD');
    }

    // 4. Procesar datos del webhook
    const webhookData: WebhookData = req.body;
    if (!webhookData || !webhookData.data?.id) {
      throw new AppError('Datos de webhook inválidos', 400, 'INVALID_WEBHOOK_DATA');
    }

    // 5. Validar firma de seguridad
    const isValidSignature = await validateWebhookSignature(
      xSignature, 
      xRequestId, 
      webhookData.data.id, 
      ts
    );
    
    if (!isValidSignature) {
      logger.error('❌ Firma de webhook inválida', {
        webhookId,
        signature: xSignature,
        requestId: xRequestId,
        dataId: webhookData.data.id
      });
      throw new AppError('Firma de webhook inválida', 401, 'INVALID_SIGNATURE');
    }

    // 6. Verificar idempotencia (evitar procesamiento duplicado)
    const isAlreadyProcessed = await checkIfWebhookProcessed(webhookId, xRequestId);
    if (isAlreadyProcessed) {
      logger.info('🔄 Webhook ya procesado, omitiendo', { webhookId, requestId: xRequestId });
      res.status(200).json({ received: true, already_processed: true });
      return;
    }

    // 7. Procesar según tipo de evento
    let result: PaymentWebhookResult;
    
    switch (webhookData.type) {
      case 'payment':
        result = await processPaymentWebhook(webhookData, webhookId);
        break;
      case 'merchant_order':
        result = await processMerchantOrderWebhook(webhookData, webhookId);
        break;
      default:
        logger.warn('⚠️ Tipo de webhook no soportado', {
          webhookId,
          type: webhookData.type,
          action: webhookData.action
        });
        result = { success: true }; // Ignorar tipos desconocidos
    }

    // 8. Registrar que el webhook fue procesado
    await markWebhookAsProcessed(webhookId, xRequestId, webhookData, result);

    // 9. Responder a MercadoPago
    const processingTime = Date.now() - startTime;
    
    logger.info('✅ Webhook procesado exitosamente', {
      webhookId,
      result: result.success,
      processingTime: `${processingTime}ms`,
      paymentId: result.paymentId,
      status: result.status
    });

    res.status(200).json({ 
      received: true, 
      processed: result.success,
      processing_time: processingTime
    });

  } catch (error) {
    const processingTime = Date.now() - startTime;
    
    logger.error('❌ Error procesando webhook MercadoPago', {
      webhookId,
      error: error.message,
      stack: error.stack,
      processingTime: `${processingTime}ms`,
      body: req.body
    });

    // Responder con error apropiado
    if (error instanceof AppError) {
      res.status(error.statusCode).json({ 
        error: error.message, 
        code: error.code 
      });
    } else {
      res.status(500).json({ 
        error: 'Error interno procesando webhook' 
      });
    }
  }
}

/**
 * Procesar webhook específico de pago
 */
async function processPaymentWebhook(
  webhookData: WebhookData, 
  webhookId: string
): Promise<PaymentWebhookResult> {
  try {
    const paymentId = webhookData.data.id;
    
    logger.info('💳 Procesando webhook de pago', {
      webhookId,
      paymentId,
      action: webhookData.action
    });

    // 1. Obtener datos del pago desde MercadoPago
    const paymentData = await mercadoPagoService.getPayment(paymentId);
    
    if (!paymentData) {
      throw new Error(`Pago no encontrado en MercadoPago: ${paymentId}`);
    }

    // 2. Mapear estado de MercadoPago a nuestro sistema
    const ourStatus = mapMercadoPagoStatus(paymentData.status);
    const externalReference = paymentData.external_reference;
    
    if (!externalReference) {
      logger.warn('⚠️ Pago sin referencia externa', { 
        webhookId, 
        paymentId,
        status: paymentData.status 
      });
      return { success: true }; // Ignorar pagos sin referencia
    }

    // 3. Buscar el pago en nuestra base de datos por referencia externa
    const paymentQuery = await admin.firestore()
      .collection('payments')
      .where('externalReference', '==', externalReference)
      .limit(1)
      .get();

    if (paymentQuery.empty) {
      logger.warn('⚠️ Pago no encontrado en base de datos local', {
        webhookId,
        paymentId,
        externalReference
      });
      return { success: true }; // Ignorar pagos no encontrados
    }

    const paymentDoc = paymentQuery.docs[0];
    const localPaymentData = paymentDoc.data();
    
    // 4. Verificar si el estado cambió
    if (localPaymentData.status === ourStatus) {
      logger.info('📝 Estado de pago sin cambios', {
        webhookId,
        paymentId,
        currentStatus: ourStatus
      });
      return { success: true };
    }

    // 5. Actualizar pago en base de datos
    const updateData: any = {
      status: ourStatus,
      gatewayResponse: paymentData,
      updatedAt: new Date(),
      webhookProcessedAt: new Date(),
      lastWebhookId: webhookId
    };

    // Agregar campos específicos según el estado
    switch (ourStatus) {
      case PaymentStatus.COMPLETED:
        updateData.approvedAt = new Date();
        updateData.gatewayTransactionId = paymentData.id;
        break;
      case PaymentStatus.FAILED:
        updateData.failedAt = new Date();
        updateData.failureReason = paymentData.status_detail;
        break;
      case PaymentStatus.REFUNDED:
        updateData.refundedAt = new Date();
        break;
    }

    await paymentDoc.ref.update(updateData);

    // 6. Procesar comisiones si el pago fue aprobado
    if (ourStatus === PaymentStatus.COMPLETED) {
      await processDriverCommission(
        localPaymentData.rideId,
        localPaymentData.amount,
        webhookId
      );
    }

    // 7. Enviar notificación al usuario
    await sendPaymentNotification(
      localPaymentData.userId,
      localPaymentData.rideId,
      ourStatus,
      localPaymentData.amount
    );

    // 8. Actualizar analytics en tiempo real
    await updatePaymentAnalytics(ourStatus, localPaymentData.amount);

    logger.info('✅ Pago actualizado exitosamente', {
      webhookId,
      paymentId,
      localPaymentId: paymentDoc.id,
      oldStatus: localPaymentData.status,
      newStatus: ourStatus,
      amount: localPaymentData.amount
    });

    return {
      success: true,
      paymentId: paymentDoc.id,
      status: ourStatus,
      amount: localPaymentData.amount,
      transactionId: paymentData.id,
      data: paymentData
    };

  } catch (error) {
    logger.error('❌ Error procesando webhook de pago', {
      webhookId,
      error: error.message,
      stack: error.stack
    });

    return {
      success: false,
      error: error.message
    };
  }
}

/**
 * Procesar webhook de merchant order (órdenes)
 */
async function processMerchantOrderWebhook(
  webhookData: WebhookData, 
  webhookId: string
): Promise<PaymentWebhookResult> {
  logger.info('🏪 Procesando webhook de merchant order', {
    webhookId,
    orderId: webhookData.data.id
  });

  // Por ahora solo loggear, implementar según necesidades específicas
  return { success: true };
}

/**
 * Validar firma de webhook usando HMAC-SHA256
 */
async function validateWebhookSignature(
  xSignature: string,
  xRequestId: string, 
  dataId: string,
  ts: string
): Promise<boolean> {
  try {
    const secret = process.env.MERCADOPAGO_WEBHOOK_SECRET;
    
    if (!secret) {
      logger.error('❌ MERCADOPAGO_WEBHOOK_SECRET no configurado');
      return false;
    }

    // Crear el manifiesto según especificación de MercadoPago
    const manifest = `id:${dataId};request-id:${xRequestId};ts:${ts};`;
    
    // Generar HMAC
    const hmac = crypto.createHmac('sha256', secret);
    hmac.update(manifest);
    const expectedSignature = hmac.digest('hex');
    
    // Extraer firma del header
    const receivedSignature = xSignature.split('v1=')[1];
    
    if (!receivedSignature) {
      logger.error('❌ Formato de firma inválido', { xSignature });
      return false;
    }

    // Comparación segura
    return crypto.timingSafeEqual(
      Buffer.from(expectedSignature, 'hex'),
      Buffer.from(receivedSignature, 'hex')
    );

  } catch (error) {
    logger.error('❌ Error validando firma webhook', {
      error: error.message,
      xSignature,
      dataId
    });
    return false;
  }
}

/**
 * Extraer timestamp de la firma x-signature
 */
function extractTimestamp(xSignature: string): string | null {
  try {
    const tsMatch = xSignature.match(/ts=([^,]+)/);
    return tsMatch ? tsMatch[1] : null;
  } catch {
    return null;
  }
}

/**
 * Verificar si el webhook ya fue procesado (idempotencia)
 */
async function checkIfWebhookProcessed(
  webhookId: string, 
  xRequestId: string
): Promise<boolean> {
  try {
    const webhookDoc = await admin.firestore()
      .collection('processed_webhooks')
      .doc(xRequestId)
      .get();
    
    return webhookDoc.exists;
  } catch (error) {
    logger.error('Error verificando webhook procesado', { error });
    return false; // En caso de error, procesar el webhook
  }
}

/**
 * Marcar webhook como procesado
 */
async function markWebhookAsProcessed(
  webhookId: string,
  xRequestId: string,
  webhookData: WebhookData,
  result: PaymentWebhookResult
): Promise<void> {
  try {
    await admin.firestore()
      .collection('processed_webhooks')
      .doc(xRequestId)
      .set({
        webhookId,
        xRequestId,
        type: webhookData.type,
        action: webhookData.action,
        dataId: webhookData.data.id,
        result: {
          success: result.success,
          paymentId: result.paymentId,
          status: result.status
        },
        processedAt: new Date(),
        expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000) // 7 días
      });
  } catch (error) {
    logger.error('Error marcando webhook como procesado', { 
      error, 
      webhookId, 
      xRequestId 
    });
    // No lanzar error, es logging auxiliar
  }
}

/**
 * Mapear estados de MercadoPago a nuestros estados internos
 */
function mapMercadoPagoStatus(mpStatus: string): PaymentStatus {
  switch (mpStatus) {
    case 'approved':
      return PaymentStatus.COMPLETED;
    case 'pending':
    case 'in_process':
    case 'in_mediation':
      return PaymentStatus.PROCESSING;
    case 'rejected':
    case 'cancelled':
      return PaymentStatus.FAILED;
    case 'refunded':
    case 'charged_back':
      return PaymentStatus.REFUNDED;
    default:
      logger.warn('Estado de MercadoPago desconocido', { mpStatus });
      return PaymentStatus.PENDING;
  }
}

/**
 * Procesar comisión del conductor (80% conductor, 20% plataforma)
 */
async function processDriverCommission(
  rideId: string,
  paymentAmount: number,
  webhookId: string
): Promise<void> {
  try {
    // Obtener datos del viaje
    const rideDoc = await admin.firestore()
      .collection('rides')
      .doc(rideId)
      .get();
    
    if (!rideDoc.exists) {
      logger.warn('⚠️ Viaje no encontrado para procesar comisión', { rideId, webhookId });
      return;
    }

    const rideData = rideDoc.data();
    const driverId = rideData?.driverId;
    
    if (!driverId) {
      logger.warn('⚠️ Conductor no encontrado en viaje', { rideId, webhookId });
      return;
    }

    // Calcular comisiones
    const platformCommission = paymentAmount * 0.20; // 20% plataforma
    const driverEarnings = paymentAmount * 0.80;     // 80% conductor

    // Actualizar ganancias del conductor
    const driverEarningsRef = admin.firestore()
      .collection('driver_earnings')
      .doc(driverId);

    await driverEarningsRef.set({
      totalEarnings: admin.firestore.FieldValue.increment(driverEarnings),
      totalRides: admin.firestore.FieldValue.increment(1),
      lastEarningAt: new Date(),
      updatedAt: new Date()
    }, { merge: true });

    // Crear registro detallado de ganancia
    await admin.firestore()
      .collection('earnings_transactions')
      .add({
        driverId,
        rideId,
        type: 'ride_earning',
        amount: driverEarnings,
        platformCommission,
        totalPayment: paymentAmount,
        currency: 'PEN',
        status: 'completed',
        processedAt: new Date(),
        webhookId
      });

    logger.info('💰 Comisión de conductor procesada', {
      webhookId,
      rideId,
      driverId,
      driverEarnings,
      platformCommission,
      totalPayment: paymentAmount
    });

  } catch (error) {
    logger.error('❌ Error procesando comisión del conductor', {
      error: error.message,
      rideId,
      webhookId
    });
    // No lanzar error, es procesamiento auxiliar
  }
}

/**
 * Enviar notificación al usuario sobre estado del pago
 */
async function sendPaymentNotification(
  userId: string,
  rideId: string,
  status: PaymentStatus,
  amount: number
): Promise<void> {
  try {
    // Obtener token FCM del usuario
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(userId)
      .get();
    
    const userData = userDoc.data();
    const fcmToken = userData?.fcmToken;
    
    if (!fcmToken) {
      logger.warn('⚠️ Token FCM no encontrado para usuario', { userId, rideId });
      return;
    }

    // Configurar mensaje según estado
    let title: string;
    let body: string;
    let sound: string = 'default';
    
    switch (status) {
      case PaymentStatus.COMPLETED:
        title = '✅ Pago Confirmado';
        body = `Tu pago de S/${amount.toFixed(2)} ha sido procesado exitosamente`;
        sound = 'payment_success.wav';
        break;
      case PaymentStatus.FAILED:
        title = '❌ Pago Rechazado';
        body = `Tu pago de S/${amount.toFixed(2)} no pudo ser procesado. Intenta nuevamente.`;
        sound = 'payment_failed.wav';
        break;
      case PaymentStatus.REFUNDED:
        title = '↩️ Reembolso Procesado';
        body = `Tu reembolso de S/${amount.toFixed(2)} ha sido procesado`;
        break;
      default:
        title = '🔄 Pago en Proceso';
        body = `Tu pago de S/${amount.toFixed(2)} está siendo procesado`;
    }

    // Enviar notificación push
    const message = {
      token: fcmToken,
      notification: { title, body },
      data: {
        type: 'payment_update',
        rideId,
        status,
        amount: amount.toString()
      },
      android: {
        notification: { sound },
        priority: 'high'
      },
      apns: {
        payload: {
          aps: {
            sound: sound,
            badge: 1
          }
        }
      }
    };

    await admin.messaging().send(message);
    
    logger.info('📱 Notificación de pago enviada', {
      userId,
      rideId,
      status,
      title
    });

  } catch (error) {
    logger.error('❌ Error enviando notificación de pago', {
      error: error.message,
      userId,
      rideId,
      status
    });
    // No lanzar error, es notificación auxiliar
  }
}

/**
 * Actualizar analytics de pagos en tiempo real
 */
async function updatePaymentAnalytics(
  status: PaymentStatus,
  amount: number
): Promise<void> {
  try {
    const today = new Date().toISOString().split('T')[0];
    const analyticsRef = admin.firestore()
      .collection('payment_analytics')
      .doc(today);

    const updateData: any = {
      updatedAt: new Date()
    };

    switch (status) {
      case PaymentStatus.COMPLETED:
        updateData.successfulPayments = admin.firestore.FieldValue.increment(1);
        updateData.totalRevenue = admin.firestore.FieldValue.increment(amount);
        break;
      case PaymentStatus.FAILED:
        updateData.failedPayments = admin.firestore.FieldValue.increment(1);
        break;
      case PaymentStatus.REFUNDED:
        updateData.refundedPayments = admin.firestore.FieldValue.increment(1);
        updateData.totalRefunded = admin.firestore.FieldValue.increment(amount);
        break;
    }

    await analyticsRef.set(updateData, { merge: true });

  } catch (error) {
    logger.error('❌ Error actualizando analytics', {
      error: error.message,
      status,
      amount
    });
    // No lanzar error, es analytics auxiliar
  }
}