import * as admin from 'firebase-admin';
import { logger, loggerHelpers } from '@shared/utils/logger';
import { MercadoPagoProvider } from './mercadopago-provider';

export class WalletProvider {
  private mercadoPagoProvider?: MercadoPagoProvider;

  constructor() {
    // Initialize MercadoPago for wallet top-ups
    try {
      this.mercadoPagoProvider = new MercadoPagoProvider();
    } catch (error) {
      logger.warn('MercadoPago not available for wallet top-ups', { error });
    }
  }

  /**
   * Get wallet balance for a user
   */
  async getBalance(userId: string): Promise<number> {
    try {
      const walletDoc = await admin.firestore()
        .collection('user_wallets')
        .doc(userId)
        .get();

      if (!walletDoc.exists) {
        // Create wallet if doesn't exist
        await this.createWallet(userId);
        return 0;
      }

      const walletData = walletDoc.data();
      return walletData?.balance || 0;
    } catch (error: any) {
      logger.error('Error getting wallet balance', {
        error: error.message,
        userId,
      });
      return 0;
    }
  }

  /**
   * Create a new wallet for a user
   */
  async createWallet(userId: string): Promise<void> {
    try {
      await admin.firestore()
        .collection('user_wallets')
        .doc(userId)
        .set({
          userId,
          balance: 0,
          currency: 'ARS',
          isActive: true,
          createdAt: new Date(),
          updatedAt: new Date(),
        });

      logger.info('Wallet created', { userId });
    } catch (error: any) {
      logger.error('Error creating wallet', {
        error: error.message,
        userId,
      });
      throw error;
    }
  }

  /**
   * Process a payment using wallet balance
   */
  async processPayment(
    userId: string,
    amount: number,
    metadata: {
      paymentId: string;
      rideId: string;
    }
  ): Promise<{
    success: boolean;
    transactionId?: string;
    error?: string;
    newBalance?: number;
  }> {
    try {
      const currentBalance = await this.getBalance(userId);

      if (currentBalance < amount) {
        return {
          success: false,
          error: 'Saldo insuficiente en la billetera',
        };
      }

      // Create transaction record
      const transactionRef = admin.firestore().collection('wallet_transactions').doc();
      const transactionId = transactionRef.id;

      const transactionData = {
        id: transactionId,
        userId,
        type: 'payment',
        amount: -amount, // Negative for payment
        description: `Pago viaje ${metadata.rideId}`,
        status: 'completed',
        paymentId: metadata.paymentId,
        rideId: metadata.rideId,
        createdAt: new Date(),
        balanceBefore: currentBalance,
        balanceAfter: currentBalance - amount,
      };

      // Use transaction to ensure atomicity
      await admin.firestore().runTransaction(async (transaction) => {
        const walletRef = admin.firestore()
          .collection('user_wallets')
          .doc(userId);

        // Get current balance again within transaction
        const walletDoc = await transaction.get(walletRef);
        const walletData = walletDoc.data();
        const actualBalance = walletData?.balance || 0;

        if (actualBalance < amount) {
          throw new Error('Saldo insuficiente');
        }

        // Update wallet balance
        transaction.update(walletRef, {
          balance: actualBalance - amount,
          updatedAt: new Date(),
        });

        // Create transaction record
        transaction.set(transactionRef, transactionData);
      });

      loggerHelpers.logPaymentEvent('WALLET_PAYMENT', metadata.paymentId, amount, {
        userId,
        rideId: metadata.rideId,
        transactionId,
        newBalance: currentBalance - amount,
      });

      return {
        success: true,
        transactionId,
        newBalance: currentBalance - amount,
      };
    } catch (error: any) {
      logger.error('Wallet payment error', {
        error: error.message,
        userId,
        amount,
        paymentId: metadata.paymentId,
      });

      return {
        success: false,
        error: error.message,
      };
    }
  }

