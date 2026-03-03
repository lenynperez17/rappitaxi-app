// ⚡ Cargar variables de entorno PRIMERO (antes de cualquier otro import)
// NOTA: En Firebase Gen 2, las variables de entorno se cargan automáticamente
// desde Secret Manager o desde el archivo .env durante el deploy
// NO usar dotenv.config() aquí ya que causa timeout durante el análisis del código

// ⚠️ FIREBASE FUNCTIONS V2 (GEN 2) - SINTAXIS MODERNA
import { onDocumentCreated, onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { onRequest } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { setGlobalOptions } from 'firebase-functions/v2';
import * as admin from 'firebase-admin';
import * as crypto from 'crypto';
import { NotificationService } from './services/NotificationService';
import { TripNotificationHandler } from './handlers/TripNotificationHandler';
import { PaymentNotificationHandler } from './handlers/PaymentNotificationHandler';
import { EmergencyNotificationHandler } from './handlers/EmergencyNotificationHandler';
import { MercadoPagoService } from './services/MercadoPagoService';
import { CulqiService } from './services/CulqiService';
import { IzipayService } from './services/IzipayService';

// Inicializar Firebase Admin SDK
admin.initializeApp();

const db = admin.firestore();

// ✅ CORRECCIÓN: Lazy initialization para evitar timeout durante deploy
let notificationService: NotificationService | null = null;
function getNotificationService(): NotificationService {
  if (!notificationService) {
    notificationService = new NotificationService();
  }
  return notificationService;
}

// Configurar opciones globales para todas las funciones Gen 2
setGlobalOptions({
  region: 'us-central1',
  maxInstances: 10,
  timeoutSeconds: 60,
  memory: '512MiB',
});

/**
 * 💰 FUNCIÓN AUXILIAR: Procesar pago cuando un viaje se completa
 * Lee comisión desde Firebase settings, distribuye pagos con transacción atómica
 * @param rideId - ID del viaje completado
 * @param rideData - Datos del viaje
 */
async function processCompletedTripPayment(
  rideId: string,
  rideData: any
): Promise<void> {
  console.log(`💰 Iniciando procesamiento de pago para viaje: ${rideId}`);

  // 1. Obtener configuración de comisión desde Firebase
  let commissionRate = 20.0; // Default 20%
  try {
    const settingsDoc = await db.collection('settings').doc('app_config').get();
    if (settingsDoc.exists) {
      const settings = settingsDoc.data();
      commissionRate = settings?.commission ?? 20.0;
      console.log(`📊 Comisión configurada en admin: ${commissionRate}%`);
    } else {
      console.warn('⚠️ No existe configuración de comisión, usando 20% por defecto');
    }
  } catch (error) {
    console.error('❌ Error leyendo configuración de comisión:', error);
    // Continuar con default 20%
  }

  // 2. Extraer datos del viaje
  const fareAmount = rideData.finalFare || rideData.estimatedFare || 0;
  const passengerId = rideData.userId || rideData.passengerId;
  const driverId = rideData.driverId;

  // ✅ MODELO INDRIVER: Verificar método de pago
  const paymentMethod = rideData.paymentMethod || 'cash'; // Default: efectivo
  const isPaidOutsideApp = rideData.isPaidOutsideApp !== undefined
    ? rideData.isPaidOutsideApp
    : (paymentMethod === 'cash' || paymentMethod === 'yape_external' || paymentMethod === 'plin_external');

  console.log(`💳 Método de pago: ${paymentMethod}, Pago externo: ${isPaidOutsideApp}`);

  if (!passengerId || !driverId) {
    throw new Error(`Faltan IDs críticos: passengerId=${passengerId}, driverId=${driverId}`);
  }

  if (fareAmount <= 0) {
    throw new Error(`Monto de tarifa inválido: ${fareAmount}`);
  }

  // 3. Calcular distribución
  const platformCommission = parseFloat((fareAmount * (commissionRate / 100)).toFixed(2));
  const driverEarnings = parseFloat((fareAmount - platformCommission).toFixed(2));

  console.log(`💵 Distribución de pago:`);
  console.log(`   Total: S/ ${fareAmount.toFixed(2)}`);
  console.log(`   Comisión (${commissionRate}%): S/ ${platformCommission.toFixed(2)}`);
  console.log(`   Conductor: S/ ${driverEarnings.toFixed(2)}`);

  // 4. Ejecutar transacción atómica
  await db.runTransaction(async (transaction) => {
    const timestamp = admin.firestore.FieldValue.serverTimestamp();

    // 4.1 Verificar y debitar saldo del pasajero (SOLO si pago es dentro de app)
    // ✅ MODELO INDRIVER: Si es pago externo (cash, Yape, Plin), NO debitar pasajero
    if (isPaidOutsideApp) {
      console.log(`💵 Pago externo detectado (${paymentMethod}). Pasajero NO será debitado.`);
      console.log(`   El pasajero ya pagó al conductor con ${paymentMethod}.`);
    } else {
      // Pago con wallet dentro de la app
      console.log(`💰 Pago con wallet detectado. Debitando pasajero...`);

      const passengerRef = db.collection('users').doc(passengerId);
      const passengerDoc = await transaction.get(passengerRef);

      if (!passengerDoc.exists) {
        throw new Error(`Pasajero no encontrado: ${passengerId}`);
      }

      const passengerBalance = passengerDoc.data()?.balance || 0;

      if (passengerBalance < fareAmount) {
        throw new Error(
          `Saldo insuficiente del pasajero: tiene S/ ${passengerBalance}, necesita S/ ${fareAmount}. ` +
          `El viaje no debería haberse completado sin saldo suficiente cuando el método es wallet.`
        );
      }

      // Debitar al pasajero
      transaction.update(passengerRef, {
        balance: admin.firestore.FieldValue.increment(-fareAmount),
        updatedAt: timestamp,
      });
      console.log(`✅ Debitado S/ ${fareAmount.toFixed(2)} del pasajero ${passengerId}`);
    }

    // 4.2 Acreditar al conductor (verificar/crear wallet)
    const driverWalletRef = db.collection('wallets').doc(driverId);
    const driverWalletDoc = await transaction.get(driverWalletRef);

    if (!driverWalletDoc.exists) {
      // Crear wallet si no existe
      console.log(`🆕 Creando wallet para conductor ${driverId}`);
      transaction.set(driverWalletRef, {
        userId: driverId,
        balance: driverEarnings,
        totalEarnings: driverEarnings,
        totalWithdrawals: 0,
        pendingBalance: 0,
        currency: 'PEN',
        status: 'active',
        createdAt: timestamp,
        lastActivityDate: timestamp,
      });
    } else {
      // Actualizar wallet existente
      transaction.update(driverWalletRef, {
        balance: admin.firestore.FieldValue.increment(driverEarnings),
        totalEarnings: admin.firestore.FieldValue.increment(driverEarnings),
        lastActivityDate: timestamp,
        updatedAt: timestamp,
      });
    }
    console.log(`✅ Acreditado S/ ${driverEarnings.toFixed(2)} al conductor ${driverId}`);

    // 4.3 Acreditar comisión a la plataforma (verificar/crear wallet)
    const platformWalletRef = db.collection('wallets').doc('PLATFORM_WALLET');
    const platformWalletDoc = await transaction.get(platformWalletRef);

    if (!platformWalletDoc.exists) {
      // Crear wallet de plataforma si no existe
      console.log(`🆕 Creando wallet de plataforma`);
      transaction.set(platformWalletRef, {
        userId: 'PLATFORM',
        balance: platformCommission,
        totalEarnings: platformCommission,
        totalWithdrawals: 0,
        pendingBalance: 0,
        currency: 'PEN',
        status: 'active',
        createdAt: timestamp,
        lastActivityDate: timestamp,
      });
    } else {
      // Actualizar wallet de plataforma
      transaction.update(platformWalletRef, {
        balance: admin.firestore.FieldValue.increment(platformCommission),
        totalEarnings: admin.firestore.FieldValue.increment(platformCommission),
        lastActivityDate: timestamp,
        updatedAt: timestamp,
      });
    }
    console.log(`✅ Acreditado S/ ${platformCommission.toFixed(2)} a la plataforma`);

    // 4.4 Crear transacción del pasajero (débito) - SOLO si pagó con wallet
    if (!isPaidOutsideApp) {
      const passengerTransactionRef = db.collection('transactions').doc();
      transaction.set(passengerTransactionRef, {
        userId: passengerId,
        type: 'trip_payment',
        amount: -fareAmount,
        tripId: rideId,
        driverId: driverId,
        status: 'completed',
        description: `Pago por viaje completado con ${paymentMethod}`,
        metadata: {
          paymentMethod: paymentMethod,
          isPaidOutsideApp: isPaidOutsideApp,
          commissionRate: commissionRate,
          platformCommission: platformCommission,
          driverEarnings: driverEarnings,
        },
        createdAt: timestamp,
        processedAt: timestamp,
      });
      console.log(`✅ Transacción de débito creada para pasajero ${passengerId}`);
    } else {
      console.log(`ℹ️ No se crea transacción de débito (pago externo con ${paymentMethod})`);
    }

    // 4.5 Crear transacción del conductor (crédito)
    const driverTransactionRef = db.collection('walletTransactions').doc();
    transaction.set(driverTransactionRef, {
      walletId: driverId,
      type: 'earning',
      amount: driverEarnings,
      tripId: rideId,
      passengerId: passengerId,
      status: 'completed',
      description: isPaidOutsideApp
        ? `Ganancia por viaje (pasajero pagó con ${paymentMethod})`
        : 'Ganancia por viaje completado',
      metadata: {
        paymentMethod: paymentMethod,
        isPaidOutsideApp: isPaidOutsideApp,
        grossAmount: fareAmount,
        commission: platformCommission,
        commissionRate: `${commissionRate.toFixed(2)}`,
        netEarnings: driverEarnings,
      },
      createdAt: timestamp,
      processedAt: timestamp,
    });
    console.log(`✅ Transacción de ganancia creada para conductor ${driverId}`);

    // 4.6 Actualizar el viaje con información de pago
    const rideRef = db.collection('rides').doc(rideId);
    transaction.update(rideRef, {
      platformCommission: platformCommission,
      driverEarnings: driverEarnings,
      paymentProcessed: true,
      paymentProcessedAt: timestamp,
      // Confirmar método de pago usado
      paymentMethodUsed: paymentMethod,
      wasPaidOutsideApp: isPaidOutsideApp,
      updatedAt: timestamp,
    });

    console.log(`✅ Transacción atómica completada exitosamente para viaje ${rideId}`);
  });

  console.log(`🎉 Pago procesado completamente para viaje ${rideId}`);
  console.log(`   Método de pago: ${paymentMethod} (${isPaidOutsideApp ? 'externo' : 'wallet'})`);
}

/**
 * 🚗 TRIGGER: Nuevo viaje creado
 * Auto-envía notificaciones a conductores disponibles
 * ✅ ACTUALIZADO: Usa colección 'rides' (reemplaza 'trips' obsoleto)
 */
export const onRideCreated = onDocumentCreated('rides/{rideId}', async (event) => {
  const snapshot = event.data;
  if (!snapshot) {
    console.log('No data found');
    return;
  }

  const rideId = event.params.rideId;
  const rideData = snapshot.data();

  console.log(`🚗 Nuevo viaje creado: ${rideId}`);

  try {
    const handler = new TripNotificationHandler(getNotificationService(), db);
    await handler.handleNewTrip(rideId, rideData);

    console.log(`✅ Notificaciones de nuevo viaje enviadas: ${rideId}`);
  } catch (error) {
    console.error(`❌ Error procesando nuevo viaje ${rideId}:`, error);

    // Log del error en Firestore para debugging
    await db.collection('error_logs').add({
      type: 'ride_created_notification_failed',
      rideId,
      error: error instanceof Error ? error.message : String(error),
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
});

/**
 * 🚗 TRIGGER: Estado del viaje actualizado
 * Auto-envía notificaciones según el nuevo estado
 * ✅ ACTUALIZADO: Usa colección 'rides' (reemplaza 'trips' obsoleto)
 */
export const onRideStatusUpdate = onDocumentUpdated('rides/{rideId}', async (event) => {
  const change = event.data;
  if (!change) {
    console.log('No data found');
    return;
  }

  const rideId = event.params.rideId;
  const beforeData = change.before.data();
  const afterData = change.after.data();

  // Solo procesar si el status cambió
  if (beforeData.status === afterData.status) {
    return;
  }

  console.log(`🔄 Estado del viaje ${rideId} cambió: ${beforeData.status} → ${afterData.status}`);

  try {
    // ✅ NUEVO: Procesar pago cuando el viaje se completa
    if (afterData.status === 'completed' && beforeData.status !== 'completed') {
      console.log(`💰 Procesando pago automático para viaje completado: ${rideId}`);
      try {
        await processCompletedTripPayment(rideId, afterData);
        console.log(`✅ Pago procesado exitosamente para viaje: ${rideId}`);
      } catch (paymentError) {
        console.error(`❌ Error procesando pago del viaje ${rideId}:`, paymentError);
        // Registrar error pero continuar con notificaciones
        await db.collection('error_logs').add({
          type: 'trip_payment_processing_failed',
          rideId,
          error: paymentError instanceof Error ? paymentError.message : String(paymentError),
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }

    // Continuar con notificaciones
    const handler = new TripNotificationHandler(getNotificationService(), db);
    await handler.handleTripStatusChange(rideId, beforeData.status, afterData.status, afterData);

    console.log(`✅ Notificaciones de cambio de estado enviadas: ${rideId}`);
  } catch (error) {
    console.error(`❌ Error procesando cambio de estado ${rideId}:`, error);

    await db.collection('error_logs').add({
      type: 'ride_status_notification_failed',
      rideId,
      oldStatus: beforeData.status,
      newStatus: afterData.status,
      error: error instanceof Error ? error.message : String(error),
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
});

/**
 * 💰 TRIGGER: Pago procesado
 * Auto-envía notificaciones de confirmación de pago
 */
export const onPaymentProcessed = onDocumentCreated('payments/{paymentId}', async (event) => {
  const snapshot = event.data;
  if (!snapshot) {
    console.log('No data found');
    return;
  }

  const paymentId = event.params.paymentId;
  const paymentData = snapshot.data();

  console.log(`💰 Nuevo pago procesado: ${paymentId}`);

  try {
    const handler = new PaymentNotificationHandler(getNotificationService(), db);
    await handler.handlePaymentProcessed(paymentId, paymentData);

    console.log(`✅ Notificaciones de pago enviadas: ${paymentId}`);
  } catch (error) {
    console.error(`❌ Error procesando pago ${paymentId}:`, error);

    await db.collection('error_logs').add({
      type: 'payment_notification_failed',
      paymentId,
      error: error instanceof Error ? error.message : String(error),
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
});

/**
 * 🚨 TRIGGER: Botón SOS activado
 * Auto-envía alertas de emergencia inmediatas
 */
export const onEmergencyActivated = onDocumentCreated('emergencies/{emergencyId}', async (event) => {
  const snapshot = event.data;
  if (!snapshot) {
    console.log('No data found');
    return;
  }

  const emergencyId = event.params.emergencyId;
  const emergencyData = snapshot.data();

  console.log(`🚨 EMERGENCIA ACTIVADA: ${emergencyId}`);

  try {
    const handler = new EmergencyNotificationHandler(getNotificationService(), db);
    await handler.handleEmergency(emergencyId, emergencyData);

    console.log(`✅ Alertas de emergencia enviadas: ${emergencyId}`);
  } catch (error) {
    console.error(`❌ ERROR CRÍTICO procesando emergencia ${emergencyId}:`, error);

    // Para emergencias, también enviamos log crítico
    await db.collection('critical_errors').add({
      type: 'emergency_notification_failed',
      emergencyId,
      error: error instanceof Error ? error.message : String(error),
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      severity: 'CRITICAL',
    });
  }
});

/**
 * 📤 HTTP ENDPOINT: Envío manual de notificaciones
 * Para testing y envío directo desde la app
 */
export const sendNotification = onRequest({ cors: true }, async (req, res) => {
  // Verificar método HTTP
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Método no permitido. Usar POST.' });
    return;
  }

  try {
    const { tokens, topic, notification, data } = req.body;

    if (!notification || !notification.title || !notification.body) {
      res.status(400).json({
        error: 'Notification requerida con title y body'
      });
      return;
    }

    console.log(`📤 Enviando notificación manual: ${notification.title}`);

    let result;

    if (tokens && Array.isArray(tokens)) {
      // Envío a tokens específicos
      result = await getNotificationService().sendToTokens(tokens, notification, data);
    } else if (topic) {
      // Envío a topic
      result = await getNotificationService().sendToTopic(topic, notification, data);
    } else {
      res.status(400).json({
        error: 'Debe especificar tokens o topic'
      });
      return;
    }

    // Registrar envío exitoso
    await db.collection('notification_logs').add({
      type: 'manual_send',
      notification,
      result,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      source: 'http_endpoint',
    });

    res.status(200).json({
      success: true,
      result,
      message: 'Notificación enviada exitosamente',
    });

  } catch (error) {
    console.error('❌ Error en sendNotification endpoint:', error);

    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Error interno',
    });
  }
});

/**
 * 🧹 SCHEDULED: Limpieza de tokens inválidos
 * Ejecuta diariamente a las 2:00 AM
 */
export const cleanupInvalidTokens = onSchedule(
  {
    schedule: '0 2 * * *', // Cron: 2:00 AM todos los días
    timeZone: 'America/Lima', // Hora de Perú
  },
  async (event) => {
    console.log('🧹 Iniciando limpieza de tokens inválidos...');

    try {
      const usersRef = db.collection('users');
      const snapshot = await usersRef
        .where('fcmToken', '!=', null)
        .get();

      const batch = db.batch();
      let cleanedCount = 0;

      snapshot.forEach((doc) => {
        const userData = doc.data();
        const token = userData.fcmToken;

        // Validar formato del token
        if (!token ||
            typeof token !== 'string' ||
            token.length < 100 ||
            (!token.includes(':') && !token.includes('-'))) {
          batch.update(doc.ref, { fcmToken: admin.firestore.FieldValue.delete() });
          cleanedCount++;
        }
      });

      if (cleanedCount > 0) {
        await batch.commit();
        console.log(`🧹 Limpiados ${cleanedCount} tokens inválidos`);
      } else {
        console.log('🧹 No se encontraron tokens inválidos para limpiar');
      }

      // Registrar métricas
      await db.collection('cleanup_logs').add({
        type: 'token_cleanup',
        totalProcessed: snapshot.size,
        tokensRemoved: cleanedCount,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

    } catch (error) {
      console.error('❌ Error en limpieza de tokens:', error);
    }
  }
);

/**
 * 📊 SCHEDULED: Métricas de notificaciones
 * Ejecuta cada hora para generar estadísticas
 */
export const generateNotificationMetrics = onSchedule(
  {
    schedule: '0 * * * *', // Cada hora
    timeZone: 'America/Lima',
  },
  async (event) => {
    console.log('📊 Generando métricas de notificaciones...');

    try {
      const now = new Date();
      const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000);

      // Obtener logs de la última hora
      const logsRef = db.collection('notification_logs');
      const snapshot = await logsRef
        .where('timestamp', '>=', oneHourAgo)
        .get();

      const metrics = {
        totalSent: 0,
        byType: {} as Record<string, number>,
        byChannel: {} as Record<string, number>,
        successRate: 0,
        failureCount: 0,
      };

      snapshot.forEach((doc) => {
        const logData = doc.data();
        metrics.totalSent++;

        if (logData.type) {
          metrics.byType[logData.type] = (metrics.byType[logData.type] || 0) + 1;
        }

        if (logData.channel) {
          metrics.byChannel[logData.channel] = (metrics.byChannel[logData.channel] || 0) + 1;
        }

        if (logData.success === false) {
          metrics.failureCount++;
        }
      });

      metrics.successRate = metrics.totalSent > 0
        ? ((metrics.totalSent - metrics.failureCount) / metrics.totalSent) * 100
        : 100;

      // Guardar métricas
      await db.collection('notification_metrics').add({
        ...metrics,
        periodStart: oneHourAgo,
        periodEnd: now,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`📊 Métricas generadas: ${metrics.totalSent} notificaciones, ${metrics.successRate.toFixed(2)}% éxito`);

    } catch (error) {
      console.error('❌ Error generando métricas:', error);
    }
  }
);

/**
 * ⚙️ HTTP ENDPOINT: Health check del sistema
 */
export const healthCheck = onRequest({ cors: true }, async (req, res) => {
  try {
    const health = {
      status: 'healthy',
      timestamp: new Date().toISOString(),
      services: {
        firestore: false,
        fcm: false,
      },
    };

    // Test Firestore
    try {
      await db.collection('health_check').limit(1).get();
      health.services.firestore = true;
    } catch (error) {
      console.error('Firestore health check failed:', error);
    }

    // Test FCM
    try {
      const testResult = await getNotificationService().testConnection();
      health.services.fcm = testResult;
    } catch (error) {
      console.error('FCM health check failed:', error);
    }

    const allHealthy = Object.values(health.services).every(Boolean);

    res.status(allHealthy ? 200 : 503).json({
      ...health,
      status: allHealthy ? 'healthy' : 'degraded',
    });

  } catch (error) {
    res.status(500).json({
      status: 'unhealthy',
      error: error instanceof Error ? error.message : 'Error desconocido',
      timestamp: new Date().toISOString(),
    });
  }
});

/**
 * 🔐 HTTP ENDPOINT: Obtener configuración de MercadoPago
 * ✅ SEGURIDAD: Public key almacenada en environment variables
 * ✅ Solo usuarios autenticados pueden acceder
 */
export const getMercadoPagoConfig = onRequest({ cors: true }, async (req, res) => {
  try {
    // Validar método HTTP
    if (req.method !== 'GET') {
      res.status(405).json({ error: 'Método no permitido. Usar GET.' });
      return;
    }

    // ✅ SEGURIDAD: Validar token de autenticación (opcional pero recomendado)
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      try {
        const idToken = authHeader.split('Bearer ')[1];
        await admin.auth().verifyIdToken(idToken);
        console.log('🔐 Usuario autenticado solicitando config de MercadoPago');
      } catch (error) {
        console.warn('⚠️ Token inválido, permitiendo acceso público a config');
        // Permitir acceso sin auth para no bloquear la app
      }
    }

    // Obtener public key desde environment variables
    const publicKey = process.env.MERCADOPAGO_PUBLIC_KEY;

    if (!publicKey) {
      console.error('❌ MERCADOPAGO_PUBLIC_KEY no configurada en environment variables');
      res.status(500).json({
        success: false,
        error: 'Configuración de MercadoPago no disponible. Contacta al administrador.',
      });
      return;
    }

    // Determinar si es producción o test basado en el formato de la key
    const isProduction = publicKey.startsWith('APP_USR-');

    console.log(`✅ Config de MercadoPago solicitada - Modo: ${isProduction ? 'PRODUCCIÓN' : 'TEST'}`);

    res.status(200).json({
      success: true,
      publicKey,
      environment: isProduction ? 'production' : 'test',
    });

  } catch (error) {
    console.error('❌ Error obteniendo config de MercadoPago:', error);
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Error interno',
    });
  }
});

// ============================================================================
// 💳 MERCADOPAGO - ENDPOINTS DE PAGOS Y RETIROS
// ============================================================================

// ✅ CORRECCIÓN: Lazy initialization para evitar timeout durante deploy
let mercadoPagoService: MercadoPagoService | null = null;
function getMercadoPagoService(): MercadoPagoService {
  if (!mercadoPagoService) {
    mercadoPagoService = new MercadoPagoService();
  }
  return mercadoPagoService;
}

/**
 * 💳 HTTP ENDPOINT: Crear preferencia de pago para recarga
 */
export const createRechargePreference = onRequest({ cors: true }, async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Método no permitido. Usar POST.' });
    return;
  }

  try {
    const { userId, amount, email, firstName, lastName } = req.body;

    // Validar parámetros requeridos
    if (!userId || !amount || !email || !firstName || !lastName) {
      res.status(400).json({
        success: false,
        error: 'Parámetros faltantes: userId, amount, email, firstName, lastName',
      });
      return;
    }

    console.log(`💳 Creando preferencia de recarga - Usuario: ${userId}, Monto: S/ ${amount}`);

    // Crear preferencia con MercadoPago
    const result = await getMercadoPagoService().createRechargePreference({
      userId,
      amount: parseFloat(amount),
      email,
      firstName,
      lastName,
    });

    if (result.success) {
      res.status(200).json({
        success: true,
        data: {
          preferenceId: result.preferenceId,
          initPoint: result.initPoint,
          sandboxInitPoint: result.sandboxInitPoint,
          publicKey: result.publicKey,
          transactionId: result.transactionId,
        },
      });
    } else {
      res.status(400).json({
        success: false,
        error: result.error,
      });
    }

  } catch (error: any) {
    console.error('❌ Error en createRechargePreference:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Error interno del servidor',
    });
  }
});

/**
 * 💳 HTTP ENDPOINT: Procesar pago con MercadoPago Checkout Bricks
 * Procesa un pago usando el token generado por Checkout Bricks (in-app)
 */
export const processMercadoPagoBricks = onRequest({ cors: true }, async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Método no permitido. Usar POST.' });
    return;
  }

  try {
    const {
      rideId,
      token,
      payment_method_id,
      issuer_id,
      installments,
      transaction_amount,
      payer,
      description,
    } = req.body;

    // Validar parámetros requeridos
    if (!rideId || !token || !payment_method_id || !transaction_amount || !payer?.email) {
      res.status(400).json({
        success: false,
        error: 'Parámetros faltantes: rideId, token, payment_method_id, transaction_amount, payer.email',
      });
      return;
    }

    // Obtener userId del auth token
    let userId: string | undefined;
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      try {
        const idToken = authHeader.split('Bearer ')[1];
        const decodedToken = await admin.auth().verifyIdToken(idToken);
        userId = decodedToken.uid;
      } catch (error) {
        console.error('Error verificando token de autenticación:', error);
        // Continuar sin userId, se manejará en el servicio
      }
    }

    console.log(`💳 Procesando pago Checkout Bricks - Ride: ${rideId}, Monto: S/ ${transaction_amount}, Usuario: ${userId}`);

    // Procesar pago con MercadoPago usando el token
    const result = await getMercadoPagoService().processCheckoutBricksPayment({
      rideId,
      userId, // Pasar userId obtenido del token
      token,
      paymentMethodId: payment_method_id,
      issuerId: issuer_id || '',
      installments: installments || 1,
      transactionAmount: parseFloat(transaction_amount),
      payerEmail: payer.email,
      description: description || 'Pago RapiTeam',
    });

    if (result.success) {
      res.status(200).json({
        success: true,
        paymentId: result.paymentId,
        status: result.status,
        message: 'Pago procesado exitosamente',
      });
    } else {
      res.status(400).json({
        success: false,
        error: result.error || 'Error procesando el pago',
      });
    }

  } catch (error: any) {
    console.error('❌ Error en processMercadoPagoBricks:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Error interno del servidor',
    });
  }
});

/**
 * 🔔 HTTP ENDPOINT: Webhook de MercadoPago
 */
export const mercadopagoWebhook = onRequest({ cors: true }, async (req, res) => {
  console.log('🔔 Webhook MercadoPago recibido');

  try {
    // 🔐 VALIDACIÓN DE FIRMA (Seguridad)
    const xSignature = req.headers['x-signature'] as string;
    const xRequestId = req.headers['x-request-id'] as string;

    // Obtener secret desde variables de entorno
    const webhookSecret = process.env.MERCADOPAGO_WEBHOOK_SECRET;

    if (webhookSecret && xSignature && xRequestId) {
      // Construir el string a firmar según documentación de MercadoPago
      const dataID = req.query['data.id'] || req.body?.data?.id;
      const parts = xSignature.split(',');

      let isValid = false;
      for (const part of parts) {
        const [key, value] = part.trim().split('=');
        if (key === 'v1') {
          // Crear HMAC con SHA256
          const hmac = crypto.createHmac('sha256', webhookSecret);
          const dataToSign = `id:${dataID};request-id:${xRequestId};`;
          const hash = hmac.update(dataToSign).digest('hex');

          if (hash === value) {
            isValid = true;
            console.log('✅ Firma del webhook validada correctamente');
            break;
          }
        }
      }

      if (!isValid) {
        console.warn('⚠️ Firma del webhook inválida - procesando de todas formas en desarrollo');
        // No rechazar en desarrollo - solo advertir
      }
    } else {
      console.log('ℹ️ Webhook sin firma (modo desarrollo o configuración incompleta)');
    }

    // MercadoPago envía notificaciones como query params o body
    const { type, data } = req.body || req.query;

    if (!type || !data) {
      console.log('⚠️ Webhook sin datos válidos');
      res.status(400).send('Invalid webhook data');
      return;
    }

    // Responder inmediatamente a MercadoPago (200 OK)
    res.status(200).send('OK');

    // Procesar webhook de forma asíncrona
    await getMercadoPagoService().processWebhook({ type, data });

    console.log('✅ Webhook procesado exitosamente');

  } catch (error: any) {
    console.error('❌ Error procesando webhook MercadoPago:', error);
    // Ya respondimos 200 si llegamos aquí, solo logueamos el error
  }
});

/**
 * 💸 HTTP ENDPOINT: Solicitar retiro
 */
export const requestWithdrawal = onRequest({ cors: true }, async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Método no permitido. Usar POST.' });
    return;
  }

  try {
    const {
      driverId,
      amount,
      method, // 'bank_transfer', 'yape', 'plin'
      bankAccount,
      bankName,
      phoneNumber,
      accountHolderName,
      accountHolderDocumentType,
      accountHolderDocumentNumber,
    } = req.body;

    // Validar parámetros básicos
    if (!driverId || !amount || !method || !accountHolderName || !accountHolderDocumentNumber) {
      res.status(400).json({
        success: false,
        error: 'Parámetros faltantes: driverId, amount, method, accountHolderName, accountHolderDocumentNumber',
      });
      return;
    }

    // Validar según método
    if (method === 'bank_transfer' && (!bankAccount || !bankName)) {
      res.status(400).json({
        success: false,
        error: 'Para transferencia bancaria se requiere: bankAccount y bankName',
      });
      return;
    }

    if ((method === 'yape' || method === 'plin') && !phoneNumber) {
      res.status(400).json({
        success: false,
        error: `Para ${method} se requiere: phoneNumber`,
      });
      return;
    }

    console.log(`💸 Solicitud de retiro - Driver: ${driverId}, Monto: S/ ${amount}, Método: ${method}`);

    // Crear solicitud de retiro en Firestore
    const withdrawalRef = await db.collection('withdrawal_requests').add({
      driverId,
      amount: parseFloat(amount),
      method,
      bankAccount: bankAccount || null,
      bankName: bankName || null,
      phoneNumber: phoneNumber || null,
      accountHolderName,
      accountHolderDocumentType: accountHolderDocumentType || 'DNI',
      accountHolderDocumentNumber,
      status: 'pending',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const withdrawalId = withdrawalRef.id;

    // Procesar retiro automáticamente
    const result = await getMercadoPagoService().processWithdrawal({
      withdrawalId,
      driverId,
      amount: parseFloat(amount),
      bankAccount: bankAccount || '',
      bankName: bankName || '',
      accountHolderName,
      accountHolderDocumentType: accountHolderDocumentType || 'DNI',
      accountHolderDocumentNumber,
    });

    if (result.success) {
      res.status(200).json({
        success: true,
        data: {
          withdrawalId,
          transferId: result.transferId,
          status: result.status,
          amount: result.amount,
        },
      });
    } else {
      res.status(400).json({
        success: false,
        error: result.error,
      });
    }

  } catch (error: any) {
    console.error('❌ Error en requestWithdrawal:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Error interno del servidor',
    });
  }
});

/**
 * 📊 TRIGGER: Procesar retiros pendientes automáticamente
 * Se ejecuta cuando se crea una nueva solicitud de retiro
 */
export const onWithdrawalRequested = onDocumentCreated('withdrawal_requests/{withdrawalId}', async (event) => {
  const snapshot = event.data;
  if (!snapshot) {
    console.log('No data found');
    return;
  }

  const withdrawalId = event.params.withdrawalId;
  const withdrawalData = snapshot.data();

  // Solo procesar si está pendiente
  if (withdrawalData.status !== 'pending') {
    return;
  }

  console.log(`💸 Nueva solicitud de retiro: ${withdrawalId}`);

  try {
    // Procesar retiro automáticamente
    const result = await getMercadoPagoService().processWithdrawal({
      withdrawalId,
      driverId: withdrawalData.driverId,
      amount: withdrawalData.amount,
      bankAccount: withdrawalData.bankAccount,
      bankName: withdrawalData.bankName,
      accountHolderName: withdrawalData.accountHolderName,
      accountHolderDocumentType: withdrawalData.accountHolderDocumentType || 'DNI',
      accountHolderDocumentNumber: withdrawalData.accountHolderDocumentNumber,
    });

    if (!result.success) {
      console.error(`❌ Error procesando retiro ${withdrawalId}:`, result.error);

      // Marcar como fallido
      await snapshot.ref.update({
        status: 'failed',
        errorMessage: result.error,
        failedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

  } catch (error: any) {
    console.error(`❌ Error crítico procesando retiro ${withdrawalId}:`, error);

    await snapshot.ref.update({
      status: 'failed',
      errorMessage: error.message,
      failedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
});

/**
 * 📲 CLOUD FUNCTION: Enviar notificación push (CALLABLE)
 *
 * ⚠️ SEGURIDAD: Esta función reemplaza el envío de notificaciones desde la app.
 * El service-account.json ya NO está en el cliente Flutter.
 *
 * Uso desde Flutter:
 * ```dart
 * final result = await FirebaseFunctions.instance
 *   .httpsCallable('sendPushNotification')
 *   .call({
 *     'userId': 'USER_ID',
 *     'title': 'Título',
 *     'body': 'Mensaje',
 *     'data': {'key': 'value'},
 *   });
 * ```
 */
export const sendPushNotification = onRequest({ cors: true }, async (req, res) => {
  try {
    // Validar método
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Método no permitido' });
      return;
    }

    // Obtener parámetros
    const { userId, title, body, data, imageUrl } = req.body;

    // Validar parámetros requeridos
    if (!userId || !title || !body) {
      res.status(400).json({
        error: 'Parámetros requeridos: userId, title, body'
      });
      return;
    }

    console.log(`📲 Enviando notificación a usuario: ${userId}`);

    // Obtener token FCM del usuario
    const userDoc = await db.collection('users').doc(userId).get();

    if (!userDoc.exists) {
      res.status(404).json({ error: 'Usuario no encontrado' });
      return;
    }

    const userData = userDoc.data();
    const fcmToken = userData?.fcmToken;

    if (!fcmToken) {
      res.status(400).json({ error: 'Usuario sin token FCM' });
      return;
    }

    // Construir mensaje de notificación
    const message: admin.messaging.Message = {
      token: fcmToken,
      notification: {
        title: title,
        body: body,
        imageUrl: imageUrl || undefined,
      },
      data: data || {},
      android: {
        priority: 'high',
        notification: {
          channelId: 'default',
          sound: 'default',
          priority: 'high',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    // Enviar notificación usando Firebase Admin SDK
    const response = await admin.messaging().send(message);

    console.log(`✅ Notificación enviada exitosamente: ${response}`);

    res.status(200).json({
      success: true,
      messageId: response,
    });

  } catch (error: any) {
    console.error('❌ Error enviando notificación:', error);

    res.status(500).json({
      error: 'Error enviando notificación',
      details: error.message,
    });
  }
});




// ============================================================
// ✅ CLOUD FUNCTIONS PARA VERIFICACIÓN MUTUA PASAJERO-CONDUCTOR
// ============================================================

import { onCall, HttpsError } from 'firebase-functions/v2/https';

/**
 * ✅ Generar código de verificación del conductor cuando acepta un viaje
 *
 * @param data.rideId - ID del viaje en Firestore
 * @param data.driverId - ID del conductor que acepta
 * @returns {driverVerificationCode: string} - Código de 4 dígitos generado
 */
export const generateDriverVerificationCode = onCall(async (request) => {
  // Verificar autenticación
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Usuario no autenticado');
  }

  const { rideId, driverId } = request.data;

  // Validar parámetros
  if (!rideId || !driverId) {
    throw new HttpsError('invalid-argument', 'rideId y driverId son requeridos');
  }

  try {
    // Generar código aleatorio de 4 dígitos
    const driverCode = Math.floor(1000 + Math.random() * 9000).toString();

    // Actualizar el viaje con el código del conductor
    await db.collection('rides').doc(rideId).update({
      driverVerificationCode: driverCode,
      driverId,
      status: 'accepted',
      acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`✅ Código del conductor generado para viaje ${rideId}: ${driverCode}`);

    return {
      success: true,
      driverVerificationCode: driverCode,
    };
  } catch (error) {
    console.error('❌ Error generando código del conductor:', error);
    throw new HttpsError('internal', 'Error generando código del conductor');
  }
});

/**
 * ✅ Verificar código del pasajero (lo hace el conductor)
 *
 * @param data.rideId - ID del viaje en Firestore
 * @param data.code - Código ingresado por el conductor
 * @returns {verified: boolean, message: string}
 */
export const verifyPassengerCode = onCall(async (request) => {
  // Verificar autenticación
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Usuario no autenticado');
  }

  const { rideId, code } = request.data;

  // Validar parámetros
  if (!rideId || !code) {
    throw new HttpsError('invalid-argument', 'rideId y code son requeridos');
  }

  try {
    // Obtener el viaje
    const rideDoc = await db.collection('rides').doc(rideId).get();

    if (!rideDoc.exists) {
      throw new HttpsError('not-found', 'Viaje no encontrado');
    }

    const rideData = rideDoc.data();
    const correctCode = rideData?.passengerVerificationCode;

    // Verificar código
    if (code === correctCode) {
      // Marcar que el conductor verificó al pasajero
      await db.collection('rides').doc(rideId).update({
        isPassengerVerified: true,
        passengerVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`✅ Conductor verificó correctamente al pasajero en viaje ${rideId}`);

      return {
        verified: true,
        message: 'Código del pasajero verificado correctamente',
      };
    } else {
      console.log(`❌ Código incorrecto del pasajero en viaje ${rideId}`);

      return {
        verified: false,
        message: 'Código del pasajero incorrecto',
      };
    }
  } catch (error) {
    console.error('❌ Error verificando código del pasajero:', error);
    throw new HttpsError('internal', 'Error verificando código del pasajero');
  }
});

/**
 * ✅ Verificar código del conductor (lo hace el pasajero)
 * Si ambos están verificados, inicia el viaje automáticamente
 *
 * @param data.rideId - ID del viaje en Firestore
 * @param data.code - Código ingresado por el pasajero
 * @returns {verified: boolean, message: string, rideStarted: boolean}
 */
export const verifyDriverCode = onCall(async (request) => {
  // Verificar autenticación
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Usuario no autenticado');
  }

  const { rideId, code } = request.data;

  // Validar parámetros
  if (!rideId || !code) {
    throw new HttpsError('invalid-argument', 'rideId y code son requeridos');
  }

  try {
    // Obtener el viaje
    const rideDoc = await db.collection('rides').doc(rideId).get();

    if (!rideDoc.exists) {
      throw new HttpsError('not-found', 'Viaje no encontrado');
    }

    const rideData = rideDoc.data();
    const correctCode = rideData?.driverVerificationCode;
    const isPassengerVerified = rideData?.isPassengerVerified ?? false;

    // Verificar código
    if (code === correctCode) {
      const updateData: any = {
        isDriverVerified: true,
        driverVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      // Si ambos ya están verificados, iniciar el viaje
      let rideStarted = false;
      if (isPassengerVerified) {
        updateData.verificationCompletedAt = admin.firestore.FieldValue.serverTimestamp();
        updateData.status = 'in_progress';
        updateData.startedAt = admin.firestore.FieldValue.serverTimestamp();
        updateData.isVerificationCodeUsed = true; // Compatibilidad
        rideStarted = true;
      }

      // Actualizar el viaje
      await db.collection('rides').doc(rideId).update(updateData);

      const message = rideStarted
        ? '✅ VERIFICACIÓN MUTUA COMPLETADA - Viaje iniciado'
        : '✅ Código del conductor verificado - Esperando verificación del conductor';

      console.log(`${message} para viaje ${rideId}`);

      return {
        verified: true,
        message,
        rideStarted,
      };
    } else {
      console.log(`❌ Código incorrecto del conductor en viaje ${rideId}`);

      return {
        verified: false,
        message: 'Código del conductor incorrecto',
        rideStarted: false,
      };
    }
  } catch (error) {
    console.error('❌ Error verificando código del conductor:', error);
    throw new HttpsError('internal', 'Error verificando código del conductor');
  }
});

// ============================================================
// 🗑️ CLOUD FUNCTION PARA LIMPIEZA DE COLECCIÓN OBSOLETA 'TRIPS'
// ============================================================
export { cleanupTripsCollection_callable } from './cleanupTrips';

// ============================================================
// ✅ CLOUD FUNCTION PARA LIMPIEZA DE USUARIOS Y SETUP ADMIN
// ============================================================
export { cleanupUsersAndSetupAdmin } from './cleanupUsersAndSetupAdmin';

// ============================================================
// 🗑️ LIMPIEZA: Eliminar documentos huérfanos en Firestore
// ============================================================
/**
 * 🗑️ SCHEDULED: Limpieza de documentos huérfanos
 *
 * Se ejecuta cada hora para detectar y eliminar documentos en Firestore
 * que no tienen usuario correspondiente en Firebase Auth.
 *
 * Esto mantiene sincronizados Auth y Firestore automáticamente.
 */
export const cleanupOrphanedUsers = onSchedule(
  {
    schedule: '0 * * * *', // Cada hora
    timeZone: 'America/Lima',
  },
  async () => {
    console.log('🧹 Iniciando limpieza de usuarios huérfanos...');

    try {
      const usersSnapshot = await db.collection('users').get();
      let orphanedCount = 0;
      let checkedCount = 0;

      for (const doc of usersSnapshot.docs) {
        checkedCount++;
        const uid = doc.id;

        try {
          // Intentar obtener el usuario en Auth
          await admin.auth().getUser(uid);
          // Si no lanza error, el usuario existe en Auth
        } catch (authError: any) {
          // Si el error es 'user-not-found', es un documento huérfano
          if (authError.code === 'auth/user-not-found') {
            const userData = doc.data();
            console.log(`🗑️ Documento huérfano encontrado: ${uid} (${userData.email || 'sin email'})`);

            // Eliminar documento
            await doc.ref.delete();
            orphanedCount++;

            // Eliminar wallet si existe
            const walletRef = db.collection('wallets').doc(uid);
            const walletDoc = await walletRef.get();
            if (walletDoc.exists) {
              await walletRef.delete();
              console.log(`   ↳ Wallet eliminada: ${uid}`);
            }

            // Registrar para auditoría
            await db.collection('deleted_users_log').add({
              uid,
              email: userData.email || 'sin email',
              deletedAt: admin.firestore.FieldValue.serverTimestamp(),
              deletedFrom: 'orphan_cleanup',
              reason: 'Usuario no existe en Firebase Auth',
            });
          }
        }
      }

      console.log(`🧹 Limpieza completada: ${orphanedCount} huérfanos eliminados de ${checkedCount} revisados`);

      // Registrar métricas
      await db.collection('cleanup_logs').add({
        type: 'orphaned_users_cleanup',
        totalChecked: checkedCount,
        orphanedRemoved: orphanedCount,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

    } catch (error) {
      console.error('❌ Error en limpieza de usuarios huérfanos:', error);

      await db.collection('error_logs').add({
        type: 'orphan_cleanup_failed',
        error: error instanceof Error ? error.message : String(error),
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  }
);

/**
 * 🗑️ HTTP ENDPOINT: Limpieza manual de usuario específico
 *
 * Permite eliminar un documento huérfano específico por UID.
 * Uso: POST /deleteOrphanedUser { uid: 'USER_UID' }
 */
export const deleteOrphanedUser = onRequest({ cors: true }, async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Método no permitido. Usar POST.' });
    return;
  }

  try {
    const { uid } = req.body;

    if (!uid) {
      res.status(400).json({ error: 'Se requiere uid del usuario' });
      return;
    }

    console.log(`🗑️ Solicitud de eliminación manual para: ${uid}`);

    // Verificar si el usuario existe en Auth
    let existsInAuth = false;
    try {
      await admin.auth().getUser(uid);
      existsInAuth = true;
    } catch (authError: any) {
      if (authError.code !== 'auth/user-not-found') {
        throw authError;
      }
    }

    if (existsInAuth) {
      res.status(400).json({
        error: 'El usuario existe en Firebase Auth. No es un documento huérfano.',
        suggestion: 'Elimina primero el usuario desde Firebase Auth.',
      });
      return;
    }

    // Eliminar documento de Firestore
    const userRef = db.collection('users').doc(uid);
    const userDoc = await userRef.get();

    if (!userDoc.exists) {
      res.status(404).json({ error: 'Documento no encontrado en Firestore' });
      return;
    }

    const userData = userDoc.data();
    await userRef.delete();

    // Eliminar wallet si existe
    const walletRef = db.collection('wallets').doc(uid);
    const walletDoc = await walletRef.get();
    if (walletDoc.exists) {
      await walletRef.delete();
    }

    // Registrar para auditoría
    await db.collection('deleted_users_log').add({
      uid,
      email: userData?.email || 'sin email',
      deletedAt: admin.firestore.FieldValue.serverTimestamp(),
      deletedFrom: 'manual_api',
    });

    console.log(`✅ Usuario huérfano eliminado: ${uid}`);

    res.status(200).json({
      success: true,
      message: 'Documento huérfano eliminado exitosamente',
      uid,
      email: userData?.email,
    });

  } catch (error: any) {
    console.error('❌ Error eliminando usuario huérfano:', error);
    res.status(500).json({
      error: 'Error interno',
      details: error.message,
    });
  }
});

// ============================================================================
// 💳 CULQI - ENDPOINTS DE PAGOS (PASARELA PERUANA)
// ============================================================================

// ✅ Lazy initialization para CulqiService
let culqiService: CulqiService | null = null;
function getCulqiService(): CulqiService {
  if (!culqiService) {
    culqiService = new CulqiService();
  }
  return culqiService;
}

/**
 * 🔐 HTTP ENDPOINT: Obtener configuración pública de Culqi
 * Retorna la public key para el Custom Checkout
 */
export const getCulqiConfig = onRequest({ cors: true }, async (req, res) => {
  try {
    if (req.method !== 'GET') {
      res.status(405).json({ error: 'Método no permitido. Usar GET.' });
      return;
    }

    // Validar autenticación (opcional pero recomendado)
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      try {
        const idToken = authHeader.split('Bearer ')[1];
        await admin.auth().verifyIdToken(idToken);
        console.log('🔐 Usuario autenticado solicitando config de Culqi');
      } catch (error) {
        console.warn('⚠️ Token inválido, permitiendo acceso público a config');
      }
    }

    // Obtener public key desde environment variables
    const publicKey = process.env.CULQI_PUBLIC_KEY;

    if (!publicKey) {
      console.error('❌ CULQI_PUBLIC_KEY no configurada en environment variables');
      res.status(500).json({
        success: false,
        error: 'Configuración de Culqi no disponible. Contacta al administrador.',
      });
      return;
    }

    // Determinar si es producción o test basado en el prefijo de la key
    const isProduction = publicKey.startsWith('pk_live_');

    console.log(`✅ Config de Culqi solicitada - Modo: ${isProduction ? 'PRODUCCIÓN' : 'TEST'}`);

    res.status(200).json({
      success: true,
      publicKey,
      environment: isProduction ? 'production' : 'test',
    });

  } catch (error) {
    console.error('❌ Error obteniendo config de Culqi:', error);
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Error interno',
    });
  }
});

/**
 * 💳 HTTP ENDPOINT: Crear cargo con token de Culqi
 * Procesa un pago usando el token generado por Custom Checkout
 */
export const createCulqiCharge = onRequest({ cors: true }, async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Método no permitido. Usar POST.' });
    return;
  }

  try {
    const {
      sourceId,       // Token o source ID de Culqi (tkn_, ype_, src_)
      amount,         // Monto en céntimos (1000 = S/ 10.00)
      currencyCode,   // Moneda (PEN)
      email,          // Email del pagador
      description,    // Descripción del cargo
      metadata,       // Metadata adicional
      antifraudDetails, // Detalles antifraude
    } = req.body;

    // Validar parámetros requeridos
    if (!sourceId || !amount || !email) {
      res.status(400).json({
        success: false,
        error: 'Parámetros faltantes: sourceId, amount, email',
      });
      return;
    }

    // Obtener userId del auth token
    let userId: string | undefined;
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      try {
        const idToken = authHeader.split('Bearer ')[1];
        const decodedToken = await admin.auth().verifyIdToken(idToken);
        userId = decodedToken.uid;
      } catch (error) {
        console.error('Error verificando token de autenticación:', error);
      }
    }

    console.log(`💳 Creando cargo Culqi - Monto: S/ ${(amount / 100).toFixed(2)}, Usuario: ${userId || 'anónimo'}`);

    // Crear cargo con Culqi
    const result = await getCulqiService().createCharge({
      sourceId,
      amount: parseInt(amount),
      currencyCode: currencyCode || 'PEN',
      email,
      description: description || 'Pago RapiTeam',
      metadata: {
        ...metadata,
        userId: userId || 'anonymous',
      },
      antifraudDetails,
    });

    if (result.success) {
      res.status(200).json({
        success: true,
        chargeId: result.chargeId,
        status: result.status,
        amount: result.amount,
        message: 'Cargo creado exitosamente',
      });
    } else {
      res.status(400).json({
        success: false,
        error: result.error,
        errorCode: result.errorCode,
      });
    }

  } catch (error: any) {
    console.error('❌ Error en createCulqiCharge:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Error interno del servidor',
    });
  }
});

/**
 * 💰 HTTP ENDPOINT: Procesar recarga de wallet con Culqi
 */
export const processCulqiRecharge = onRequest({ cors: true }, async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Método no permitido. Usar POST.' });
    return;
  }

  try {
    const {
      userId,
      sourceId,
      amount,
      email,
      firstName,
      lastName,
    } = req.body;

    // Validar parámetros requeridos
    if (!userId || !sourceId || !amount || !email) {
      res.status(400).json({
        success: false,
        error: 'Parámetros faltantes: userId, sourceId, amount, email',
      });
      return;
    }

    console.log(`💰 Procesando recarga Culqi - Usuario: ${userId}, Monto: S/ ${(amount / 100).toFixed(2)}`);

    // Procesar recarga con Culqi
    const result = await getCulqiService().processRecharge({
      userId,
      sourceId,
      amount: parseInt(amount),
      email,
      firstName: firstName || undefined,
      lastName: lastName || undefined,
    });

    if (result.success) {
      res.status(200).json({
        success: true,
        chargeId: result.chargeId,
        transactionId: result.transactionId,
        newBalance: result.newBalance,
        message: 'Recarga procesada exitosamente',
      });
    } else {
      res.status(400).json({
        success: false,
        error: result.error,
      });
    }

  } catch (error: any) {
    console.error('❌ Error en processCulqiRecharge:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Error interno del servidor',
    });
  }
});

/**
 * 🔔 HTTP ENDPOINT: Webhook de Culqi
 * Recibe notificaciones de eventos de Culqi
 */
export const culqiWebhook = onRequest({ cors: true }, async (req, res) => {
  console.log('🔔 Webhook Culqi recibido');

  try {
    // Responder inmediatamente a Culqi (200 OK)
    res.status(200).send('OK');

    // Procesar webhook de forma asíncrona
    const { type, data } = req.body;

    if (!type || !data) {
      console.log('⚠️ Webhook sin datos válidos');
      return;
    }

    await getCulqiService().processWebhook({ type, data });

    console.log('✅ Webhook Culqi procesado exitosamente');

  } catch (error: any) {
    console.error('❌ Error procesando webhook Culqi:', error);
  }
});

/**
 * 💸 HTTP ENDPOINT: Crear reembolso con Culqi
 */
export const createCulqiRefund = onRequest({ cors: true }, async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Método no permitido. Usar POST.' });
    return;
  }

  try {
    const {
      chargeId,
      amount,
      reason,
    } = req.body;

    // Validar parámetros requeridos
    if (!chargeId || !amount || !reason) {
      res.status(400).json({
        success: false,
        error: 'Parámetros faltantes: chargeId, amount, reason',
      });
      return;
    }

    // Verificar autenticación (requerida para reembolsos)
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      res.status(401).json({
        success: false,
        error: 'Autenticación requerida para reembolsos',
      });
      return;
    }

    try {
      const idToken = authHeader.split('Bearer ')[1];
      await admin.auth().verifyIdToken(idToken);
    } catch (error) {
      res.status(401).json({
        success: false,
        error: 'Token de autenticación inválido',
      });
      return;
    }

    console.log(`💸 Creando reembolso Culqi - Cargo: ${chargeId}, Monto: S/ ${(amount / 100).toFixed(2)}`);

    // Crear reembolso con Culqi
    const result = await getCulqiService().createRefund({
      chargeId,
      amount: parseInt(amount),
      reason,
    });

    if (result.success) {
      res.status(200).json({
        success: true,
        refundId: result.refundId,
        status: result.status,
        amount: result.amount,
        message: 'Reembolso creado exitosamente',
      });
    } else {
      res.status(400).json({
        success: false,
        error: result.error,
      });
    }

  } catch (error: any) {
    console.error('❌ Error en createCulqiRefund:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Error interno del servidor',
    });
  }
});

