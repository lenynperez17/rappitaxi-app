import { Request, Response } from 'express';
import * as admin from 'firebase-admin';
import { logger, loggerHelpers } from '@shared/utils/logger';
import { AppError } from '@shared/middleware/error-handler';
import { 
  ApiResponse, 
  Payment, 
  PaymentStatus, 
  PaymentMethod, 
  CreatePaymentRequest,
  PaginationInfo 
} from '@shared/types';
import { validateAmount } from '../../auth/validators/auth-validators';
import { MercadoPagoProvider } from '../providers/mercadopago-provider';
import { WalletProvider } from '../providers/wallet-provider';

// Initialize payment providers
const mercadoPagoProvider = new MercadoPagoProvider();
const walletProvider = new WalletProvider();

/**
 * Create a new payment
 */
export const createPayment = async (req: Request, res: Response): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }

  const { rideId, amount, method, paymentToken }: CreatePaymentRequest = req.body;

  // Validation
  if (!rideId || !amount || !method) {
    throw new AppError('Campos requeridos faltantes', 400, 'VALIDATION_ERROR');
  }

  if (!validateAmount(amount)) {
    throw new AppError('Monto inválido', 400, 'INVALID_AMOUNT');
  }

  const validMethods = ['cash', 'credit_card', 'mercado_pago', 'wallet'];
  if (!validMethods.includes(method)) {
    throw new AppError('Método de pago inválido', 400, 'INVALID_PAYMENT_METHOD');
  }

  try {
    // Verify ride exists and belongs to user
    const rideDoc = await admin.firestore()
      .collection('rides')
      .doc(rideId)
      .get();

    if (!rideDoc.exists) {
      throw new AppError('Viaje no encontrado', 404, 'RIDE_NOT_FOUND');
    }

    const rideData = rideDoc.data();
    if (rideData?.passengerId !== req.userId) {
      throw new AppError('Acceso denegado', 403, 'ACCESS_DENIED');
    }

    if (rideData?.status !== 'completed') {
      throw new AppError('Solo se pueden procesar pagos de viajes completados', 409, 'RIDE_NOT_COMPLETED');
    }

    // Check if payment already exists for this ride
    const existingPaymentQuery = await admin.firestore()
      .collection('payments')
      .where('rideId', '==', rideId)
      .where('status', 'in', ['completed', 'processing'])
      .get();

    if (!existingPaymentQuery.empty) {
      throw new AppError('Ya existe un pago para este viaje', 409, 'PAYMENT_EXISTS');
    }

    // Create payment document
    const paymentRef = admin.firestore().collection('payments').doc();
    const now = new Date();

    const paymentData: Partial<Payment> = {
      id: paymentRef.id,
      rideId,
      userId: req.userId,
      amount,
      currency: 'ARS',
      method: method as PaymentMethod,
      status: PaymentStatus.PENDING,
      createdAt: now,
      metadata: {
        userAgent: req.get('User-Agent'),
        ip: req.ip,
        paymentToken: method !== 'cash' ? paymentToken : undefined,
      },
    };

    await paymentRef.set(paymentData);

    // Process payment based on method
    let paymentResult: any;

    switch (method) {
      case 'cash':
        // Cash payments are processed directly
        paymentResult = { success: true, transactionId: `cash_${paymentRef.id}` };
        break;
        
      case 'credit_card':
        if (!paymentToken) {
          throw new AppError('Token de tarjeta requerido', 400, 'PAYMENT_TOKEN_REQUIRED');
        }
        // Use MercadoPago for credit card processing
        paymentResult = await mercadoPagoProvider.processPayment(amount, paymentToken, {
          paymentId: paymentRef.id,
          rideId,
          userId: req.userId,
        });
        break;
        
      case 'mercado_pago':
        if (!paymentToken) {
          throw new AppError('Token de MercadoPago requerido', 400, 'PAYMENT_TOKEN_REQUIRED');
        }
        paymentResult = await mercadoPagoProvider.processPayment(amount, paymentToken, {
          paymentId: paymentRef.id,
          rideId,
          userId: req.userId,
        });
        break;
        
      case 'wallet':
        paymentResult = await walletProvider.processPayment(req.userId, amount, {
          paymentId: paymentRef.id,
          rideId,
        });
        break;
        
      default:
        throw new AppError('Método de pago no soportado', 400, 'UNSUPPORTED_PAYMENT_METHOD');
    }

    // Update payment with result
    const updateData: any = {
      updatedAt: new Date(),
    };

    if (paymentResult.success) {
      updateData.status = PaymentStatus.COMPLETED;
      updateData.processedAt = new Date();
      updateData.gatewayTransactionId = paymentResult.transactionId;
      updateData.gatewayResponse = paymentResult.response;
    } else {
      updateData.status = PaymentStatus.FAILED;
      updateData.failedAt = new Date();
      updateData.gatewayResponse = paymentResult.error;
    }

    await paymentRef.update(updateData);

    // Log payment event
    loggerHelpers.logPaymentEvent(
      paymentResult.success ? 'PAYMENT_COMPLETED' : 'PAYMENT_FAILED',
      paymentRef.id,
      amount,
      {
        rideId,
        method,
        transactionId: paymentResult.transactionId,
        userId: req.userId,
      }
    );

    const response: ApiResponse<{ 
      payment: Partial<Payment>; 
      success: boolean; 
      transactionId?: string 
    }> = {
      success: true,
      data: {
        payment: { ...paymentData, ...updateData },
        success: paymentResult.success,
        transactionId: paymentResult.transactionId,
      },
      timestamp: new Date().toISOString(),
    };

    res.status(201).json(response);
  } catch (error) {
    throw error;
  }
};

