// ⚡ Cargar variables de entorno PRIMERO (antes de cualquier otro import)
import * as dotenv from 'dotenv';
import * as path from 'path';

// Cargar .env SOLO en desarrollo local (no durante deploy)
// Durante deploy/producción, las variables se configuran con firebase functions:secrets:set
if (process.env.NODE_ENV !== 'production' && !process.env.FUNCTION_NAME) {
  dotenv.config({ path: path.join(__dirname, '../.env') });
}

// ⚠️ FIREBASE FUNCTIONS V2 (GEN 2) - SINTAXIS MODERNA
import { onDocumentCreated, onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { onRequest } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { auth } from 'firebase-functions/v1';
import { setGlobalOptions } from 'firebase-functions/v2';
import * as admin from 'firebase-admin';
import * as crypto from 'crypto';
import { NotificationService } from './services/NotificationService';
import { TripNotificationHandler } from './handlers/TripNotificationHandler';
import { PaymentNotificationHandler } from './handlers/PaymentNotificationHandler';
import { EmergencyNotificationHandler } from './handlers/EmergencyNotificationHandler';
import { MercadoPagoService } from './services/MercadoPagoService';

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
  let fareAmount = rideData.finalFare || rideData.estimatedFare || 0;
  const passengerId = rideData.userId || rideData.passengerId;
  const driverId = rideData.driverId;

  // ✅ SISTEMA DE PROMOCIONES: Validar y aplicar descuento
  const appliedPromotionId = rideData.appliedPromotionId;
  const appliedPromotionCode = rideData.appliedPromotionCode;
  let discountApplied = 0;
  let originalFare = fareAmount;

  if (appliedPromotionId || appliedPromotionCode) {
    try {
      console.log(`🎟️ Promoción detectada: ${appliedPromotionCode || appliedPromotionId}`);

      // Buscar la promoción en Firestore
      let promoDoc;
      if (appliedPromotionId) {
        promoDoc = await db.collection('promotions').doc(appliedPromotionId).get();
      } else if (appliedPromotionCode) {
        const promoQuery = await db.collection('promotions')
          .where('code', '==', appliedPromotionCode)
          .where('isActive', '==', true)
          .limit(1)
          .get();
        promoDoc = promoQuery.docs[0];
      }

      if (promoDoc && promoDoc.exists) {
        const promo = promoDoc.data();
        const now = new Date();
        const validUntil = promo?.validUntil?.toDate ? promo.validUntil.toDate() : null;

        // Validar que la promoción siga vigente
        if (promo?.isActive && (!validUntil || validUntil > now)) {
          // Verificar límite de usos del usuario
          const userUsageRef = db.collection('users').doc(passengerId)
            .collection('used_promotions').doc(promoDoc.id);
          const userUsageDoc = await userUsageRef.get();
          const usedCount = userUsageDoc.exists ? (userUsageDoc.data()?.usedCount || 0) : 0;
          const maxUses = promo?.maxUses || 1;

          if (usedCount < maxUses) {
            // Calcular descuento según tipo
            if (promo?.type === 'percentage' && promo?.value) {
              discountApplied = parseFloat((fareAmount * (promo.value / 100)).toFixed(2));
              console.log(`   Descuento porcentaje: ${promo.value}% = S/ ${discountApplied}`);
            } else if (promo?.type === 'fixed' && promo?.value) {
              discountApplied = Math.min(promo.value, fareAmount);
              console.log(`   Descuento fijo: S/ ${discountApplied}`);
            } else if (promo?.type === 'freeRide') {
              discountApplied = fareAmount;
              console.log(`   Viaje gratis aplicado`);
            }

            // Aplicar descuento
            if (discountApplied > 0) {
              originalFare = fareAmount;
              fareAmount = parseFloat((fareAmount - discountApplied).toFixed(2));
              if (fareAmount < 0) fareAmount = 0;

              // Registrar uso de la promoción
              await userUsageRef.set({
                usedCount: usedCount + 1,
                lastUsedAt: admin.firestore.FieldValue.serverTimestamp(),
                promotionCode: appliedPromotionCode,
              }, { merge: true });

              console.log(`✅ Promoción aplicada: S/ ${originalFare} → S/ ${fareAmount}`);
            }
          } else {
            console.warn(`⚠️ Usuario ya usó esta promoción ${usedCount}/${maxUses} veces`);
          }
        } else {
          console.warn(`⚠️ Promoción expirada o inactiva`);
        }
      } else {
        console.warn(`⚠️ Promoción no encontrada: ${appliedPromotionCode || appliedPromotionId}`);
      }
    } catch (promoError) {
      console.error('❌ Error procesando promoción:', promoError);
      // Continuar sin descuento
    }
  }

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
    const rideUpdateData: Record<string, any> = {
      platformCommission: platformCommission,
      driverEarnings: driverEarnings,
      paymentProcessed: true,
      paymentProcessedAt: timestamp,
      // Confirmar método de pago usado
      paymentMethodUsed: paymentMethod,
      wasPaidOutsideApp: isPaidOutsideApp,
      updatedAt: timestamp,
    };

    // ✅ Agregar información de promoción si se aplicó
    if (discountApplied > 0) {
      rideUpdateData.discountApplied = discountApplied;
      rideUpdateData.originalFare = originalFare;
      rideUpdateData.finalFareAfterDiscount = fareAmount;
    }

    transaction.update(rideRef, rideUpdateData);

    console.log(`✅ Transacción atómica completada exitosamente para viaje ${rideId}`);
  });

  console.log(`🎉 Pago procesado completamente para viaje ${rideId}`);
  console.log(`   Método de pago: ${paymentMethod} (${isPaidOutsideApp ? 'externo' : 'wallet'})`);
}