/**
 * 👤 HTTP ENDPOINT: Crear o actualizar cliente en Culqi
 */
export const createCulqiCustomer = onRequest({ cors: true }, async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Método no permitido. Usar POST.' });
    return;
  }

  try {
    const {
      firstName,
      lastName,
      email,
      phone,
      address,
      addressCity,
    } = req.body;

    // Validar parámetros requeridos
    if (!firstName || !lastName || !email) {
      res.status(400).json({
        success: false,
        error: 'Parámetros faltantes: firstName, lastName, email',
      });
      return;
    }

    // Obtener userId del auth token (solo para logging)
    let userId: string | undefined;
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      try {
        const idToken = authHeader.split('Bearer ')[1];
        const decodedToken = await admin.auth().verifyIdToken(idToken);
        userId = decodedToken.uid;
      } catch (error) {
        console.error('Error verificando token de autenticación:', error);
      }
    }

    console.log(`👤 Creando cliente Culqi - Email: ${email}, Usuario: ${userId || 'anónimo'}`);

    // Crear cliente con Culqi
    const result = await getCulqiService().createCustomer({
      firstName,
      lastName,
      email,
      phone: phone || undefined,
      address: address || undefined,
      addressCity: addressCity || 'Lima',
    });

    if (result.success) {
      res.status(200).json({
        success: true,
        customerId: result.customerId,
        message: 'Cliente creado exitosamente',
      });
    } else {
      res.status(400).json({
        success: false,
        error: result.error,
      });
    }

  } catch (error: any) {
    console.error('❌ Error en createCulqiCustomer:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Error interno del servidor',
    });
  }
});

