import axios from 'axios';

/// Servicio para la integración con Izipay (API REST Krypton)
/// Genera formTokens para el formulario embebido de pago
export class IzipayService {
  private shopId: string;
  private password: string;
  private publicKey: string;
  private hmacKey: string;
  private keyRSA: string;
  private isProduction: boolean;

  constructor() {
    const mode = process.env.IZYPAY_MODE || 'test';
    this.isProduction = mode === 'production' || mode === 'prod';
    this.shopId = process.env.IZYPAY_SHOP_ID || '';
    this.keyRSA = process.env.IZYPAY_KEY_RSA || '';

    if (this.isProduction) {
      this.password = process.env.IZYPAY_PROD_PASSWORD || '';
      this.publicKey = process.env.IZYPAY_PROD_PUBLIC_KEY || '';
      this.hmacKey = process.env.IZYPAY_HMAC_PROD || '';
    } else {
      this.password = process.env.IZYPAY_TEST_PASSWORD || '';
      this.publicKey = process.env.IZYPAY_TEST_PUBLIC_KEY || '';
      this.hmacKey = process.env.IZYPAY_HMAC_TEST || '';
    }

    if (!this.shopId || !this.password || !this.publicKey) {
      console.error('❌ Credenciales de Izipay no configuradas en .env');
    }
  }

  /// Genera un formToken para el formulario embebido de Izipay
  async createFormToken(params: {
    amount: number;
    currency?: string;
    orderId: string;
    email: string;
    firstName?: string;
    lastName?: string;
    phone?: string;
  }): Promise<{
    success: boolean;
    formToken?: string;
    publicKey?: string;
    error?: string;
  }> {
    const apiUrl = 'https://api.micuentaweb.pe/api-payment/V4/Charge/CreatePayment';

    // El monto en la API de Izipay es en céntimos (1000 = S/ 10.00)
    const amountInCents = Math.round(params.amount * 100);

    const payload = {
      amount: amountInCents,
      currency: params.currency || 'PEN',
      orderId: params.orderId,
      formAction: 'PAYMENT',
      customer: {
        email: params.email,
        billingDetails: {
          firstName: params.firstName || 'Cliente',
          lastName: params.lastName || 'RapiTeam',
          phoneNumber: params.phone || '999999999',
          address: 'Lima',
          country: 'PE',
          city: 'Lima',
          state: 'Lima',
          zipCode: '15001',
        },
      },
    };

    try {
      console.log(`💳 Izipay: Generando formToken - orderId=${params.orderId}, monto=S/ ${params.amount.toFixed(2)}`);

      // Basic Auth: shopId:password
      const authString = Buffer.from(`${this.shopId}:${this.password}`).toString('base64');

      const response = await axios.post(apiUrl, payload, {
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Basic ${authString}`,
        },
        timeout: 15000,
      });

      if (response.data.status === 'SUCCESS' && response.data.answer?.formToken) {
        console.log(`✅ Izipay: formToken generado exitosamente para orderId=${params.orderId}`);
        return {
          success: true,
          formToken: response.data.answer.formToken,
          publicKey: this.publicKey,
        };
      }

      console.error('❌ Izipay: Respuesta inesperada:', JSON.stringify(response.data));
      return {
        success: false,
        error: response.data.answer?.errorMessage || 'Respuesta inesperada de Izipay',
      };
    } catch (error: any) {
      console.error('❌ Izipay: Error generando formToken:', error.response?.data || error.message);
      return {
        success: false,
        error: error.response?.data?.answer?.errorMessage || error.message || 'Error de comunicación con Izipay',
      };
    }
  }

  /// Obtiene la public key para el cliente
  getPublicKey(): string {
    return this.publicKey;
  }

  /// Obtiene la clave HMAC para validación de IPN
  getHmacKey(): string {
    return this.hmacKey;
  }

  /// Obtiene la clave RSA pública para el SDK Web-Core
  getKeyRSA(): string {
    return this.keyRSA;
  }

  /// Indica si está en modo producción
  getIsProduction(): boolean {
    return this.isProduction;
  }

  /// Obtiene el código de comercio (merchantCode / shopId)
  getShopId(): string {
    return this.shopId;
  }
}
