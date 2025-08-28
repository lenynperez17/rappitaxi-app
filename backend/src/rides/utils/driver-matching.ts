import * as admin from 'firebase-admin';
import { LocationData, VehicleType, User } from '@shared/types';
import { calculateDistance, calculateDriverScore } from './ride-calculations';
import { logger } from '@shared/utils/logger';

export interface DriverMatch {
  id: string;
  name: string;
  rating: number;
  distance: number;
  eta: number;
  score: number;
  vehicleInfo: any;
  currentLocation: LocationData;
}

/**
 * Find nearby available drivers for a ride request
 */
export async function findNearbyDrivers(
  pickupLocation: LocationData,
  vehicleType: VehicleType,
  maxRadius: number = 15, // km
  maxDrivers: number = 10
): Promise<DriverMatch[]> {
  try {
    // Get all online and available drivers with matching vehicle type
    const driverStatusQuery = await admin.firestore()
      .collection('driver_status')
      .where('isOnline', '==', true)
      .where('isAvailable', '==', true)
      .where('currentRideId', '==', null)
      .get();

    if (driverStatusQuery.empty) {
      logger.info('No online drivers found');
      return [];
    }

    const driverMatches: DriverMatch[] = [];

    // Process each driver
    for (const driverStatusDoc of driverStatusQuery.docs) {
      const driverStatus = driverStatusDoc.data();
      const driverId = driverStatus.driverId;

      // Skip if no location available
      if (!driverStatus.currentLocation) {
        continue;
      }

      try {
        // Get driver user data
        const driverDoc = await admin.firestore()
          .collection('users')
          .doc(driverId)
          .get();

        if (!driverDoc.exists) {
          continue;
        }

        const driverData = driverDoc.data() as User;

        // Check if driver is active
        if (!driverData.isActive) {
          continue;
        }

        // Check vehicle type compatibility
        const driverVehicleType = driverData.driverData?.vehicleInfo?.type;
        if (!isVehicleTypeCompatible(vehicleType, driverVehicleType)) {
          continue;
        }

        // Calculate distance to pickup
        const distance = calculateDistance(driverStatus.currentLocation, pickupLocation);

        // Skip if too far
        if (distance > maxRadius) {
          continue;
        }

        // Calculate ETA (estimated time of arrival)
        const eta = calculateEstimatedTime(distance);

        // Calculate driver score
        const driverScore = calculateDriverScore(
          driverStatus.currentLocation,
          pickupLocation,
          {
            rating: driverData.driverData?.rating || 5.0,
            totalRides: driverData.driverData?.totalRides || 0,
            acceptanceRate: await getDriverAcceptanceRate(driverId),
            cancellationRate: await getDriverCancellationRate(driverId),
          }
        );

        const driverMatch: DriverMatch = {
          id: driverId,
          name: driverData.name,
          rating: driverData.driverData?.rating || 5.0,
          distance,
          eta,
          score: driverScore,
          vehicleInfo: driverData.driverData?.vehicleInfo,
          currentLocation: driverStatus.currentLocation,
        };

        driverMatches.push(driverMatch);
      } catch (error: any) {
        logger.error('Error processing driver for matching', {
          error: error.message,
          driverId,
        });
        continue;
      }
    }

    // Sort by score (highest first) and limit results
    const sortedDrivers = driverMatches
      .sort((a, b) => b.score - a.score)
      .slice(0, maxDrivers);

    logger.info('Driver matching completed', {
      totalDriversFound: driverMatches.length,
      returnedDrivers: sortedDrivers.length,
      vehicleType,
      maxRadius,
    });

    return sortedDrivers;
  } catch (error: any) {
    logger.error('Error in findNearbyDrivers', {
      error: error.message,
      pickupLocation,
      vehicleType,
      maxRadius,
    });
    return [];
  }
}

/**
 * Calculate estimated time based on distance (simplified)
 */
function calculateEstimatedTime(distanceKm: number): number {
  // Assume average speed of 25 km/h in city with traffic
  const avgSpeed = 25;
  const timeHours = distanceKm / avgSpeed;
  const timeMinutes = timeHours * 60;
  
  // Add buffer time for city driving
  return Math.round(timeMinutes * 1.2);
}

/**
 * Check if driver's vehicle type is compatible with requested type
 */
