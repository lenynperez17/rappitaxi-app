import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { logger } from '@shared/utils/logger';
import { Notification } from '@shared/types';

/**
 * Firestore trigger when a notification document is created
 */
export const onNotificationCreate = functions
  .region('us-central1')
  .firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    try {
      const notificationId = context.params.notificationId;
      const notificationData = snap.data() as Notification;

      logger.info('Notification created', {
        notificationId,
        userId: notificationData.userId,
        type: notificationData.type,
        title: notificationData.title,
      });

      // Update user's unread count
      await updateUserUnreadCount(notificationData.userId, 1);

      // Send real-time update to user if they're online
      await sendRealTimeUpdate(notificationData.userId, {
        type: 'new_notification',
        notification: notificationData,
      });

    } catch (error: any) {
      logger.error('Error in onNotificationCreate trigger', {
        error: error.message,
        notificationId: context.params.notificationId,
      });
    }
  });

/**
 * Firestore trigger when a notification document is updated
 */
export const onNotificationUpdate = functions
  .region('us-central1')
  .firestore
  .document('notifications/{notificationId}')
  .onUpdate(async (change, context) => {
    try {
      const notificationId = context.params.notificationId;
      const beforeData = change.before.data() as Notification;
      const afterData = change.after.data() as Notification;

      // Handle read status changes
      if (!beforeData.read && afterData.read) {
        logger.debug('Notification marked as read', {
          notificationId,
          userId: afterData.userId,
        });

        // Update user's unread count
        await updateUserUnreadCount(afterData.userId, -1);

        // Send real-time update
        await sendRealTimeUpdate(afterData.userId, {
          type: 'notification_read',
          notificationId,
        });
      }

    } catch (error: any) {
      logger.error('Error in onNotificationUpdate trigger', {
        error: error.message,
        notificationId: context.params.notificationId,
      });
    }
  });

/**
 * Firestore trigger when a notification document is deleted
 */
export const onNotificationDelete = functions
  .region('us-central1')
  .firestore
  .document('notifications/{notificationId}')
  .onDelete(async (snap, context) => {
    try {
      const notificationId = context.params.notificationId;
      const notificationData = snap.data() as Notification;

      logger.debug('Notification deleted', {
        notificationId,
        userId: notificationData.userId,
      });

      // Update user's unread count if notification was unread
      if (!notificationData.read) {
        await updateUserUnreadCount(notificationData.userId, -1);
      }

      // Send real-time update
      await sendRealTimeUpdate(notificationData.userId, {
        type: 'notification_deleted',
        notificationId,
      });

    } catch (error: any) {
      logger.error('Error in onNotificationDelete trigger', {
        error: error.message,
        notificationId: context.params.notificationId,
      });
    }
  });

/**
 * Update user's unread notification count in cache
 */
async function updateUserUnreadCount(userId: string, increment: number): Promise<void> {
  try {
    const userStatsRef = admin.firestore()
      .collection('user_notification_stats')
      .doc(userId);

    await userStatsRef.set({
      unreadCount: admin.firestore.FieldValue.increment(increment),
      lastUpdated: new Date(),
    }, );

    // Ensure count doesn't go negative
    const statsDoc = await userStatsRef.get();
    const statsData = statsDoc.data();
    
    if (statsData && statsData.unreadCount < 0) {
      await userStatsRef.update({
        unreadCount: 0,
        lastUpdated: new Date(),
      });
    }

  } catch (error: any) {
    logger.error('Error updating user unread count', {
      error: error.message,
      userId,
      increment,
    });
  }
}

/**
 * Send real-time update to user via WebSocket or FCM data message
 */
async function sendRealTimeUpdate(userId: string, data: any): Promise<void> {
  try {
    // Get user's device tokens for real-time updates
    const tokensDoc = await admin.firestore()
      .collection('user_device_tokens')
      .doc(userId)
      .get();

    if (!tokensDoc.exists) {
      return;
    }

    const tokensData = tokensDoc.data();
    const tokens = tokensData?.tokens || [];
    const deviceTokens = tokens.map((t: any) => t.token);

    if (deviceTokens.length === 0) {
      return;
    }

    // Send data-only message for real-time updates
    const message = {
      data: {
        type: 'realtime_update',
        payload: JSON.stringify(data),
        timestamp: new Date().toISOString(),
      },
      tokens: deviceTokens,
    };

    await admin.messaging().sendMulticast(message);

    logger.debug('Real-time update sent', {
      userId,
      type: data.type,
      tokenCount: deviceTokens.length,
    });

  } catch (error: any) {
    logger.error('Error sending real-time update', {
      error: error.message,
      userId,
      data,
    });
  }
}

