import { EventEmitter } from 'events';
import * as admin from 'firebase-admin';
import axios from 'axios';
import crypto from 'crypto';
import Stripe from 'stripe';
import { logger } from '@shared/utils/logger';
import { AppError } from '@shared/middleware/error-handler';

// 💳 Configuración de servicios de pago
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY || 'sk_test_', {
  apiVersion: '2023-10-16'
});

const MERCADOPAGO_ACCESS_TOKEN = process.env.MERCADOPAGO_ACCESS_TOKEN || 'TEST_TOKEN';
const MERCADOPAGO_PUBLIC_KEY = process.env.MERCADOPAGO_PUBLIC_KEY || 'TEST_PUBLIC_KEY';
const MERCADOPAGO_BASE_URL = 'https://api.mercadopago.com';

// 💰 Tipos de pago
export enum PaymentMethod {
  CASH = 'cash',
  CARD = 'card',
  MERCADOPAGO = 'mercadopago',
  STRIPE = 'stripe',
  WALLET = 'wallet',
  BANK_TRANSFER = 'bank_transfer',
  QR_CODE = 'qr_code'
}

export enum PaymentStatus {
  PENDING = 'pending',
  PROCESSING = 'processing',
  AUTHORIZED = 'authorized',
  CAPTURED = 'captured',
  COMPLETED = 'completed',
  FAILED = 'failed',
  REFUNDED = 'refunded',
  CANCELLED = 'cancelled'
}

export enum TransactionType {
  RIDE_PAYMENT = 'ride_payment',
  WALLET_TOPUP = 'wallet_topup',
  WALLET_WITHDRAWAL = 'wallet_withdrawal',
  TIP = 'tip',
  CANCELLATION_FEE = 'cancellation_fee',
  REFUND = 'refund',
  COMMISSION = 'commission',
  BONUS = 'bonus',
  PROMO_CREDIT = 'promo_credit'
}

// 📊 Interfaces
export interface Payment {
  id: string;
  rideId?: string;
  userId: string;
  userRole: 'passenger' | 'driver';
  amount: number;
  currency: string;
  method: PaymentMethod;
  status: PaymentStatus;
  transactionType: TransactionType;
  
  // Referencias externas
  stripePaymentIntentId?: string;
  stripeCustomerId?: string;
  mercadopagoPaymentId?: string;
  mercadopagoPreferenceId?: string;
  
  // Detalles
  description?: string;
  metadata?: Record<string, any>;
  
  // Tarjeta (si aplica)
  cardDetails?: {
    last4: string;
    brand: string;
    expiryMonth: number;
    expiryYear: number;
    country?: string;
  };
  
  // Comisiones y fees
  platformFee?: number;
  processingFee?: number;
  driverEarnings?: number;
  
  // Timestamps
  authorizedAt?: Date;
  capturedAt?: Date;
  completedAt?: Date;
  failedAt?: Date;
  refundedAt?: Date;
  
  createdAt: Date;
  updatedAt: Date;
}

export interface PaymentMethodInfo {
  id: string;
  userId: string;
  type: PaymentMethod;
  isDefault: boolean;
  isActive: boolean;
  
  // Detalles según el tipo
  cardInfo?: {
    stripePaymentMethodId?: string;
    last4: string;
    brand: string;
    expiryMonth: number;
    expiryYear: number;
    holderName: string;
  };
  
  bankInfo?: {
    bankName: string;
    accountNumber: string;
    accountType: string;
    holderName: string;
  };
  
  mercadopagoInfo?: {
    customerId: string;
    email: string;
  };
  
  createdAt: Date;
  updatedAt: Date;
}

export interface Wallet {
  id: string;
  userId: string;
  balance: number;
  currency: string;
  pendingBalance: number;
  withdrawableBalance: number;
  
  // Límites
  dailyLimit: number;
  monthlyLimit: number;
  usedToday: number;
  usedThisMonth: number;
  
  // Estado
  isActive: boolean;
  isFrozen: boolean;
  freezeReason?: string;
  
  // KYC
  isVerified: boolean;
  verificationLevel: 'basic' | 'intermediate' | 'advanced';
  