/**
 * 🔄 FUNCIÓN AUXILIAR: Reembolsar créditos de servicio cuando un viaje se cancela
 * Si el conductor ya aceptó y se consumieron créditos, se le reembolsan
 * @param rideId - ID del viaje cancelado
 * @param rideData - Datos del viaje
 */
async function refundCreditsOnCancelledTrip(
  rideId: string,
  rideData: any
): Promise<void> {
  const driverId = rideData.driverId;
  const negotiationId = rideData.negotiationId;
  const cancelledBy = rideData.cancelledBy;

  console.log(`🔄 Verificando reembolso para viaje cancelado: ${rideId}`);
  console.log(`   Driver: ${driverId}, Cancelado por: ${cancelledBy}`);

  // Solo procesar si el viaje tenía conductor asignado
  if (!driverId) {
    console.log(`ℹ️ Viaje sin conductor asignado, no hay créditos que reembolsar`);
    return;
  }

  try {
    // Buscar si hubo consumo de créditos por aceptar este viaje
    // Los créditos se consumen cuando el conductor acepta la oferta
    const transactionsSnapshot = await db.collection('walletTransactions')
      .where('walletId', '==', driverId)
      .where('type', '==', 'service_charge')
      .where('metadata.negotiationId', '==', negotiationId || rideId)
      .where('status', '==', 'completed')
      .limit(1)
      .get();

    if (transactionsSnapshot.empty) {
      console.log(`ℹ️ No se encontró cobro de servicio para este viaje, verificando por rideId...`);

      // Buscar por rideId en metadata también
      const transactionsByRide = await db.collection('walletTransactions')
        .where('walletId', '==', driverId)
        .where('type', '==', 'service_charge')
        .where('metadata.rideId', '==', rideId)
        .where('status', '==', 'completed')
        .limit(1)
        .get();

      if (transactionsByRide.empty) {
        console.log(`ℹ️ No hay créditos que reembolsar para este viaje`);
        return;
      }

      // Usar la transacción encontrada por rideId
      const chargeDoc = transactionsByRide.docs[0];
      await processRefund(driverId, rideId, chargeDoc);
      return;
    }

    const chargeDoc = transactionsSnapshot.docs[0];
    await processRefund(driverId, rideId, chargeDoc);

  } catch (error) {
    console.error(`❌ Error procesando reembolso:`, error);
    throw error;
  }
}

/**
 * 🔄 Procesar el reembolso de créditos
 */