/**
 * 💳 HTTP ENDPOINT: Guardar tarjeta de cliente en Culqi
 */
export const saveCulqiCard = onRequest({ cors: true }, async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Método no permitido. Usar POST.' });
    return;
  }

  try {
    const {
      customerId,
      tokenId,
    } = req.body;

    // Validar parámetros requeridos
    if (!customerId || !tokenId) {
      res.status(400).json({
        success: false,
        error: 'Parámetros faltantes: customerId, tokenId',
      });
      return;
    }

    // Verificar autenticación
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      res.status(401).json({
        success: false,
        error: 'Autenticación requerida',
      });
      return;
    }

    try {
      const idToken = authHeader.split('Bearer ')[1];
      await admin.auth().verifyIdToken(idToken);
    } catch (error) {
      res.status(401).json({
        success: false,
        error: 'Token de autenticación inválido',
      });
      return;
    }

    console.log(`💳 Guardando tarjeta Culqi - Cliente: ${customerId}`);

    // Guardar tarjeta con Culqi
    const result = await getCulqiService().saveCard({
      customerId,
      tokenId,
    });

    if (result.success) {
      res.status(200).json({
        success: true,
        cardId: result.cardId,
        cardBrand: result.cardBrand,
        cardLast4: result.cardLast4,
        message: 'Tarjeta guardada exitosamente',
      });
    } else {
      res.status(400).json({
        success: false,
        error: result.error,
      });
    }

  } catch (error: any) {
    console.error('❌ Error en saveCulqiCard:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Error interno del servidor',
    });
  }
});