/**
 * Process an existing payment
 */
export const processPayment = async (req: Request, res: Response): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }

  const { paymentId } = req.params;
  const { paymentToken } = req.body;

  try {
    const paymentDoc = await admin.firestore()
      .collection('payments')
      .doc(paymentId)
      .get();

    if (!paymentDoc.exists) {
      throw new AppError('Pago no encontrado', 404, 'PAYMENT_NOT_FOUND');
    }

    const paymentData = paymentDoc.data() as Payment;

    // Check ownership
    if (paymentData.userId !== req.userId) {
      throw new AppError('Acceso denegado', 403, 'ACCESS_DENIED');
    }

    // Check if payment is in correct status
    if (paymentData.status !== PaymentStatus.PENDING) {
      throw new AppError('El pago no puede ser procesado en su estado actual', 409, 'INVALID_PAYMENT_STATUS');
    }

    // Update status to processing
    await admin.firestore()
      .collection('payments')
      .doc(paymentId)
      .update({
        status: PaymentStatus.PROCESSING,
        updatedAt: new Date(),
      });

    // Process based on method
    let paymentResult: any;

    switch (paymentData.method) {
      case PaymentMethod.CREDIT_CARD:
        // Use MercadoPago for credit card processing
        paymentResult = await mercadoPagoProvider.processPayment(
          paymentData.amount,
          paymentToken,
          { paymentId, rideId: paymentData.rideId, userId: req.userId }
        );
        break;
        
      case PaymentMethod.MERCADO_PAGO:
        paymentResult = await mercadoPagoProvider.processPayment(
          paymentData.amount,
          paymentToken,
          { paymentId, rideId: paymentData.rideId, userId: req.userId }
        );
        break;
        
      case PaymentMethod.WALLET:
        paymentResult = await walletProvider.processPayment(
          req.userId,
          paymentData.amount,
          { paymentId, rideId: paymentData.rideId }
        );
        break;
        
      default:
        throw new AppError('Método de pago no soportado para procesamiento', 400, 'UNSUPPORTED_PAYMENT_METHOD');
    }

    // Update payment with final result
    const finalStatus = paymentResult.success ? PaymentStatus.COMPLETED : PaymentStatus.FAILED;
    
    await admin.firestore()
      .collection('payments')
      .doc(paymentId)
      .update({
        status: finalStatus,
        gatewayTransactionId: paymentResult.transactionId,
        gatewayResponse: paymentResult.response || paymentResult.error,
        [paymentResult.success ? 'processedAt' : 'failedAt']: new Date(),
        updatedAt: new Date(),
      });

    loggerHelpers.logPaymentEvent(
      paymentResult.success ? 'PAYMENT_PROCESSED' : 'PAYMENT_PROCESSING_FAILED',
      paymentId,
      paymentData.amount,
      {
        rideId: paymentData.rideId,
        method: paymentData.method,
        transactionId: paymentResult.transactionId,
      }
    );

    const response: ApiResponse<{ success: boolean; transactionId?: string }> = {
      success: true,
      data: {
        success: paymentResult.success,
        transactionId: paymentResult.transactionId,
      },
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error) {
    // Update payment status to failed if error occurs
    try {
      await admin.firestore()
        .collection('payments')
        .doc(paymentId)
        .update({
          status: PaymentStatus.FAILED,
          failedAt: new Date(),
          updatedAt: new Date(),
        });
    } catch (updateError) {
      logger.error('Failed to update payment status after error', {
        paymentId,
        error: updateError,
      });
    }
    
    throw error;
  }
};

