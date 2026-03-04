import { Router, Request, Response } from 'express';
import { MercadoPagoConfig, Preference, Payment } from 'mercadopago';
import { body, validationResult } from 'express-validator';
import { logger } from '../utils/logger';
import { db } from '../config/firebase';
import { Timestamp, FieldValue } from 'firebase-admin/firestore';
import axios from 'axios';

const router = Router();

// Configuración de MercadoPago para Perú
const mercadopago = new MercadoPagoConfig({ 
  accessToken: process.env.MERCADOPAGO_ACCESS_TOKEN || 'APP_USR-8709825494258279-092911-227a4fb2d827cdb19f33ec2f4db7f983-892746351'
});

// Constantes de configuración
const PLATFORM_COMMISSION = 0.20; // 20% para la plataforma
const CURRENCY = 'PEN'; // Soles peruanos
const WEBHOOK_URL = process.env.WEBHOOK_URL || 'https://api.rapi-team.com/api/v1/payments/webhook';

// Tipos de pago disponibles
enum PaymentMethod {
  MERCADOPAGO = 'mercadopago',
  YAPE = 'yape',
  PLIN = 'plin',
  CASH = 'cash',
  CARD = 'card'
}

// Estados de pago
enum PaymentStatus {
  PENDING = 'pending',
  PROCESSING = 'processing',
  APPROVED = 'approved',
  REJECTED = 'rejected',
  REFUNDED = 'refunded',
  CANCELLED = 'cancelled'
}

// ============================================================================
// CREAR PREFERENCIA DE PAGO CON MERCADOPAGO
// ============================================================================

router.post('/create-preference', [
  body('rideId').notEmpty().withMessage('ID del viaje requerido'),
  body('amount').isNumeric().withMessage('Monto requerido'),
  body('description').optional().isString(),
  body('payerEmail').isEmail().withMessage('Email del pagador requerido'),
  body('payerName').notEmpty().withMessage('Nombre del pagador requerido')
], async (req: Request, res: Response) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ 
        success: false, 
        errors: errors.array() 
      });
    }

    const { rideId, amount, description, payerEmail, payerName } = req.body;
    
    // Calcular comisión de la plataforma
    const platformCommission = amount * PLATFORM_COMMISSION;
    const driverEarnings = amount - platformCommission;

    // Crear preferencia de pago en MercadoPago
    const preferenceClient = new Preference(mercadopago);
    
    const preferenceData = {
      items: [
        {
          id: rideId,
          title: description || `Viaje Rappi Team #${rideId}`,
          quantity: 1,
          unit_price: parseFloat(amount),
          currency_id: CURRENCY,
          description: `Tarifa del viaje: S/${amount}`,
        }
      ],
      payer: {
        name: payerName,
        email: payerEmail,
        identification: {
          type: 'DNI',
          number: '00000000' // Se actualizará con datos reales del usuario
        }
      },
      payment_methods: {
        excluded_payment_types: [],
        installments: 1,
        default_installments: 1
      },
      back_urls: {
        success: `${process.env.FRONTEND_URL}/payment/success?ride_id=${rideId}`,
        failure: `${process.env.FRONTEND_URL}/payment/failure?ride_id=${rideId}`,
        pending: `${process.env.FRONTEND_URL}/payment/pending?ride_id=${rideId}`
      },
      auto_return: 'approved',
      notification_url: `${WEBHOOK_URL}/mercadopago?source_news=ipn&ride_id=${rideId}`,
      statement_descriptor: 'RAPPI TEAM',
      binary_mode: true, // Pago instantáneo, sin estados pendientes
      expires: true,
      expiration_date_from: new Date().toISOString(),
      expiration_date_to: new Date(Date.now() + 30 * 60 * 1000).toISOString(), // 30 minutos
      metadata: {
        ride_id: rideId,
        platform_commission: platformCommission,
        driver_earnings: driverEarnings,
        integration_type: 'rappi_team_app'
      }
    };

    const preference = await preferenceClient.create({ body: preferenceData });
    
    // Guardar información de pago en Firestore
    await db.collection('payments').doc(preference.id).set({
      preferenceId: preference.id,
      rideId,
      amount,
      platformCommission,
      driverEarnings,
      status: PaymentStatus.PENDING,
      paymentMethod: PaymentMethod.MERCADOPAGO,
      payerEmail,
      payerName,
      initPoint: preference.init_point,
      sandboxInitPoint: preference.sandbox_init_point,
      createdAt: Timestamp.now(),
      expiresAt: Timestamp.fromDate(new Date(Date.now() + 30 * 60 * 1000))
    });

    // Actualizar el viaje con la preferencia de pago
    await db.collection('rides').doc(rideId).update({
      paymentPreferenceId: preference.id,
      paymentStatus: PaymentStatus.PENDING,
      paymentMethod: PaymentMethod.MERCADOPAGO
    });

    logger.info(`💳 Preferencia de pago creada: ${preference.id} para viaje ${rideId}`);

    res.json({
      success: true,
      data: {
        preferenceId: preference.id,
        initPoint: preference.init_point,
        sandboxInitPoint: preference.sandbox_init_point,
        publicKey: process.env.MERCADOPAGO_PUBLIC_KEY,
        amount,
        platformCommission,
        driverEarnings
      }
    });

  } catch (error) {
    logger.error('❌ Error creando preferencia de pago:', error);
    res.status(500).json({
      success: false,
      message: 'Error creando preferencia de pago',
      error: error.message
    });
  }
});