  lastActivity: Date;
  createdAt: Date;
  updatedAt: Date;
}

export interface Invoice {
  id: string;
  paymentId: string;
  rideId?: string;
  userId: string;
  invoiceNumber: string;
  
  // Detalles fiscales
  subtotal: number;
  tax: number;
  total: number;
  currency: string;
  
  // Información del cliente
  customerInfo: {
    name: string;
    email?: string;
    phone?: string;
    taxId?: string;
    address?: string;
  };
  
  // Líneas de detalle
  items: Array<{
    description: string;
    quantity: number;
    unitPrice: number;
    total: number;
  }>;
  
  // Estado
  status: 'draft' | 'sent' | 'paid' | 'cancelled';
  pdfUrl?: string;
  sentAt?: Date;
  paidAt?: Date;
  
  createdAt: Date;
  updatedAt: Date;
}

/**
 * 💳 Servicio de Pagos
 */
export class PaymentService extends EventEmitter {
  private processingPayments: Map<string, Payment> = new Map();
  private webhookSecret: string;

  constructor() {
    super();
    this.webhookSecret = process.env.STRIPE_WEBHOOK_SECRET || '';
  }

  /**
   * 💰 Procesar pago de viaje
   */
  async processRidePayment(data: {
    rideId: string;
    passengerId: string;
    driverId: string;
    amount: number;
    paymentMethodId: string;
    tip?: number;
    promoCode?: string;
  }): Promise<Payment> {
    try {
      // Validar método de pago
      const paymentMethod = await this.getPaymentMethod(data.paymentMethodId, data.passengerId);
      
      if (!paymentMethod || !paymentMethod.isActive) {
        throw new AppError('Método de pago inválido', 400, 'INVALID_PAYMENT_METHOD');
      }

      // Calcular montos
      const subtotal = data.amount;
      const tip = data.tip || 0;
      let discount = 0;
      
      // Aplicar código promocional
      if (data.promoCode) {
        discount = await this.applyPromoCode(data.promoCode, subtotal);
      }
      
      const total = subtotal - discount + tip;
      const platformFee = total * 0.20; // 20% comisión plataforma
      const driverEarnings = total - platformFee + tip;

      // Crear registro de pago
      const paymentId = crypto.randomBytes(16).toString('hex');
      const payment: Payment = {
        id: paymentId,
        rideId: data.rideId,
        userId: data.passengerId,
        userRole: 'passenger',
        amount: total,
        currency: 'MXN',
        method: paymentMethod.type,
        status: PaymentStatus.PENDING,
        transactionType: TransactionType.RIDE_PAYMENT,
        platformFee,
        driverEarnings,
        metadata: {
          subtotal,
          discount,
          tip,
          promoCode: data.promoCode,
          driverId: data.driverId
        },
        createdAt: new Date(),
        updatedAt: new Date()
      };

      // Guardar en procesamiento
      this.processingPayments.set(paymentId, payment);

      // Procesar según método
      let processedPayment: Payment;
      
      switch (paymentMethod.type) {
        case PaymentMethod.CASH:
          processedPayment = await this.processCashPayment(payment);
          break;
          
        case PaymentMethod.CARD:
        case PaymentMethod.STRIPE:
          processedPayment = await this.processStripePayment(payment, paymentMethod);
          break;
          
        case PaymentMethod.MERCADOPAGO:
          processedPayment = await this.processMercadoPagoPayment(payment, paymentMethod);
          break;
          
        case PaymentMethod.WALLET:
          processedPayment = await this.processWalletPayment(payment, data.passengerId);
          break;
          
        default:
          throw new AppError('Método de pago no soportado', 400, 'UNSUPPORTED_PAYMENT_METHOD');
      }

      // Guardar en Firestore
      await admin.firestore()
        .collection('payments')
        .doc(paymentId)
        .set(processedPayment);

      // Si el pago fue exitoso, acreditar al conductor
      if (processedPayment.status === PaymentStatus.COMPLETED) {
        await this.creditDriver(data.driverId, driverEarnings);
        
        // Generar factura
        await this.generateInvoice(processedPayment);
        
        // Emitir eventos
        this.emit('payment:completed', processedPayment);
      }

      // Limpiar de procesamiento
      this.processingPayments.delete(paymentId);

      logger.info(`Pago procesado: ${paymentId} - ${processedPayment.status}`);
      return processedPayment;

    } catch (error) {
      logger.error('Error procesando pago:', error);
      throw error;
    }
  }

