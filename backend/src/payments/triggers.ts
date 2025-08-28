import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { logger, loggerHelpers } from '@shared/utils/logger';
import { Payment, PaymentStatus } from '@shared/types';
import { sendRideNotification } from '../notifications/services/notification-service';

/**
 * Firestore trigger when a payment document is created
 */
export const onPaymentCreate = functions
  .region('us-central1')
  .firestore
  .document('payments/{paymentId}')
  .onCreate(async (snap, context) => {
    try {
      const paymentId = context.params.paymentId;
      const paymentData = snap.data() as Payment;

      logger.info('Payment created', {
        paymentId,
        userId: paymentData.userId,
        amount: paymentData.amount,
        method: paymentData.method,
        status: paymentData.status,
      });

      // Set timeout for payment expiration if pending
      if (paymentData.status === PaymentStatus.PENDING && paymentData.method !== 'cash') {
        setTimeout(async () => {
          try {
            const currentPaymentDoc = await admin.firestore()
              .collection('payments')
              .doc(paymentId)
              .get();

            if (currentPaymentDoc.exists) {
              const currentPaymentData = currentPaymentDoc.data() as Payment;
              
              // Expire payment if still pending after 30 minutes
              if (currentPaymentData.status === PaymentStatus.PENDING) {
                await admin.firestore()
                  .collection('payments')
                  .doc(paymentId)
                  .update({
                    status: PaymentStatus.CANCELLED,
                    failedAt: new Date(),
                    updatedAt: new Date(),
                    cancellationReason: 'Pago expirado - tiempo de espera agotado',
                  });

                loggerHelpers.logPaymentEvent('PAYMENT_EXPIRED', paymentId, paymentData.amount, {
                  userId: paymentData.userId,
                  method: paymentData.method,
                });
              }
            }
          } catch (error: any) {
            logger.error('Error in payment expiration check', {
              error: error.message,
              paymentId,
            });
          }
        }, 30 * 60 * 1000); // 30 minutes
      }

    } catch (error: any) {
      logger.error('Error in onPaymentCreate trigger', {
        error: error.message,
        paymentId: context.params.paymentId,
      });
    }
  });

/**
 * Firestore trigger when a payment document is updated
 */
export const onPaymentUpdate = functions
  .region('us-central1')
  .firestore
  .document('payments/{paymentId}')
  .onUpdate(async (change, context) => {
    try {
      const paymentId = context.params.paymentId;
      const beforeData = change.before.data() as Payment;
      const afterData = change.after.data() as Payment;

      // Handle status changes
      if (beforeData.status !== afterData.status) {
        loggerHelpers.logPaymentEvent(
          'PAYMENT_STATUS_CHANGED',
          paymentId,
          afterData.amount,
          {
            from: beforeData.status,
            to: afterData.status,
            userId: afterData.userId,
            method: afterData.method,
            rideId: afterData.rideId,
          }
        );

        await handlePaymentStatusChange(paymentId, beforeData, afterData);
      }

    } catch (error: any) {
      logger.error('Error in onPaymentUpdate trigger', {
        error: error.message,
        paymentId: context.params.paymentId,
      });
    }
  });

/**
 * Handle payment status changes with appropriate actions
 */
async function handlePaymentStatusChange(paymentId: string, beforeData: Payment, afterData: Payment): Promise<void> {
  try {
    switch (afterData.status) {
      case PaymentStatus.COMPLETED:
        await handlePaymentCompleted(paymentId, afterData);
        break;
        
      case PaymentStatus.FAILED:
        await handlePaymentFailed(paymentId, afterData);
        break;
        
      case PaymentStatus.REFUNDED:
        await handlePaymentRefunded(paymentId, afterData);
        break;
        
      case PaymentStatus.CANCELLED:
        await handlePaymentCancelled(paymentId, afterData);
        break;
    }
  } catch (error: any) {
    logger.error('Error handling payment status change', {
      error: error.message,
      paymentId,
      status: afterData.status,
    });
  }
}

/**
 * Handle payment completed
 */
