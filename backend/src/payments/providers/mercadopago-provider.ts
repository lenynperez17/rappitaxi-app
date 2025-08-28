import { MercadoPagoConfig, Payment, Preference } from 'mercadopago';
import { logger } from '@shared/utils/logger';

export class MercadoPagoProvider {
  private client: MercadoPagoConfig;
  private payment: Payment;
  private preference: Preference;

  constructor() {
    const accessToken = process.env.MERCADOPAGO_ACCESS_TOKEN;
    if (!accessToken) {
      throw new Error('MercadoPago access token not configured');
    }

    this.client = new MercadoPagoConfig({
      accessToken,
      options: {
        timeout: 5000,
        idempotencyKey: 'oasis-taxi-backend',
      },
    });

    this.payment = new Payment(this.client);
    this.preference = new Preference(this.client);
  }

  /**
   * Process a payment using MercadoPago
   */
  async processPayment(
    amount: number,
    token: string,
    metadata: {
      paymentId: string;
      rideId: string;
      userId: string;
    }
  ): Promise<{
    success: boolean;
    transactionId?: string;
    response?: any;
    error?: string;
  }> {
    try {
      const paymentData = {
        transaction_amount: amount,
        token,
        description: `Pago viaje OASIS Taxi - ${metadata.rideId}`,
        installments: 1,
        payment_method_id: 'visa', // This should be detected from token
        payer: {
          email: 'user@oasistaxiapp.com', // Should get from user data
        },
        external_reference: metadata.paymentId,
        metadata: {
          ride_id: metadata.rideId,
          user_id: metadata.userId,
        },
        notification_url: `${process.env.BACKEND_URL}/api/payments/webhooks/mercadopago`,
      };

      const response = await this.payment.create({ body: paymentData });

      if (response.status === 'approved') {
        logger.info('MercadoPago payment approved', {
          paymentId: metadata.paymentId,
          transactionId: response.id,
          amount,
        });

        return {
          success: true,
          transactionId: response.id?.toString(),
          response: response,
        };
      } else {
        logger.warn('MercadoPago payment not approved', {
          paymentId: metadata.paymentId,
          status: response.status,
          statusDetail: response.status_detail,
        });

        return {
          success: false,
          error: `Payment ${response.status}: ${response.status_detail}`,
          response: response,
        };
      }
    } catch (error: any) {
      logger.error('MercadoPago payment error', {
        error: error.message,
        paymentId: metadata.paymentId,
        amount,
      });

      return {
        success: false,
        error: error.message,
      };
    }
  }

  /**
   * Refund a payment
   */
  async refundPayment(
    transactionId: string,
    amount: number,
    reason?: string
  ): Promise<{
    success: boolean;
    refundId?: string;
    error?: string;
  }> {
    try {
      const refundData = {
        amount,
        reason: reason || 'Reembolso solicitado por el usuario',
      };

      // Create refund
      const response = await this.payment.refund({
        id: parseInt(transactionId),
        body: refundData,
      });

      if (response.status === 'approved') {
        logger.info('MercadoPago refund approved', {
          transactionId,
          refundId: response.id,
          amount,
        });

        return {
          success: true,
          refundId: response.id?.toString(),
        };
      } else {
        logger.warn('MercadoPago refund not approved', {
          transactionId,
          status: response.status,
        });

        return {
          success: false,
          error: `Refund ${response.status}`,
        };
      }
    } catch (error: any) {
      logger.error('MercadoPago refund error', {
        error: error.message,
        transactionId,
        amount,
      });

      return {
        success: false,
        error: error.message,
      };
    }
  }

  /**
   * Generate a payment link
   */
  async generatePaymentLink(
    amount: number,
    options: {
      userId: string;
      description: string;
      expiresIn: number;
    }
  ): Promise<{
    url: string;
    id: string;
  }> {
    try {
      const preferenceData = {
        items: [
          {
            title: options.description,
            unit_price: amount,
            quantity: 1,
            currency_id: 'ARS',
          },
        ],
        payer: {
          email: 'user@oasistaxiapp.com', // Should get from user data
        },
        back_urls: {
          success: `${process.env.FRONTEND_URL}/payment/success`,
          failure: `${process.env.FRONTEND_URL}/payment/failure`,
          pending: `${process.env.FRONTEND_URL}/payment/pending`,
        },
        auto_return: 'approved',
        external_reference: options.userId,
        expires: true,
        expiration_date_from: new Date().toISOString(),
        expiration_date_to: new Date(Date.now() + options.expiresIn * 1000).toISOString(),
        notification_url: `${process.env.BACKEND_URL}/api/payments/webhooks/mercadopago`,
      };

      const response = await this.preference.create({ body: preferenceData });

      if (response.init_point) {
        logger.info('MercadoPago payment link generated', {
          userId: options.userId,
          preferenceId: response.id,
          amount,
        });

        return {
          url: response.init_point,
          id: response.id!,
        };
      } else {
        throw new Error('No payment URL generated');
      }
    } catch (error: any) {
      logger.error('MercadoPago payment link generation error', {
        error: error.message,
        userId: options.userId,
        amount,
      });

      throw error;
    }
  }

