import * as admin from 'firebase-admin';
import axios from 'axios';

/**
 * 💳 SERVICIO MERCADOPAGO - COMPLETO Y FUNCIONAL
 * ============================================
 *
 * Funcionalidades:
 * ✅ Crear preferencias de pago (recargas)
 * ✅ Procesar webhooks de MercadoPago
 * ✅ Retiros automáticos con Money Out API
 * ✅ Verificar estado de pagos
 * ✅ Gestión de saldo y transacciones
 */
export class MercadoPagoService {
  private readonly accessToken: string;
  private readonly publicKey: string;
  private readonly baseUrl = 'https://api.mercadopago.com';
  private readonly db: admin.firestore.Firestore;

  constructor() {
    this.db = admin.firestore();

    // 🔑 CREDENCIALES DE MERCADOPAGO desde variables de entorno (.env)
    // ✅ Migrado de functions.config() (deprecado) a dotenv
    this.accessToken = process.env.MERCADOPAGO_ACCESS_TOKEN || '';
    this.publicKey = process.env.MERCADOPAGO_PUBLIC_KEY || '';

    if (!this.accessToken) {
      console.error('⚠️ MercadoPago: Access token no configurado en .env');
      console.error('📝 Crear archivo functions/.env con:');
      console.error('   MERCADOPAGO_ACCESS_TOKEN=APP_USR-...');
      console.error('   MERCADOPAGO_PUBLIC_KEY=APP_USR-...');
    }
  }

  // ============================================================================
  // RECARGAS - CREAR PREFERENCIAS DE PAGO
  // ============================================================================

  /**
   * Crear preferencia de pago para recarga de saldo
   */
  async createRechargePreference(params: {
    userId: string;
    amount: number;
    email: string;
    firstName: string;
    lastName: string;
  }): Promise<MercadoPagoPreferenceResult> {
    try {
      console.log(`💳 Creando preferencia de recarga para usuario ${params.userId} - S/ ${params.amount}`);

      // Validar monto mínimo (S/ 5.00)
      if (params.amount < 5) {
        throw new Error('El monto mínimo de recarga es S/ 5.00');
      }

      // Crear ID único para la transacción
      const transactionId = `recharge_${params.userId}_${Date.now()}`;

      // Crear preferencia en MercadoPago
      const preferenceData = {
        items: [
          {
            title: 'Recarga RapiTeam',
            description: `Recarga de saldo para usar en viajes`,
            quantity: 1,
            currency_id: 'PEN', // Soles peruanos
            unit_price: params.amount,
          },
        ],
        payer: {
          email: params.email,
          name: params.firstName,
          surname: params.lastName,
        },
        back_urls: {
          success: `rapiteam://payment/success?transaction_id=${transactionId}`,
          failure: `rapiteam://payment/failure?transaction_id=${transactionId}`,
          pending: `rapiteam://payment/pending?transaction_id=${transactionId}`,
        },
        auto_return: 'approved',
        notification_url: `${process.env.FUNCTIONS_URL || 'https://us-central1-rapi-team.cloudfunctions.net'}/mercadopagoWebhook`,
        external_reference: transactionId,
        statement_descriptor: 'RAPITEAM',
        metadata: {
          user_id: params.userId,
          transaction_type: 'recharge',
          platform: 'rapiteam',
        },
      };

      const response = await axios.post(
        `${this.baseUrl}/checkout/preferences`,
        preferenceData,
        {
          headers: {
            'Authorization': `Bearer ${this.accessToken}`,
            'Content-Type': 'application/json',
          },
        }
      );

      const preference = response.data;

      // Guardar transacción pendiente en Firestore
      await this.db.collection('recharge_transactions').doc(transactionId).set({
        userId: params.userId,
        amount: params.amount,
        preferenceId: preference.id,
        status: 'pending',
        paymentMethod: 'mercadopago',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        metadata: {
          email: params.email,
          name: `${params.firstName} ${params.lastName}`,
        },
      });

      console.log(`✅ Preferencia creada: ${preference.id}`);

      return {
        success: true,
        preferenceId: preference.id,
        initPoint: preference.init_point,
        sandboxInitPoint: preference.sandbox_init_point,
        publicKey: this.publicKey,
        transactionId,
      };

    } catch (error: any) {
      console.error('❌ Error creando preferencia MercadoPago:', error.response?.data || error.message);

      return {
        success: false,
        error: error.response?.data?.message || error.message || 'Error creando preferencia de pago',
      };
    }
  }