  /**
   * 💵 Procesar pago en efectivo
   */
  private async processCashPayment(payment: Payment): Promise<Payment> {
    // El pago en efectivo se marca como autorizado
    // Se completa cuando el conductor confirma recepción
    payment.status = PaymentStatus.AUTHORIZED;
    payment.authorizedAt = new Date();
    payment.updatedAt = new Date();
    
    logger.info(`Pago en efectivo autorizado: ${payment.id}`);
    return payment;
  }

  /**
   * 💳 Procesar pago con Stripe
   */
  private async processStripePayment(
    payment: Payment,
    paymentMethod: PaymentMethodInfo
  ): Promise<Payment> {
    try {
      // Obtener o crear cliente de Stripe
      let stripeCustomerId = await this.getOrCreateStripeCustomer(payment.userId);
      
      // Crear Payment Intent
      const paymentIntent = await stripe.paymentIntents.create({
        amount: Math.round(payment.amount * 100), // Convertir a centavos
        currency: payment.currency.toLowerCase(),
        customer: stripeCustomerId,
        payment_method: paymentMethod.cardInfo?.stripePaymentMethodId,
        confirm: true,
        automatic_payment_methods: {
          enabled: false
        },
        metadata: {
          paymentId: payment.id,
          rideId: payment.rideId || '',
          userId: payment.userId
        },
        description: `Viaje RappiTaxi ${payment.rideId}`,
        
        // Split payment (para marketplace)
        transfer_data: payment.metadata?.driverId ? {
          destination: await this.getStripeConnectAccount(payment.metadata.driverId)
        } : undefined,
        
        application_fee_amount: Math.round(payment.platformFee! * 100)
      });

      payment.stripePaymentIntentId = paymentIntent.id;
      payment.stripeCustomerId = stripeCustomerId;

      if (paymentIntent.status === 'succeeded') {
        payment.status = PaymentStatus.COMPLETED;
        payment.completedAt = new Date();
      } else if (paymentIntent.status === 'requires_action') {
        payment.status = PaymentStatus.PROCESSING;
        // Necesita 3D Secure u otra acción
      } else {
        payment.status = PaymentStatus.FAILED;
        payment.failedAt = new Date();
      }

      payment.updatedAt = new Date();
      
      logger.info(`Pago Stripe procesado: ${payment.id} - ${paymentIntent.status}`);
      return payment;

    } catch (error: any) {
      logger.error('Error procesando pago con Stripe:', error);
      
      payment.status = PaymentStatus.FAILED;
      payment.failedAt = new Date();
      payment.metadata = {
        ...payment.metadata,
        errorMessage: error.message,
        errorCode: error.code
      };
      
      throw new AppError('Error procesando pago', 500, 'STRIPE_PAYMENT_ERROR');
    }
  }