async function handlePaymentCompleted(paymentId: string, paymentData: Payment): Promise<void> {
  try {
    // Send notification to user
    await sendRideNotification(paymentData.userId, 'payment_processed', {
      paymentId,
      amount: paymentData.amount,
      method: paymentData.method,
      rideId: paymentData.rideId,
      message: 'Tu pago ha sido procesado exitosamente',
    });

    // Update ride payment status if applicable
    if (paymentData.rideId) {
      await admin.firestore()
        .collection('rides')
        .doc(paymentData.rideId)
        .update({
          paymentStatus: 'paid',
          paymentId: paymentId,
          paymentMethod: paymentData.method,
          updatedAt: new Date(),
        });
    }

    // Update daily revenue analytics
    const today = new Date().toISOString().split('T')[0];
    await admin.firestore()
      .collection('daily_analytics')
      .doc(today)
      .update({
        totalRevenue: admin.firestore.FieldValue.increment(paymentData.amount),
        totalPayments: admin.firestore.FieldValue.increment(1),
        [`paymentMethods.${paymentData.method}`]: admin.firestore.FieldValue.increment(1),
        updatedAt: new Date(),
      }, );

    // Update user payment analytics
    await admin.firestore()
      .collection('user_analytics')
      .doc(paymentData.userId)
      .update({
        totalSpent: admin.firestore.FieldValue.increment(paymentData.amount),
        totalPayments: admin.firestore.FieldValue.increment(1),
        lastPaymentDate: new Date(),
        updatedAt: new Date(),
      });

    logger.info('Payment completed successfully', {
      paymentId,
      userId: paymentData.userId,
      amount: paymentData.amount,
      method: paymentData.method,
    });

  } catch (error: any) {
    logger.error('Error handling payment completion', {
      error: error.message,
      paymentId,
    });
  }
}

/**
 * Handle payment failed
 */
async function handlePaymentFailed(paymentId: string, paymentData: Payment): Promise<void> {
  try {
    // Send notification to user
    await sendRideNotification(paymentData.userId, 'payment_failed', {
      paymentId,
      amount: paymentData.amount,
      method: paymentData.method,
      rideId: paymentData.rideId,
      message: 'Tu pago no pudo procesarse. Por favor, intenta con otro método.',
    });

    // Update ride payment status if applicable
    if (paymentData.rideId) {
      await admin.firestore()
        .collection('rides')
        .doc(paymentData.rideId)
        .update({
          paymentStatus: 'failed',
          paymentId: paymentId,
          updatedAt: new Date(),
        });
    }

    // Update analytics
    const today = new Date().toISOString().split('T')[0];
    await admin.firestore()
      .collection('daily_analytics')
      .doc(today)
      .update({
        failedPayments: admin.firestore.FieldValue.increment(1),
        [`failedPaymentMethods.${paymentData.method}`]: admin.firestore.FieldValue.increment(1),
        updatedAt: new Date(),
      }, );

    logger.warn('Payment failed', {
      paymentId,
      userId: paymentData.userId,
      amount: paymentData.amount,
      method: paymentData.method,
      gatewayResponse: paymentData.gatewayResponse,
    });

  } catch (error: any) {
    logger.error('Error handling payment failure', {
      error: error.message,
      paymentId,
    });
  }
}

/**
 * Handle payment refunded
 */
async function handlePaymentRefunded(paymentId: string, paymentData: Payment): Promise<void> {
  try {
    // Send notification to user
    await sendRideNotification(paymentData.userId, 'payment_refunded', {
      paymentId,
      amount: paymentData.amount,
      method: paymentData.method,
      rideId: paymentData.rideId,
      message: 'Tu pago ha sido reembolsado',
    });

    // Update ride payment status if applicable
    if (paymentData.rideId) {
      await admin.firestore()
        .collection('rides')
        .doc(paymentData.rideId)
        .update({
          paymentStatus: 'refunded',
          paymentId: paymentId,
          updatedAt: new Date(),
        });
    }

    // Update analytics
    const today = new Date().toISOString().split('T')[0];
    await admin.firestore()
      .collection('daily_analytics')
      .doc(today)
      .update({
        totalRefunds: admin.firestore.FieldValue.increment(paymentData.amount),
        refundCount: admin.firestore.FieldValue.increment(1),
        updatedAt: new Date(),
      }, );

    logger.info('Payment refunded', {
      paymentId,
      userId: paymentData.userId,
      amount: paymentData.amount,
      method: paymentData.method,
    });

  } catch (error: any) {
    logger.error('Error handling payment refund', {
      error: error.message,
      paymentId,
    });
  }
}

