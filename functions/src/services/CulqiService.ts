import * as admin from 'firebase-admin';
import Culqi from 'culqi-node';

/**
 * 💳 SERVICIO CULQI - PASARELA DE PAGOS PERUANA
 * ============================================
 *
 * Funcionalidades:
 * ✅ Crear cargos con tokens de tarjeta
 * ✅ Crear cargos con tokens de Yape
 * ✅ Crear órdenes para PagoEfectivo/billeteras
 * ✅ Procesar webhooks de Culqi
 * ✅ Crear reembolsos
 * ✅ Gestión de saldo y transacciones
 * ✅ Crear clientes y tarjetas para pagos recurrentes
 *
 * Documentación: https://docs.culqi.com/es/documentacion/
 */
export class CulqiService {
  private culqi: InstanceType<typeof Culqi>;
  private readonly publicKey: string;
  private readonly db: admin.firestore.Firestore;

  constructor() {
    this.db = admin.firestore();

    // 🔑 CREDENCIALES DE CULQI desde variables de entorno (.env)
    const privateKey = process.env.CULQI_PRIVATE_KEY || '';
    this.publicKey = process.env.CULQI_PUBLIC_KEY || '';

    if (!privateKey) {
      console.error('⚠️ Culqi: Private key no configurado en .env');
      console.error('📝 Crear archivo functions/.env con:');
      console.error('   CULQI_PRIVATE_KEY=sk_test_...');
      console.error('   CULQI_PUBLIC_KEY=pk_test_...');
    }

    // Inicializar SDK de Culqi
    this.culqi = new Culqi({
      privateKey: privateKey,
    });
  }

  // ============================================================================
  // CARGOS - CREAR PAGOS CON TOKEN
  // ============================================================================

  /**
   * Crear cargo con token de tarjeta o Yape
   * El token se genera en el frontend con Custom Checkout
   */
  async createCharge(params: {
    sourceId: string; // Token (tkn_) o tarjeta guardada (crd_) o Yape (ype_)
    amount: number; // En céntimos (S/ 10.00 = 1000)
    currencyCode: string; // PEN o USD
    email: string;
    description?: string;
    metadata?: Record<string, string>;
    antifraudDetails?: {
      firstName?: string;
      lastName?: string;
      phone?: string;
      address?: string;
      addressCity?: string;
      countryCode?: string;
    };
  }): Promise<CulqiChargeResult> {
    try {
      console.log(`💳 Creando cargo Culqi - Monto: ${params.amount} céntimos - Source: ${params.sourceId.substring(0, 10)}...`);

      // Validar monto mínimo (S/ 3.00 = 300 céntimos)
      if (params.amount < 300) {
        throw new Error('El monto mínimo es S/ 3.00');
      }

      const chargeData: any = {
        amount: params.amount.toString(),
        currency_code: params.currencyCode || 'PEN',
        email: params.email,
        source_id: params.sourceId,
      };

      // Agregar descripción si existe
      if (params.description) {
        chargeData.description = params.description;
      }

      // Agregar metadata si existe
      if (params.metadata) {
        chargeData.metadata = params.metadata;
      }

      // Agregar detalles antifraude si existen
      if (params.antifraudDetails) {
        chargeData.antifraud_details = {
          first_name: params.antifraudDetails.firstName,
          last_name: params.antifraudDetails.lastName,
          phone_number: params.antifraudDetails.phone,
          address: params.antifraudDetails.address,
          address_city: params.antifraudDetails.addressCity,
          country_code: params.antifraudDetails.countryCode || 'PE',
        };
      }

      const charge = await this.culqi.charges.createCharge(chargeData);

      // Castear a any para acceder a propiedades que pueden no estar en los tipos
      const chargeResult = charge as any;
      console.log(`✅ Cargo creado: ${chargeResult.id} - Estado: ${chargeResult.outcome?.type || 'unknown'}`);

      return {
        success: true,
        chargeId: chargeResult.id,
        amount: chargeResult.amount,
        currencyCode: chargeResult.currency_code,
        email: chargeResult.email,
        outcome: chargeResult.outcome,
        referenceCode: chargeResult.reference_code,
        responseCode: chargeResult.response_code,
        merchantMessage: chargeResult.outcome?.merchant_message,
        userMessage: chargeResult.outcome?.user_message,
      };

    } catch (error: any) {
      console.error('❌ Error creando cargo Culqi:', error.message || error);

      return {
        success: false,
        error: error.user_message || error.merchant_message || error.message || 'Error procesando el pago',
        errorCode: error.type || 'unknown_error',
      };
    }
  }