  /**
   * 🏪 Procesar pago con MercadoPago
   */
  private async processMercadoPagoPayment(
    payment: Payment,
    paymentMethod: PaymentMethodInfo
  ): Promise<Payment> {
    try {
      // Crear preferencia de pago
      const preference = {
        items: [{
          id: payment.rideId || payment.id,
          title: `Viaje RappiTaxi ${payment.rideId}`,
          quantity: 1,
          unit_price: payment.amount,
          currency_id: payment.currency
        }],
        payer: {
          email: paymentMethod.mercadopagoInfo?.email || 'customer@rappitaxi.com'
        },
        payment_methods: {
          excluded_payment_types: [
            { id: 'ticket' },
            { id: 'atm' }
          ],
          installments: 1
        },
        statement_descriptor: 'RappiTaxi',
        external_reference: payment.id,
        notification_url: `${process.env.API_URL}/webhooks/mercadopago`,
        back_urls: {
          success: `${process.env.APP_URL}/payment/success`,
          failure: `${process.env.APP_URL}/payment/failure`,
          pending: `${process.env.APP_URL}/payment/pending`
        },
        auto_return: 'approved',
        binary_mode: true // Solo aprobado o rechazado
      };

      const response = await axios.post(
        `${MERCADOPAGO_BASE_URL}/checkout/preferences`,
        preference,
        {
          headers: {
            'Authorization': `Bearer ${MERCADOPAGO_ACCESS_TOKEN}`,
            'Content-Type': 'application/json'
          }
        }
      );

      payment.mercadopagoPreferenceId = response.data.id;
      payment.status = PaymentStatus.PROCESSING;
      payment.metadata = {
        ...payment.metadata,
        checkoutUrl: response.data.init_point,
        sandboxUrl: response.data.sandbox_init_point
      };
      payment.updatedAt = new Date();

      logger.info(`Preferencia MercadoPago creada: ${payment.id}`);
      return payment;

    } catch (error: any) {
      logger.error('Error procesando pago con MercadoPago:', error);
      
      payment.status = PaymentStatus.FAILED;
      payment.failedAt = new Date();
      payment.metadata = {
        ...payment.metadata,
        errorMessage: error.message
      };
      
      throw new AppError('Error procesando pago', 500, 'MERCADOPAGO_PAYMENT_ERROR');
    }
  }

  /**
   * 👛 Procesar pago con wallet
   */
  private async processWalletPayment(
    payment: Payment,
    userId: string
  ): Promise<Payment> {
    try {
      const wallet = await this.getWallet(userId);
      
      if (!wallet || !wallet.isActive) {
        throw new AppError('Wallet no disponible', 400, 'WALLET_NOT_AVAILABLE');
      }

      if (wallet.isFrozen) {
        throw new AppError('Wallet congelada', 400, 'WALLET_FROZEN');
      }

      if (wallet.balance < payment.amount) {
        throw new AppError('Saldo insuficiente', 400, 'INSUFFICIENT_BALANCE');
      }

      // Verificar límites
      const dailyUsage = wallet.usedToday + payment.amount;
      if (dailyUsage > wallet.dailyLimit) {
        throw new AppError('Límite diario excedido', 400, 'DAILY_LIMIT_EXCEEDED');
      }

      // Debitar del wallet
      await this.debitWallet(userId, payment.amount, payment.id);

      payment.status = PaymentStatus.COMPLETED;
      payment.completedAt = new Date();
      payment.updatedAt = new Date();

      logger.info(`Pago con wallet completado: ${payment.id}`);
      return payment;

    } catch (error) {
      logger.error('Error procesando pago con wallet:', error);
      
      payment.status = PaymentStatus.FAILED;
      payment.failedAt = new Date();
      
      throw error;
    }
  }

  /**
   * 💳 Agregar método de pago
   */
  async addPaymentMethod(data: {
    userId: string;
    type: PaymentMethod;
    cardDetails?: {
      number: string;
      expiryMonth: number;
      expiryYear: number;
      cvc: string;
      holderName: string;
    };
    bankDetails?: {
      bankName: string;
      accountNumber: string;
      accountType: string;
      holderName: string;
    };
    setAsDefault?: boolean;
  }): Promise<PaymentMethodInfo> {
    try {
      const methodId = crypto.randomBytes(16).toString('hex');
      let paymentMethodInfo: PaymentMethodInfo = {
        id: methodId,
        userId: data.userId,
        type: data.type,
        isDefault: false,
        isActive: true,
        createdAt: new Date(),
        updatedAt: new Date()
      };

      // Procesar según tipo
      if (data.type === PaymentMethod.CARD && data.cardDetails) {
        // Crear método de pago en Stripe
        const stripePaymentMethod = await stripe.paymentMethods.create({
          type: 'card',
          card: {
            number: data.cardDetails.number,
            exp_month: data.cardDetails.expiryMonth,
            exp_year: data.cardDetails.expiryYear,
            cvc: data.cardDetails.cvc
          },
          billing_details: {
            name: data.cardDetails.holderName
          }
        });

        // Asociar con cliente
        const customerId = await this.getOrCreateStripeCustomer(data.userId);
        await stripe.paymentMethods.attach(stripePaymentMethod.id, {
          customer: customerId
        });

        paymentMethodInfo.cardInfo = {
          stripePaymentMethodId: stripePaymentMethod.id,
          last4: stripePaymentMethod.card!.last4,
          brand: stripePaymentMethod.card!.brand,
          expiryMonth: stripePaymentMethod.card!.exp_month,
          expiryYear: stripePaymentMethod.card!.exp_year,
          holderName: data.cardDetails.holderName
        };
      } else if (data.type === PaymentMethod.BANK_TRANSFER && data.bankDetails) {
        paymentMethodInfo.bankInfo = data.bankDetails;
      }

      // Si es el primer método o se marca como default
      if (data.setAsDefault) {
        await this.setDefaultPaymentMethod(data.userId, methodId);
        paymentMethodInfo.isDefault = true;
      }

      // Guardar en Firestore
      await admin.firestore()
        .collection('payment_methods')
        .doc(methodId)
        .set(paymentMethodInfo);

      logger.info(`Método de pago agregado: ${methodId} para usuario ${data.userId}`);
      return paymentMethodInfo;

    } catch (error) {
      logger.error('Error agregando método de pago:', error);
      throw error;
    }
  }