// ============================================================================
// PROCESAR PAGO CON YAPE
// ============================================================================

router.post('/process-yape', [
  body('rideId').notEmpty().withMessage('ID del viaje requerido'),
  body('amount').isNumeric().withMessage('Monto requerido'),
  body('phoneNumber').matches(/^9\d{8}$/).withMessage('Número de teléfono inválido'),
  body('transactionCode').optional().isString()
], async (req: Request, res: Response) => {
  try {
    const { rideId, amount, phoneNumber, transactionCode } = req.body;
    
    // Calcular comisiones
    const platformCommission = amount * PLATFORM_COMMISSION;
    const driverEarnings = amount - platformCommission;

    // Crear registro de pago Yape
    const paymentRef = db.collection('payments').doc();
    const paymentData = {
      id: paymentRef.id,
      rideId,
      amount,
      platformCommission,
      driverEarnings,
      status: PaymentStatus.PENDING,
      paymentMethod: PaymentMethod.YAPE,
      phoneNumber,
      transactionCode: transactionCode || null,
      createdAt: Timestamp.now(),
      metadata: {
        qrCode: `yape://payment?amount=${amount}&phone=946123456`, // Número de Rappi Team
        message: `Pago por viaje #${rideId}`
      }
    };

    await paymentRef.set(paymentData);

    // Actualizar el viaje
    await db.collection('rides').doc(rideId).update({
      paymentId: paymentRef.id,
      paymentStatus: PaymentStatus.PENDING,
      paymentMethod: PaymentMethod.YAPE
    });

    // Generar QR para Yape (simulado, en producción usar API real de Yape)
    const yapeQRData = {
      phoneNumber: '946123456', // Número de Rappi Team para recibir pagos
      amount,
      message: `Viaje #${rideId}`,
      qrUrl: `https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=yape://payment?amount=${amount}&phone=946123456`
    };

    logger.info(`📱 Pago Yape iniciado para viaje ${rideId}`);

    res.json({
      success: true,
      data: {
        paymentId: paymentRef.id,
        yapeData: yapeQRData,
        instructions: 'Escanea el código QR con tu app de Yape o ingresa el número 946123456 y el monto',
        amount,
        platformCommission,
        driverEarnings
      }
    });

  } catch (error) {
    logger.error('❌ Error procesando pago con Yape:', error);
    res.status(500).json({
      success: false,
      message: 'Error procesando pago con Yape',
      error: error.message
    });
  }
});

