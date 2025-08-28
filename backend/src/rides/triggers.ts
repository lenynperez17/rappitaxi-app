import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { logger, loggerHelpers } from '@shared/utils/logger';
import { Ride, RideStatus } from '@shared/types';
import { sendRideNotification } from '../notifications/services/notification-service';
import { findNearbyDrivers } from './utils/driver-matching';

/**
 * Firestore trigger when a ride document is created
 */
export const onRideCreate = functions
  .region('us-central1')
  .firestore
  .document('rides/{rideId}')
  .onCreate(async (snap, context) => {
    try {
      const rideId = context.params.rideId;
      const rideData = snap.data() as Ride;

      logger.info('Ride created', {
        rideId,
        passengerId: rideData.passengerId,
        status: rideData.status,
        fare: rideData.fare,
      });

      // If ride is pending, start driver matching process
      if (rideData.status === RideStatus.PENDING) {
        // Set timeout for ride cancellation if no driver accepts
        setTimeout(async () => {
          try {
            const currentRideDoc = await admin.firestore()
              .collection('rides')
              .doc(rideId)
              .get();

            if (currentRideDoc.exists) {
              const currentRideData = currentRideDoc.data() as Ride;
              
              // Cancel ride if still pending after 5 minutes
              if (currentRideData.status === RideStatus.PENDING) {
                await admin.firestore()
                  .collection('rides')
                  .doc(rideId)
                  .update({
                    status: RideStatus.CANCELLED,
                    cancellationReason: 'Tiempo de espera agotado - No hay conductores disponibles',
                    cancelledAt: new Date(),
                    updatedAt: new Date(),
                  });

                // Notify passenger
                await sendRideNotification(rideData.passengerId, 'ride_cancelled', {
                  rideId,
                  reason: 'Tiempo de espera agotado',
                });

                loggerHelpers.logRideEvent('RIDE_TIMEOUT_CANCELLED', rideId, 'system', {
                  passengerId: rideData.passengerId,
                });
              }
            }
          } catch (error: any) {
            logger.error('Error in ride timeout cancellation', {
              error: error.message,
              rideId,
            });
          }
        }, 5 * 60 * 1000); // 5 minutes
      }

    } catch (error: any) {
      logger.error('Error in onRideCreate trigger', {
        error: error.message,
        rideId: context.params.rideId,
      });
    }
  });

/**
 * Firestore trigger when a ride document is updated
 */
export const onRideUpdate = functions
  .region('us-central1')
  .firestore
  .document('rides/{rideId}')
  .onUpdate(async (change, context) => {
    try {
      const rideId = context.params.rideId;
      const beforeData = change.before.data() as Ride;
      const afterData = change.after.data() as Ride;

      // Log status changes
      if (beforeData.status !== afterData.status) {
        loggerHelpers.logRideEvent(
          'RIDE_STATUS_CHANGED',
          rideId,
          afterData.driverId || afterData.passengerId,
          {
            from: beforeData.status,
            to: afterData.status,
            passengerId: afterData.passengerId,
            driverId: afterData.driverId,
          }
        );

        // Handle specific status changes
        await handleRideStatusChange(rideId, beforeData, afterData);
      }

      // Track location updates
      if (afterData.currentDriverLocation && 
          JSON.stringify(beforeData.currentDriverLocation) !== JSON.stringify(afterData.currentDriverLocation)) {
        
        // Update passenger with driver location
        if (afterData.status === RideStatus.DRIVER_ASSIGNED || 
            afterData.status === RideStatus.DRIVER_ARRIVED ||
            afterData.status === RideStatus.IN_PROGRESS) {
          
          await sendRideNotification(afterData.passengerId, 'driver_location_update', {
            rideId,
            driverLocation: afterData.currentDriverLocation,
          });
        }
      }

    } catch (error: any) {
      logger.error('Error in onRideUpdate trigger', {
        error: error.message,
        rideId: context.params.rideId,
      });
    }
  });

/**
 * Handle ride status changes with appropriate actions
 */
async function handleRideStatusChange(rideId: string, beforeData: Ride, afterData: Ride): Promise<void> {
  try {
    switch (afterData.status) {
      case RideStatus.DRIVER_ASSIGNED:
        await handleDriverAssigned(rideId, afterData);
        break;
        
      case RideStatus.DRIVER_ARRIVED:
        await handleDriverArrived(rideId, afterData);
        break;
        
      case RideStatus.IN_PROGRESS:
        await handleRideStarted(rideId, afterData);
        break;
        
      case RideStatus.COMPLETED:
        await handleRideCompleted(rideId, beforeData, afterData);
        break;
        
      case RideStatus.CANCELLED:
        await handleRideCancelled(rideId, beforeData, afterData);
        break;
    }
  } catch (error: any) {
    logger.error('Error handling ride status change', {
      error: error.message,
      rideId,
      status: afterData.status,
    });
  }
}

/**
 * Handle driver assigned to ride
 */