  /**
   * 💰 Recargar wallet
   */
  async topUpWallet(data: {
    userId: string;
    amount: number;
    paymentMethodId: string;
  }): Promise<Payment> {
    try {
      // Validar monto
      if (data.amount <= 0) {
        throw new AppError('Monto inválido', 400, 'INVALID_AMOUNT');
      }

      const maxTopUp = 10000; // Límite de recarga
      if (data.amount > maxTopUp) {
        throw new AppError('Monto excede el límite', 400, 'AMOUNT_EXCEEDS_LIMIT');
      }

      // Crear pago
      const payment: Payment = {
        id: crypto.randomBytes(16).toString('hex'),
        userId: data.userId,
        userRole: 'passenger',
        amount: data.amount,
        currency: 'MXN',
        method: PaymentMethod.CARD, // Por defecto
        status: PaymentStatus.PENDING,
        transactionType: TransactionType.WALLET_TOPUP,
        createdAt: new Date(),
        updatedAt: new Date()
      };

      // Procesar recarga
      const paymentMethod = await this.getPaymentMethod(data.paymentMethodId, data.userId);
      let processedPayment: Payment;

      switch (paymentMethod.type) {
        case PaymentMethod.CARD:
        case PaymentMethod.STRIPE:
          processedPayment = await this.processStripePayment(payment, paymentMethod);
          break;
        case PaymentMethod.MERCADOPAGO:
          processedPayment = await this.processMercadoPagoPayment(payment, paymentMethod);
          break;
        default:
          throw new AppError('Método no soportado para recarga', 400, 'UNSUPPORTED_METHOD');
      }

      // Si exitoso, acreditar wallet
      if (processedPayment.status === PaymentStatus.COMPLETED) {
        await this.creditWallet(data.userId, data.amount, processedPayment.id);
      }

      await admin.firestore()
        .collection('payments')
        .doc(processedPayment.id)
        .set(processedPayment);

      logger.info(`Recarga de wallet procesada: ${processedPayment.id}`);
      return processedPayment;

    } catch (error) {
      logger.error('Error recargando wallet:', error);
      throw error;
    }
  }