/**
 * Get payment by ID
 */
export const getPaymentById = async (req: Request, res: Response): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }

  const { paymentId } = req.params;

  try {
    const paymentDoc = await admin.firestore()
      .collection('payments')
      .doc(paymentId)
      .get();

    if (!paymentDoc.exists) {
      throw new AppError('Pago no encontrado', 404, 'PAYMENT_NOT_FOUND');
    }

    const paymentData = paymentDoc.data() as Payment;

    // Check ownership or admin access
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(req.userId)
      .get();

    const userData = userDoc.data();
    const isAdmin = userData?.role === 'admin';

    if (!isAdmin && paymentData.userId !== req.userId) {
      throw new AppError('Acceso denegado', 403, 'ACCESS_DENIED');
    }

    const response: ApiResponse<{ payment: Payment }> = {
      success: true,
      data: { payment: paymentData },
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error) {
    throw error;
  }
};

/**
 * Get user payments with pagination
 */
export const getUserPayments = async (req: Request, res: Response): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }

  const page = parseInt(req.query.page as string) || 1;
  const limit = Math.min(parseInt(req.query.limit as string) || 10, 50);
  const status = req.query.status as string;
  const method = req.query.method as string;
  const userId = req.params.userId || req.userId;

  // Check access permissions
  const userDoc = await admin.firestore()
    .collection('users')
    .doc(req.userId)
    .get();

  const userData = userDoc.data();
  const isAdmin = userData?.role === 'admin';

  if (!isAdmin && userId !== req.userId) {
    throw new AppError('Acceso denegado', 403, 'ACCESS_DENIED');
  }

  try {
    let query = admin.firestore()
      .collection('payments')
      .where('userId', '==', userId) as any;

    // Apply filters
    if (status) {
      query = query.where('status', '==', status);
    }

    if (method) {
      query = query.where('method', '==', method);
    }

    // Order by creation date (newest first)
    query = query.orderBy('createdAt', 'desc');

    // Get total count
    const totalSnapshot = await query.get();
    const total = totalSnapshot.size;

    // Apply pagination
    const offset = (page - 1) * limit;
    const paymentsSnapshot = await query.offset(offset).limit(limit).get();

    const payments = paymentsSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
    }));

    const totalPages = Math.ceil(total / limit);
    const pagination: PaginationInfo = {
      page,
      limit,
      total,
      totalPages,
      hasNext: page < totalPages,
      hasPrev: page > 1,
    };

    const response: ApiResponse<{ 
      payments: any[]; 
      pagination: PaginationInfo;
      summary: {
        totalAmount: number;
        completedAmount: number;
        failedCount: number;
      }
    }> = {
      success: true,
      data: { 
        payments, 
        pagination,
        summary: calculatePaymentsSummary(payments),
      },
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error) {
    throw error;
  }
};