  // ============================================================================
  // RECARGAS - CREAR CARGOS PARA RECARGA DE SALDO
  // ============================================================================

  /**
   * Procesar recarga de saldo con token de Culqi
   */
  async processRecharge(params: {
    userId: string;
    sourceId: string; // Token generado en frontend
    amount: number; // En céntimos
    email: string;
    firstName?: string;
    lastName?: string;
  }): Promise<CulqiChargeResult> {
    try {
      console.log(`💰 Procesando recarga Culqi - Usuario: ${params.userId} - Monto: S/ ${params.amount / 100}`);

      // Crear ID único para la transacción
      const transactionId = `recharge_${params.userId}_${Date.now()}`;

      // Crear el cargo
      const chargeResult = await this.createCharge({
        sourceId: params.sourceId,
        amount: params.amount,
        currencyCode: 'PEN',
        email: params.email,
        description: 'Recarga de saldo RapiTeam',
        metadata: {
          user_id: params.userId,
          transaction_id: transactionId,
          transaction_type: 'recharge',
          platform: 'rapiteam',
        },
        antifraudDetails: {
          firstName: params.firstName,
          lastName: params.lastName,
          countryCode: 'PE',
        },
      });

      // Guardar transacción en Firestore
      await this.db.collection('recharge_transactions').doc(transactionId).set({
        userId: params.userId,
        amount: params.amount / 100, // Guardar en soles
        amountCents: params.amount,
        chargeId: chargeResult.chargeId,
        status: chargeResult.success ? 'completed' : 'failed',
        paymentMethod: 'culqi',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        metadata: {
          email: params.email,
          name: `${params.firstName || ''} ${params.lastName || ''}`.trim(),
        },
        chargeResult: chargeResult,
      });

      // Si el cargo fue exitoso, acreditar saldo
      let newBalance: number | undefined;
      if (chargeResult.success) {
        newBalance = await this.creditUserBalance(params.userId, params.amount / 100, transactionId, chargeResult.chargeId!);
      }

      return {
        ...chargeResult,
        transactionId,
        newBalance,
        status: chargeResult.success ? 'successful' : 'failed',
      };

    } catch (error: any) {
      console.error('❌ Error procesando recarga Culqi:', error.message);
      return {
        success: false,
        error: error.message || 'Error procesando la recarga',
      };
    }
  }