  /**
   * 💸 Retirar de wallet
   */
  async withdrawFromWallet(data: {
    userId: string;
    amount: number;
    bankAccountId: string;
  }): Promise<Payment> {
    try {
      const wallet = await this.getWallet(data.userId);
      
      if (!wallet || wallet.withdrawableBalance < data.amount) {
        throw new AppError('Saldo insuficiente', 400, 'INSUFFICIENT_BALANCE');
      }

      // Crear transacción de retiro
      const payment: Payment = {
        id: crypto.randomBytes(16).toString('hex'),
        userId: data.userId,
        userRole: 'driver', // Usualmente conductores retiran
        amount: data.amount,
        currency: 'MXN',
        method: PaymentMethod.BANK_TRANSFER,
        status: PaymentStatus.PROCESSING,
        transactionType: TransactionType.WALLET_WITHDRAWAL,
        createdAt: new Date(),
        updatedAt: new Date()
      };

      // Debitar wallet
      await this.debitWallet(data.userId, data.amount, payment.id);

      // Procesar transferencia bancaria (aquí iría integración con banco)
      // Por ahora simulamos
      setTimeout(async () => {
        payment.status = PaymentStatus.COMPLETED;
        payment.completedAt = new Date();
        
        await admin.firestore()
          .collection('payments')
          .doc(payment.id)
          .update(payment);

        this.emit('withdrawal:completed', payment);
      }, 5000);

      await admin.firestore()
        .collection('payments')
        .doc(payment.id)
        .set(payment);

      logger.info(`Retiro iniciado: ${payment.id}`);
      return payment;

    } catch (error) {
      logger.error('Error procesando retiro:', error);
      throw error;
    }
  }

  /**
   * 💵 Procesar reembolso
   */
  async processRefund(data: {
    paymentId: string;
    amount?: number; // Parcial si se especifica
    reason: string;
  }): Promise<Payment> {
    try {
      // Obtener pago original
      const originalPaymentDoc = await admin.firestore()
        .collection('payments')
        .doc(data.paymentId)
        .get();

      if (!originalPaymentDoc.exists) {
        throw new AppError('Pago no encontrado', 404, 'PAYMENT_NOT_FOUND');
      }

      const originalPayment = originalPaymentDoc.data() as Payment;

      if (originalPayment.status !== PaymentStatus.COMPLETED) {
        throw new AppError('Solo se pueden reembolsar pagos completados', 400, 'INVALID_PAYMENT_STATUS');
      }

      const refundAmount = data.amount || originalPayment.amount;
      
      if (refundAmount > originalPayment.amount) {
        throw new AppError('Monto de reembolso excede el pago original', 400, 'REFUND_EXCEEDS_ORIGINAL');
      }

      // Crear registro de reembolso
      const refund: Payment = {
        id: crypto.randomBytes(16).toString('hex'),
        rideId: originalPayment.rideId,
        userId: originalPayment.userId,
        userRole: originalPayment.userRole,
        amount: refundAmount,
        currency: originalPayment.currency,
        method: originalPayment.method,
        status: PaymentStatus.PROCESSING,
        transactionType: TransactionType.REFUND,
        metadata: {
          originalPaymentId: data.paymentId,
          reason: data.reason
        },
        createdAt: new Date(),
        updatedAt: new Date()
      };

      // Procesar según método original
      if (originalPayment.stripePaymentIntentId) {
        // Reembolso con Stripe
        const stripeRefund = await stripe.refunds.create({
          payment_intent: originalPayment.stripePaymentIntentId,
          amount: Math.round(refundAmount * 100),
          reason: 'requested_by_customer',
          metadata: {
            refundId: refund.id,
            reason: data.reason
          }
        });

        refund.status = stripeRefund.status === 'succeeded' 
          ? PaymentStatus.REFUNDED 
          : PaymentStatus.FAILED;
        refund.refundedAt = new Date();

      } else if (originalPayment.mercadopagoPaymentId) {
        // Reembolso con MercadoPago
        const response = await axios.post(
          `${MERCADOPAGO_BASE_URL}/v1/payments/${originalPayment.mercadopagoPaymentId}/refunds`,
          { amount: refundAmount },
          {
            headers: {
              'Authorization': `Bearer ${MERCADOPAGO_ACCESS_TOKEN}`,
              'Content-Type': 'application/json'
            }
          }
        );

        refund.status = response.data.status === 'approved' 
          ? PaymentStatus.REFUNDED 
          : PaymentStatus.FAILED;
        refund.refundedAt = new Date();

      } else if (originalPayment.method === PaymentMethod.WALLET) {
        // Reembolso a wallet
        await this.creditWallet(originalPayment.userId, refundAmount, refund.id);
        refund.status = PaymentStatus.REFUNDED;
        refund.refundedAt = new Date();
      }

      // Guardar reembolso
      await admin.firestore()
        .collection('payments')
        .doc(refund.id)
        .set(refund);

      // Actualizar pago original
      await admin.firestore()
        .collection('payments')
        .doc(data.paymentId)
        .update({
          status: PaymentStatus.REFUNDED,
          refundedAt: new Date(),
          refundAmount: refundAmount
        });

      logger.info(`Reembolso procesado: ${refund.id}`);
      return refund;

    } catch (error) {
      logger.error('Error procesando reembolso:', error);
      throw error;
    }
  }