// ============================================================================
// PROCESAR PAGO CON PLIN
// ============================================================================

router.post('/process-plin', [
  body('rideId').notEmpty().withMessage('ID del viaje requerido'),
  body('amount').isNumeric().withMessage('Monto requerido'),
  body('phoneNumber').matches(/^9\d{8}$/).withMessage('Número de teléfono inválido')
], async (req: Request, res: Response) => {
  try {
    const { rideId, amount, phoneNumber } = req.body;
    
    // Calcular comisiones
    const platformCommission = amount * PLATFORM_COMMISSION;
    const driverEarnings = amount - platformCommission;

    // Crear registro de pago Plin
    const paymentRef = db.collection('payments').doc();
    const paymentData = {
      id: paymentRef.id,
      rideId,
      amount,
      platformCommission,
      driverEarnings,
      status: PaymentStatus.PENDING,
      paymentMethod: PaymentMethod.PLIN,
      phoneNumber,
      createdAt: Timestamp.now(),
      metadata: {
        qrCode: `plin://payment?amount=${amount}&phone=946123456`,
        message: `Pago por viaje #${rideId}`
      }
    };

    await paymentRef.set(paymentData);

    // Actualizar el viaje
    await db.collection('rides').doc(rideId).update({
      paymentId: paymentRef.id,
      paymentStatus: PaymentStatus.PENDING,
      paymentMethod: PaymentMethod.PLIN
    });

    // Generar QR para Plin (simulado, en producción usar API real)
    const plinQRData = {
      phoneNumber: '946123456', // Número de Rappi Team
      amount,
      message: `Viaje #${rideId}`,
      qrUrl: `https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=plin://payment?amount=${amount}&phone=946123456`
    };

    logger.info(`📱 Pago Plin iniciado para viaje ${rideId}`);

    res.json({
      success: true,
      data: {
        paymentId: paymentRef.id,
        plinData: plinQRData,
        instructions: 'Escanea el código QR con tu app Plin o ingresa el número 946123456',
        amount,
        platformCommission,
        driverEarnings
      }
    });

  } catch (error) {
    logger.error('❌ Error procesando pago con Plin:', error);
    res.status(500).json({
      success: false,
      message: 'Error procesando pago con Plin',
      error: error.message
    });
  }
});

// ============================================================================
// WEBHOOK IPN DE MERCADOPAGO
// ============================================================================

router.post('/webhook/mercadopago', async (req: Request, res: Response) => {
  try {
    const { type, data } = req.body;
    const rideId = req.query.ride_id as string;

    logger.info(`🔔 Webhook MercadoPago recibido: ${type}`, { data, rideId });

    if (type === 'payment') {
      const paymentClient = new Payment(mercadopago);
      const payment = await paymentClient.get({ id: data.id });

      // Actualizar estado del pago en Firestore
      const paymentQuery = await db.collection('payments')
        .where('rideId', '==', rideId)
        .limit(1)
        .get();

      if (!paymentQuery.empty) {
        const paymentDoc = paymentQuery.docs[0];
        const updateData: any = {
          mercadopagoPaymentId: payment.id,
          status: mapMercadoPagoStatus(payment.status),
          statusDetail: payment.status_detail,
          updatedAt: Timestamp.now()
        };

        if (payment.status === 'approved') {
          updateData.approvedAt = Timestamp.now();
          updateData.transactionDetails = {
            netAmount: payment.transaction_details?.net_received_amount,
            totalPaid: payment.transaction_details?.total_paid_amount,
            installmentAmount: payment.transaction_details?.installment_amount
          };

          // Actualizar ganancias del conductor
          const rideDoc = await db.collection('rides').doc(rideId).get();
          const rideData = rideDoc.data();
          
          if (rideData?.driverId) {
            await db.collection('drivers').doc(rideData.driverId).update({
              totalEarnings: FieldValue.increment(updateData.driverEarnings || 0),
              pendingWithdrawal: FieldValue.increment(updateData.driverEarnings || 0),
              lastPaymentAt: Timestamp.now()
            });
          }

          // Actualizar estadísticas de la plataforma
          await db.collection('statistics').doc('platform').update({
            totalRevenue: FieldValue.increment(updateData.platformCommission || 0),
            totalTransactions: FieldValue.increment(1),
            lastTransactionAt: Timestamp.now()
          });
        }

        await paymentDoc.ref.update(updateData);

        // Actualizar el viaje
        await db.collection('rides').doc(rideId).update({
          paymentStatus: updateData.status,
          paymentCompletedAt: payment.status === 'approved' ? Timestamp.now() : null
        });

        // Enviar notificación push al conductor y pasajero
        if (payment.status === 'approved') {
          await sendPaymentNotification(rideId, 'approved', payment.transaction_details?.total_paid_amount);
        }
      }
    }

    res.status(200).send('OK');

  } catch (error) {
    logger.error('❌ Error procesando webhook:', error);
    res.status(500).json({ error: 'Error procesando webhook' });
  }
});