/**
 * 📋 HTTP ENDPOINT: Obtener tarjetas guardadas del cliente
 */
export const getCulqiCards = onRequest({ cors: true }, async (req, res) => {
  if (req.method !== 'GET') {
    res.status(405).json({ error: 'Método no permitido. Usar GET.' });
    return;
  }

  try {
    const customerId = req.query.customerId as string;

    if (!customerId) {
      res.status(400).json({
        success: false,
        error: 'Parámetro faltante: customerId',
      });
      return;
    }

    // Verificar autenticación
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      res.status(401).json({
        success: false,
        error: 'Autenticación requerida',
      });
      return;
    }

    try {
      const idToken = authHeader.split('Bearer ')[1];
      await admin.auth().verifyIdToken(idToken);
    } catch (error) {
      res.status(401).json({
        success: false,
        error: 'Token de autenticación inválido',
      });
      return;
    }

    console.log(`📋 Obteniendo tarjetas Culqi - Cliente: ${customerId}`);

    // Obtener tarjetas con Culqi
    const result = await getCulqiService().getCustomerCards(customerId);

    if (result.success) {
      res.status(200).json({
        success: true,
        cards: result.cards,
      });
    } else {
      res.status(400).json({
        success: false,
        error: result.error,
      });
    }

  } catch (error: any) {
    console.error('❌ Error en getCulqiCards:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Error interno del servidor',
    });
  }
});