/**
 * Refund a payment (Admin only)
 */
export const refundPayment = async (req: Request, res: Response): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }

  const { paymentId } = req.params;
  const { reason, amount } = req.body;

  try {
    const paymentDoc = await admin.firestore()
      .collection('payments')
      .doc(paymentId)
      .get();

    if (!paymentDoc.exists) {
      throw new AppError('Pago no encontrado', 404, 'PAYMENT_NOT_FOUND');
    }

    const paymentData = paymentDoc.data() as Payment;

    if (paymentData.status !== PaymentStatus.COMPLETED) {
      throw new AppError('Solo se pueden reembolsar pagos completados', 409, 'INVALID_PAYMENT_STATUS');
    }

    const refundAmount = amount || paymentData.amount;

    if (refundAmount > paymentData.amount) {
      throw new AppError('El monto del reembolso no puede ser mayor al pago original', 400, 'INVALID_REFUND_AMOUNT');
    }

    // Process refund based on original payment method
    let refundResult: any;

    switch (paymentData.method) {
      case PaymentMethod.CREDIT_CARD:
        // Use MercadoPago for credit card refunds
        refundResult = await mercadoPagoProvider.refundPayment(
          paymentData.gatewayTransactionId!,
          refundAmount,
          reason
        );
        break;
        
      case PaymentMethod.MERCADO_PAGO:
        refundResult = await mercadoPagoProvider.refundPayment(
          paymentData.gatewayTransactionId!,
          refundAmount,
          reason
        );
        break;
        
      case PaymentMethod.WALLET:
        refundResult = await walletProvider.refundPayment(
          paymentData.userId,
          refundAmount,
          { paymentId, reason }
        );
        break;
        
      case PaymentMethod.CASH:
        // Cash refunds need manual processing
        refundResult = { 
          success: true, 
          refundId: `cash_refund_${Date.now()}`,
          note: 'Reembolso en efectivo requiere procesamiento manual'
        };
        break;
        
      default:
        throw new AppError('Método de pago no soporta reembolsos automáticos', 400, 'REFUND_NOT_SUPPORTED');
    }

    if (refundResult.success) {
      // Update payment status
      await admin.firestore()
        .collection('payments')
        .doc(paymentId)
        .update({
          status: PaymentStatus.REFUNDED,
          refundedAt: new Date(),
          updatedAt: new Date(),
          refundData: {
            amount: refundAmount,
            reason,
            refundId: refundResult.refundId,
            processedBy: req.userId,
            processedAt: new Date(),
          },
        });

      loggerHelpers.logPaymentEvent('PAYMENT_REFUNDED', paymentId, refundAmount, {
        originalAmount: paymentData.amount,
        reason,
        refundId: refundResult.refundId,
        processedBy: req.userId,
      });

      const response: ApiResponse<{ refundId: string }> = {
        success: true,
        data: { refundId: refundResult.refundId },
        timestamp: new Date().toISOString(),
      };

      res.json(response);
    } else {
      throw new AppError('Error procesando reembolso: ' + refundResult.error, 500, 'REFUND_FAILED');
    }
  } catch (error) {
    throw error;
  }
};

/**
 * Get user's payment methods
 */
export const getPaymentMethods = async (req: Request, res: Response): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }

  try {
    const paymentMethodsDoc = await admin.firestore()
      .collection('user_payment_methods')
      .doc(req.userId)
      .get();

    const paymentMethods = paymentMethodsDoc.exists ? paymentMethodsDoc.data()?.methods || [] : [];

    const response: ApiResponse<{ paymentMethods: any[] }> = {
      success: true,
      data: { paymentMethods },
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error) {
    throw error;
  }
};