  /**
   * Add funds to wallet
   */
  async addFunds(
    userId: string,
    amount: number,
    paymentMethod: string,
    paymentToken?: string
  ): Promise<{
    success: boolean;
    transactionId?: string;
    newBalance?: number;
    error?: string;
  }> {
    try {
      let paymentResult: any;

      // Process external payment first
      switch (paymentMethod) {
        case 'mercado_pago':
          if (!this.mercadoPagoProvider) {
            throw new Error('MercadoPago no disponible');
          }
          if (!paymentToken) {
            throw new Error('Token de pago requerido');
          }
          
          paymentResult = await this.mercadoPagoProvider.processPayment(amount, paymentToken, {
            paymentId: `wallet_topup_${Date.now()}`,
            rideId: 'wallet_topup',
            userId,
          });
          break;

        case 'cash':
          // For cash top-ups (maybe through physical locations)
          paymentResult = {
            success: true,
            transactionId: `cash_topup_${Date.now()}`,
          };
          break;

        default:
          throw new Error('Método de pago no soportado para recarga');
      }

      if (!paymentResult.success) {
        return {
          success: false,
          error: paymentResult.error || 'Error procesando pago',
        };
      }

      // Add funds to wallet
      const currentBalance = await this.getBalance(userId);
      const transactionRef = admin.firestore().collection('wallet_transactions').doc();
      const transactionId = transactionRef.id;

      const transactionData = {
        id: transactionId,
        userId,
        type: 'topup',
        amount: amount, // Positive for top-up
        description: `Recarga de billetera - ${paymentMethod}`,
        status: 'completed',
        paymentMethod,
        externalTransactionId: paymentResult.transactionId,
        createdAt: new Date(),
        balanceBefore: currentBalance,
        balanceAfter: currentBalance + amount,
      };

      // Use transaction to ensure atomicity
      await admin.firestore().runTransaction(async (transaction) => {
        const walletRef = admin.firestore()
          .collection('user_wallets')
          .doc(userId);

        // Get current balance again within transaction
        const walletDoc = await transaction.get(walletRef);
        const walletData = walletDoc.data();
        const actualBalance = walletData?.balance || 0;

        // Update wallet balance
        transaction.update(walletRef, {
          balance: actualBalance + amount,
          updatedAt: new Date(),
        });

        // Create transaction record
        transaction.set(transactionRef, transactionData);
      });

      logger.info('Wallet funds added', {
        userId,
        amount,
        paymentMethod,
        transactionId,
        newBalance: currentBalance + amount,
      });

      return {
        success: true,
        transactionId,
        newBalance: currentBalance + amount,
      };
    } catch (error: any) {
      logger.error('Error adding funds to wallet', {
        error: error.message,
        userId,
        amount,
        paymentMethod,
      });

      return {
        success: false,
        error: error.message,
      };
    }
  }

  /**
   * Withdraw funds from wallet
   */
  async withdrawFunds(
    userId: string,
    amount: number,
    bankAccount: {
      bankName: string;
      accountNumber: string;
      accountType: string;
    }
  ): Promise<{
    success: boolean;
    transactionId?: string;
    newBalance?: number;
    error?: string;
  }> {
    try {
      const currentBalance = await this.getBalance(userId);

      if (currentBalance < amount) {
        return {
          success: false,
          error: 'Saldo insuficiente en la billetera',
        };
      }

      // Create withdrawal transaction
      const transactionRef = admin.firestore().collection('wallet_transactions').doc();
      const transactionId = transactionRef.id;

      const transactionData = {
        id: transactionId,
        userId,
        type: 'withdrawal',
        amount: -amount, // Negative for withdrawal
        description: `Retiro a cuenta ${bankAccount.accountNumber.slice(-4)}`,
        status: 'pending', // Withdrawals start as pending
        bankAccount: {
          ...bankAccount,
          accountNumber: bankAccount.accountNumber.slice(-4), // Only store last 4 digits
        },
        createdAt: new Date(),
        balanceBefore: currentBalance,
        balanceAfter: currentBalance - amount,
        scheduledFor: new Date(Date.now() + 24 * 60 * 60 * 1000), // Next business day
      };

      // Use transaction to ensure atomicity
      await admin.firestore().runTransaction(async (transaction) => {
        const walletRef = admin.firestore()
          .collection('user_wallets')
          .doc(userId);

        // Get current balance again within transaction
        const walletDoc = await transaction.get(walletRef);
        const walletData = walletDoc.data();
        const actualBalance = walletData?.balance || 0;

        if (actualBalance < amount) {
          throw new Error('Saldo insuficiente');
        }

        // Update wallet balance (freeze funds)
        transaction.update(walletRef, {
          balance: actualBalance - amount,
          frozenBalance: (walletData?.frozenBalance || 0) + amount,
          updatedAt: new Date(),
        });

        // Create transaction record
        transaction.set(transactionRef, transactionData);
      });

      // Create withdrawal request for admin processing
      await admin.firestore()
        .collection('withdrawal_requests')
        .doc(transactionId)
        .set({
          id: transactionId,
          userId,
          amount,
          bankAccount,
          status: 'pending',
          createdAt: new Date(),
          scheduledFor: new Date(Date.now() + 24 * 60 * 60 * 1000),
        });

      logger.info('Wallet withdrawal requested', {
        userId,
        amount,
        transactionId,
        bankAccount: bankAccount.accountNumber.slice(-4),
      });

      return {
        success: true,
        transactionId,
        newBalance: currentBalance - amount,
      };
    } catch (error: any) {
      logger.error('Error withdrawing funds from wallet', {
        error: error.message,
        userId,
        amount,
      });

      return {
        success: false,
        error: error.message,
      };
    }
  }