async function handleDriverAssigned(rideId: string, rideData: Ride): Promise<void> {
  // Send notification to passenger
  await sendRideNotification(rideData.passengerId, 'ride_assigned', {
    rideId,
    driverId: rideData.driverId,
  });

  // Set ETA notification timer
  setTimeout(async () => {
    try {
      const currentRideDoc = await admin.firestore()
        .collection('rides')
        .doc(rideId)
        .get();

      if (currentRideDoc.exists) {
        const currentRideData = currentRideDoc.data() as Ride;
        
        // If driver hasn't arrived yet, send ETA update
        if (currentRideData.status === RideStatus.DRIVER_ASSIGNED) {
          await sendRideNotification(rideData.passengerId, 'driver_eta_update', {
            rideId,
            message: 'Tu conductor debería llegar pronto',
          });
        }
      }
    } catch (error: any) {
      logger.error('Error sending ETA update', { error: error.message, rideId });
    }
  }, 3 * 60 * 1000); // 3 minutes
}

/**
 * Handle driver arrived at pickup
 */
async function handleDriverArrived(rideId: string, rideData: Ride): Promise<void> {
  // Send notification to passenger
  await sendRideNotification(rideData.passengerId, 'driver_arrived', {
    rideId,
    message: 'Tu conductor ha llegado',
  });

  // Set waiting timeout
  setTimeout(async () => {
    try {
      const currentRideDoc = await admin.firestore()
        .collection('rides')
        .doc(rideId)
        .get();

      if (currentRideDoc.exists) {
        const currentRideData = currentRideDoc.data() as Ride;
        
        // If still waiting after 5 minutes, send reminder
        if (currentRideData.status === RideStatus.DRIVER_ARRIVED) {
          await sendRideNotification(rideData.passengerId, 'waiting_reminder', {
            rideId,
            message: 'Tu conductor está esperando. Por favor, acércate al vehículo.',
          });

          // Send notification to driver too
          if (rideData.driverId) {
            await sendRideNotification(rideData.driverId, 'passenger_waiting', {
              rideId,
              message: 'El pasajero aún no ha abordado. Puedes contactarlo si es necesario.',
            });
          }
        }
      }
    } catch (error: any) {
      logger.error('Error sending waiting reminder', { error: error.message, rideId });
    }
  }, 5 * 60 * 1000); // 5 minutes
}

/**
 * Handle ride started
 */
async function handleRideStarted(rideId: string, rideData: Ride): Promise<void> {
  // Send notification to passenger
  await sendRideNotification(rideData.passengerId, 'ride_started', {
    rideId,
    message: 'Tu viaje ha comenzado',
  });

  // Create ride tracking document for real-time updates
  await admin.firestore()
    .collection('ride_tracking')
    .doc(rideId)
    .set({
      rideId,
      passengerId: rideData.passengerId,
      driverId: rideData.driverId,
      status: 'active',
      startedAt: new Date(),
      lastLocationUpdate: null,
      estimatedArrival: null,
      createdAt: new Date(),
    });
}

/**
 * Handle ride completed
 */
async function handleRideCompleted(rideId: string, beforeData: Ride, afterData: Ride): Promise<void> {
  // Send completion notifications
  await Promise.all([
    sendRideNotification(afterData.passengerId, 'ride_completed', {
      rideId,
      fare: afterData.fare,
      message: 'Tu viaje ha terminado. ¡Gracias por viajar con nosotros!',
    }),
    sendRideNotification(afterData.driverId!, 'ride_completed', {
      rideId,
      fare: afterData.fare,
      earnings: afterData.fare * 0.8, // 80% to driver
      message: '¡Viaje completado exitosamente!',
    }),
  ]);

  // Update analytics
  await updateRideAnalytics(rideId, afterData);

  // Clean up ride tracking
  await admin.firestore()
    .collection('ride_tracking')
    .doc(rideId)
    .update({
      status: 'completed',
      completedAt: new Date(),
    });

  // Schedule rating reminders
  setTimeout(async () => {
    try {
      // Check if passenger has rated
      const rideDoc = await admin.firestore()
        .collection('rides')
        .doc(rideId)
        .get();

      if (rideDoc.exists) {
        const currentRideData = rideDoc.data() as Ride;
        
        if (!currentRideData.rating?.passengerRating) {
          await sendRideNotification(afterData.passengerId, 'rating_reminder', {
            rideId,
            message: '¿Cómo fue tu viaje? Califica a tu conductor.',
          });
        }

        if (!currentRideData.rating?.driverRating && afterData.driverId) {
          await sendRideNotification(afterData.driverId, 'rating_reminder', {
            rideId,
            message: 'Califica a tu pasajero para ayudar a mejorar la comunidad.',
          });
        }
      }
    } catch (error: any) {
      logger.error('Error sending rating reminders', { error: error.message, rideId });
    }
  }, 2 * 60 * 1000); // 2 minutes after completion
}

/**
 * Handle ride cancelled
 */