/**
 * Add a payment method
 */
export const addPaymentMethod = async (req: Request, res: Response): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }

  const { type, token, details } = req.body;

  if (!type || !token) {
    throw new AppError('Tipo y token requeridos', 400, 'VALIDATION_ERROR');
  }

  const validTypes = ['credit_card', 'mercado_pago'];
  if (!validTypes.includes(type)) {
    throw new AppError('Tipo de método de pago inválido', 400, 'INVALID_PAYMENT_TYPE');
  }

  try {
    // Verify token with respective provider
    let methodDetails: any;

    switch (type) {
      case 'credit_card':
        // Use MercadoPago for credit card verification
        methodDetails = await mercadoPagoProvider.verifyPaymentMethod(token);
        break;
      case 'mercado_pago':
        methodDetails = await mercadoPagoProvider.verifyPaymentMethod(token);
        break;
    }

    const newMethod = {
      id: admin.firestore().collection('temp').doc().id,
      type,
      token,
      details: methodDetails,
      isDefault: false,
      createdAt: new Date(),
    };

    // Add to user's payment methods
    const userPaymentMethodsRef = admin.firestore()
      .collection('user_payment_methods')
      .doc(req.userId);

    await userPaymentMethodsRef.set({
      methods: admin.firestore.FieldValue.arrayUnion(newMethod),
      updatedAt: new Date(),
    }, );

    const response: ApiResponse<{ method: any }> = {
      success: true,
      data: { method: newMethod },
      timestamp: new Date().toISOString(),
    };

    res.status(201).json(response);
  } catch (error) {
    throw error;
  }
};

/**
 * Remove a payment method
 */
export const removePaymentMethod = async (req: Request, res: Response): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }

  const { methodId } = req.params;

  try {
    const userPaymentMethodsDoc = await admin.firestore()
      .collection('user_payment_methods')
      .doc(req.userId)
      .get();

    if (!userPaymentMethodsDoc.exists) {
      throw new AppError('Métodos de pago no encontrados', 404, 'PAYMENT_METHODS_NOT_FOUND');
    }

    const data = userPaymentMethodsDoc.data();
    const methods = data?.methods || [];
    
    const methodIndex = methods.findIndex((m: any) => m.id === methodId);
    if (methodIndex === -1) {
      throw new AppError('Método de pago no encontrado', 404, 'PAYMENT_METHOD_NOT_FOUND');
    }

    methods.splice(methodIndex, 1);

    await admin.firestore()
      .collection('user_payment_methods')
      .doc(req.userId)
      .update({
        methods,
        updatedAt: new Date(),
      });

    const response: ApiResponse = {
      success: true,
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error) {
    throw error;
  }
};

/**
 * Set default payment method
 */
export const setDefaultPaymentMethod = async (req: Request, res: Response): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }

  const { methodId } = req.params;

  try {
    const userPaymentMethodsDoc = await admin.firestore()
      .collection('user_payment_methods')
      .doc(req.userId)
      .get();

    if (!userPaymentMethodsDoc.exists) {
      throw new AppError('Métodos de pago no encontrados', 404, 'PAYMENT_METHODS_NOT_FOUND');
    }

    const data = userPaymentMethodsDoc.data();
    let methods = data?.methods || [];
    
    const methodIndex = methods.findIndex((m: any) => m.id === methodId);
    if (methodIndex === -1) {
      throw new AppError('Método de pago no encontrado', 404, 'PAYMENT_METHOD_NOT_FOUND');
    }

    // Remove default from all methods and set it on the selected one
    methods = methods.map((method: any) => ({
      ...method,
      isDefault: method.id === methodId,
    }));

    await admin.firestore()
      .collection('user_payment_methods')
      .doc(req.userId)
      .update({
        methods,
        updatedAt: new Date(),
      });

    const response: ApiResponse = {
      success: true,
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error) {
    throw error;
  }
};

/**
 * Get wallet balance
 */