  /**
   * Refund payment to wallet
   */
  async refundPayment(
    userId: string,
    amount: number,
    metadata: {
      paymentId: string;
      reason?: string;
    }
  ): Promise<{
    success: boolean;
    refundId?: string;
    error?: string;
  }> {
    try {
      const currentBalance = await this.getBalance(userId);
      const transactionRef = admin.firestore().collection('wallet_transactions').doc();
      const refundId = transactionRef.id;

      const transactionData = {
        id: refundId,
        userId,
        type: 'refund',
        amount: amount, // Positive for refund
        description: `Reembolso - ${metadata.reason || 'Solicitud de reembolso'}`,
        status: 'completed',
        paymentId: metadata.paymentId,
        createdAt: new Date(),
        balanceBefore: currentBalance,
        balanceAfter: currentBalance + amount,
      };

      // Use transaction to ensure atomicity
      await admin.firestore().runTransaction(async (transaction) => {
        const walletRef = admin.firestore()
          .collection('user_wallets')
          .doc(userId);

        // Get current balance again within transaction
        const walletDoc = await transaction.get(walletRef);
        const walletData = walletDoc.data();
        const actualBalance = walletData?.balance || 0;

        // Update wallet balance
        transaction.update(walletRef, {
          balance: actualBalance + amount,
          updatedAt: new Date(),
        });

        // Create transaction record
        transaction.set(transactionRef, transactionData);
      });

      logger.info('Wallet refund processed', {
        userId,
        amount,
        paymentId: metadata.paymentId,
        refundId,
        newBalance: currentBalance + amount,
      });

      return {
        success: true,
        refundId,
      };
    } catch (error: any) {
      logger.error('Error processing wallet refund', {
        error: error.message,
        userId,
        amount,
        paymentId: metadata.paymentId,
      });

      return {
        success: false,
        error: error.message,
      };
    }
  }