/**
 * Handle payment cancelled
 */
async function handlePaymentCancelled(paymentId: string, paymentData: Payment): Promise<void> {
  try {
    // Send notification to user if not expired
    const reason = (paymentData as any).cancellationReason;
    if (!reason?.includes('expirado')) {
      await sendRideNotification(paymentData.userId, 'payment_cancelled', {
        paymentId,
        rideId: paymentData.rideId,
        message: 'Tu pago ha sido cancelado',
      });
    }

    // Update ride payment status if applicable
    if (paymentData.rideId) {
      await admin.firestore()
        .collection('rides')
        .doc(paymentData.rideId)
        .update({
          paymentStatus: 'cancelled',
          paymentId: paymentId,
          updatedAt: new Date(),
        });
    }

    logger.info('Payment cancelled', {
      paymentId,
      userId: paymentData.userId,
      reason,
    });

  } catch (error: any) {
    logger.error('Error handling payment cancellation', {
      error: error.message,
      paymentId,
    });
  }
}

/**
 * Scheduled function to process driver payouts
 */
export const processDriverPayouts = functions
  .region('us-central1')
  .pubsub
  .schedule('0 9 * * 1') // Every Monday at 9 AM
  .timeZone('America/Argentina/Buenos_Aires')
  .onRun(async (context) => {
    try {
      logger.info('Starting driver payout processing');

      // Get pending payouts
      const pendingPayoutsQuery = await admin.firestore()
        .collection('driver_payouts')
        .where('status', '==', 'pending')
        .where('scheduledFor', '<=', new Date())
        .limit(100) // Process in batches
        .get();

      if (pendingPayoutsQuery.empty) {
        logger.info('No pending driver payouts found');
        return;
      }

      const batch = admin.firestore().batch();
      let processedCount = 0;
      let failedCount = 0;

      for (const doc of pendingPayoutsQuery.docs) {
        try {
          const payoutData = doc.data();
          
          // Here you would integrate with actual banking/payment API
          // For now, we'll simulate the process
          const success = Math.random() > 0.1; // 90% success rate simulation

          if (success) {
            // Mark as completed
            batch.update(doc.ref, {
              status: 'completed',
              processedAt: new Date(),
              externalTransactionId: `bank_transfer_${Date.now()}`,
            });

            // Update driver earnings
            const driverEarningsRef = admin.firestore()
              .collection('driver_earnings')
              .doc(payoutData.driverId);

            batch.update(driverEarningsRef, {
              pendingPayouts: admin.firestore.FieldValue.increment(-payoutData.amount),
              completedPayouts: admin.firestore.FieldValue.increment(payoutData.amount),
              lastPayoutDate: new Date(),
              updatedAt: new Date(),
            });

            processedCount++;
          } else {
            // Mark as failed
            batch.update(doc.ref, {
              status: 'failed',
              failedAt: new Date(),
              failureReason: 'Error procesando transferencia bancaria',
            });

            // Return funds to driver earnings
            const driverEarningsRef = admin.firestore()
              .collection('driver_earnings')
              .doc(payoutData.driverId);

            batch.update(driverEarningsRef, {
              pendingPayouts: admin.firestore.FieldValue.increment(-payoutData.amount),
              totalEarnings: admin.firestore.FieldValue.increment(payoutData.amount),
              updatedAt: new Date(),
            });

            failedCount++;
          }
        } catch (error: any) {
          logger.error('Error processing individual payout', {
            error: error.message,
            payoutId: doc.id,
          });
          failedCount++;
        }
      }

      await batch.commit();

      logger.info('Driver payout processing completed', {
        totalProcessed: pendingPayoutsQuery.size,
        successful: processedCount,
        failed: failedCount,
      });

    } catch (error: any) {
      logger.error('Error in processDriverPayouts scheduled function', {
        error: error.message,
      });
    }
  });