async function handleRideCancelled(rideId: string, beforeData: Ride, afterData: Ride): Promise<void> {
  // Send cancellation notifications
  const notifications: Promise<any>[] = [];

  notifications.push(
    sendRideNotification(afterData.passengerId, 'ride_cancelled', {
      rideId,
      reason: afterData.cancellationReason,
      message: `Tu viaje ha sido cancelado. ${afterData.cancellationReason || ''}`,
    })
  );

  if (afterData.driverId) {
    notifications.push(
      sendRideNotification(afterData.driverId, 'ride_cancelled', {
        rideId,
        reason: afterData.cancellationReason,
        message: `El viaje ha sido cancelado. ${afterData.cancellationReason || ''}`,
      })
    );
  }

  await Promise.all(notifications);

  // If driver was assigned, make them available again
  if (afterData.driverId) {
    await admin.firestore()
      .collection('driver_status')
      .doc(afterData.driverId)
      .update({
        isAvailable: true,
        currentRideId: null,
        updatedAt: new Date(),
      });
  }

  // Update analytics
  await updateRideAnalytics(rideId, afterData);

  // Clean up ride tracking
  await admin.firestore()
    .collection('ride_tracking')
    .doc(rideId)
    .update({
      status: 'cancelled',
      cancelledAt: new Date(),
    });

  // If cancelled due to no drivers, try to find alternatives
  if (afterData.cancellationReason?.includes('conductores disponibles')) {
    setTimeout(async () => {
      try {
        // Try to find drivers again after 2 minutes
        const nearbyDrivers = await findNearbyDrivers(
          afterData.pickup,
          afterData.vehicleType,
          20 // Increased radius
        );

        if (nearbyDrivers.length > 0) {
          // Send notification about drivers becoming available
          await sendRideNotification(afterData.passengerId, 'drivers_available', {
            message: 'Ahora hay conductores disponibles. ¿Quieres solicitar otro viaje?',
            driversCount: nearbyDrivers.length,
          });
        }
      } catch (error: any) {
        logger.error('Error checking for available drivers after cancellation', {
          error: error.message,
          rideId,
        });
      }
    }, 2 * 60 * 1000); // 2 minutes
  }
}

/**
 * Update ride analytics
 */
async function updateRideAnalytics(rideId: string, rideData: Ride): Promise<void> {
  try {
    const batch = admin.firestore().batch();

    // Update daily analytics
    const today = new Date().toISOString().split('T')[0];
    const dailyAnalyticsRef = admin.firestore()
      .collection('daily_analytics')
      .doc(today);

    if (rideData.status === RideStatus.COMPLETED) {
      batch.update(dailyAnalyticsRef, {
        totalCompletedRides: admin.firestore.FieldValue.increment(1),
        totalRevenue: admin.firestore.FieldValue.increment(rideData.fare),
        totalDistance: admin.firestore.FieldValue.increment(rideData.distance),
        updatedAt: new Date(),
      }, );
    } else if (rideData.status === RideStatus.CANCELLED) {
      batch.update(dailyAnalyticsRef, {
        totalCancelledRides: admin.firestore.FieldValue.increment(1),
        updatedAt: new Date(),
      }, );
    }

    // Update user analytics
    const passengerAnalyticsRef = admin.firestore()
      .collection('user_analytics')
      .doc(rideData.passengerId);

    batch.update(passengerAnalyticsRef, {
      totalRides: admin.firestore.FieldValue.increment(1),
      totalSpent: rideData.status === RideStatus.COMPLETED 
        ? admin.firestore.FieldValue.increment(rideData.fare) 
        : admin.firestore.FieldValue.increment(0),
      lastActivity: new Date(),
      updatedAt: new Date(),
    });

    // Update driver analytics if applicable
    if (rideData.driverId && rideData.status === RideStatus.COMPLETED) {
      const driverAnalyticsRef = admin.firestore()
        .collection('user_analytics')
        .doc(rideData.driverId);

      batch.update(driverAnalyticsRef, {
        totalRides: admin.firestore.FieldValue.increment(1),
        totalEarned: admin.firestore.FieldValue.increment(rideData.fare * 0.8),
        lastActivity: new Date(),
        updatedAt: new Date(),
      });
    }

    await batch.commit();
  } catch (error: any) {
    logger.error('Error updating ride analytics', {
      error: error.message,
      rideId,
    });
  }
}

/**
 * Scheduled function to cleanup old ride tracking data
 */
export const cleanupRideTracking = functions
  .region('us-central1')
  .pubsub
  .schedule('0 3 * * *') // Every day at 3 AM
  .timeZone('America/Argentina/Buenos_Aires')
  .onRun(async (context) => {
    try {
      const sevenDaysAgo = new Date();
      sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

      // Find old tracking documents
      const oldTrackingQuery = await admin.firestore()
        .collection('ride_tracking')
        .where('createdAt', '<', sevenDaysAgo)
        .limit(500) // Process in batches
        .get();

      if (oldTrackingQuery.empty) {
        logger.info('No old ride tracking data to cleanup');
        return;
      }

      const batch = admin.firestore().batch();
      
      oldTrackingQuery.docs.forEach(doc => {
        batch.delete(doc.ref);
      });

      await batch.commit();

      logger.info('Cleaned up old ride tracking data', {
        deletedCount: oldTrackingQuery.size,
      });

    } catch (error: any) {
      logger.error('Error in cleanupRideTracking scheduled function', {
        error: error.message,
      });
    }
  });