export const getWalletBalance = async (req: Request, res: Response): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }

  try {
    const balance = await walletProvider.getBalance(req.userId);

    const response: ApiResponse<{ balance: number; currency: string }> = {
      success: true,
      data: { balance, currency: 'ARS' },
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error) {
    throw error;
  }
};

/**
 * Add funds to wallet
 */
export const addFundsToWallet = async (req: Request, res: Response): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }

  const { amount, paymentMethod, paymentToken } = req.body;

  if (!validateAmount(amount) || amount < 100) {
    throw new AppError('Monto mínimo: $100', 400, 'INVALID_AMOUNT');
  }

  if (amount > 50000) {
    throw new AppError('Monto máximo: $50,000', 400, 'AMOUNT_TOO_HIGH');
  }

  try {
    const result = await walletProvider.addFunds(req.userId, amount, paymentMethod, paymentToken);

    if (result.success) {
      const response: ApiResponse<{ transactionId: string; newBalance: number }> = {
        success: true,
        data: {
          transactionId: result.transactionId,
          newBalance: result.newBalance,
        },
        timestamp: new Date().toISOString(),
      };

      res.json(response);
    } else {
      throw new AppError('Error agregando fondos: ' + result.error, 500, 'ADD_FUNDS_FAILED');
    }
  } catch (error) {
    throw error;
  }
};

/**
 * Withdraw from wallet
 */
export const withdrawFromWallet = async (req: Request, res: Response): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }

  const { amount, bankAccount } = req.body;

  if (!validateAmount(amount) || amount < 500) {
    throw new AppError('Monto mínimo de retiro: $500', 400, 'INVALID_AMOUNT');
  }

  try {
    const result = await walletProvider.withdrawFunds(req.userId, amount, bankAccount);

    if (result.success) {
      const response: ApiResponse<{ transactionId: string; newBalance: number }> = {
        success: true,
        data: {
          transactionId: result.transactionId,
          newBalance: result.newBalance,
        },
        timestamp: new Date().toISOString(),
      };

      res.json(response);
    } else {
      throw new AppError('Error procesando retiro: ' + result.error, 500, 'WITHDRAWAL_FAILED');
    }
  } catch (error) {
    throw error;
  }
};

/**
 * Get payment history
 */
export const getPaymentHistory = async (req: Request, res: Response): Promise<void> => {
  // Reuse getUserPayments logic
  return getUserPayments(req, res);
};

/**
 * Process webhook from payment providers
 */
export const processWebhook = async (req: Request, res: Response): Promise<void> => {
  const webhookType = 'mercadopago';
  
  try {
    let result: any;

    switch (webhookType) {
      case 'mercadopago':
        result = await mercadoPagoProvider.processWebhook(req.body, req.headers);
        break;
    }

    if (result.paymentId) {
      // Update payment status based on webhook
      await admin.firestore()
        .collection('payments')
        .doc(result.paymentId)
        .update({
          status: result.status,
          gatewayResponse: result.data,
          updatedAt: new Date(),
          ...(result.status === 'completed' && { processedAt: new Date() }),
          ...(result.status === 'failed' && { failedAt: new Date() }),
        });

      loggerHelpers.logPaymentEvent(
        `WEBHOOK_${result.status.toUpperCase()}`,
        result.paymentId,
        result.amount || 0,
        {
          provider: webhookType,
          transactionId: result.transactionId,
        }
      );
    }

    res.status(200).json({ received: true });
  } catch (error: any) {
    logger.error('Webhook processing error', {
      error: error.message,
      webhookType,
      body: req.body,
    });
    
    res.status(400).json({ error: 'Webhook processing failed' });
  }
};

/**
 * Generate payment link
 */