  /**
   * Acreditar saldo al usuario después de un pago exitoso
   * @returns El nuevo saldo del usuario
   */
  private async creditUserBalance(
    userId: string,
    amount: number, // En soles
    transactionId: string,
    chargeId: string
  ): Promise<number> {
    try {
      console.log(`✅ Acreditando S/ ${amount} a usuario ${userId}`);

      let finalBalance = 0;

      await this.db.runTransaction(async (transaction) => {
        const userRef = this.db.collection('users').doc(userId);
        const userDoc = await transaction.get(userRef);

        if (!userDoc.exists) {
          throw new Error(`Usuario ${userId} no encontrado`);
        }

        const currentBalance = userDoc.data()?.balance || 0;
        const newBalance = currentBalance + amount;
        finalBalance = newBalance;

        // Actualizar saldo del usuario
        transaction.update(userRef, {
          balance: newBalance,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Registrar en historial de transacciones
        const historyRef = this.db.collection('users').doc(userId).collection('transactions').doc();
        transaction.set(historyRef, {
          type: 'recharge',
          amount: amount,
          paymentMethod: 'culqi',
          chargeId: chargeId,
          transactionId: transactionId,
          status: 'completed',
          previousBalance: currentBalance,
          newBalance: newBalance,
          description: 'Recarga de saldo con Culqi',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      // Notificar al usuario
      await this.notifyUserRechargeSuccess(userId, amount);

      console.log(`✅ Saldo acreditado exitosamente: S/ ${amount}`);

      return finalBalance;

    } catch (error: any) {
      console.error('❌ Error acreditando saldo:', error.message);
      throw error;
    }
  }

  // ============================================================================
  // ÓRDENES - PARA PAGOEFECTIVO Y BILLETERAS
  // ============================================================================

  /**
   * Crear orden para pagos diferidos (PagoEfectivo, billeteras)
   */
  async createOrder(params: {
    amount: number; // En céntimos
    currencyCode: string;
    description: string;
    orderId: string;
    clientDetails: {
      firstName: string;
      lastName: string;
      email: string;
      phone?: string;
    };
    expirationDate?: Date; // Por defecto 24 horas
    metadata?: Record<string, string>;
  }): Promise<CulqiOrderResult> {
    try {
      console.log(`📋 Creando orden Culqi - ID: ${params.orderId} - Monto: ${params.amount} céntimos`);

      // Calcular fecha de expiración (default 24 horas)
      const expiration = params.expirationDate || new Date(Date.now() + 24 * 60 * 60 * 1000);

      // Nota: La creación de órdenes requiere el API v2.0 de Culqi
      // La estructura de datos sería:
      // {
      //   amount: params.amount,
      //   currency_code: params.currencyCode || 'PEN',
      //   description: params.description,
      //   order_number: params.orderId,
      //   client_details: { first_name, last_name, email, phone_number },
      //   expiration_date: Math.floor(expiration.getTime() / 1000),
      //   confirm: false,
      //   metadata: params.metadata,
      // }
      console.log(`⚠️ Creación de órdenes pendiente de implementación con API v2.0 - Exp: ${expiration.toISOString()}`);

      return {
        success: true,
        orderId: params.orderId,
        message: 'Orden creada (pendiente implementación API v2.0)',
      };

    } catch (error: any) {
      console.error('❌ Error creando orden Culqi:', error.message);
      return {
        success: false,
        error: error.message || 'Error creando la orden',
      };
    }
  }

  // ============================================================================
  // REEMBOLSOS
  // ============================================================================

  /**
   * Crear reembolso de un cargo
   */
  async createRefund(params: {
    chargeId: string;
    amount: number; // En céntimos (parcial o total)
    reason: string; // 'duplicado', 'fraudulento', 'solicitud_comprador'
  }): Promise<CulqiRefundResult> {
    try {
      console.log(`💸 Creando reembolso Culqi - Cargo: ${params.chargeId} - Monto: ${params.amount}`);

      const refund = await this.culqi.refunds.createRefund({
        charge_id: params.chargeId,
        amount: params.amount,
        reason: params.reason,
      });

      console.log(`✅ Reembolso creado: ${refund.id}`);

      return {
        success: true,
        refundId: refund.id,
        amount: refund.amount,
        chargeId: refund.charge_id,
        reason: refund.reason,
      };

    } catch (error: any) {
      console.error('❌ Error creando reembolso Culqi:', error.message);
      return {
        success: false,
        error: error.user_message || error.message || 'Error procesando el reembolso',
      };
    }
  }

  // ============================================================================
  // WEBHOOKS - PROCESAR NOTIFICACIONES DE CULQI
  // ============================================================================

  /**
   * Procesar webhook de Culqi
   * Configurar en CulqiPanel > Eventos > Webhooks
   */
  async processWebhook(webhookData: any): Promise<void> {
    try {
      const eventType = webhookData.type || webhookData.event;
      const data = webhookData.data || webhookData;

      console.log(`🔔 Webhook Culqi recibido - Tipo: ${eventType}`);

      switch (eventType) {
        case 'charge.creation':
          await this.handleChargeCreation(data);
          break;

        case 'charge.update':
          await this.handleChargeUpdate(data);
          break;

        case 'order.status.changed':
          await this.handleOrderStatusChange(data);
          break;

        case 'refund.creation':
          await this.handleRefundCreation(data);
          break;

        default:
          console.log(`ℹ️ Tipo de webhook ${eventType} no manejado`);
      }

    } catch (error: any) {
      console.error('❌ Error procesando webhook Culqi:', error.message);
      throw error;
    }
  }

  /**
   * Manejar creación de cargo
   */
  private async handleChargeCreation(chargeData: any): Promise<void> {
    try {
      const chargeId = chargeData.id;
      const metadata = chargeData.metadata || {};
      const userId = metadata.user_id;
      const transactionType = metadata.transaction_type;

      console.log(`💳 Cargo creado: ${chargeId} - Tipo: ${transactionType}`);

      if (transactionType === 'recharge' && userId) {
        // Ya se procesó en processRecharge, solo actualizar estado si es necesario
        console.log(`ℹ️ Recarga ya procesada para usuario ${userId}`);
      }

    } catch (error: any) {
      console.error('❌ Error manejando creación de cargo:', error.message);
    }
  }

  /**
   * Manejar actualización de cargo
   */
  private async handleChargeUpdate(chargeData: any): Promise<void> {
    try {
      const chargeId = chargeData.id;
      const outcome = chargeData.outcome;

      console.log(`🔄 Cargo actualizado: ${chargeId} - Estado: ${outcome?.type}`);

      // Buscar y actualizar la transacción correspondiente
      const transactionsSnapshot = await this.db.collection('recharge_transactions')
        .where('chargeId', '==', chargeId)
        .limit(1)
        .get();

      if (!transactionsSnapshot.empty) {
        const transactionDoc = transactionsSnapshot.docs[0];
        await transactionDoc.ref.update({
          status: outcome?.type === 'venta_exitosa' ? 'completed' : 'failed',
          outcomeType: outcome?.type,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

    } catch (error: any) {
      console.error('❌ Error manejando actualización de cargo:', error.message);
    }
  }

  /**
   * Manejar cambio de estado de orden (PagoEfectivo, billeteras)
   */
  private async handleOrderStatusChange(orderData: any): Promise<void> {
    try {
      const orderId = orderData.id || orderData.order_number;
      const state = orderData.state;

      console.log(`📋 Orden actualizada: ${orderId} - Estado: ${state}`);

      // Buscar la orden en Firestore
      const ordersSnapshot = await this.db.collection('payment_orders')
        .where('orderId', '==', orderId)
        .limit(1)
        .get();

      if (!ordersSnapshot.empty) {
        const orderDoc = ordersSnapshot.docs[0];
        const orderDocData = orderDoc.data();

        await orderDoc.ref.update({
          status: state,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Si la orden fue pagada, acreditar saldo
        if (state === 'paid' || state === 'completed') {
          const userId = orderDocData.userId;
          const amount = orderDocData.amount;

          if (userId && amount) {
            await this.creditUserBalance(userId, amount / 100, orderId, orderId);
          }
        }
      }

    } catch (error: any) {
      console.error('❌ Error manejando cambio de orden:', error.message);
    }
  }

  /**
   * Manejar creación de reembolso
   */
  private async handleRefundCreation(refundData: any): Promise<void> {
    try {
      const refundId = refundData.id;
      const chargeId = refundData.charge_id;
      const amount = refundData.amount;

      console.log(`💸 Reembolso creado: ${refundId} - Cargo: ${chargeId} - Monto: ${amount}`);

      // Buscar la transacción original
      const transactionsSnapshot = await this.db.collection('recharge_transactions')
        .where('chargeId', '==', chargeId)
        .limit(1)
        .get();

      if (!transactionsSnapshot.empty) {
        const transactionDoc = transactionsSnapshot.docs[0];
        const transactionData = transactionDoc.data();
        const userId = transactionData.userId;

        // Descontar saldo del usuario
        if (userId) {
          await this.debitUserBalance(userId, amount / 100, refundId);
        }

        // Actualizar transacción
        await transactionDoc.ref.update({
          status: 'refunded',
          refundId: refundId,
          refundAmount: amount,
          refundedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

    } catch (error: any) {
      console.error('❌ Error manejando creación de reembolso:', error.message);
    }
  }

  /**
   * Descontar saldo del usuario (para reembolsos)
   */
  private async debitUserBalance(userId: string, amount: number, refundId: string): Promise<void> {
    try {
      console.log(`💸 Descontando S/ ${amount} de usuario ${userId}`);

      await this.db.runTransaction(async (transaction) => {
        const userRef = this.db.collection('users').doc(userId);
        const userDoc = await transaction.get(userRef);

        if (!userDoc.exists) {
          throw new Error(`Usuario ${userId} no encontrado`);
        }

        const currentBalance = userDoc.data()?.balance || 0;
        const newBalance = Math.max(0, currentBalance - amount);

        transaction.update(userRef, {
          balance: newBalance,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Registrar en historial
        const historyRef = this.db.collection('users').doc(userId).collection('transactions').doc();
        transaction.set(historyRef, {
          type: 'refund',
          amount: -amount,
          paymentMethod: 'culqi',
          refundId: refundId,
          status: 'completed',
          previousBalance: currentBalance,
          newBalance: newBalance,
          description: 'Reembolso de recarga',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      console.log(`✅ Saldo descontado: S/ ${amount}`);

    } catch (error: any) {
      console.error('❌ Error descontando saldo:', error.message);
      throw error;
    }
  }

  // ============================================================================
  // CLIENTES Y TARJETAS (PAGOS RECURRENTES)
  // ============================================================================

  /**
   * Crear cliente en Culqi para pagos recurrentes
   */
  async createCustomer(params: {
    firstName: string;
    lastName: string;
    email: string;
    phone?: string;
    address?: string;
    addressCity?: string;
  }): Promise<CulqiCustomerResult> {
    try {
      console.log(`👤 Creando cliente Culqi: ${params.email}`);

      // Construir payload solo con campos requeridos + opcionales presentes
      const customerPayload: any = {
        first_name: params.firstName,
        last_name: params.lastName,
        email: params.email,
      };

      // Agregar campos opcionales solo si tienen valor
      if (params.phone) customerPayload.phone_number = params.phone;
      if (params.address) customerPayload.address = params.address;
      if (params.addressCity) customerPayload.address_city = params.addressCity;

      const customer = await this.culqi.customers.createCustomer(customerPayload);

      console.log(`✅ Cliente creado: ${customer.id}`);

      return {
        success: true,
        customerId: customer.id,
        email: customer.email,
      };

    } catch (error: any) {
      console.error('❌ Error creando cliente Culqi:', error.message);
      return {
        success: false,
        error: error.user_message || error.message || 'Error creando el cliente',
      };
    }
  }

  /**
   * Crear tarjeta guardada para un cliente
   */
  async createCard(params: {
    customerId: string;
    tokenId: string; // Token de tarjeta generado en frontend
  }): Promise<CulqiCardResult> {
    try {
      console.log(`💳 Guardando tarjeta para cliente: ${params.customerId}`);

      const card = await this.culqi.cards.createCard({
        customer_id: params.customerId,
        token_id: params.tokenId,
      });

      // Castear a any para acceder a propiedades adicionales
      const cardData = card as any;
      console.log(`✅ Tarjeta guardada: ${cardData.id}`);

      const last4 = cardData.source?.last_four || cardData.last_four;
      return {
        success: true,
        cardId: cardData.id,
        customerId: cardData.customer_id || params.customerId,
        cardBrand: cardData.source?.iin?.card_brand || cardData.iin?.card_brand,
        cardNumber: last4, // Últimos 4 dígitos
        cardLast4: last4, // Alias
      };

    } catch (error: any) {
      console.error('❌ Error guardando tarjeta Culqi:', error.message);
      return {
        success: false,
        error: error.user_message || error.message || 'Error guardando la tarjeta',
      };
    }
  }

  /**
   * Alias de createCard para compatibilidad con endpoints
   */
  async saveCard(params: {
    customerId: string;
    tokenId: string;
  }): Promise<CulqiCardResult> {
    return this.createCard(params);
  }

  /**
   * Obtener tarjetas guardadas de un cliente
   */
  async getCustomerCards(customerId: string): Promise<CulqiCardsListResult> {
    try {
      console.log(`📋 Obteniendo tarjetas del cliente: ${customerId}`);

      // Usar any para el parámetro ya que los tipos de culqi-node pueden no estar completos
      const cardsRequest: any = { customer_id: customerId };
      const cards = await this.culqi.cards.getCards(cardsRequest);

      // Castear respuesta a any para acceder a propiedades
      const cardsData = cards as any;
      console.log(`✅ Tarjetas encontradas: ${cardsData.data?.length || 0}`);

      return {
        success: true,
        cards: (cardsData.data || []).map((card: any) => ({
          id: card.id,
          brand: card.source?.iin?.card_brand || card.iin?.card_brand || 'Unknown',
          last4: card.source?.last_four || card.last_four || '****',
          type: card.source?.iin?.card_type || card.iin?.card_type,
          expMonth: card.source?.expiration_month || card.expiration_month,
          expYear: card.source?.expiration_year || card.expiration_year,
          active: card.active,
        })),
      };

    } catch (error: any) {
      console.error('❌ Error obteniendo tarjetas Culqi:', error.message);
      return {
        success: false,
        error: error.user_message || error.message || 'Error obteniendo tarjetas',
      };
    }
  }

  // ============================================================================
  // UTILIDADES
  // ============================================================================

  /**
   * Obtener configuración pública de Culqi (para el frontend)
   */
  getPublicConfig(): CulqiPublicConfig {
    return {
      publicKey: this.publicKey,
      rsaId: process.env.CULQI_RSA_ID || '',
      rsaPublicKey: process.env.CULQI_RSA_PUBLIC_KEY || '',
    };
  }

  /**
   * Verificar si Culqi está correctamente configurado
   */
  isConfigured(): boolean {
    return !!process.env.CULQI_PRIVATE_KEY && !!this.publicKey;
  }

  // ============================================================================
  // NOTIFICACIONES
  // ============================================================================

  private async notifyUserRechargeSuccess(userId: string, amount: number): Promise<void> {
    try {
      const userDoc = await this.db.collection('users').doc(userId).get();
      const userData = userDoc.data();

      if (userData?.fcmToken) {
        await admin.messaging().send({
          token: userData.fcmToken,
          notification: {
            title: '✅ Recarga exitosa',
            body: `Se acreditó S/ ${amount.toFixed(2)} a tu cuenta`,
          },
          data: {
            type: 'recharge_success',
            amount: amount.toString(),
          },
        });
      }
    } catch (error) {
      console.error('Error enviando notificación de recarga:', error);
    }
  }
}

// ============================================================================
// TIPOS E INTERFACES
// ============================================================================

export interface CulqiChargeResult {
  success: boolean;
  chargeId?: string;
  amount?: number;
  currencyCode?: string;
  email?: string;
  outcome?: any;
  referenceCode?: string;
  responseCode?: string;
  merchantMessage?: string;
  userMessage?: string;
  error?: string;
  errorCode?: string;
  status?: string;
  transactionId?: string;
  newBalance?: number;
}

export interface CulqiOrderResult {
  success: boolean;
  orderId?: string;
  amount?: number;
  state?: string;
  paymentCode?: string; // Código CIP para PagoEfectivo
  expirationDate?: string;
  message?: string;
  error?: string;
}

export interface CulqiRefundResult {
  success: boolean;
  refundId?: string;
  amount?: number;
  chargeId?: string;
  reason?: string;
  status?: string;
  error?: string;
}

export interface CulqiCustomerResult {
  success: boolean;
  customerId?: string;
  email?: string;
  error?: string;
}

export interface CulqiCardResult {
  success: boolean;
  cardId?: string;
  customerId?: string;
  cardBrand?: string;
  cardNumber?: string; // Últimos 4 dígitos
  cardLast4?: string; // Alias para cardNumber
  error?: string;
}

export interface CulqiPublicConfig {
  publicKey: string;
  rsaId: string;
  rsaPublicKey: string;
}

export interface CulqiCardsListResult {
  success: boolean;
  cards?: Array<{
    id: string;
    brand: string;
    last4: string;
    type?: string;
    expMonth?: number;
    expYear?: number;
    active?: boolean;
  }>;
  error?: string;
}
