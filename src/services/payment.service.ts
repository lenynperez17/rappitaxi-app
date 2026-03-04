import { MercadoPagoConfig, Preference, Payment, PaymentRefund } from 'mercadopago';
import { v4 as uuidv4 } from 'uuid';
import admin from 'firebase-admin';
import logger from '../utils/logger';
import dotenv from 'dotenv';

// Cargar variables de entorno
dotenv.config();

export class PaymentService {
  private client: MercadoPagoConfig;
  private preferenceAPI: Preference;
  private paymentAPI: Payment;
  private refundAPI: PaymentRefund;

  constructor() {
    // Configurar MercadoPago para Perú con CREDENCIALES REALES DE PRODUCCIÓN
    this.client = new MercadoPagoConfig({ 
      accessToken: process.env.MERCADOPAGO_ACCESS_TOKEN!,
      options: { timeout: 5000 }
    });
    
    this.preferenceAPI = new Preference(this.client);
    this.paymentAPI = new Payment(this.client);
    this.refundAPI = new PaymentRefund(this.client);

    logger.info('💳 Servicio de MercadoPago configurado para Perú');
  }

  /**
   * Crear preferencia de pago para un viaje
   */
  async createPaymentPreference(rideData: {
    rideId: string;
    amount: number;
    passengerId: string;
    passengerEmail: string;
    passengerName: string;
    description: string;
  }) {
    try {
      const preference = {
        items: [
          {
            id: rideData.rideId,
            title: 'Viaje Rappi Team',
            description: rideData.description,
            picture_url: 'https://rapiteam.app/logo.png',
            category_id: 'transport',
            quantity: 1,
            currency_id: 'PEN', // Soles peruanos
            unit_price: rideData.amount
          }
        ],
        payer: {
          name: rideData.passengerName,
          email: rideData.passengerEmail,
          identification: {
            type: 'DNI',
            number: '12345678'
          }
        },
        back_urls: {
          success: `${process.env.APP_URL}/payment/success`,
          failure: `${process.env.APP_URL}/payment/failure`,
          pending: `${process.env.APP_URL}/payment/pending`
        },
        auto_return: 'approved',
        payment_methods: {
          excluded_payment_methods: [],
          excluded_payment_types: [],
          installments: 1
        },
        notification_url: `${process.env.API_URL}/webhooks/mercadopago`,
        statement_descriptor: 'RAPPI TEAM',
        external_reference: rideData.rideId,
        expires: true,
        expiration_date_from: new Date().toISOString(),
        expiration_date_to: new Date(Date.now() + 30 * 60 * 1000).toISOString() // 30 minutos
      };

      const response = await this.preferenceAPI.create({ body: preference });

      // Guardar preferencia en Firebase
      await admin.firestore().collection('payment_preferences').doc(rideData.rideId).set({
        preferenceId: response.id,
        initPoint: response.init_point,
        sandboxInitPoint: response.sandbox_init_point,
        amount: rideData.amount,
        status: 'pending',
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });

      logger.info(`✅ Preferencia de pago creada: ${response.id}`);

      return {
        preferenceId: response.id,
        initPoint: response.init_point, // URL de pago producción
        sandboxInitPoint: response.sandbox_init_point // URL de pago testing
      };
    } catch (error) {
      logger.error('Error creando preferencia de pago:', error);
      throw error;
    }
  }

  /**
   * Procesar pago directo con tarjeta
   */
  async processCardPayment(paymentData: {
    token: string;
    installments: number;
    amount: number;
    description: string;
    payerEmail: string;
    rideId: string;
  }) {
    try {
      const payment = {
        transaction_amount: paymentData.amount,
        token: paymentData.token,
        description: paymentData.description,
        installments: paymentData.installments,
        payment_method_id: 'visa', // o 'mastercard', 'amex', etc
        payer: {
          email: paymentData.payerEmail
        },
        metadata: {
          ride_id: paymentData.rideId
        }
      };

      const response = await this.paymentAPI.create({ body: payment });

      // Actualizar estado en Firebase
      await admin.firestore().collection('payments').doc(paymentData.rideId).set({
        paymentId: response.id,
        status: response.status,
        statusDetail: response.status_detail,
        amount: response.transaction_amount,
        method: response.payment_method_id,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });

      logger.info(`✅ Pago procesado: ${response.id} - Status: ${response.status}`);

      return {
        paymentId: response.id,
        status: response.status,
        statusDetail: response.status_detail
      };
    } catch (error) {
      logger.error('Error procesando pago:', error);
      throw error;
    }
  }