// ============================================================================
// 💳 IZIPAY - ENDPOINT PARA FORMULARIO EMBEBIDO (WEB-CORE SDK)
// ============================================================================

// Lazy initialization para IzipayService
let izipayService: IzipayService | null = null;
function getIzipayService(): IzipayService {
  if (!izipayService) {
    izipayService = new IzipayService();
  }
  return izipayService;
}

/**
 * 💳 HTTP ENDPOINT: Generar formToken de Izipay
 * Crea un token de formulario para el formulario embebido (JavaScript Krypton SDK)
 * Se usa desde la app Flutter via WebView
 */
export const createIzipayFormToken = onRequest({ cors: true }, async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Método no permitido. Usar POST.' });
    return;
  }

  try {
    const { amount, email, firstName, lastName, phone, orderId } = req.body;

    // Validar parámetros requeridos
    if (!amount || !email) {
      res.status(400).json({
        success: false,
        error: 'Parámetros faltantes: amount, email',
      });
      return;
    }

    // Generar orderId único si no se proporciona
    const finalOrderId = orderId || `RT-${Date.now()}`;

    console.log(`💳 Creando formToken Izipay - Monto: S/ ${parseFloat(amount).toFixed(2)}, Email: ${email}`);

    // Generar formToken con la API de Izipay
    const result = await getIzipayService().createFormToken({
      amount: parseFloat(amount),
      email,
      firstName: firstName || 'Cliente',
      lastName: lastName || 'RapiTeam',
      phone: phone || '999999999',
      orderId: finalOrderId,
    });

    if (result.success) {
      res.status(200).json({
        success: true,
        formToken: result.formToken,
        publicKey: result.publicKey,
        orderId: finalOrderId,
      });
    } else {
      res.status(400).json({
        success: false,
        error: result.error,
      });
    }

  } catch (error: any) {
    console.error('❌ Error en createIzipayFormToken:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Error interno del servidor',
    });
  }
});

