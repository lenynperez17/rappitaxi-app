import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { logger, loggerHelpers } from '@shared/utils/logger';
import { User } from '@shared/types';

/**
 * Firestore trigger when a user document is created
 */
export const onUserDocumentCreate = functions
  .region('us-central1')
  .firestore
  .document('users/{userId}')
  .onCreate(async (snap, context) => {
    try {
      const userId = context.params.userId;
      const userData = snap.data() as User;

      logger.info('User document created', {
        userId,
        email: userData.email,
        role: userData.role,
      });

      // Initialize user-specific collections
      const batch = admin.firestore().batch();

      // Create user settings document
      const userSettingsRef = admin.firestore()
        .collection('user_settings')
        .doc(userId);

      batch.set(userSettingsRef, {
        userId,
        notifications: {
          email: true,
          push: true,
          sms: false,
          marketing: false,
        },
        privacy: {
          shareLocation: true,
          shareRideHistory: false,
          allowDataCollection: true,
        },
        preferences: {
          language: 'es',
          currency: 'ARS',
          theme: 'light',
          autoAcceptRides: false,
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Create user analytics document (for tracking)
      const userAnalyticsRef = admin.firestore()
        .collection('user_analytics')
        .doc(userId);

      batch.set(userAnalyticsRef, {
        userId,
        role: userData.role,
        registrationDate: userData.createdAt,
        lastActivity: userData.createdAt,
        totalSessions: 0,
        totalRides: 0,
        totalSpent: 0,
        totalEarned: userData.role === 'driver' ? 0 : null,
        averageRating: 5.0,
        lifetimeValue: 0,
        acquisitionChannel: 'organic', // Default
        retentionSegment: 'new',
        riskScore: 0.1, // Low risk for new users
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // If driver, create driver-specific documents
      if (userData.role === 'driver') {
        // Create driver status document
        const driverStatusRef = admin.firestore()
          .collection('driver_status')
          .doc(userId);

        batch.set(driverStatusRef, {
          driverId: userId,
          isOnline: false,
          isAvailable: false,
          currentLocation: null,
          lastLocationUpdate: null,
          currentRideId: null,
          totalOnlineMinutes: 0,
          sessionStartTime: null,
          documentsVerified: false,
          backgroundCheckStatus: 'pending',
          vehicleInspectionStatus: 'pending',
          approvalStatus: 'pending',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Create driver earnings document
        const driverEarningsRef = admin.firestore()
          .collection('driver_earnings')
          .doc(userId);

        batch.set(driverEarningsRef, {
          driverId: userId,
          totalEarnings: 0,
          weeklyEarnings: 0,
          monthlyEarnings: 0,
          pendingPayouts: 0,
          completedPayouts: 0,
          totalRides: 0,
          averageRideValue: 0,
          peakHourMultiplier: 1.0,
          bonusEarnings: 0,
          tips: 0,
          deductions: 0,
          netEarnings: 0,
          lastPayoutDate: null,
          nextPayoutDate: null,
          payoutFrequency: 'weekly',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      loggerHelpers.logSecurityEvent(
        'USER_INITIALIZATION_COMPLETED',
        userId,
        undefined,
        {
          role: userData.role,
          email: userData.email,
        }
      );

    } catch (error: any) {
      logger.error('Error in onUserDocumentCreate trigger', {
        error: error.message,
        userId: context.params.userId,
      });
    }
  });

/**
 * Firestore trigger when a user document is updated
 */
export const onUserDocumentUpdate = functions
  .region('us-central1')
  .firestore
  .document('users/{userId}')
  .onUpdate(async (change, context) => {
    try {
      const userId = context.params.userId;
      const beforeData = change.before.data() as User;
      const afterData = change.after.data() as User;

      // Check if role changed
      if (beforeData.role !== afterData.role) {
        loggerHelpers.logSecurityEvent(
          'USER_ROLE_CHANGED',
          userId,
          undefined,
          {
            oldRole: beforeData.role,
            newRole: afterData.role,
          }
        );

        // Handle role-specific initialization
        if (afterData.role === 'driver' && beforeData.role !== 'driver') {
          // Initialize driver-specific documents
          const batch = admin.firestore().batch();

          const driverStatusRef = admin.firestore()
            .collection('driver_status')
            .doc(userId);

          batch.set(driverStatusRef, {
            driverId: userId,
            isOnline: false,
            isAvailable: false,
            currentLocation: null,
            lastLocationUpdate: null,
            currentRideId: null,
            totalOnlineMinutes: 0,
            sessionStartTime: null,
            documentsVerified: false,
            backgroundCheckStatus: 'pending',
            vehicleInspectionStatus: 'pending',
            approvalStatus: 'pending',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          const driverEarningsRef = admin.firestore()
            .collection('driver_earnings')
            .doc(userId);

          batch.set(driverEarningsRef, {
            driverId: userId,
            totalEarnings: 0,
            weeklyEarnings: 0,
            monthlyEarnings: 0,
            pendingPayouts: 0,
            completedPayouts: 0,
            totalRides: 0,
            averageRideValue: 0,
            peakHourMultiplier: 1.0,
            bonusEarnings: 0,
            tips: 0,
            deductions: 0,
            netEarnings: 0,
            lastPayoutDate: null,
            nextPayoutDate: null,
            payoutFrequency: 'weekly',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          await batch.commit();
        }
      }

      // Check if user was deactivated
      if (beforeData.isActive && !afterData.isActive) {
        loggerHelpers.logSecurityEvent(
          'USER_DEACTIVATED',
          userId,
          undefined,
          {
            email: afterData.email,
            role: afterData.role,
          }
        );

        // If driver, set offline
        if (afterData.role === 'driver') {
          await admin.firestore()
            .collection('driver_status')
            .doc(userId)
            .update({
              isOnline: false,
              isAvailable: false,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }
      }

      // Check if user was reactivated
      if (!beforeData.isActive && afterData.isActive) {
        loggerHelpers.logSecurityEvent(
          'USER_REACTIVATED',
          userId,
          undefined,
          {
            email: afterData.email,
            role: afterData.role,
          }
        );
      }

      // Update user analytics
      await admin.firestore()
        .collection('user_analytics')
        .doc(userId)
        .update({
          lastActivity: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

    } catch (error: any) {
      logger.error('Error in onUserDocumentUpdate trigger', {
        error: error.message,
        userId: context.params.userId,
      });
    }
  });

/**
 * Firestore trigger when a user document is deleted
 */
export const onUserDocumentDelete = functions
  .region('us-central1')
  .firestore
  .document('users/{userId}')
  .onDelete(async (snap, context) => {
    try {
      const userId = context.params.userId;
      const userData = snap.data() as User;

      logger.info('User document deleted, cleaning up related data', {
        userId,
        email: userData.email,
        role: userData.role,
      });

      // Clean up all related documents
      const batch = admin.firestore().batch();

      // Delete user settings
      const userSettingsRef = admin.firestore()
        .collection('user_settings')
        .doc(userId);
      batch.delete(userSettingsRef);

      // Delete user analytics
      const userAnalyticsRef = admin.firestore()
        .collection('user_analytics')
        .doc(userId);
      batch.delete(userAnalyticsRef);

      // If driver, delete driver-specific documents
      if (userData.role === 'driver') {
        const driverStatusRef = admin.firestore()
          .collection('driver_status')
          .doc(userId);
        batch.delete(driverStatusRef);

        const driverEarningsRef = admin.firestore()
          .collection('driver_earnings')
          .doc(userId);
        batch.delete(driverEarningsRef);
      }

      await batch.commit();

      loggerHelpers.logSecurityEvent(
        'USER_DATA_CLEANUP_COMPLETED',
        userId,
        undefined,
        {
          email: userData.email,
          role: userData.role,
        }
      );

    } catch (error: any) {
      logger.error('Error in onUserDocumentDelete trigger', {
        error: error.message,
        userId: context.params.userId,
      });
    }
  });

/**
 * Scheduled function to clean up inactive users
 */
export const cleanupInactiveUsers = functions
  .region('us-central1')
  .pubsub
  .schedule('0 2 * * 0') // Every Sunday at 2 AM
  .timeZone('America/Argentina/Buenos_Aires')
  .onRun(async (context) => {
    try {
      const sixMonthsAgo = new Date();
      sixMonthsAgo.setMonth(sixMonthsAgo.getMonth() - 6);

      // Find users inactive for 6 months
      const inactiveUsersQuery = await admin.firestore()
        .collection('user_analytics')
        .where('lastActivity', '<', sixMonthsAgo)
        .where('totalRides', '==', 0)
        .limit(100) // Process in batches
        .get();

      if (inactiveUsersQuery.empty) {
        logger.info('No inactive users found for cleanup');
        return;
      }

      const batch = admin.firestore().batch();
      const userIds: string[] = [];

      inactiveUsersQuery.docs.forEach(doc => {
        const userId = doc.data().userId;
        userIds.push(userId);
        
        // Mark for deletion in user_analytics
        batch.update(doc.ref, {
          markedForDeletion: true,
          deletionScheduledAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      await batch.commit();

      logger.info('Marked inactive users for deletion', {
        count: userIds.length,
        userIds,
      });

      // Note: Actual user deletion should be done through admin review
      // This just marks them for potential cleanup

    } catch (error: any) {
      logger.error('Error in cleanupInactiveUsers scheduled function', {
        error: error.message,
      });
    }
  });