  // ============================================================================
  // WEBHOOKS - PROCESAR NOTIFICACIONES DE MERCADOPAGO
  // ============================================================================

  /**
   * Procesar webhook de MercadoPago
   */
  async processWebhook(webhookData: any): Promise<void> {
    try {
      const { type, data } = webhookData;

      console.log(`🔔 Webhook MercadoPago recibido - Tipo: ${type}`);

      // Solo procesar notificaciones de pagos
      if (type !== 'payment') {
        console.log(`ℹ️ Tipo de webhook ${type} ignorado`);
        return;
      }

      const paymentId = data.id;

      // Obtener detalles del pago
      const paymentDetails = await this.getPaymentDetails(paymentId);

      if (!paymentDetails) {
        console.error(`❌ No se pudieron obtener detalles del pago ${paymentId}`);
        return;
      }

      // Procesar según el estado del pago
      await this.handlePaymentStatus(paymentDetails);

    } catch (error: any) {
      console.error('❌ Error procesando webhook:', error.message);
      throw error;
    }
  }

  /**
   * Obtener detalles de un pago desde MercadoPago
   */
  private async getPaymentDetails(paymentId: string): Promise<any> {
    try {
      const response = await axios.get(
        `${this.baseUrl}/v1/payments/${paymentId}`,
        {
          headers: {
            'Authorization': `Bearer ${this.accessToken}`,
          },
        }
      );

      return response.data;

    } catch (error: any) {
      console.error(`❌ Error obteniendo detalles del pago ${paymentId}:`, error.message);
      return null;
    }
  }