  /**
   * Get wallet transaction history
   */
  async getTransactionHistory(
    userId: string,
    limit: number = 20,
    offset: number = 0
  ): Promise<{
    transactions: any[];
    total: number;
  }> {
    try {
      const query = admin.firestore()
        .collection('wallet_transactions')
        .where('userId', '==', userId)
        .orderBy('createdAt', 'desc')
        .limit(limit)
        .offset(offset);

      const snapshot = await query.get();
      const transactions = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data(),
      }));

      // Get total count
      const totalQuery = await admin.firestore()
        .collection('wallet_transactions')
        .where('userId', '==', userId)
        .get();

      return {
        transactions,
        total: totalQuery.size,
      };
    } catch (error: any) {
      logger.error('Error getting wallet transaction history', {
        error: error.message,
        userId,
      });

      return {
        transactions: [],
        total: 0,
      };
    }
  }

  /**
   * Transfer funds between wallets
   */
  async transferFunds(
    fromUserId: string,
    toUserId: string,
    amount: number,
    description?: string
  ): Promise<{
    success: boolean;
    transactionId?: string;
    error?: string;
  }> {
    try {
      const fromBalance = await this.getBalance(fromUserId);

      if (fromBalance < amount) {
        return {
          success: false,
          error: 'Saldo insuficiente',
        };
      }

      const toBalance = await this.getBalance(toUserId);
      const transactionId = admin.firestore().collection('temp').doc().id;

      // Use transaction to ensure atomicity
      await admin.firestore().runTransaction(async (transaction) => {
        const fromWalletRef = admin.firestore()
          .collection('user_wallets')
          .doc(fromUserId);
        
        const toWalletRef = admin.firestore()
          .collection('user_wallets')
          .doc(toUserId);

        // Get current balances within transaction
        const [fromWalletDoc, toWalletDoc] = await Promise.all([
          transaction.get(fromWalletRef),
          transaction.get(toWalletRef),
        ]);

        const fromWalletData = fromWalletDoc.data();
        const toWalletData = toWalletDoc.data();

        const actualFromBalance = fromWalletData?.balance || 0;
        const actualToBalance = toWalletData?.balance || 0;

        if (actualFromBalance < amount) {
          throw new Error('Saldo insuficiente');
        }

        // Update balances
        transaction.update(fromWalletRef, {
          balance: actualFromBalance - amount,
          updatedAt: new Date(),
        });

        transaction.update(toWalletRef, {
          balance: actualToBalance + amount,
          updatedAt: new Date(),
        });

        // Create transaction records
        const fromTransactionRef = admin.firestore()
          .collection('wallet_transactions')
          .doc();

        const toTransactionRef = admin.firestore()
          .collection('wallet_transactions')
          .doc();

        transaction.set(fromTransactionRef, {
          id: fromTransactionRef.id,
          userId: fromUserId,
          type: 'transfer_out',
          amount: -amount,
          description: `Transferencia a usuario ${toUserId.slice(0, 8)}...`,
          status: 'completed',
          relatedUserId: toUserId,
          transferId: transactionId,
          createdAt: new Date(),
          balanceBefore: actualFromBalance,
          balanceAfter: actualFromBalance - amount,
        });

        transaction.set(toTransactionRef, {
          id: toTransactionRef.id,
          userId: toUserId,
          type: 'transfer_in',
          amount: amount,
          description: `Transferencia de usuario ${fromUserId.slice(0, 8)}...`,
          status: 'completed',
          relatedUserId: fromUserId,
          transferId: transactionId,
          createdAt: new Date(),
          balanceBefore: actualToBalance,
          balanceAfter: actualToBalance + amount,
        });
      });

      logger.info('Wallet transfer completed', {
        fromUserId,
        toUserId,
        amount,
        transactionId,
      });

      return {
        success: true,
        transactionId,
      };
    } catch (error: any) {
      logger.error('Error transferring wallet funds', {
        error: error.message,
        fromUserId,
        toUserId,
        amount,
      });

      return {
        success: false,
        error: error.message,
      };
    }
  }

  /**
   * Freeze wallet funds (for pending withdrawals, etc.)
   */
  async freezeFunds(
    userId: string,
    amount: number,
    reason: string
  ): Promise<{
    success: boolean;
    error?: string;
  }> {
    try {
      await admin.firestore().runTransaction(async (transaction) => {
        const walletRef = admin.firestore()
          .collection('user_wallets')
          .doc(userId);

        const walletDoc = await transaction.get(walletRef);
        const walletData = walletDoc.data();

        const currentBalance = walletData?.balance || 0;
        const currentFrozen = walletData?.frozenBalance || 0;

        if (currentBalance < amount) {
          throw new Error('Saldo insuficiente para congelar');
        }

        transaction.update(walletRef, {
          balance: currentBalance - amount,
          frozenBalance: currentFrozen + amount,
          updatedAt: new Date(),
        });

        // Log freeze transaction
        const transactionRef = admin.firestore()
          .collection('wallet_transactions')
          .doc();

        transaction.set(transactionRef, {
          id: transactionRef.id,
          userId,
          type: 'freeze',
          amount: -amount,
          description: `Fondos congelados - ${reason}`,
          status: 'completed',
          createdAt: new Date(),
          balanceBefore: currentBalance,
          balanceAfter: currentBalance - amount,
        });
      });

      return { success: true };
    } catch (error: any) {
      logger.error('Error freezing wallet funds', {
        error: error.message,
        userId,
        amount,
        reason,
      });

      return {
        success: false,
        error: error.message,
      };
    }
  }

  /**
   * Unfreeze wallet funds
   */
  async unfreezeFunds(
    userId: string,
    amount: number,
    reason: string
  ): Promise<{
    success: boolean;
    error?: string;
  }> {
    try {
      await admin.firestore().runTransaction(async (transaction) => {
        const walletRef = admin.firestore()
          .collection('user_wallets')
          .doc(userId);

        const walletDoc = await transaction.get(walletRef);
        const walletData = walletDoc.data();

        const currentBalance = walletData?.balance || 0;
        const currentFrozen = walletData?.frozenBalance || 0;

        if (currentFrozen < amount) {
          throw new Error('No hay suficientes fondos congelados');
        }

        transaction.update(walletRef, {
          balance: currentBalance + amount,
          frozenBalance: currentFrozen - amount,
          updatedAt: new Date(),
        });

        // Log unfreeze transaction
        const transactionRef = admin.firestore()
          .collection('wallet_transactions')
          .doc();

        transaction.set(transactionRef, {
          id: transactionRef.id,
          userId,
          type: 'unfreeze',
          amount: amount,
          description: `Fondos liberados - ${reason}`,
          status: 'completed',
          createdAt: new Date(),
          balanceBefore: currentBalance,
          balanceAfter: currentBalance + amount,
        });
      });

      return { success: true };
    } catch (error: any) {
      logger.error('Error unfreezing wallet funds', {
        error: error.message,
        userId,
        amount,
        reason,
      });

      return {
        success: false,
        error: error.message,
      };
    }
  }
}