export const generatePaymentLink = async (req: Request, res: Response): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }

  const { amount, description, expiresIn } = req.body;

  if (!validateAmount(amount)) {
    throw new AppError('Monto inválido', 400, 'INVALID_AMOUNT');
  }

  try {
    const paymentLink = await mercadoPagoProvider.generatePaymentLink(amount, {
      userId: req.userId,
      description: description || 'Pago OASIS Taxi',
      expiresIn: expiresIn || 3600, // 1 hour default
    });

    const response: ApiResponse<{ paymentUrl: string; linkId: string }> = {
      success: true,
      data: {
        paymentUrl: paymentLink.url,
        linkId: paymentLink.id,
      },
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error) {
    throw error;
  }
};

/**
 * Validate payment
 */
export const validatePayment = async (req: Request, res: Response): Promise<void> => {
  const { paymentId, transactionId, provider } = req.body;

  if (!paymentId || !transactionId || !provider) {
    throw new AppError('Datos de validación requeridos', 400, 'VALIDATION_ERROR');
  }

  try {
    let isValid = false;
    let paymentData: any = {};

    switch (provider) {
      case 'mercadopago':
        const mpResult = await mercadoPagoProvider.validatePayment(transactionId);
        isValid = mpResult.valid;
        paymentData = mpResult.data;
        break;
        
        
      default:
        throw new AppError('Proveedor de pago no soportado', 400, 'UNSUPPORTED_PROVIDER');
    }

    const response: ApiResponse<{ valid: boolean; paymentData?: any }> = {
      success: true,
      data: {
        valid: isValid,
        ...(isValid && { paymentData }),
      },
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error) {
    throw error;
  }
};

/**
 * Get driver earnings
 */
export const getDriverEarnings = async (req: Request, res: Response): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }

  const targetDriverId = req.query.driverId as string || req.userId;

  // Check access permissions
  const userDoc = await admin.firestore()
    .collection('users')
    .doc(req.userId)
    .get();

  const userData = userDoc.data();
  const isAdmin = userData?.role === 'admin';
  const isDriver = userData?.role === 'driver';

  if (!isAdmin && (!isDriver || targetDriverId !== req.userId)) {
    throw new AppError('Acceso denegado', 403, 'ACCESS_DENIED');
  }

  try {
    const earningsDoc = await admin.firestore()
      .collection('driver_earnings')
      .doc(targetDriverId)
      .get();

    const earnings = earningsDoc.exists ? earningsDoc.data() : {
      totalEarnings: 0,
      weeklyEarnings: 0,
      monthlyEarnings: 0,
      pendingPayouts: 0,
      totalRides: 0,
    };

    const response: ApiResponse<{ earnings: any }> = {
      success: true,
      data: { earnings },
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error) {
    throw error;
  }
};

/**
 * Process driver payout
 */
export const processDriverPayout = async (req: Request, res: Response): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }

  const { amount, bankAccount } = req.body;

  if (!validateAmount(amount) || amount < 1000) {
    throw new AppError('Monto mínimo de pago: $1,000', 400, 'INVALID_AMOUNT');
  }

  try {
    // Get driver earnings
    const earningsDoc = await admin.firestore()
      .collection('driver_earnings')
      .doc(req.userId)
      .get();

    if (!earningsDoc.exists) {
      throw new AppError('Datos de ganancias no encontrados', 404, 'EARNINGS_NOT_FOUND');
    }

    const earnings = earningsDoc.data();
    const availableAmount = earnings.totalEarnings - earnings.pendingPayouts - earnings.completedPayouts;

    if (amount > availableAmount) {
      throw new AppError('Monto insuficiente disponible', 400, 'INSUFFICIENT_FUNDS');
    }

    // Process payout (this would integrate with actual banking API)
    const payoutId = `payout_${Date.now()}`;
    
    // Update driver earnings
    await admin.firestore()
      .collection('driver_earnings')
      .doc(req.userId)
      .update({
        pendingPayouts: admin.firestore.FieldValue.increment(amount),
        updatedAt: new Date(),
      });

    // Create payout record
    await admin.firestore()
      .collection('driver_payouts')
      .doc(payoutId)
      .set({
        id: payoutId,
        driverId: req.userId,
        amount,
        bankAccount,
        status: 'pending',
        createdAt: new Date(),
        scheduledFor: new Date(Date.now() + 24 * 60 * 60 * 1000), // Next day
      });

    loggerHelpers.logPaymentEvent('DRIVER_PAYOUT_REQUESTED', payoutId, amount, {
      driverId: req.userId,
      bankAccount: bankAccount.accountNumber.slice(-4), // Only last 4 digits
    });

    const response: ApiResponse<{ payoutId: string; scheduledFor: Date }> = {
      success: true,
      data: {
        payoutId,
        scheduledFor: new Date(Date.now() + 24 * 60 * 60 * 1000),
      },
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error) {
    throw error;
  }
};