function isVehicleTypeCompatible(requestedType: VehicleType, driverType: string): boolean {
  const compatibilityMatrix = {
    standard: ['standard', 'premium', 'xl'],
    premium: ['premium', 'xl'],
    xl: ['xl'],
  };

  return compatibilityMatrix[requestedType]?.includes(driverType) || false;
}

/**
 * Get driver's acceptance rate from recent rides
 */
async function getDriverAcceptanceRate(driverId: string): Promise<number> {
  try {
    // Get driver stats from the last 30 days
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    // This would ideally be stored in a driver_stats collection for performance
    // For now, calculate from ride notifications (simplified)
    
    // In a real implementation, you'd track:
    // - Total ride requests sent to driver
    // - Total accepted rides
    // - Calculate acceptance rate

    // Return default high acceptance rate for now
    return 0.85; // 85% default acceptance rate
  } catch (error) {
    return 0.8; // Default fallback
  }
}

/**
 * Get driver's cancellation rate from recent rides
 */
async function getDriverCancellationRate(driverId: string): Promise<number> {
  try {
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    // Get rides where driver was assigned but cancelled
    const cancelledRidesQuery = await admin.firestore()
      .collection('rides')
      .where('driverId', '==', driverId)
      .where('status', '==', 'cancelled')
      .where('createdAt', '>=', thirtyDaysAgo)
      .get();

    // Get total completed + cancelled rides by driver
    const totalRidesQuery = await admin.firestore()
      .collection('rides')
      .where('driverId', '==', driverId)
      .where('createdAt', '>=', thirtyDaysAgo)
      .get();

    if (totalRidesQuery.empty) {
      return 0.05; // Low default cancellation rate for new drivers
    }

    const cancellationRate = cancelledRidesQuery.size / totalRidesQuery.size;
    return Math.min(cancellationRate, 1.0);
  } catch (error) {
    return 0.05; // Default low cancellation rate
  }
}

/**
 * Find optimal driver for immediate assignment
 */
export async function findOptimalDriver(
  pickupLocation: LocationData,
  vehicleType: VehicleType,
  passengerPreferences?: {
    preferredDriverIds?: string[];
    minRating?: number;
    maxDistance?: number;
  }
): Promise<DriverMatch | null> {
  try {
    const maxDistance = passengerPreferences?.maxDistance || 10;
    const minRating = passengerPreferences?.minRating || 4.0;

    let drivers = await findNearbyDrivers(pickupLocation, vehicleType, maxDistance, 20);

    // Filter by minimum rating
    drivers = drivers.filter(driver => driver.rating >= minRating);

    if (drivers.length === 0) {
      return null;
    }

    // Prioritize preferred drivers if specified
    if (passengerPreferences?.preferredDriverIds) {
      const preferredDrivers = drivers.filter(driver => 
        passengerPreferences.preferredDriverIds!.includes(driver.id)
      );
      
      if (preferredDrivers.length > 0) {
        return preferredDrivers[0]; // Return best preferred driver
      }
    }

    // Apply additional scoring factors
    const scoredDrivers = drivers.map(driver => ({
      ...driver,
      finalScore: calculateFinalDriverScore(driver, {
        distanceWeight: 0.4,
        ratingWeight: 0.3,
        experienceWeight: 0.2,
        reliabilityWeight: 0.1,
      }),
    }));

    // Sort by final score and return best match
    scoredDrivers.sort((a, b) => b.finalScore - a.finalScore);
    
    return scoredDrivers[0];
  } catch (error: any) {
    logger.error('Error finding optimal driver', {
      error: error.message,
      pickupLocation,
      vehicleType,
    });
    return null;
  }
}

/**
 * Calculate final driver score with weighted factors
 */
function calculateFinalDriverScore(
  driver: DriverMatch,
  weights: {
    distanceWeight: number;
    ratingWeight: number;
    experienceWeight: number;
    reliabilityWeight: number;
  }
): number {
  // Normalize distance score (closer is better, max 10 points)
  const distanceScore = Math.max(0, 10 - driver.distance);
  
  // Rating score (direct rating value, max 5)
  const ratingScore = driver.rating;
  
  // Use existing score for experience and reliability
  const experienceScore = Math.min(3, driver.score / 5); // Approximate from total score
  const reliabilityScore = Math.min(2, driver.score / 10); // Approximate from total score
  
  const finalScore = 
    (distanceScore * weights.distanceWeight) +
    (ratingScore * weights.ratingWeight) +
    (experienceScore * weights.experienceWeight) +
    (reliabilityScore * weights.reliabilityWeight);

  return Math.round(finalScore * 100) / 100;
}