  /**
   * Procesar pago con Yape o Plin (métodos populares en Perú)
   */
  async processDigitalWalletPayment(walletData: {
    phoneNumber: string;
    amount: number;
    rideId: string;
    walletType: 'yape' | 'plin';
  }) {
    try {
      // MercadoPago en Perú soporta estos métodos
      const payment = {
        transaction_amount: walletData.amount,
        payment_method_id: walletData.walletType,
        description: `Viaje Rappi Team - ${walletData.rideId}`,
        payer: {
          phone: {
            number: walletData.phoneNumber
          }
        }
      };

      const response = await this.paymentAPI.create({ body: payment });

      return {
        paymentId: response.id,
        status: response.status,
        qrCode: response.point_of_interaction?.transaction_data?.qr_code
      };
    } catch (error) {
      logger.error('Error con billetera digital:', error);
      throw error;
    }
  }

  /**
   * Verificar estado de un pago
   */
  async checkPaymentStatus(paymentId: string) {
    try {
      const response = await this.paymentAPI.get({ id: paymentId });
      
      return {
        status: response.status,
        statusDetail: response.status_detail,
        amount: response.transaction_amount,
        dateApproved: response.date_approved
      };
    } catch (error) {
      logger.error('Error verificando estado de pago:', error);
      throw error;
    }
  }

  /**
   * Procesar reembolso
   */
  async refundPayment(paymentId: string, amount?: number) {
    try {
      // Usar PaymentRefund para reembolsos en v2
      const refundRequest: any = {
        payment_id: paymentId
      };

      // Si se especifica monto, es reembolso parcial
      if (amount) {
        refundRequest.body = { amount };
      }

      const response = await this.refundAPI.create(refundRequest);

      // Actualizar en Firebase
      await admin.firestore().collection('refunds').add({
        paymentId,
        refundId: response.id,
        amount: response.amount || amount,
        status: 'refunded',
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });

      logger.info(`✅ Reembolso procesado: ${response.id}`);

      return {
        refundId: response.id,
        amount: response.amount || amount,
        status: 'refunded'
      };
    } catch (error) {
      logger.error('Error procesando reembolso:', error);
      throw error;
    }
  }

  /**
   * Webhook de MercadoPago para notificaciones IPN
   */
  async handleWebhook(data: any) {
    try {
      if (data.type === 'payment') {
        const paymentId = data.data.id;
        const payment = await this.checkPaymentStatus(paymentId);

        // Actualizar estado en Firebase
        await admin.firestore().collection('payments').doc(paymentId).update({
          status: payment.status,
          statusDetail: payment.statusDetail,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        // Si el pago fue aprobado, actualizar el viaje
        if (payment.status === 'approved') {
          const paymentDoc = await admin.firestore().collection('payments').doc(paymentId).get();
          const rideId = paymentDoc.data()?.rideId;

          if (rideId) {
            await admin.firestore().collection('rides').doc(rideId).update({
              paymentStatus: 'paid',
              paymentId: paymentId,
              paidAt: admin.firestore.FieldValue.serverTimestamp()
            });
          }
        }

        logger.info(`Webhook procesado: Pago ${paymentId} - Status: ${payment.status}`);
      }
    } catch (error) {
      logger.error('Error procesando webhook:', error);
      throw error;
    }
  }

  /**
   * Calcular comisión de Rappi Team (20%)
   */
  calculateCommission(amount: number): { driverAmount: number; platformCommission: number } {
    const commissionRate = 0.20; // 20% para la plataforma
    const platformCommission = amount * commissionRate;
    const driverAmount = amount - platformCommission;

    return {
      driverAmount: Math.round(driverAmount * 100) / 100,
      platformCommission: Math.round(platformCommission * 100) / 100
    };
  }
}

export default new PaymentService();