/**
 * Scheduled function to send daily digest notifications
 */
export const sendDailyDigest = functions
  .region('us-central1')
  .pubsub
  .schedule('0 19 * * *') // Every day at 7 PM
  .timeZone('America/Argentina/Buenos_Aires')
  .onRun(async (context) => {
    try {
      logger.info('Starting daily digest notification sending');

      const yesterday = new Date();
      yesterday.setDate(yesterday.getDate() - 1);
      yesterday.setHours(0, 0, 0, 0);

      const today = new Date(yesterday);
      today.setDate(today.getDate() + 1);

      // Get users who have unread notifications and enabled digest
      const usersQuery = await admin.firestore()
        .collection('user_notification_preferences')
        .where('dailyDigest', '==', true)
        .get();

      if (usersQuery.empty) {
        logger.info('No users with daily digest enabled');
        return;
      }

      let digestsSent = 0;
      let digestsFailed = 0;

      for (const userDoc of usersQuery.docs) {
        try {
          const userId = userDoc.id;
          
          // Get unread notifications from the last 24 hours
          const unreadNotificationsQuery = await admin.firestore()
            .collection('notifications')
            .where('userId', '==', userId)
            .where('read', '==', false)
            .where('createdAt', '>=', yesterday)
            .where('createdAt', '<', today)
            .orderBy('createdAt', 'desc')
            .limit(10)
            .get();

          if (unreadNotificationsQuery.empty) {
            continue;
          }

          const notifications = unreadNotificationsQuery.docs.map(doc => doc.data());
          
          // Create digest notification
          const digestTitle = `Tienes ${notifications.length} notificaciones sin leer`;
          const digestBody = notifications.slice(0, 3)
            .map(n => n.title)
            .join(', ');

          // Get user's device tokens
          const tokensDoc = await admin.firestore()
            .collection('user_device_tokens')
            .doc(userId)
            .get();

          if (!tokensDoc.exists) {
            continue;
          }

          const tokensData = tokensDoc.data();
          const tokens = tokensData?.tokens || [];
          const deviceTokens = tokens.map((t: any) => t.token);

          if (deviceTokens.length === 0) {
            continue;
          }

          // Send digest notification
          const message = {
            notification: {
              title: digestTitle,
              body: digestBody,
            },
            data: {
              type: 'daily_digest',
              unreadCount: notifications.length.toString(),
              click_action: 'NOTIFICATIONS',
            },
            tokens: deviceTokens,
          };

          await admin.messaging().sendMulticast(message);
          digestsSent++;

        } catch (error: any) {
          logger.error('Error sending digest to user', {
            error: error.message,
            userId: userDoc.id,
          });
          digestsFailed++;
        }
      }

      logger.info('Daily digest notifications completed', {
        totalUsers: usersQuery.size,
        digestsSent,
        digestsFailed,
      });

    } catch (error: any) {
      logger.error('Error in sendDailyDigest scheduled function', {
        error: error.message,
      });
    }
  });

/**
 * Scheduled function to cleanup old notifications
 */
export const cleanupOldNotifications = functions
  .region('us-central1')
  .pubsub
  .schedule('0 3 * * 0') // Every Sunday at 3 AM
  .timeZone('America/Argentina/Buenos_Aires')
  .onRun(async (context) => {
    try {
      logger.info('Starting old notifications cleanup');

      const threeMonthsAgo = new Date();
      threeMonthsAgo.setMonth(threeMonthsAgo.getMonth() - 3);

      // Find old read notifications to delete
      const oldNotificationsQuery = await admin.firestore()
        .collection('notifications')
        .where('read', '==', true)
        .where('createdAt', '<', threeMonthsAgo)
        .limit(1000) // Process in batches
        .get();

      if (oldNotificationsQuery.empty) {
        logger.info('No old notifications found for cleanup');
        return;
      }

      const batch = admin.firestore().batch();
      
      oldNotificationsQuery.docs.forEach(doc => {
        batch.delete(doc.ref);
      });

      await batch.commit();

      logger.info('Old notifications cleanup completed', {
        deletedCount: oldNotificationsQuery.size,
      });

    } catch (error: any) {
      logger.error('Error in cleanupOldNotifications scheduled function', {
        error: error.message,
      });
    }
  });