// ============================================================================
// CONFIRMAR PAGO DE YAPE/PLIN (Manual por admin)
// ============================================================================

router.post('/confirm-payment', [
  body('paymentId').notEmpty().withMessage('ID del pago requerido'),
  body('transactionCode').notEmpty().withMessage('Código de transacción requerido'),
  body('status').isIn(['approved', 'rejected']).withMessage('Estado inválido')
], async (req: Request, res: Response) => {
  try {
    const { paymentId, transactionCode, status } = req.body;

    const paymentRef = db.collection('payments').doc(paymentId);
    const paymentDoc = await paymentRef.get();

    if (!paymentDoc.exists) {
      return res.status(404).json({
        success: false,
        message: 'Pago no encontrado'
      });
    }

    const paymentData = paymentDoc.data();

    // Actualizar estado del pago
    await paymentRef.update({
      status: status === 'approved' ? PaymentStatus.APPROVED : PaymentStatus.REJECTED,
      transactionCode,
      confirmedAt: Timestamp.now(),
      confirmedBy: req.user?.uid || 'admin'
    });

    // Si el pago fue aprobado, actualizar ganancias
    if (status === 'approved') {
      const rideDoc = await db.collection('rides').doc(paymentData.rideId).get();
      const rideData = rideDoc.data();

      if (rideData?.driverId) {
        await db.collection('drivers').doc(rideData.driverId).update({
          totalEarnings: FieldValue.increment(paymentData.driverEarnings),
          pendingWithdrawal: FieldValue.increment(paymentData.driverEarnings)
        });
      }

      await db.collection('statistics').doc('platform').update({
        totalRevenue: FieldValue.increment(paymentData.platformCommission),
        totalTransactions: FieldValue.increment(1)
      });

      // Actualizar el viaje
      await db.collection('rides').doc(paymentData.rideId).update({
        paymentStatus: PaymentStatus.APPROVED,
        paymentCompletedAt: Timestamp.now()
      });
    }

    logger.info(`✅ Pago ${paymentId} confirmado como ${status}`);

    res.json({
      success: true,
      message: `Pago ${status === 'approved' ? 'aprobado' : 'rechazado'} exitosamente`
    });

  } catch (error) {
    logger.error('❌ Error confirmando pago:', error);
    res.status(500).json({
      success: false,
      message: 'Error confirmando pago',
      error: error.message
    });
  }
});

// ============================================================================
// PROCESAR REEMBOLSO
// ============================================================================