/**
 * Filter drivers by availability and vehicle requirements
 */
export async function filterAvailableDrivers(
  driverIds: string[],
  vehicleType: VehicleType,
  specialRequirements?: {
    accessibilityRequired?: boolean;
    petFriendly?: boolean;
    smokingAllowed?: boolean;
  }
): Promise<string[]> {
  try {
    const availableDrivers: string[] = [];

    for (const driverId of driverIds) {
      // Check driver status
      const driverStatusDoc = await admin.firestore()
        .collection('driver_status')
        .doc(driverId)
        .get();

      if (!driverStatusDoc.exists) continue;

      const driverStatus = driverStatusDoc.data();
      
      // Check basic availability
      if (!driverStatus.isOnline || !driverStatus.isAvailable || driverStatus.currentRideId) {
        continue;
      }

      // Check vehicle compatibility
      const driverDoc = await admin.firestore()
        .collection('users')
        .doc(driverId)
        .get();

      if (!driverDoc.exists) continue;

      const driverData = driverDoc.data() as User;
      const driverVehicleType = driverData.driverData?.vehicleInfo?.type;

      if (!isVehicleTypeCompatible(vehicleType, driverVehicleType)) {
        continue;
      }

      // Check special requirements if specified
      if (specialRequirements) {
        const vehicleInfo = driverData.driverData?.vehicleInfo;
        
        if (specialRequirements.accessibilityRequired && !vehicleInfo?.accessibilityFeatures) {
          continue;
        }
        
        if (specialRequirements.petFriendly && !vehicleInfo?.petFriendly) {
          continue;
        }
        
        if (specialRequirements.smokingAllowed && !vehicleInfo?.smokingAllowed) {
          continue;
        }
      }

      availableDrivers.push(driverId);
    }

    return availableDrivers;
  } catch (error: any) {
    logger.error('Error filtering available drivers', {
      error: error.message,
      driverIds,
      vehicleType,
    });
    return [];
  }
}

/**
 * Get driver utilization statistics
 */
export async function getDriverUtilizationStats(driverId: string): Promise<{
  onlineHoursToday: number;
  ridesCompletedToday: number;
  acceptanceRateToday: number;
  averageRatingLast30Days: number;
  totalEarningsToday: number;
}> {
  try {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    // Get today's completed rides
    const todayRidesQuery = await admin.firestore()
      .collection('rides')
      .where('driverId', '==', driverId)
      .where('status', '==', 'completed')
      .where('completedAt', '>=', today)
      .where('completedAt', '<', tomorrow)
      .get();

    const ridesCompletedToday = todayRidesQuery.size;

    // Calculate today's earnings
    let totalEarningsToday = 0;
    todayRidesQuery.docs.forEach(doc => {
      const ride = doc.data();
      totalEarningsToday += ride.fare * 0.8; // 80% to driver
    });

    // Get driver earnings document for other stats
    const driverEarningsDoc = await admin.firestore()
      .collection('driver_earnings')
      .doc(driverId)
      .get();

    const driverEarnings = driverEarningsDoc.exists ? driverEarningsDoc.data() : {};

    // Get driver data for rating
    const driverDoc = await admin.firestore()
      .collection('users')
      .doc(driverId)
      .get();

    const driverData = driverDoc.exists ? driverDoc.data() : {};

    return {
      onlineHoursToday: 0, // Would need to track online sessions
      ridesCompletedToday,
      acceptanceRateToday: await getDriverAcceptanceRate(driverId),
      averageRatingLast30Days: driverData.driverData?.rating || 5.0,
      totalEarningsToday: Math.round(totalEarningsToday),
    };
  } catch (error: any) {
    logger.error('Error getting driver utilization stats', {
      error: error.message,
      driverId,
    });
    
    return {
      onlineHoursToday: 0,
      ridesCompletedToday: 0,
      acceptanceRateToday: 0.8,
      averageRatingLast30Days: 5.0,
      totalEarningsToday: 0,
    };
  }
}

export interface PaginationInfo {
  page: number;
  limit: number;
  total: number;
  totalPages: number;
}