/**
 * Scheduled function to clean up invalid device tokens
 */
export const cleanupInvalidTokens = functions
  .region('us-central1')
  .pubsub
  .schedule('0 4 * * 1') // Every Monday at 4 AM
  .timeZone('America/Argentina/Buenos_Aires')
  .onRun(async (context) => {
    try {
      logger.info('Starting invalid device tokens cleanup');

      const allTokensQuery = await admin.firestore()
        .collection('user_device_tokens')
        .get();

      if (allTokensQuery.empty) {
        logger.info('No device tokens found');
        return;
      }

      let totalTokensChecked = 0;
      let invalidTokensRemoved = 0;

      for (const doc of allTokensQuery.docs) {
        try {
          const tokensData = doc.data();
          const tokens = tokensData?.tokens || [];
          
          if (tokens.length === 0) {
            continue;
          }

          const validTokens = [];
          const deviceTokensToCheck = tokens.map((t: any) => t.token);
          totalTokensChecked += deviceTokensToCheck.length;

          // Test each token by sending a dry-run message
          for (const tokenObj of tokens) {
            try {
              const message = {
                data: { test: 'token_validation' },
                token: tokenObj.token,
              };

              await admin.messaging().send(message, true); // dry-run
              validTokens.push(tokenObj);
            } catch (error: any) {
              // Token is invalid
              logger.debug('Invalid token removed', {
                userId: doc.id,
                tokenPrefix: tokenObj.token.substring(0, 10),
                error: error.code,
              });
              invalidTokensRemoved++;
            }
          }

          // Update document with valid tokens only
          if (validTokens.length !== tokens.length) {
            await admin.firestore()
              .collection('user_device_tokens')
              .doc(doc.id)
              .update({
                tokens: validTokens,
                updatedAt: new Date(),
              });
          }

        } catch (error: any) {
          logger.error('Error processing user tokens', {
            error: error.message,
            userId: doc.id,
          });
        }
      }

      logger.info('Invalid device tokens cleanup completed', {
        totalTokensChecked,
        invalidTokensRemoved,
        usersProcessed: allTokensQuery.size,
      });

    } catch (error: any) {
      logger.error('Error in cleanupInvalidTokens scheduled function', {
        error: error.message,
      });
    }
  });

/**
 * Scheduled function to send promotional notifications
 */
export const sendPromotionalNotifications = functions
  .region('us-central1')
  .pubsub
  .schedule('0 20 * * 3,6') // Wednesday and Saturday at 8 PM
  .timeZone('America/Argentina/Buenos_Aires')
  .onRun(async (context) => {
    try {
      logger.info('Starting promotional notifications');

      // Get active promotions
      const promotionsQuery = await admin.firestore()
        .collection('promotions')
        .where('isActive', '==', true)
        .where('scheduledFor', '<=', new Date())
        .where('sent', '==', false)
        .get();

      if (promotionsQuery.empty) {
        logger.info('No promotions to send');
        return;
      }

      for (const promotionDoc of promotionsQuery.docs) {
        try {
          const promotionData = promotionDoc.data();
          
          // Send to promotions topic
          const message = {
            notification: {
              title: promotionData.title,
              body: promotionData.description,
            },
            data: {
              type: 'promotion',
              promotionId: promotionDoc.id,
              click_action: 'PROMOTIONS',
            },
            topic: 'promotions',
          };

          await admin.messaging().send(message);

          // Mark promotion as sent
          await admin.firestore()
            .collection('promotions')
            .doc(promotionDoc.id)
            .update({
              sent: true,
              sentAt: new Date(),
            });

          logger.info('Promotional notification sent', {
            promotionId: promotionDoc.id,
            title: promotionData.title,
          });

        } catch (error: any) {
          logger.error('Error sending promotional notification', {
            error: error.message,
            promotionId: promotionDoc.id,
          });
        }
      }

    } catch (error: any) {
      logger.error('Error in sendPromotionalNotifications scheduled function', {
        error: error.message,
      });
    }
  });