router.post('/refund', [
  body('paymentId').notEmpty().withMessage('ID del pago requerido'),
  body('amount').optional().isNumeric(),
  body('reason').notEmpty().withMessage('Razón del reembolso requerida')
], async (req: Request, res: Response) => {
  try {
    const { paymentId, amount, reason } = req.body;

    const paymentDoc = await db.collection('payments').doc(paymentId).get();
    
    if (!paymentDoc.exists) {
      return res.status(404).json({
        success: false,
        message: 'Pago no encontrado'
      });
    }

    const payment = paymentDoc.data();
    
    if (payment.status !== PaymentStatus.APPROVED) {
      return res.status(400).json({
        success: false,
        message: 'Solo se pueden reembolsar pagos aprobados'
      });
    }

    const refundAmount = amount || payment.amount;

    // Si es MercadoPago, procesar reembolso a través de su API
    if (payment.paymentMethod === PaymentMethod.MERCADOPAGO && payment.mercadopagoPaymentId) {
      const paymentClient = new Payment(mercadopago);
      
      try {
        const refund = await paymentClient.refund({
          id: payment.mercadopagoPaymentId,
          body: { amount: refundAmount }
        });

        await paymentDoc.ref.update({
          status: PaymentStatus.REFUNDED,
          refundedAt: Timestamp.now(),
          refundAmount,
          refundReason: reason,
          refundId: refund.id
        });

        logger.info(`💸 Reembolso procesado: ${refund.id}`);

      } catch (mpError) {
        logger.error('Error procesando reembolso en MercadoPago:', mpError);
        return res.status(500).json({
          success: false,
          message: 'Error procesando reembolso en MercadoPago'
        });
      }
    } else {
      // Para Yape/Plin, marcar como pendiente de reembolso manual
      await paymentDoc.ref.update({
        status: PaymentStatus.REFUNDED,
        refundedAt: Timestamp.now(),
        refundAmount,
        refundReason: reason,
        refundPending: true,
        refundMethod: payment.paymentMethod
      });
    }

    // Actualizar estadísticas
    await db.collection('drivers').doc(payment.driverId).update({
      totalEarnings: FieldValue.increment(-payment.driverEarnings),
      pendingWithdrawal: FieldValue.increment(-payment.driverEarnings)
    });

    await db.collection('statistics').doc('platform').update({
      totalRevenue: FieldValue.increment(-payment.platformCommission),
      totalRefunds: FieldValue.increment(1),
      totalRefundAmount: FieldValue.increment(refundAmount)
    });

    // Actualizar el viaje
    await db.collection('rides').doc(payment.rideId).update({
      paymentStatus: PaymentStatus.REFUNDED,
      refundedAt: Timestamp.now()
    });

    res.json({
      success: true,
      message: 'Reembolso procesado exitosamente',
      data: {
        refundAmount,
        status: PaymentStatus.REFUNDED
      }
    });

  } catch (error) {
    logger.error('❌ Error procesando reembolso:', error);
    res.status(500).json({
      success: false,
      message: 'Error procesando reembolso',
      error: error.message
    });
  }
});

// ============================================================================
// OBTENER ESTADO DE PAGO
// ============================================================================

router.get('/status/:paymentId', async (req: Request, res: Response) => {
  try {
    const { paymentId } = req.params;

    const paymentDoc = await db.collection('payments').doc(paymentId).get();

    if (!paymentDoc.exists) {
      return res.status(404).json({
        success: false,
        message: 'Pago no encontrado'
      });
    }

    const payment = paymentDoc.data();

    res.json({
      success: true,
      data: {
        id: paymentDoc.id,
        status: payment.status,
        amount: payment.amount,
        paymentMethod: payment.paymentMethod,
        platformCommission: payment.platformCommission,
        driverEarnings: payment.driverEarnings,
        createdAt: payment.createdAt.toDate(),
        approvedAt: payment.approvedAt?.toDate() || null,
        refundedAt: payment.refundedAt?.toDate() || null
      }
    });

  } catch (error) {
    logger.error('❌ Error obteniendo estado del pago:', error);
    res.status(500).json({
      success: false,
      message: 'Error obteniendo estado del pago'
    });
  }
});