  /**
   * Validate a payment
   */
  async validatePayment(transactionId: string): Promise<{
    valid: boolean;
    data?: any;
  }> {
    try {
      const response = await this.payment.get({ id: parseInt(transactionId) });

      return {
        valid: response.status === 'approved',
        data: response,
      };
    } catch (error: any) {
      logger.error('MercadoPago payment validation error', {
        error: error.message,
        transactionId,
      });

      return {
        valid: false,
      };
    }
  }

  /**
   * Verify payment method
   */
  async verifyPaymentMethod(token: string): Promise<any> {
    try {
      // This would typically call MercadoPago's API to verify the payment method
      // For now, return a mock response
      return {
        type: 'credit_card',
        brand: 'visa',
        lastFour: '4242',
        expiryMonth: 12,
        expiryYear: 2025,
        verified: true,
      };
    } catch (error: any) {
      logger.error('MercadoPago payment method verification error', {
        error: error.message,
        token,
      });

      throw error;
    }
  }

  /**
   * Process webhook notification
   */
  async processWebhook(
    body: any,
    headers: any
  ): Promise<{
    paymentId?: string;
    status?: string;
    amount?: number;
    transactionId?: string;
    data?: any;
  }> {
    try {
      logger.info('Processing MercadoPago webhook', { body, headers });

      // Verify webhook signature (implement signature verification)
      if (!this.verifyWebhookSignature(body, headers)) {
        throw new Error('Invalid webhook signature');
      }

      const { type, data } = body;

      if (type === 'payment') {
        const paymentId = data.id;
        const paymentInfo = await this.payment.get({ id: paymentId });

        let status = 'pending';
        switch (paymentInfo.status) {
          case 'approved':
            status = 'completed';
            break;
          case 'rejected':
          case 'cancelled':
            status = 'failed';
            break;
          case 'pending':
          case 'in_process':
          case 'in_mediation':
            status = 'pending';
            break;
        }

        return {
          paymentId: paymentInfo.external_reference,
          status,
          amount: paymentInfo.transaction_amount,
          transactionId: paymentInfo.id?.toString(),
          data: paymentInfo,
        };
      }

      return {};
    } catch (error: any) {
      logger.error('MercadoPago webhook processing error', {
        error: error.message,
        body,
      });

      throw error;
    }
  }

  /**
   * Verify webhook signature
   */
  private verifyWebhookSignature(body: any, headers: any): boolean {
    // Implement MercadoPago webhook signature verification
    // This is a simplified version - implement proper verification
    const signature = headers['x-signature'];
    const requestId = headers['x-request-id'];
    
    if (!signature || !requestId) {
      return false;
    }

    // In production, verify the signature using MercadoPago's secret
    // For now, return true for development
    return true;
  }

  /**
   * Get payment status
   */
  async getPaymentStatus(transactionId: string): Promise<{
    status: string;
    amount?: number;
    currency?: string;
    createdAt?: Date;
  }> {
    try {
      const response = await this.payment.get({ id: parseInt(transactionId) });

      let status = 'pending';
      switch (response.status) {
        case 'approved':
          status = 'completed';
          break;
        case 'rejected':
        case 'cancelled':
          status = 'failed';
          break;
        case 'pending':
        case 'in_process':
          status = 'pending';
          break;
      }

      return {
        status,
        amount: response.transaction_amount,
        currency: response.currency_id,
        createdAt: response.date_created ? new Date(response.date_created) : undefined,
      };
    } catch (error: any) {
      logger.error('Error getting MercadoPago payment status', {
        error: error.message,
        transactionId,
      });

      return { status: 'unknown' };
    }
  }

  /**
   * Cancel a payment
   */
  async cancelPayment(transactionId: string): Promise<{
    success: boolean;
    error?: string;
  }> {
    try {
      await this.payment.cancel({ id: parseInt(transactionId) });

      logger.info('MercadoPago payment cancelled', { transactionId });

      return { success: true };
    } catch (error: any) {
      logger.error('Error cancelling MercadoPago payment', {
        error: error.message,
        transactionId,
      });

      return {
        success: false,
        error: error.message,
      };
    }
  }
}