  /**
   * 📄 Generar factura
   */
  async generateInvoice(payment: Payment): Promise<Invoice> {
    try {
      // Obtener información del usuario
      const userDoc = await admin.firestore()
        .collection('users')
        .doc(payment.userId)
        .get();

      const userData = userDoc.data();

      // Generar número de factura
      const invoiceNumber = `INV-${new Date().getFullYear()}-${Date.now().toString().slice(-6)}`;

      const invoice: Invoice = {
        id: crypto.randomBytes(16).toString('hex'),
        paymentId: payment.id,
        rideId: payment.rideId,
        userId: payment.userId,
        invoiceNumber,
        subtotal: payment.metadata?.subtotal || payment.amount,
        tax: payment.amount * 0.16, // IVA 16%
        total: payment.amount,
        currency: payment.currency,
        customerInfo: {
          name: userData?.name || 'Cliente',
          email: userData?.email,
          phone: userData?.phone,
          taxId: userData?.taxId
        },
        items: [{
          description: `Servicio de transporte - Viaje ${payment.rideId}`,
          quantity: 1,
          unitPrice: payment.metadata?.subtotal || payment.amount,
          total: payment.metadata?.subtotal || payment.amount
        }],
        status: 'paid',
        paidAt: payment.completedAt,
        createdAt: new Date(),
        updatedAt: new Date()
      };

      // Agregar propina si existe
      if (payment.metadata?.tip) {
        invoice.items.push({
          description: 'Propina',
          quantity: 1,
          unitPrice: payment.metadata.tip,
          total: payment.metadata.tip
        });
      }

      // Guardar factura
      await admin.firestore()
        .collection('invoices')
        .doc(invoice.id)
        .set(invoice);

      // Generar PDF (aquí iría la generación real del PDF)
      // invoice.pdfUrl = await this.generateInvoicePDF(invoice);

      logger.info(`Factura generada: ${invoice.invoiceNumber}`);
      return invoice;

    } catch (error) {
      logger.error('Error generando factura:', error);
      throw error;
    }
  }

  // 🔧 FUNCIONES AUXILIARES
  // ========================

  private async getPaymentMethod(methodId: string, userId: string): Promise<PaymentMethodInfo> {
    const methodDoc = await admin.firestore()
      .collection('payment_methods')
      .doc(methodId)
      .get();

    if (!methodDoc.exists || methodDoc.data()?.userId !== userId) {
      throw new AppError('Método de pago no encontrado', 404, 'PAYMENT_METHOD_NOT_FOUND');
    }

    return methodDoc.data() as PaymentMethodInfo;
  }

  private async getOrCreateStripeCustomer(userId: string): Promise<string> {
    // Buscar cliente existente
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(userId)
      .get();

    const userData = userDoc.data();
    
    if (userData?.stripeCustomerId) {
      return userData.stripeCustomerId;
    }

    // Crear nuevo cliente
    const customer = await stripe.customers.create({
      metadata: { userId },
      email: userData?.email,
      name: userData?.name,
      phone: userData?.phone
    });

    // Guardar ID
    await admin.firestore()
      .collection('users')
      .doc(userId)
      .update({ stripeCustomerId: customer.id });

    return customer.id;
  }

  private async getStripeConnectAccount(driverId: string): Promise<string> {
    // Aquí iría la lógica de Stripe Connect para conductores
    // Por ahora retornamos un placeholder
    return 'acct_driver_' + driverId;
  }

  private async getWallet(userId: string): Promise<Wallet | null> {
    const walletDoc = await admin.firestore()
      .collection('wallets')
      .doc(userId)
      .get();

    return walletDoc.exists ? walletDoc.data() as Wallet : null;
  }