/**
 * Get payment analytics (Admin only)
 */
export const getPaymentAnalytics = async (req: Request, res: Response): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }

  const period = req.query.period as string || '30d';
  const startDate = req.query.startDate as string;
  const endDate = req.query.endDate as string;

  try {
    // Calculate date range
    let start: Date, end: Date;
    
    if (startDate && endDate) {
      start = new Date(startDate);
      end = new Date(endDate);
    } else {
      end = new Date();
      switch (period) {
        case '7d':
          start = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
          break;
        case '30d':
          start = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
          break;
        case '90d':
          start = new Date(Date.now() - 90 * 24 * 60 * 60 * 1000);
          break;
        default:
          start = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
      }
    }

    // Get payments in date range
    const paymentsQuery = await admin.firestore()
      .collection('payments')
      .where('createdAt', '>=', start)
      .where('createdAt', '<=', end)
      .get();

    const analytics = calculatePaymentAnalytics(paymentsQuery.docs.map(doc => doc.data()));

    const response: ApiResponse<{ 
      analytics: any; 
      period: { start: Date; end: Date } 
    }> = {
      success: true,
      data: {
        analytics,
        period: { start, end },
      },
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error) {
    throw error;
  }
};

// Helper functions

/**
 * Calculate payments summary
 */
function calculatePaymentsSummary(payments: any[]): {
  totalAmount: number;
  completedAmount: number;
  failedCount: number;
} {
  let totalAmount = 0;
  let completedAmount = 0;
  let failedCount = 0;

  payments.forEach(payment => {
    totalAmount += payment.amount;
    if (payment.status === 'completed') {
      completedAmount += payment.amount;
    } else if (payment.status === 'failed') {
      failedCount++;
    }
  });

  return {
    totalAmount: Math.round(totalAmount),
    completedAmount: Math.round(completedAmount),
    failedCount,
  };
}

/**
 * Calculate payment analytics
 */
function calculatePaymentAnalytics(payments: any[]): any {
  const total = payments.length;
  const completed = payments.filter(p => p.status === 'completed').length;
  const failed = payments.filter(p => p.status === 'failed').length;
  const pending = payments.filter(p => p.status === 'pending').length;

  const totalRevenue = payments
    .filter(p => p.status === 'completed')
    .reduce((sum, p) => sum + p.amount, 0);

  const methodBreakdown = payments.reduce((acc, payment) => {
    acc[payment.method] = (acc[payment.method] || 0) + 1;
    return acc;
  }, {});

  const dailyRevenue = payments
    .filter(p => p.status === 'completed')
    .reduce((acc, payment) => {
      const date = new Date(payment.createdAt.toDate()).toISOString().split('T')[0];
      acc[date] = (acc[date] || 0) + payment.amount;
      return acc;
    }, {});

  return {
    summary: {
      totalPayments: total,
      completedPayments: completed,
      failedPayments: failed,
      pendingPayments: pending,
      successRate: total > 0 ? (completed / total * 100).toFixed(2) + '%' : '0%',
      totalRevenue: Math.round(totalRevenue),
      averagePayment: completed > 0 ? Math.round(totalRevenue / completed) : 0,
    },
    methodBreakdown,
    dailyRevenue,
  };
}