// ============================================================================
// OBTENER HISTORIAL DE PAGOS DE UN USUARIO
// ============================================================================

router.get('/history/:userId', async (req: Request, res: Response) => {
  try {
    const { userId } = req.params;
    const { role } = req.query; // 'passenger' o 'driver'

    let query;
    if (role === 'driver') {
      // Obtener viajes del conductor
      const ridesQuery = await db.collection('rides')
        .where('driverId', '==', userId)
        .where('paymentStatus', '==', PaymentStatus.APPROVED)
        .orderBy('completedAt', 'desc')
        .limit(50)
        .get();

      const rideIds = ridesQuery.docs.map(doc => doc.id);

      query = db.collection('payments')
        .where('rideId', 'in', rideIds)
        .orderBy('createdAt', 'desc');
    } else {
      // Obtener viajes del pasajero
      const ridesQuery = await db.collection('rides')
        .where('passengerId', '==', userId)
        .orderBy('createdAt', 'desc')
        .limit(50)
        .get();

      const rideIds = ridesQuery.docs.map(doc => doc.id);

      query = db.collection('payments')
        .where('rideId', 'in', rideIds)
        .orderBy('createdAt', 'desc');
    }

    const paymentsSnapshot = await query.get();

    const payments = paymentsSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      createdAt: doc.data().createdAt?.toDate(),
      approvedAt: doc.data().approvedAt?.toDate()
    }));

    res.json({
      success: true,
      data: payments
    });

  } catch (error) {
    logger.error('❌ Error obteniendo historial de pagos:', error);
    res.status(500).json({
      success: false,
      message: 'Error obteniendo historial de pagos'
    });
  }
});

// ============================================================================
// FUNCIONES AUXILIARES
// ============================================================================

function mapMercadoPagoStatus(mpStatus: string): PaymentStatus {
  const statusMap: { [key: string]: PaymentStatus } = {
    'approved': PaymentStatus.APPROVED,
    'pending': PaymentStatus.PENDING,
    'in_process': PaymentStatus.PROCESSING,
    'rejected': PaymentStatus.REJECTED,
    'refunded': PaymentStatus.REFUNDED,
    'cancelled': PaymentStatus.CANCELLED
  };

  return statusMap[mpStatus] || PaymentStatus.PENDING;
}

async function sendPaymentNotification(rideId: string, status: string, amount: number) {
  try {
    const rideDoc = await db.collection('rides').doc(rideId).get();
    const ride = rideDoc.data();

    if (!ride) return;

    const notification = {
      title: status === 'approved' ? '✅ Pago Aprobado' : '❌ Pago Rechazado',
      body: status === 'approved' 
        ? `El pago de S/${amount} ha sido aprobado exitosamente`
        : `El pago ha sido rechazado. Por favor, intenta nuevamente`,
      data: {
        type: 'payment_status',
        rideId,
        status,
        amount: amount.toString()
      }
    };

    // Enviar a pasajero y conductor
    const tokens = [];
    
    if (ride.passengerId) {
      const passengerDoc = await db.collection('users').doc(ride.passengerId).get();
      if (passengerDoc.data()?.fcmToken) {
        tokens.push(passengerDoc.data().fcmToken);
      }
    }

    if (ride.driverId) {
      const driverDoc = await db.collection('drivers').doc(ride.driverId).get();
      if (driverDoc.data()?.fcmToken) {
        tokens.push(driverDoc.data().fcmToken);
      }
    }

    // Aquí se enviarían las notificaciones push usando Firebase Cloud Messaging
    // Por ahora solo lo registramos
    logger.info('📱 Notificaciones de pago enviadas', { rideId, status, tokens });

  } catch (error) {
    logger.error('Error enviando notificaciones de pago:', error);
  }
}

export default router;