/**
 * Scheduled function to cleanup old payment data
 */
export const cleanupOldPayments = functions
  .region('us-central1')
  .pubsub
  .schedule('0 2 1 * *') // First day of every month at 2 AM
  .timeZone('America/Argentina/Buenos_Aires')
  .onRun(async (context) => {
    try {
      logger.info('Starting old payment data cleanup');

      const oneYearAgo = new Date();
      oneYearAgo.setFullYear(oneYearAgo.getFullYear() - 1);

      // Find old completed/failed payments to archive
      const oldPaymentsQuery = await admin.firestore()
        .collection('payments')
        .where('createdAt', '<', oneYearAgo)
        .where('status', 'in', ['completed', 'failed', 'cancelled'])
        .limit(1000) // Process in batches
        .get();

      if (oldPaymentsQuery.empty) {
        logger.info('No old payments found for cleanup');
        return;
      }

      const batch = admin.firestore().batch();
      const archiveBatch = admin.firestore().batch();

      oldPaymentsQuery.docs.forEach(doc => {
        const paymentData = doc.data();
        
        // Archive the payment
        const archiveRef = admin.firestore()
          .collection('archived_payments')
          .doc(doc.id);
        
        archiveBatch.set(archiveRef, {
          ...paymentData,
          archivedAt: new Date(),
        });

        // Delete from main payments collection
        batch.delete(doc.ref);
      });

      await archiveBatch.commit();
      await batch.commit();

      logger.info('Old payment data cleanup completed', {
        archivedCount: oldPaymentsQuery.size,
      });

    } catch (error: any) {
      logger.error('Error in cleanupOldPayments scheduled function', {
        error: error.message,
      });
    }
  });

/**
 * Scheduled function to reconcile payment data
 */
export const reconcilePayments = functions
  .region('us-central1')
  .pubsub
  .schedule('0 4 * * *') // Every day at 4 AM
  .timeZone('America/Argentina/Buenos_Aires')
  .onRun(async (context) => {
    try {
      logger.info('Starting payment reconciliation');

      const yesterday = new Date();
      yesterday.setDate(yesterday.getDate() - 1);
      yesterday.setHours(0, 0, 0, 0);

      const today = new Date(yesterday);
      today.setDate(today.getDate() + 1);

      // Get all payments from yesterday
      const yesterdayPaymentsQuery = await admin.firestore()
        .collection('payments')
        .where('createdAt', '>=', yesterday)
        .where('createdAt', '<', today)
        .get();

      const paymentsData = yesterdayPaymentsQuery.docs.map(doc => doc.data());

      // Calculate reconciliation summary
      const summary = {
        totalPayments: paymentsData.length,
        completedPayments: paymentsData.filter(p => p.status === 'completed').length,
        failedPayments: paymentsData.filter(p => p.status === 'failed').length,
        pendingPayments: paymentsData.filter(p => p.status === 'pending').length,
        totalRevenue: paymentsData
          .filter(p => p.status === 'completed')
          .reduce((sum, p) => sum + p.amount, 0),
        paymentMethods: paymentsData.reduce((acc, p) => {
          acc[p.method] = (acc[p.method] || 0) + 1;
          return acc;
        }, {} as any),
      };

      // Store reconciliation report
      await admin.firestore()
        .collection('payment_reconciliation')
        .doc(yesterday.toISOString().split('T')[0])
        .set({
          date: yesterday,
          summary,
          createdAt: new Date(),
        });

      logger.info('Payment reconciliation completed', {
        date: yesterday.toISOString().split('T')[0],
        summary,
      });

    } catch (error: any) {
      logger.error('Error in reconcilePayments scheduled function', {
        error: error.message,
      });
    }
  });