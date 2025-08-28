import { Request, Response } from 'express';
import * as admin from 'firebase-admin';

// =========================================
// GESTIÓN DE MÉTODOS DE PAGO
// =========================================

export const getPaymentMethods = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;

    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }});
      return;
    }

    // Simulación de métodos de pago disponibles
    const paymentMethods = [
      {
        id: 'cash',
        type: 'cash',
        name: 'Efectivo',
        description: 'Pago en efectivo al conductor',
        icon: 'cash_icon',
        isActive: true,
        processingFee: 0
      },
      {
        id: 'mercadopago',
        type: 'digital_wallet',
        name: 'MercadoPago',
        description: 'Pago digital con MercadoPago',
        icon: 'mercadopago_icon',
        isActive: true,
        processingFee: 0.035 // 3.5%
      },
      {
        id: 'visa',
        type: 'credit_card',
        name: 'Tarjeta Visa',
        description: 'Tarjeta de crédito/débito Visa',
        icon: 'visa_icon',
        isActive: true,
        processingFee: 0.035 // 3.5%
      },
      {
        id: 'mastercard',
        type: 'credit_card', 
        name: 'Tarjeta Mastercard',
        description: 'Tarjeta de crédito/débito Mastercard',
        icon: 'mastercard_icon',
        isActive: true,
        processingFee: 0.035 // 3.5%
      },
      {
        id: 'yape',
        type: 'mobile_payment',
        name: 'Yape',
        description: 'Billetera móvil Yape',
        icon: 'yape_icon',
        isActive: true,
        processingFee: 0.015 // 1.5%
      },
      {
        id: 'plin',
        type: 'mobile_payment',
        name: 'Plin',
        description: 'Billetera móvil Plin',
        icon: 'plin_icon',
        isActive: true,
        processingFee: 0.015 // 1.5%
      }
    ];

    res.status(200).json({
      success: true,
      data: paymentMethods,
      message: 'Métodos de pago obtenidos exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

export const addCard = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    const { cardNumber, expiryDate, cvv, cardholderName, cardType } = req.body;

    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }});
      return;
    }

    if (!cardNumber || !expiryDate || !cvv || !cardholderName) {
      res.status(400).json({ 
        success: false, 
        error: { code: 'INVALID_INPUT', message: 'Todos los datos de la tarjeta son requeridos' }
      });
      return;
    }

    // En producción, esto se procesaría con MercadoPago/Stripe de forma segura
    const cardId = `card_${Date.now()}`;
    const maskedCardNumber = cardNumber.slice(-4).padStart(cardNumber.length, '*');
    
    const cardData = {
      id: cardId,
      userId,
      cardNumber: maskedCardNumber, // Solo guardar últimos 4 dígitos
      cardType: cardType || 'credit',
      cardholderName,
      expiryDate,
      isDefault: false,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    };

    await admin.firestore().collection('payment_methods').doc(cardId).set(cardData);

    res.status(201).json({
      success: true,
      data: cardData,
      message: 'Tarjeta agregada exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

export const removePaymentMethod = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    const { paymentMethodId } = req.params;

    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }});
      return;
    }

    const paymentDoc = await admin.firestore().collection('payment_methods').doc(paymentMethodId).get();
    
    if (!paymentDoc.exists || paymentDoc.data()?.userId !== userId) {
      res.status(404).json({ success: false, error: { code: 'PAYMENT_METHOD_NOT_FOUND', message: 'Método de pago no encontrado' }});
      return;
    }

    await admin.firestore().collection('payment_methods').doc(paymentMethodId).update({
      isActive: false,
      deletedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    res.status(200).json({
      success: true,
      message: 'Método de pago eliminado exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

export const setDefaultPaymentMethod = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    const { paymentMethodId } = req.params;

    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }});
      return;
    }

    // Verificar que el método de pago existe y pertenece al usuario
    const paymentDoc = await admin.firestore().collection('payment_methods').doc(paymentMethodId).get();
    
    if (!paymentDoc.exists || paymentDoc.data()?.userId !== userId) {
      res.status(404).json({ success: false, error: { code: 'PAYMENT_METHOD_NOT_FOUND', message: 'Método de pago no encontrado' }});
      return;
    }

    // Usar batch para actualizar todos los métodos de pago del usuario
    const batch = admin.firestore().batch();
    
    // Remover default de todos los métodos del usuario
    const userPaymentMethods = await admin.firestore().collection('payment_methods')
      .where('userId', '==', userId)
      .where('isActive', '==', true)
      .get();

    userPaymentMethods.docs.forEach(doc => {
      batch.update(doc.ref, { isDefault: false });
    });

    // Establecer el nuevo método como default
    batch.update(admin.firestore().collection('payment_methods').doc(paymentMethodId), { 
      isDefault: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    await batch.commit();

    res.status(200).json({
      success: true,
      message: 'Método de pago predeterminado actualizado exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

// =========================================
// BILLETERA DIGITAL
// =========================================

export const getWalletBalance = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;

    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }});
      return;
    }

    // Simular saldo de billetera
    const walletBalance = {
      userId,
      balance: Math.floor(Math.random() * 500) + 50, // Saldo aleatorio entre 50-550 soles
      currency: 'PEN',
      lastUpdated: new Date(),
      pendingTransactions: 0,
      availableBalance: Math.floor(Math.random() * 500) + 50,
      monthlySpending: Math.floor(Math.random() * 1000) + 200,
      rewardsPoints: Math.floor(Math.random() * 1000)
    };

    res.status(200).json({
      success: true,
      data: walletBalance,
      message: 'Saldo de billetera obtenido exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

export const topUpWallet = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    const { amount, paymentMethodId } = req.body;

    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }});
      return;
    }

    if (!amount || amount <= 0) {
      res.status(400).json({ success: false, error: { code: 'INVALID_AMOUNT', message: 'Monto inválido' }});
      return;
    }

    if (amount < 10) {
      res.status(400).json({ success: false, error: { code: 'MINIMUM_AMOUNT', message: 'Monto mínimo S/ 10' }});
      return;
    }

    if (amount > 2000) {
      res.status(400).json({ success: false, error: { code: 'MAXIMUM_AMOUNT', message: 'Monto máximo S/ 2000' }});
      return;
    }

    const transactionId = `topup_${Date.now()}`;
    const topUpData = {
      id: transactionId,
      userId,
      type: 'top_up',
      amount,
      paymentMethodId,
      status: 'pending',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      completedAt: null
    };

    // Guardar transacción
    await admin.firestore().collection('wallet_transactions').doc(transactionId).set(topUpData);

    // Simular procesamiento exitoso después de 2 segundos
    setTimeout(async () => {
      try {
        await admin.firestore().collection('wallet_transactions').doc(transactionId).update({
          status: 'completed',
          completedAt: admin.firestore.FieldValue.serverTimestamp()
        });
      } catch (error) {
        console.error('Error updating top-up transaction:', error);
      }
    }, 2000);

    res.status(200).json({
      success: true,
      data: {
        transactionId,
        amount,
        status: 'processing',
        estimatedCompletionTime: '2-3 minutos'
      },
      message: 'Recarga iniciada exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

export const getWalletTransactions = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    const { page = 1, limit = 20, type } = req.query;

    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }});
      return;
    }

    // Simulación de transacciones de billetera
    const mockTransactions = [
      {
        id: 'tx_001',
        type: 'ride_payment',
        amount: -25.50,
        description: 'Pago viaje #ride_123',
        status: 'completed',
        createdAt: new Date(Date.now() - 2 * 60 * 60 * 1000), // Hace 2 horas
        rideId: 'ride_123'
      },
      {
        id: 'tx_002',
        type: 'top_up',
        amount: 100.00,
        description: 'Recarga billetera',
        status: 'completed',
        createdAt: new Date(Date.now() - 1 * 24 * 60 * 60 * 1000), // Hace 1 día
        paymentMethodId: 'visa_card'
      },
      {
        id: 'tx_003',
        type: 'refund',
        amount: 15.75,
        description: 'Reembolso viaje cancelado #ride_099',
        status: 'completed',
        createdAt: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000), // Hace 2 días
        rideId: 'ride_099'
      },
      {
        id: 'tx_004',
        type: 'reward',
        amount: 5.00,
        description: 'Bono por referir amigo',
        status: 'completed',
        createdAt: new Date(Date.now() - 3 * 24 * 60 * 60 * 1000), // Hace 3 días
        referralId: 'ref_001'
      },
      {
        id: 'tx_005',
        type: 'ride_payment',
        amount: -32.25,
        description: 'Pago viaje #ride_088',
        status: 'completed',
        createdAt: new Date(Date.now() - 4 * 24 * 60 * 60 * 1000), // Hace 4 días
        rideId: 'ride_088'
      }
    ];

    const filteredTransactions = type 
      ? mockTransactions.filter(tx => tx.type === type)
      : mockTransactions;

    const startIndex = (Number(page) - 1) * Number(limit);
    const paginatedTransactions = filteredTransactions.slice(startIndex, startIndex + Number(limit));

    res.status(200).json({
      success: true,
      data: {
        transactions: paginatedTransactions,
        pagination: {
          page: Number(page),
          limit: Number(limit),
          total: filteredTransactions.length,
          hasNext: startIndex + Number(limit) < filteredTransactions.length
        },
        summary: {
          totalIncome: mockTransactions.filter(tx => tx.amount > 0).reduce((sum, tx) => sum + tx.amount, 0),
          totalExpenses: Math.abs(mockTransactions.filter(tx => tx.amount < 0).reduce((sum, tx) => sum + tx.amount, 0)),
          transactionCount: mockTransactions.length
        }
      },
      message: 'Transacciones de billetera obtenidas exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

export const transferBalance = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    const { recipientId, amount, message, pin } = req.body;

    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }});
      return;
    }

    if (!recipientId || !amount || amount <= 0) {
      res.status(400).json({ 
        success: false, 
        error: { code: 'INVALID_INPUT', message: 'Destinatario y monto son requeridos' }
      });
      return;
    }

    if (amount < 5) {
      res.status(400).json({ success: false, error: { code: 'MINIMUM_AMOUNT', message: 'Monto mínimo S/ 5' }});
      return;
    }

    if (amount > 500) {
      res.status(400).json({ success: false, error: { code: 'MAXIMUM_AMOUNT', message: 'Monto máximo S/ 500 por transferencia' }});
      return;
    }

    // Verificar PIN (simulación)
    if (!pin || pin !== '1234') {
      res.status(400).json({ success: false, error: { code: 'INVALID_PIN', message: 'PIN incorrecto' }});
      return;
    }

    // Verificar que el destinatario existe
    const recipientDoc = await admin.firestore().collection('users').doc(recipientId).get();
    if (!recipientDoc.exists) {
      res.status(404).json({ success: false, error: { code: 'RECIPIENT_NOT_FOUND', message: 'Usuario destinatario no encontrado' }});
      return;
    }

    const transferId = `transfer_${Date.now()}`;
    const transferData = {
      id: transferId,
      senderId: userId,
      recipientId,
      amount,
      message: message || '',
      status: 'completed',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      completedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    // Guardar transferencia
    await admin.firestore().collection('wallet_transfers').doc(transferId).set(transferData);

    // Crear transacciones para sender y recipient
    const batch = admin.firestore().batch();
    
    // Transacción del sender (débito)
    batch.set(admin.firestore().collection('wallet_transactions').doc(`${transferId}_sender`), {
      id: `${transferId}_sender`,
      userId,
      type: 'transfer_sent',
      amount: -amount,
      description: `Transferencia a ${recipientDoc.data()?.firstName || 'Usuario'}`,
      status: 'completed',
      transferId,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // Transacción del recipient (crédito)
    batch.set(admin.firestore().collection('wallet_transactions').doc(`${transferId}_recipient`), {
      id: `${transferId}_recipient`,
      userId: recipientId,
      type: 'transfer_received',
      amount: amount,
      description: `Transferencia recibida de ${req.user?.firstName || 'Usuario'}`,
      status: 'completed',
      transferId,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    await batch.commit();

    res.status(200).json({
      success: true,
      data: {
        transferId,
        recipientName: recipientDoc.data()?.firstName || 'Usuario',
        amount,
        status: 'completed'
      },
      message: 'Transferencia realizada exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

// =========================================
// PROCESAMIENTO DE PAGOS
// =========================================

export const processPayment = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    const { rideId, amount, paymentMethodId, tip = 0 } = req.body;

    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }});
      return;
    }

    if (!rideId || !amount || amount <= 0) {
      res.status(400).json({ 
        success: false, 
        error: { code: 'INVALID_INPUT', message: 'ID de viaje y monto son requeridos' }
      });
      return;
    }

    // Verificar que el viaje existe y pertenece al usuario
    const rideDoc = await admin.firestore().collection('rides').doc(rideId).get();
    if (!rideDoc.exists || rideDoc.data()?.passengerId !== userId) {
      res.status(404).json({ success: false, error: { code: 'RIDE_NOT_FOUND', message: 'Viaje no encontrado' }});
      return;
    }

    const totalAmount = amount + tip;
    const paymentId = `payment_${Date.now()}`;
    
    const paymentData = {
      id: paymentId,
      rideId,
      passengerId: userId,
      driverId: rideDoc.data()?.driverId,
      amount,
      tip,
      totalAmount,
      paymentMethodId,
      status: 'processing',
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    };

    // Guardar pago
    await admin.firestore().collection('payments').doc(paymentId).set(paymentData);

    // Simular procesamiento
    setTimeout(async () => {
      try {
        await Promise.all([
          admin.firestore().collection('payments').doc(paymentId).update({
            status: 'completed',
            completedAt: admin.firestore.FieldValue.serverTimestamp()
          }),
          admin.firestore().collection('rides').doc(rideId).update({
            paymentStatus: 'paid',
            paymentId,
            paidAt: admin.firestore.FieldValue.serverTimestamp()
          })
        ]);
      } catch (error) {
        console.error('Error updating payment status:', error);
      }
    }, 3000); // 3 segundos

    res.status(200).json({
      success: true,
      data: {
        paymentId,
        totalAmount,
        status: 'processing',
        estimatedCompletionTime: '3-5 segundos'
      },
      message: 'Pago iniciado exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

// =========================================
// REEMBOLSOS Y DISPUTS
// =========================================

export const requestRefund = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    const { paymentId, reason, amount } = req.body;

    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }});
      return;
    }

    if (!paymentId || !reason) {
      res.status(400).json({ 
        success: false, 
        error: { code: 'INVALID_INPUT', message: 'ID de pago y motivo son requeridos' }
      });
      return;
    }

    // Verificar que el pago existe y pertenece al usuario
    const paymentDoc = await admin.firestore().collection('payments').doc(paymentId).get();
    if (!paymentDoc.exists || paymentDoc.data()?.passengerId !== userId) {
      res.status(404).json({ success: false, error: { code: 'PAYMENT_NOT_FOUND', message: 'Pago no encontrado' }});
      return;
    }

    const refundId = `refund_${Date.now()}`;
    const refundData = {
      id: refundId,
      paymentId,
      passengerId: userId,
      requestedAmount: amount || paymentDoc.data()?.totalAmount,
      reason,
      status: 'pending',
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    };

    await admin.firestore().collection('refunds').doc(refundId).set(refundData);

    res.status(201).json({
      success: true,
      data: refundData,
      message: 'Solicitud de reembolso creada exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

export const getPaymentHistory = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    const { page = 1, limit = 20, status } = req.query;

    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }});
      return;
    }

    let query = admin.firestore().collection('payments')
      .where('passengerId', '==', userId)
      .orderBy('createdAt', 'desc');

    if (status) {
      query = query.where('status', '==', status);
    }

    const snapshot = await query.limit(Number(limit)).get();
    const payments = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));

    res.status(200).json({
      success: true,
      data: {
        payments,
        pagination: {
          page: Number(page),
          limit: Number(limit),
          total: payments.length,
          hasNext: payments.length === Number(limit)
        }
      },
      message: 'Historial de pagos obtenido exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};