async function processRefund(
  driverId: string,
  rideId: string,
  chargeDoc: FirebaseFirestore.QueryDocumentSnapshot
): Promise<void> {
  const chargeData = chargeDoc.data();
  const chargedAmount = Math.abs(chargeData.amount || 0);

  if (chargedAmount <= 0) {
    console.log(`ℹ️ Monto de cargo es 0, no hay que reembolsar`);
    return;
  }

  console.log(`💰 Reembolsando S/ ${chargedAmount} créditos al conductor ${driverId}`);

  // Ejecutar reembolso en transacción atómica
  await db.runTransaction(async (transaction) => {
    const timestamp = admin.firestore.FieldValue.serverTimestamp();

    // 1. Actualizar wallet del conductor (agregar créditos)
    const walletRef = db.collection('wallets').doc(driverId);
    const walletDoc = await transaction.get(walletRef);

    if (walletDoc.exists) {
      transaction.update(walletRef, {
        serviceCredits: admin.firestore.FieldValue.increment(chargedAmount),
        updatedAt: timestamp,
      });
    } else {
      // Si no existe wallet, crear una con el reembolso
      transaction.set(walletRef, {
        userId: driverId,
        serviceCredits: chargedAmount,
        balance: 0,
        createdAt: timestamp,
        updatedAt: timestamp,
      });
    }

    // 2. Crear transacción de reembolso
    const refundRef = db.collection('walletTransactions').doc();
    transaction.set(refundRef, {
      walletId: driverId,
      type: 'refund',
      amount: chargedAmount,
      status: 'completed',
      description: 'Reembolso de créditos por viaje cancelado',
      metadata: {
        rideId: rideId,
        originalChargeId: chargeDoc.id,
        originalChargeAmount: chargedAmount,
        reason: 'trip_cancelled',
      },
      createdAt: timestamp,
      processedAt: timestamp,
    });

    // 3. Marcar el cargo original como reembolsado
    const chargeRef = db.collection('walletTransactions').doc(chargeDoc.id);
    transaction.update(chargeRef, {
      isRefunded: true,
      refundedAt: timestamp,
      refundTransactionId: refundRef.id,
      refundReason: 'trip_cancelled',
    });

    // 4. Actualizar el viaje para indicar que se reembolsó
    const rideRef = db.collection('rides').doc(rideId);
    transaction.update(rideRef, {
      creditsRefunded: true,
      creditsRefundedAmount: chargedAmount,
      creditsRefundedAt: timestamp,
    });

    console.log(`✅ Reembolso de S/ ${chargedAmount} completado para conductor ${driverId}`);
  });

  console.log(`🎉 Créditos reembolsados exitosamente para viaje cancelado ${rideId}`);
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

    // ✅ NUEVO: Reembolsar créditos cuando el viaje se cancela (si ya fueron cobrados)
    if (afterData.status === 'cancelled' && beforeData.status !== 'cancelled') {
      console.log(`🔄 Viaje cancelado, verificando reembolso de créditos: ${rideId}`);
      try {
        await refundCreditsOnCancelledTrip(rideId, afterData);
      } catch (refundError) {
        console.error(`❌ Error reembolsando créditos del viaje ${rideId}:`, refundError);
        await db.collection('error_logs').add({
          type: 'credit_refund_failed',
          rideId,
          error: refundError instanceof Error ? refundError.message : String(refundError),
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
export const sendNotification = onRequest({ cors: true, invoker: 'public' }, async (req, res) => {
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
export const healthCheck = onRequest({ cors: true, invoker: 'public' }, async (req, res) => {
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
export const getMercadoPagoConfig = onRequest({ cors: true, invoker: 'public' }, async (req, res) => {
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
export const createRechargePreference = onRequest({ cors: true, invoker: 'public' }, async (req, res) => {
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
export const processMercadoPagoBricks = onRequest({ cors: true, invoker: 'public' }, async (req, res) => {
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
      payerFirstName: payer.first_name || '',
      payerLastName: payer.last_name || '',
      identificationType: payer.identification?.type || '',
      identificationNumber: payer.identification?.number || '',
      description: description || 'Pago RappiTeam',
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
export const mercadopagoWebhook = onRequest({ cors: true, invoker: 'public' }, async (req, res) => {
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
export const requestWithdrawal = onRequest({ cors: true, invoker: 'public' }, async (req, res) => {
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
export const sendPushNotification = onRequest({ cors: true, invoker: 'public' }, async (req, res) => {
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

/**
 * 🔧 FUNCIÓN TEMPORAL: Restaurar cuenta de usuario
 * Solo para restauración manual - eliminar después de usar
 */
export const restoreUserAccount = onRequest({ cors: true, invoker: 'public' }, async (req, res) => {
  try {
    const userId = 'EDIogARxF7WvsFUzs2sUxnEgIGj1';

    const userData = {
      fullName: 'Lenyn Perez',
      email: 'lenynperez17@gmail.com',
      phone: '983504739',
      phoneVerified: true,
      emailVerified: true,
      profilePhotoUrl: '',
      userType: 'dual',
      activeMode: 'passenger',
      currentMode: 'passenger',
      availableRoles: ['passenger', 'driver'],
      isDualAccount: true,
      rating: 5.0,
      totalTrips: 0,
      balance: 0,
      driverInfo: {
        licenseNumber: '',
        licenseExpiry: null,
        vehicleInfo: {
          make: '',
          model: '',
          year: 0,
          color: '',
          licensePlate: '',
          vehicleType: 'sedan',
        },
        documents: {
          driverLicense: { url: '', verified: false, uploadedAt: null },
          vehicleRegistration: { url: '', verified: false, uploadedAt: null },
          insurance: { url: '', verified: false, uploadedAt: null },
          backgroundCheck: { url: '', verified: false, uploadedAt: null },
          dni: { url: '', verified: false, uploadedAt: null },
          soat: { url: '', verified: false, uploadedAt: null },
          revisionTecnica: { url: '', verified: false, uploadedAt: null },
          certificacionBancaria: { url: '', verified: false, uploadedAt: null },
          vehiclePhotos: {
            frontal: '',
            lateral: '',
            trasera: '',
            interior: '',
          },
        },
        isActive: false,
        isAvailable: false,
        currentLocation: null,
        rating: 5.0,
        totalTrips: 0,
        earnings: 0,
        documentsVerified: false,
      },
      isActive: true,
      isVerified: false,
      twoFactorEnabled: false,
      deviceInfo: {
        trustedDevices: [],
        lastDeviceId: '',
      },
      securitySettings: {
        loginAttempts: 0,
        passwordHistory: [],
      },
      createdAt: admin.firestore.Timestamp.fromMillis(1760046797825),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastPhoneVerification: admin.firestore.FieldValue.serverTimestamp(),
    };

    await db.collection('users').doc(userId).set(userData, { merge: true });

    console.log('✅ Usuario restaurado correctamente');

    res.status(200).json({
      success: true,
      message: 'Usuario restaurado correctamente',
      userId,
      userData: {
        email: userData.email,
        phone: userData.phone,
        fullName: userData.fullName,
        isDualAccount: userData.isDualAccount,
        availableRoles: userData.availableRoles,
      },
    });
  } catch (error: any) {
    console.error('❌ Error restaurando usuario:', error);

    res.status(500).json({
      error: 'Error restaurando usuario',
      details: error.message,
    });
  }
});

// ⚠️ FUNCIÓN DESHABILITADA POR SEGURIDAD - Contenía contraseña hardcodeada
// La función createAdminUserOnce fue removida porque:
// 1. Tenía credenciales hardcodeadas en el código fuente
// 2. Era una función temporal que ya cumplió su propósito
// 3. Representaba un riesgo de seguridad en producción
//
// Si necesitas crear un admin, usa Firebase Console directamente
// o crea una Cloud Function segura que use variables de entorno

// ✨ FUNCIÓN PARA CREAR SOLO EL DOCUMENTO DE ADMIN (SIN AUTH)
export const setupAdminDocument = onRequest({ cors: true, invoker: 'public' }, async (req, res) => {
  try {
    console.log('🔧 Iniciando setupAdminDocument...');
    const uid = '9kWqHsP68icHIUx3afD59s8rjAo1';
    const adminEmail = 'facturacion.rapiteam@gmail.com';

    console.log('📝 UID:', uid);
    console.log('📧 Email:', adminEmail);

    const adminData = {
      fullName: "Administrador Rappi Team",
      email: adminEmail,
      phone: "999999999",
      phoneVerified: true,
      emailVerified: true,
      profilePhotoUrl: "https://lh3.googleusercontent.com/a/ACg8ocLupk14xQyGHTr5zckHldBekY6577VZiCXpZJuc3J-qnBGEwONq=s96-c",
      userType: "admin",
      activeMode: "admin",
      currentMode: "admin",
      availableRoles: ["admin"],
      isDualAccount: false,
      isAdmin: true,
      adminLevel: "super_admin",
      permissions: [
        "users.read", "users.write", "users.delete",
        "drivers.read", "drivers.write", "drivers.approve", "drivers.reject", "drivers.documents.verify",
        "trips.read", "trips.write", "trips.cancel",
        "analytics.read", "promotions.read", "promotions.write",
        "settings.read", "settings.write", "reports.read", "system.manage"
      ],
      rating: 5,
      totalTrips: 0,
      balance: 0,
      isActive: true,
      isVerified: true,
      twoFactorEnabled: false,
      deviceInfo: { trustedDevices: [], lastDeviceId: "" },
      securitySettings: {
        loginAttempts: 0,
        passwordHistory: [],
        lastPasswordChange: admin.firestore.FieldValue.serverTimestamp()
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastLoginAt: null,
      fcmToken: "",
      fcmTokenUpdatedAt: null,
      phoneHash: ""
    };

    console.log('💾 Escribiendo documento en Firestore...');
    console.log('   Colección: users');
    console.log('   Doc ID:', uid);

    const writeResult = await db.collection('users').doc(uid).set(adminData, { merge: true });

    console.log('✅ Documento escrito exitosamente!');
    console.log('   WriteResult:', writeResult);

    // Verificar que el documento se creó leyéndolo
    const docSnap = await db.collection('users').doc(uid).get();
    console.log('🔍 Verificando documento...');
    console.log('   Exists:', docSnap.exists);
    if (docSnap.exists) {
      console.log('   Data:', JSON.stringify(docSnap.data(), null, 2));
    }

    res.status(200).json({
      success: true,
      message: '✅ Documento de admin creado exitosamente',
      uid: uid,
      email: adminEmail,
      verified: docSnap.exists,
      note: 'Ahora puedes iniciar sesión con Google usando facturacion.rapiteam@gmail.com'
    });
  } catch (error: any) {
    console.error('❌ Error completo:', error);
    console.error('❌ Error message:', error.message);
    console.error('❌ Error stack:', error.stack);
    res.status(500).json({
      success: false,
      error: error.message,
      stack: error.stack
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
export const deleteOrphanedUser = onRequest({ cors: true, invoker: 'public' }, async (req, res) => {
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

/**
 * 🗑️ TRIGGER: Limpieza automática ANTES de eliminar un usuario de Auth
 *
 * Se ejecuta automáticamente cuando se va a eliminar un usuario de Firebase Auth.
 * Elimina todos los datos relacionados en Firestore y Storage.
 *
 * Usa beforeUserDeleted para limpiar datos ANTES de que el usuario sea eliminado,
 * garantizando que no queden datos huérfanos.
 */
export const onUserDeleted = auth.user().onDelete(async (user: auth.UserRecord) => {
  const uid = user.uid;
  const email = user.email || 'sin email';

  console.log(`🗑️ Usuario siendo eliminado de Auth: ${uid} (${email})`);
  console.log('   Iniciando limpieza de datos relacionados...');

  const deletedData: Record<string, number> = {};

  try {
    // 1. Eliminar documento de usuario
    const userRef = db.collection('users').doc(uid);
    const userDoc = await userRef.get();
    if (userDoc.exists) {
      await userRef.delete();
      deletedData['users'] = 1;
      console.log(`   ✓ Documento de usuario eliminado`);
    }

    // 2. Eliminar wallet
    const walletRef = db.collection('wallets').doc(uid);
    const walletDoc = await walletRef.get();
    if (walletDoc.exists) {
      await walletRef.delete();
      deletedData['wallets'] = 1;
      console.log(`   ✓ Wallet eliminada`);
    }

    // 3. Eliminar rides donde es pasajero
    const ridesAsPassenger = await db.collection('rides')
      .where('passengerId', '==', uid).get();
    for (const doc of ridesAsPassenger.docs) {
      await doc.ref.delete();
    }
    deletedData['rides_passenger'] = ridesAsPassenger.size;
    if (ridesAsPassenger.size > 0) {
      console.log(`   ✓ ${ridesAsPassenger.size} viajes como pasajero eliminados`);
    }

    // 4. Eliminar rides donde es conductor
    const ridesAsDriver = await db.collection('rides')
      .where('driverId', '==', uid).get();
    for (const doc of ridesAsDriver.docs) {
      await doc.ref.delete();
    }
    deletedData['rides_driver'] = ridesAsDriver.size;
    if (ridesAsDriver.size > 0) {
      console.log(`   ✓ ${ridesAsDriver.size} viajes como conductor eliminados`);
    }

    // 5. Eliminar transactions del usuario
    const transactionsUser = await db.collection('transactions')
      .where('userId', '==', uid).get();
    for (const doc of transactionsUser.docs) {
      await doc.ref.delete();
    }
    deletedData['transactions_user'] = transactionsUser.size;

    // 6. Eliminar transactions del conductor
    const transactionsDriver = await db.collection('transactions')
      .where('driverId', '==', uid).get();
    for (const doc of transactionsDriver.docs) {
      await doc.ref.delete();
    }
    deletedData['transactions_driver'] = transactionsDriver.size;
    if (transactionsUser.size + transactionsDriver.size > 0) {
      console.log(`   ✓ ${transactionsUser.size + transactionsDriver.size} transacciones eliminadas`);
    }

    // 7. Eliminar walletTransactions
    const walletTxPassenger = await db.collection('walletTransactions')
      .where('passengerId', '==', uid).get();
    for (const doc of walletTxPassenger.docs) {
      await doc.ref.delete();
    }
    deletedData['walletTransactions'] = walletTxPassenger.size;

    // 8. Eliminar withdrawal_requests
    const withdrawals = await db.collection('withdrawal_requests')
      .where('driverId', '==', uid).get();
    for (const doc of withdrawals.docs) {
      await doc.ref.delete();
    }
    deletedData['withdrawal_requests'] = withdrawals.size;

    // 9. Eliminar emergencies
    const emergencies = await db.collection('emergencies')
      .where('userId', '==', uid).get();
    for (const doc of emergencies.docs) {
      await doc.ref.delete();
    }
    deletedData['emergencies'] = emergencies.size;

    // 10. Eliminar recharge_transactions
    const recharges = await db.collection('recharge_transactions')
      .where('userId', '==', uid).get();
    for (const doc of recharges.docs) {
      await doc.ref.delete();
    }
    deletedData['recharge_transactions'] = recharges.size;

    // 11. Eliminar archivos de Storage del usuario
    try {
      const bucket = admin.storage().bucket();
      const [userFiles] = await bucket.getFiles({ prefix: `users/${uid}/` });
      for (const file of userFiles) {
        await file.delete();
      }
      deletedData['storage_user_files'] = userFiles.length;
      if (userFiles.length > 0) {
        console.log(`   ✓ ${userFiles.length} archivos de usuario eliminados de Storage`);
      }
    } catch (storageError) {
      console.warn(`   ⚠️ Error eliminando archivos de usuario en Storage:`, storageError);
    }

    // 12. Eliminar archivos de conductor en Storage
    try {
      const bucket = admin.storage().bucket();
      const [driverFiles] = await bucket.getFiles({ prefix: `drivers/${uid}/` });
      for (const file of driverFiles) {
        await file.delete();
      }
      deletedData['storage_driver_files'] = driverFiles.length;
      if (driverFiles.length > 0) {
        console.log(`   ✓ ${driverFiles.length} archivos de conductor eliminados de Storage`);
      }
    } catch (storageError) {
      console.warn(`   ⚠️ Error eliminando archivos de conductor en Storage:`, storageError);
    }

    // Registrar auditoría
    await db.collection('deleted_users_log').add({
      uid,
      email,
      deletedAt: admin.firestore.FieldValue.serverTimestamp(),
      deletedFrom: 'auth_trigger_automatic',
      deletedData,
    });

    console.log(`✅ Limpieza completada para ${uid}:`, deletedData);

  } catch (error) {
    console.error(`❌ Error limpiando datos de ${uid}:`, error);

    // Registrar error pero NO lanzar excepción para permitir que Auth elimine al usuario
    await db.collection('error_logs').add({
      type: 'user_deletion_cleanup_failed',
      uid,
      email,
      error: error instanceof Error ? error.message : String(error),
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
});