/**
 * 💳 HTTP ENDPOINT: Página de pago embebido de Izipay (Web-Core SDK)
 * Genera el formToken (session token) y sirve el HTML con el SDK Web-Core
 * Soporta: tarjetas, Yape, QR, Plin
 * Se carga directamente en un WebView de Flutter como URL HTTPS
 *
 * Query params: amount, email, firstName, lastName, phone
 */
export const izipayPaymentPage = onRequest({ cors: true }, async (req, res) => {
  try {
    const { amount, email, firstName, lastName, phone } = req.query;

    // Validar parámetros requeridos
    if (!amount || !email) {
      res.status(400).send('Parámetros faltantes: amount y email son requeridos');
      return;
    }

    const orderId = `RT-${Date.now()}`;
    const amountNum = parseFloat(amount as string);
    const firstNameStr = (firstName as string) || 'Cliente';
    const lastNameStr = (lastName as string) || 'RapiTeam';
    const phoneStr = (phone as string) || '999999999';
    const emailStr = email as string;

    console.log(`💳 Izipay Web-Core: Generando página de pago - S/ ${amountNum.toFixed(2)}, email=${emailStr}`);

    // Generar formToken (se usa como authorization/session token en Web-Core)
    const result = await getIzipayService().createFormToken({
      amount: amountNum,
      email: emailStr,
      firstName: firstNameStr,
      lastName: lastNameStr,
      phone: phoneStr,
      orderId,
    });

    if (!result.success || !result.formToken) {
      res.status(500).send(`
        <html><body style="font-family:sans-serif;padding:20px;text-align:center">
          <h3 style="color:#D32F2F">Error al iniciar el pago</h3>
          <p>${result.error || 'No se pudo conectar con Izipay'}</p>
        </body></html>
      `);
      return;
    }

    const shopId = getIzipayService().getShopId();
    const keyRSA = getIzipayService().getKeyRSA();
    const isProd = getIzipayService().getIsProduction();

    // URL del SDK Web-Core según entorno
    const sdkUrl = isProd
      ? 'https://checkout.izipay.pe/payments/v1/js/index.js'
      : 'https://sandbox-checkout.izipay.pe/payments/v1/js/index.js';

    // Fecha/hora actual para el config
    const now = new Date();
    const dateTimeTransaction = now.getFullYear().toString() +
      (now.getMonth() + 1).toString().padStart(2, '0') +
      now.getDate().toString().padStart(2, '0') +
      now.getHours().toString().padStart(2, '0') +
      now.getMinutes().toString().padStart(2, '0') +
      now.getSeconds().toString().padStart(2, '0');

    // Generar transactionId único
    const transactionId = `txn_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;

    // Escapar valores para inyección segura en HTML/JS
    const safeFirstName = firstNameStr.replace(/'/g, "\\'").replace(/</g, '&lt;');
    const safeLastName = lastNameStr.replace(/'/g, "\\'").replace(/</g, '&lt;');
    const safeEmail = emailStr.replace(/'/g, "\\'").replace(/</g, '&lt;');
    const safePhone = phoneStr.replace(/'/g, "\\'").replace(/</g, '&lt;');

    // Servir HTML con el SDK Web-Core (soporta tarjetas, Yape, QR, Plin)
    res.status(200).send(`<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>Pago Seguro - RapiTeam</title>
    <script src="${sdkUrl}" defer></script>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #F5F5F5;
            min-height: 100vh;
        }
        .payment-header {
            background: linear-gradient(135deg, #6C63FF, #5A52D5);
            color: white;
            padding: 20px 16px;
            text-align: center;
        }
        .payment-header h2 {
            font-size: 14px;
            font-weight: 400;
            opacity: 0.9;
            margin-bottom: 4px;
        }
        .payment-amount {
            font-size: 32px;
            font-weight: 700;
        }
        .payment-container {
            padding: 0;
            min-height: 400px;
        }
        #iframe-payment {
            width: 100%;
            min-height: 500px;
        }
        #loading-container {
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            padding: 60px 20px;
            text-align: center;
        }
        .spinner {
            width: 40px;
            height: 40px;
            border: 3px solid #E0E0E0;
            border-top: 3px solid #6C63FF;
            border-radius: 50%;
            animation: spin 1s linear infinite;
        }
        @keyframes spin { to { transform: rotate(360deg); } }
        .loading-text {
            margin-top: 16px;
            color: #666;
            font-size: 14px;
        }
        .loading-sub {
            margin-top: 4px;
            color: #999;
            font-size: 12px;
        }
        .secure-badge {
            text-align: center;
            padding: 16px;
            color: #999;
            font-size: 11px;
        }
        .error-container {
            text-align: center;
            padding: 40px 20px;
        }
        .error-container h3 {
            color: #D32F2F;
            margin-bottom: 8px;
        }
        .error-container p {
            color: #666;
            font-size: 14px;
        }
    </style>
</head>
<body>
    <div class="payment-header">
        <h2>Monto a pagar</h2>
        <div class="payment-amount">S/ ${amountNum.toFixed(2)}</div>
    </div>

    <div class="payment-container">
        <div id="loading-container">
            <div class="spinner"></div>
            <div class="loading-text">Cargando m&#233;todos de pago...</div>
            <div class="loading-sub">Tarjetas, Yape, QR y m&#225;s</div>
        </div>
        <div id="iframe-payment"></div>
    </div>

    <div class="secure-badge">
        &#128274; Pago seguro procesado por Izipay
    </div>

    <script>
        // Configuraci&#243;n del SDK Web-Core de Izipay
        var iziConfig = {
            transactionId: '${transactionId}',
            action: 'pay',
            merchantCode: '${shopId}',
            order: {
                orderNumber: '${orderId}',
                currency: 'PEN',
                amount: '${amountNum.toFixed(2)}',
                processType: 'AT',
                merchantBuyerId: '${safeEmail}',
                dateTimeTransaction: '${dateTimeTransaction}'
            },
            billing: {
                firstName: '${safeFirstName}',
                lastName: '${safeLastName}',
                email: '${safeEmail}',
                phoneNumber: '${safePhone}',
                street: 'Lima',
                city: 'Lima',
                state: 'Lima',
                country: 'PE',
                postalCode: '15001',
                documentType: 'DNI',
                document: '00000000'
            },
            shipping: {
                firstName: '${safeFirstName}',
                lastName: '${safeLastName}',
                email: '${safeEmail}',
                phoneNumber: '${safePhone}',
                street: 'Lima',
                city: 'Lima',
                state: 'Lima',
                country: 'PE',
                postalCode: '15001',
                documentType: 'DNI',
                document: '00000000'
            },
            render: {
                typeForm: 'embedded',
                container: '#iframe-payment',
                showButtonProcessForm: true
            }
        };

        // Inicializar y cargar el formulario cuando el SDK est&#233; listo
        document.addEventListener('DOMContentLoaded', function() {
            // Esperar a que el script del SDK se cargue
            var checkSdk = setInterval(function() {
                if (typeof Izipay !== 'undefined') {
                    clearInterval(checkSdk);
                    initPayment();
                }
            }, 200);

            // Timeout de 15 segundos
            setTimeout(function() {
                clearInterval(checkSdk);
                if (typeof Izipay === 'undefined') {
                    showError('No se pudo cargar el SDK de pago. Verifica tu conexi&#243;n.');
                }
            }, 15000);
        });

        function initPayment() {
            try {
                var checkout = new Izipay({ config: iziConfig });

                // Ocultar loading
                var loadingEl = document.getElementById('loading-container');
                if (loadingEl) loadingEl.style.display = 'none';

                // Notificar a Flutter que el formulario est&#225; listo
                notifyFlutter({ type: 'FORM_READY', orderId: '${orderId}' });

                checkout.LoadForm({
                    authorization: '${result.formToken}',
                    keyRSA: '${keyRSA}',
                    callbackResponse: function(response) {
                        console.log('Izipay respuesta:', JSON.stringify(response));

                        if (response && response.code === '00') {
                            // Pago exitoso
                            notifyFlutter({
                                type: 'PAYMENT_SUCCESS',
                                orderId: '${orderId}',
                                code: response.code,
                                message: response.message || '',
                                messageUser: response.messageUser || '',
                                payMethod: response.response ? response.response.payMethod : '',
                                transactionId: response.transactionId || '',
                                signature: response.signature || '',
                                response: response.response || {}
                            });
                        } else {
                            // Pago fallido o cancelado
                            notifyFlutter({
                                type: 'PAYMENT_ERROR',
                                orderId: '${orderId}',
                                code: response ? response.code : 'UNKNOWN',
                                message: response ? (response.message || 'Error desconocido') : 'Sin respuesta',
                                messageUser: response ? (response.messageUser || '') : ''
                            });
                        }
                    }
                });
            } catch (error) {
                console.error('Error inicializando Izipay:', error);
                showError(error.message || 'Error al inicializar el formulario de pago');
                notifyFlutter({
                    type: 'PAYMENT_ERROR',
                    orderId: '${orderId}',
                    code: 'INIT_ERROR',
                    message: error.message || 'Error de inicializaci&#243;n'
                });
            }
        }

        function notifyFlutter(data) {
            if (window.PaymentChannel) {
                PaymentChannel.postMessage(JSON.stringify(data));
            }
        }

        function showError(msg) {
            var loadingEl = document.getElementById('loading-container');
            if (loadingEl) {
                // Usar textContent para seguridad contra XSS
                loadingEl.textContent = '';
                var errorDiv = document.createElement('div');
                errorDiv.className = 'error-container';
                var h3 = document.createElement('h3');
                h3.textContent = 'Error';
                var p = document.createElement('p');
                p.textContent = msg;
                errorDiv.appendChild(h3);
                errorDiv.appendChild(p);
                loadingEl.appendChild(errorDiv);
            }
        }
    </script>
</body>
</html>`);

  } catch (error: any) {
    console.error('❌ Error en izipayPaymentPage:', error);
    res.status(500).send(`
      <html><body style="font-family:sans-serif;padding:20px;text-align:center">
        <h3 style="color:#D32F2F">Error interno</h3>
        <p>${error.message || 'Error desconocido'}</p>
      </body></html>
    `);
  }
});