  /**
   * Manejar estado del pago
   */
  private async handlePaymentStatus(payment: any): Promise<void> {
    const transactionId = payment.external_reference;
    const status = payment.status;
    const amount = payment.transaction_amount;

    console.log(`💰 Procesando pago ${payment.id} - Estado: ${status} - Monto: S/ ${amount}`);

    // Obtener transacción de Firestore
    const transactionRef = this.db.collection('recharge_transactions').doc(transactionId);
    const transactionDoc = await transactionRef.get();

    if (!transactionDoc.exists) {
      console.error(`❌ Transacción ${transactionId} no encontrada en Firestore`);
      return;
    }

    const transactionData = transactionDoc.data()!;
    const userId = transactionData.userId;

    switch (status) {
      case 'approved':
        await this.handleApprovedPayment(userId, amount, payment, transactionRef);
        break;

      case 'rejected':
      case 'cancelled':
        await this.handleRejectedPayment(userId, payment, transactionRef);
        break;

      case 'refunded':
        await this.handleRefundedPayment(userId, amount, payment, transactionRef);
        break;

      case 'pending':
      case 'in_process':
        await transactionRef.update({
          status: 'processing',
          paymentId: payment.id,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        break;

      default:
        console.log(`ℹ️ Estado ${status} no requiere acción`);
    }
  }

  /**
   * Manejar pago aprobado (acreditar saldo)
   */
  private async handleApprovedPayment(
    userId: string,
    amount: number,
    payment: any,
    transactionRef: admin.firestore.DocumentReference
  ): Promise<void> {
    try {
      console.log(`✅ Pago aprobado - Acreditando S/ ${amount} a usuario ${userId}`);

      // Usar transacción de Firestore para atomicidad
      await this.db.runTransaction(async (transaction) => {
        // Obtener usuario
        const userRef = this.db.collection('users').doc(userId);
        const userDoc = await transaction.get(userRef);

        if (!userDoc.exists) {
          throw new Error(`Usuario ${userId} no encontrado`);
        }

        const currentBalance = userDoc.data()?.balance || 0;
        const newBalance = currentBalance + amount;

        // Actualizar saldo del usuario
        transaction.update(userRef, {
          balance: newBalance,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Actualizar transacción
        transaction.update(transactionRef, {
          status: 'completed',
          paymentId: payment.id,
          paymentStatus: payment.status,
          paymentStatusDetail: payment.status_detail,
          paymentMethod: payment.payment_method_id,
          approvedAt: admin.firestore.FieldValue.serverTimestamp(),
          previousBalance: currentBalance,
          newBalance: newBalance,
        });

        // Registrar en historial de transacciones del usuario
        const historyRef = this.db.collection('users').doc(userId).collection('transactions').doc();
        transaction.set(historyRef, {
          type: 'recharge',
          amount: amount,
          paymentMethod: 'mercadopago',
          paymentId: payment.id,
          status: 'completed',
          previousBalance: currentBalance,
          newBalance: newBalance,
          description: 'Recarga de saldo con MercadoPago',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      // Notificar al usuario
      await this.notifyUserRechargeSuccess(userId, amount);

      console.log(`✅ Saldo acreditado exitosamente a usuario ${userId}`);

    } catch (error: any) {
      console.error('❌ Error acreditando saldo:', error.message);
      throw error;
    }
  }

  /**
   * Manejar pago rechazado
   */
  private async handleRejectedPayment(
    userId: string,
    payment: any,
    transactionRef: admin.firestore.DocumentReference
  ): Promise<void> {
    console.log(`❌ Pago rechazado para usuario ${userId}`);

    await transactionRef.update({
      status: 'failed',
      paymentId: payment.id,
      paymentStatus: payment.status,
      paymentStatusDetail: payment.status_detail,
      failureReason: payment.status_detail,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Notificar al usuario
    await this.notifyUserRechargeFailure(userId, payment.status_detail);
  }

  /**
   * Manejar reembolso
   */
  private async handleRefundedPayment(
    userId: string,
    amount: number,
    payment: any,
    transactionRef: admin.firestore.DocumentReference
  ): Promise<void> {
    try {
      console.log(`💸 Reembolso procesado - Descontando S/ ${amount} de usuario ${userId}`);

      await this.db.runTransaction(async (transaction) => {
        const userRef = this.db.collection('users').doc(userId);
        const userDoc = await transaction.get(userRef);

        if (!userDoc.exists) {
          throw new Error(`Usuario ${userId} no encontrado`);
        }

        const currentBalance = userDoc.data()?.balance || 0;
        const newBalance = Math.max(0, currentBalance - amount);

        // Actualizar saldo
        transaction.update(userRef, {
          balance: newBalance,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Actualizar transacción
        transaction.update(transactionRef, {
          status: 'refunded',
          refundedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Registrar en historial
        const historyRef = this.db.collection('users').doc(userId).collection('transactions').doc();
        transaction.set(historyRef, {
          type: 'refund',
          amount: -amount,
          paymentMethod: 'mercadopago',
          paymentId: payment.id,
          status: 'completed',
          previousBalance: currentBalance,
          newBalance: newBalance,
          description: 'Reembolso de recarga',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      console.log(`✅ Reembolso procesado exitosamente`);

    } catch (error: any) {
      console.error('❌ Error procesando reembolso:', error.message);
      throw error;
    }
  }

  // ============================================================================
  // RETIROS AUTOMÁTICOS - MONEY OUT API
  // ============================================================================

  /**
   * Procesar retiro automático con Money Out API
   */
  async processWithdrawal(params: {
    withdrawalId: string;
    driverId: string;
    amount: number;
    bankAccount: string;
    bankName: string;
    accountHolderName: string;
    accountHolderDocumentType: 'DNI' | 'CE';
    accountHolderDocumentNumber: string;
  }): Promise<WithdrawalResult> {
    try {
      console.log(`💸 Procesando retiro ${params.withdrawalId} - S/ ${params.amount} para driver ${params.driverId}`);

      // Validar monto mínimo (S/ 50.00)
      if (params.amount < 50) {
        throw new Error('El monto mínimo de retiro es S/ 50.00');
      }

      // Verificar saldo del conductor
      const driverRef = this.db.collection('users').doc(params.driverId);
      const driverDoc = await driverRef.get();

      if (!driverDoc.exists) {
        throw new Error('Conductor no encontrado');
      }

      const driverData = driverDoc.data()!;
      const currentBalance = driverData.balance || 0;

      if (currentBalance < params.amount) {
        throw new Error('Saldo insuficiente para retiro');
      }

      // Crear transferencia con Money Out API de MercadoPago
      const transferData = {
        transaction_amount: params.amount,
        description: `Retiro RapiTeam - ${params.driverId}`,
        payment_method_id: 'account_money', // Desde cuenta MercadoPago
        receiver_details: {
          type: 'bank_account',
          account_type: 'savings', // o 'checking' para cuenta corriente
          account_number: params.bankAccount,
          bank_id: this.getBankId(params.bankName),
          account_holder_name: params.accountHolderName,
          account_holder_document: {
            type: params.accountHolderDocumentType,
            number: params.accountHolderDocumentNumber,
          },
        },
        currency_id: 'PEN',
        metadata: {
          driver_id: params.driverId,
          withdrawal_id: params.withdrawalId,
          platform: 'rapiteam',
        },
      };

      // Enviar solicitud a MercadoPago Money Out API
      const response = await axios.post(
        `${this.baseUrl}/v1/money_requests`,
        transferData,
        {
          headers: {
            'Authorization': `Bearer ${this.accessToken}`,
            'Content-Type': 'application/json',
            'X-Idempotency-Key': params.withdrawalId, // Evitar duplicados
          },
        }
      );

      const transfer = response.data;

      console.log(`✅ Transferencia creada: ${transfer.id} - Estado: ${transfer.status}`);

      // Actualizar Firestore con la transferencia
      await this.handleWithdrawalTransfer(params, transfer, currentBalance);

      return {
        success: true,
        transferId: transfer.id,
        status: transfer.status,
        amount: params.amount,
      };

    } catch (error: any) {
      console.error('❌ Error procesando retiro:', error.response?.data || error.message);

      // Marcar retiro como fallido
      await this.db.collection('withdrawal_requests').doc(params.withdrawalId).update({
        status: 'failed',
        errorMessage: error.response?.data?.message || error.message,
        failedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        success: false,
        error: error.response?.data?.message || error.message || 'Error procesando retiro',
      };
    }
  }

  /**
   * Manejar transferencia de retiro
   */
  private async handleWithdrawalTransfer(
    params: any,
    transfer: any,
    previousBalance: number
  ): Promise<void> {
    await this.db.runTransaction(async (transaction) => {
      const driverRef = this.db.collection('users').doc(params.driverId);
      const withdrawalRef = this.db.collection('withdrawal_requests').doc(params.withdrawalId);

      const newBalance = previousBalance - params.amount;

      // Actualizar saldo del conductor
      transaction.update(driverRef, {
        balance: newBalance,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Actualizar solicitud de retiro
      transaction.update(withdrawalRef, {
        status: transfer.status === 'approved' ? 'completed' : 'processing',
        transferId: transfer.id,
        transferStatus: transfer.status,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
        previousBalance,
        newBalance,
      });

      // Registrar en historial del conductor
      const historyRef = this.db.collection('users').doc(params.driverId).collection('transactions').doc();
      transaction.set(historyRef, {
        type: 'withdrawal',
        amount: -params.amount,
        paymentMethod: 'bank_transfer',
        transferId: transfer.id,
        status: transfer.status === 'approved' ? 'completed' : 'processing',
        previousBalance,
        newBalance,
        description: `Retiro a ${params.bankName} - ${params.bankAccount}`,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    // Notificar al conductor
    if (transfer.status === 'approved') {
      await this.notifyDriverWithdrawalSuccess(params.driverId, params.amount);
    }
  }

  /**
   * Obtener ID de banco para MercadoPago
   */
  private getBankId(bankName: string): string {
    const bankIds: Record<string, string> = {
      'BCP': '0001',
      'BBVA': '0002',
      'Interbank': '0003',
      'Scotiabank': '0004',
      'Banbif': '0035',
      'BanBif': '0035',
      'Pichincha': '0033',
      'GNB': '0053',
      'Falabella': '0801',
      'Ripley': '0802',
      'Azteca': '0803',
      'Cencosud': '0805',
    };

    return bankIds[bankName] || '0001'; // Default BCP
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

  private async notifyUserRechargeFailure(userId: string, reason: string): Promise<void> {
    try {
      const userDoc = await this.db.collection('users').doc(userId).get();
      const userData = userDoc.data();

      if (userData?.fcmToken) {
        await admin.messaging().send({
          token: userData.fcmToken,
          notification: {
            title: '❌ Error en recarga',
            body: `No se pudo procesar tu recarga: ${reason}`,
          },
          data: {
            type: 'recharge_failed',
            reason,
          },
        });
      }
    } catch (error) {
      console.error('Error enviando notificación de fallo:', error);
    }
  }

  private async notifyDriverWithdrawalSuccess(driverId: string, amount: number): Promise<void> {
    try {
      const driverDoc = await this.db.collection('users').doc(driverId).get();
      const driverData = driverDoc.data();

      if (driverData?.fcmToken) {
        await admin.messaging().send({
          token: driverData.fcmToken,
          notification: {
            title: '💰 Retiro procesado',
            body: `Tu retiro de S/ ${amount.toFixed(2)} fue procesado exitosamente`,
          },
          data: {
            type: 'withdrawal_success',
            amount: amount.toString(),
          },
        });
      }
    } catch (error) {
      console.error('Error enviando notificación de retiro:', error);
    }
  }

  // ============================================================================
  // CHECKOUT BRICKS - PROCESAR PAGO IN-APP
  // ============================================================================

  /**
   * Procesar pago con token de Checkout Bricks
   * Este método procesa un pago usando el token generado por Checkout Bricks
   * directamente dentro de la aplicación (sin navegador externo)
   */
  async processCheckoutBricksPayment(params: {
    rideId: string;
    userId?: string; // Opcional, se obtiene del auth token si no se proporciona
    token: string;
    paymentMethodId: string;
    issuerId: string;
    installments: number;
    transactionAmount: number;
    payerEmail: string;
    description: string;
  }): Promise<CheckoutBricksPaymentResult> {
    try {
      console.log(`💳 Procesando pago Checkout Bricks: ${params.rideId} - S/${params.transactionAmount}`);

      // Crear el pago usando la API de MercadoPago
      const paymentData = {
        token: params.token,
        issuer_id: params.issuerId,
        payment_method_id: params.paymentMethodId,
        transaction_amount: params.transactionAmount,
        installments: params.installments,
        description: params.description,
        payer: {
          email: params.payerEmail,
        },
        // Metadata adicional para tracking
        metadata: {
          ride_id: params.rideId,
          user_id: params.userId || '', // Agregar userId al metadata
          payment_source: 'checkout_bricks',
        },
      };

      const response = await axios.post(
        `${this.baseUrl}/v1/payments`,
        paymentData,
        {
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${this.accessToken}`,
            'X-Idempotency-Key': `${params.rideId}_${Date.now()}`, // Prevenir pagos duplicados
          },
        }
      );

      const payment = response.data;

      console.log(`✅ Pago creado: ${payment.id} - Status: ${payment.status}`);

      // Actualizar transacción en Firestore según el tipo
      if (params.rideId.startsWith('RECARGA_')) {
        // Es una recarga de saldo
        await this.handleRechargePayment(params.rideId, payment);
      } else {
        // Es un pago de viaje
        await this.handleTripPayment(params.rideId, payment);
      }

      return {
        success: true,
        paymentId: payment.id,
        status: payment.status,
        statusDetail: payment.status_detail,
      };

    } catch (error: any) {
      console.error('❌ Error procesando pago Checkout Bricks:', error.response?.data || error.message);

      return {
        success: false,
        error: error.response?.data?.message || error.message || 'Error procesando el pago',
      };
    }
  }

  /**
   * Manejar pago de recarga (cuando rideId comienza con RECARGA_)
   */
  private async handleRechargePayment(rechargeId: string, payment: any): Promise<void> {
    try {
      // Extraer userId del metadata o buscar en la transacción
      const userId = payment.metadata?.user_id;

      if (!userId) {
        console.error('❌ No se pudo obtener userId del pago de recarga');
        return;
      }

      if (payment.status === 'approved') {
        // Actualizar saldo del conductor
        const userRef = this.db.collection('users').doc(userId);
        const userDoc = await userRef.get();
        const currentBalance = userDoc.data()?.balance || 0;
        const newBalance = currentBalance + payment.transaction_amount;

        await userRef.update({
          balance: newBalance,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Registrar transacción
        await this.db.collection('wallet_transactions').add({
          userId,
          type: 'recharge',
          amount: payment.transaction_amount,
          status: 'completed',
          paymentId: payment.id,
          rechargeId,
          description: payment.description || 'Recarga de saldo',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log(`✅ Recarga aprobada: S/${payment.transaction_amount} para usuario ${userId}`);
      }

    } catch (error) {
      console.error('❌ Error procesando recarga:', error);
    }
  }

  /**
   * Manejar pago de viaje
   */
  private async handleTripPayment(rideId: string, payment: any): Promise<void> {
    try {
      if (payment.status === 'approved') {
        // Actualizar estado del viaje
        await this.db.collection('trips').doc(rideId).update({
          paymentStatus: 'completed',
          paymentId: payment.id,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log(`✅ Pago de viaje aprobado: ${rideId}`);
      }

    } catch (error) {
      console.error('❌ Error procesando pago de viaje:', error);
    }
  }
}

// ============================================================================
// TIPOS Y INTERFACES
// ============================================================================

interface MercadoPagoPreferenceResult {
  success: boolean;
  preferenceId?: string;
  initPoint?: string;
  sandboxInitPoint?: string;
  publicKey?: string;
  transactionId?: string;
  error?: string;
}

interface WithdrawalResult {
  success: boolean;
  transferId?: string;
  status?: string;
  amount?: number;
  error?: string;
}

interface CheckoutBricksPaymentResult {
  success: boolean;
  paymentId?: string;
  status?: string;
  statusDetail?: string;
  error?: string;
}