  private async creditWallet(userId: string, amount: number, referenceId: string): Promise<void> {
    await admin.firestore()
      .collection('wallets')
      .doc(userId)
      .update({
        balance: admin.firestore.FieldValue.increment(amount),
        lastActivity: new Date(),
        updatedAt: new Date()
      });

    // Registrar transacción
    await admin.firestore()
      .collection('wallet_transactions')
      .add({
        walletId: userId,
        type: 'credit',
        amount,
        referenceId,
        timestamp: new Date()
      });
  }

  private async debitWallet(userId: string, amount: number, referenceId: string): Promise<void> {
    await admin.firestore()
      .collection('wallets')
      .doc(userId)
      .update({
        balance: admin.firestore.FieldValue.increment(-amount),
        usedToday: admin.firestore.FieldValue.increment(amount),
        usedThisMonth: admin.firestore.FieldValue.increment(amount),
        lastActivity: new Date(),
        updatedAt: new Date()
      });

    // Registrar transacción
    await admin.firestore()
      .collection('wallet_transactions')
      .add({
        walletId: userId,
        type: 'debit',
        amount,
        referenceId,
        timestamp: new Date()
      });
  }

  private async creditDriver(driverId: string, amount: number): Promise<void> {
    await admin.firestore()
      .collection('driver_earnings')
      .doc(driverId)
      .update({
        balance: admin.firestore.FieldValue.increment(amount),
        totalEarnings: admin.firestore.FieldValue.increment(amount),
        updatedAt: new Date()
      });
  }

  private async applyPromoCode(code: string, amount: number): Promise<number> {
    // Aquí iría la lógica de códigos promocionales
    // Por ahora retornamos un descuento fijo
    if (code === 'WELCOME20') {
      return amount * 0.20; // 20% descuento
    }
    return 0;
  }

  private async setDefaultPaymentMethod(userId: string, methodId: string): Promise<void> {
    // Desmarcar método actual como default
    const currentDefault = await admin.firestore()
      .collection('payment_methods')
      .where('userId', '==', userId)
      .where('isDefault', '==', true)
      .get();

    const batch = admin.firestore().batch();
    
    currentDefault.forEach(doc => {
      batch.update(doc.ref, { isDefault: false });
    });

    await batch.commit();
  }

  /**
   * 🔔 Procesar webhook de Stripe
   */
  async handleStripeWebhook(signature: string, rawBody: string): Promise<void> {
    try {
      const event = stripe.webhooks.constructEvent(rawBody, signature, this.webhookSecret);

      switch (event.type) {
        case 'payment_intent.succeeded':
          await this.handlePaymentSuccess(event.data.object as Stripe.PaymentIntent);
          break;
        case 'payment_intent.payment_failed':
          await this.handlePaymentFailure(event.data.object as Stripe.PaymentIntent);
          break;
        case 'charge.refunded':
          await this.handleRefundCompleted(event.data.object as Stripe.Charge);
          break;
      }

      logger.info(`Webhook Stripe procesado: ${event.type}`);
    } catch (error) {
      logger.error('Error procesando webhook Stripe:', error);
      throw error;
    }
  }

  private async handlePaymentSuccess(paymentIntent: Stripe.PaymentIntent): Promise<void> {
    const paymentId = paymentIntent.metadata.paymentId;
    
    await admin.firestore()
      .collection('payments')
      .doc(paymentId)
      .update({
        status: PaymentStatus.COMPLETED,
        completedAt: new Date(),
        updatedAt: new Date()
      });

    this.emit('payment:success', { paymentId });
  }

  private async handlePaymentFailure(paymentIntent: Stripe.PaymentIntent): Promise<void> {
    const paymentId = paymentIntent.metadata.paymentId;
    
    await admin.firestore()
      .collection('payments')
      .doc(paymentId)
      .update({
        status: PaymentStatus.FAILED,
        failedAt: new Date(),
        updatedAt: new Date()
      });

    this.emit('payment:failed', { paymentId });
  }

  private async handleRefundCompleted(charge: Stripe.Charge): Promise<void> {
    // Actualizar estado del reembolso
    logger.info(`Reembolso completado: ${charge.id}`);
  }
}

// Exportar instancia única
export const paymentService = new PaymentService();