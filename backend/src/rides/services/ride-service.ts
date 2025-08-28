import { Request, Response } from 'express';
import * as admin from 'firebase-admin';
import { logger, loggerHelpers } from '@shared/utils/logger';
import { AppError } from '@shared/middleware/error-handler';
import { 
  ApiResponse, 
  Ride, 
  RideStatus, 
  VehicleType, 
  PaymentMethod, 
  LocationData, 
  CreateRideRequest, 
  UpdateRideStatusRequest,
  PaginationInfo 
} from '@shared/types';
import { calculateDistance, calculateFare, calculateEstimatedTime } from '../utils/ride-calculations';
import { findNearbyDrivers } from '../utils/driver-matching';
import { validateCoordinates, validateRating } from '../../auth/validators/auth-validators';
import { sendRideNotification } from '../../notifications/services/notification-service';

/**
 * Get ride fare estimate
 */
export const getRideEstimate = async (req: Request, res: Response): Promise<void> => {
  const { pickup, destination, vehicleType = 'standard' } = req.body;

  if (!pickup || !destination) {
    throw new AppError('Ubicaciones de origen y destino requeridas', 400, 'VALIDATION_ERROR');
  }

  if (!validateCoordinates(pickup.latitude, pickup.longitude) || 
      !validateCoordinates(destination.latitude, destination.longitude)) {
    throw new AppError('Coordenadas inválidas', 400, 'INVALID_COORDINATES');
  }

  try {
    const distance = calculateDistance(pickup, destination);
    const estimatedTime = calculateEstimatedTime(distance);
    const fare = calculateFare(distance, estimatedTime, vehicleType as VehicleType);

    // Check surge pricing
    const surgePricing = await checkSurgePricing(pickup);
    const finalFare = fare * surgePricing.multiplier;

    const response: ApiResponse<{
      distance: number;
      estimatedTime: number;
      baseFare: number;
      surgePricing: any;
      finalFare: number;
      vehicleType: string;
    }> = {
      success: true,
      data: {
        distance,
        estimatedTime,
        baseFare: fare,
        surgePricing,
        finalFare,
        vehicleType,
      },
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error) {
    throw new AppError('Error al calcular estimación', 500, 'CALCULATION_ERROR');
  }
};

/**
 * Create a new ride
 */
export const createRide = async (req: Request, res: Response): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }

  const { pickup, destination, vehicleType, paymentMethod, notes }: CreateRideRequest = req.body;

  // Validation
  if (!pickup || !destination || !vehicleType || !paymentMethod) {
    throw new AppError('Todos los campos requeridos', 400, 'VALIDATION_ERROR');
  }

  if (!validateCoordinates(pickup.latitude, pickup.longitude) || 
      !validateCoordinates(destination.latitude, destination.longitude)) {
    throw new AppError('Coordenadas inválidas', 400, 'INVALID_COORDINATES');
  }

  const validVehicleTypes = ['standard', 'premium', 'xl'];
  const validPaymentMethods = ['cash', 'credit_card', 'mercado_pago', 'wallet'];

  if (!validVehicleTypes.includes(vehicleType)) {
    throw new AppError('Tipo de vehículo inválido', 400, 'INVALID_VEHICLE_TYPE');
  }

  if (!validPaymentMethods.includes(paymentMethod)) {
    throw new AppError('Método de pago inválido', 400, 'INVALID_PAYMENT_METHOD');
  }

  try {
    // Check if user has active rides
    const activeRidesQuery = await admin.firestore()
      .collection('rides')
      .where('passengerId', '==', req.userId)
      .where('status', 'in', ['pending', 'driver_assigned', 'driver_arrived', 'in_progress'])
      .get();

    if (!activeRidesQuery.empty) {
      throw new AppError('Ya tienes un viaje activo', 409, 'ACTIVE_RIDE_EXISTS');
    }

    // Calculate ride details
    const distance = calculateDistance(pickup, destination);
    const estimatedTime = calculateEstimatedTime(distance);
    const surgePricing = await checkSurgePricing(pickup);
    const baseFare = calculateFare(distance, estimatedTime, vehicleType as VehicleType);
    const fare = baseFare * surgePricing.multiplier;

    // Create ride document
    const rideRef = admin.firestore().collection('rides').doc();
    const now = new Date();

    const rideData: Partial<Ride> = {
      id: rideRef.id,
      passengerId: req.userId,
      status: RideStatus.PENDING,
      pickup,
      destination,
      vehicleType: vehicleType as VehicleType,
      paymentMethod: paymentMethod as PaymentMethod,
      fare,
      distance,
      duration: estimatedTime,
      createdAt: now,
      updatedAt: now,
      notes,
    };

    await rideRef.set(rideData);

    // Find nearby drivers
    const nearbyDrivers = await findNearbyDrivers(pickup, vehicleType as VehicleType);

    if (nearbyDrivers.length === 0) {
      // Update ride status to no drivers available
      await rideRef.update({
        status: RideStatus.CANCELLED,
        cancellationReason: 'No hay conductores disponibles',
        cancelledAt: new Date(),
        updatedAt: new Date(),
      });

      throw new AppError('No hay conductores disponibles en tu área', 404, 'NO_DRIVERS_AVAILABLE');
    }

    // Send ride requests to nearby drivers
    const notificationPromises = nearbyDrivers.slice(0, 5).map(async (driver) => {
      return sendRideNotification(driver.id, 'ride_request', {
        rideId: rideRef.id,
        pickup,
        destination,
        fare,
        distance,
        estimatedTime,
      });
    });

    await Promise.allSettled(notificationPromises);

    loggerHelpers.logRideEvent('RIDE_CREATED', rideRef.id, req.userId, {
      fare,
      distance,
      vehicleType,
      nearbyDriversCount: nearbyDrivers.length,
    });

    const response: ApiResponse<{ ride: Partial<Ride>; nearbyDriversCount: number }> = {
      success: true,
      data: {
        ride: rideData,
        nearbyDriversCount: nearbyDrivers.length,
      },
      timestamp: new Date().toISOString(),
    };

    res.status(201).json(response);
  } catch (error) {
    throw error;
  }
};

/**
 * Get ride by ID
 */
export const getRideById = async (req: Request, res: Response): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }

  const { rideId } = req.params;

  try {
    const rideDoc = await admin.firestore()
      .collection('rides')
      .doc(rideId)
      .get();

    if (!rideDoc.exists) {
      throw new AppError('Viaje no encontrado', 404, 'RIDE_NOT_FOUND');
    }

    const rideData = rideDoc.data() as Ride;

    // Check if user has access to this ride
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(req.userId)
      .get();

    const userData = userDoc.data();
    const userRole = userData?.role;

    if (userRole !== 'admin' && 
        rideData.passengerId !== req.userId && 
        rideData.driverId !== req.userId) {
      throw new AppError('Acceso denegado', 403, 'ACCESS_DENIED');
    }

    const response: ApiResponse<{ ride: Ride }> = {
      success: true,
      data: { ride: rideData },
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error) {
    throw error;
  }
};

/**
 * Get user rides with pagination
 */
export const getUserRides = async (req: Request, res: Response): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }

  const page = parseInt(req.query.page as string) || 1;
  const limit = Math.min(parseInt(req.query.limit as string) || 10, 50);
  const status = req.query.status as string;
  const userId = req.query.userId as string || req.userId;

  // Check if user can access other user's rides
  const userDoc = await admin.firestore()
    .collection('users')
    .doc(req.userId)
    .get();

  const userData = userDoc.data();
  const userRole = userData?.role;

  if (userRole !== 'admin' && userId !== req.userId) {
    throw new AppError('Acceso denegado', 403, 'ACCESS_DENIED');
  }

  try {
    let query = admin.firestore()
      .collection('rides') as any;

    // Filter by user (passenger or driver)
    if (userRole === 'driver') {
      query = query.where('driverId', '==', userId);
    } else if (userRole === 'passenger') {
      query = query.where('passengerId', '==', userId);
    } else if (userRole === 'admin' && userId !== req.userId) {
      // Admin viewing specific user's rides
      const targetUserDoc = await admin.firestore()
        .collection('users')
        .doc(userId)
        .get();
      
      const targetUserData = targetUserDoc.data();
      if (!targetUserData) {
        throw new AppError('Usuario no encontrado', 404, 'USER_NOT_FOUND');
      }

      if (targetUserData.role === 'driver') {
        query = query.where('driverId', '==', userId);
      } else {
        query = query.where('passengerId', '==', userId);
      }
    }

    // Filter by status if provided
    if (status) {
      query = query.where('status', '==', status);
    }

    // Order by creation date (newest first)
    query = query.orderBy('createdAt', 'desc');

    // Get total count for pagination
    const totalSnapshot = await query.get();
    const total = totalSnapshot.size;

    // Apply pagination
    const offset = (page - 1) * limit;
    const ridesSnapshot = await query.offset(offset).limit(limit).get();

    const rides = ridesSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
    }));

    const totalPages = Math.ceil(total / limit);
    const pagination: PaginationInfo = {
      page,
      limit,
      total,
      totalPages,
      hasNext: page < totalPages,
      hasPrev: page > 1,
    };

    const response: ApiResponse<{ rides: any[]; pagination: PaginationInfo }> = {
      success: true,
      data: { rides, pagination },
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error) {
    throw error;
  }
};

/**
 * Get nearby rides for drivers
 */
export const getNearbyRides = async (req: Request, res: Response): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }

  const { latitude, longitude, radius = 10 } = req.query;

  if (!latitude || !longitude) {
    throw new AppError('Ubicación requerida', 400, 'LOCATION_REQUIRED');
  }

  if (!validateCoordinates(Number(latitude), Number(longitude))) {
    throw new AppError('Coordenadas inválidas', 400, 'INVALID_COORDINATES');
  }

  try {
    // Check if driver is online and available
    const driverStatusDoc = await admin.firestore()
      .collection('driver_status')
      .doc(req.userId)
      .get();

    if (!driverStatusDoc.exists) {
      throw new AppError('Estado del conductor no encontrado', 404, 'DRIVER_STATUS_NOT_FOUND');
    }

    const driverStatus = driverStatusDoc.data();
    if (!driverStatus.isOnline || !driverStatus.isAvailable) {
      const response: ApiResponse<{ rides: any[] }> = {
        success: true,
        data: { rides: [] },
        timestamp: new Date().toISOString(),
      };
      res.json(response);
      return;
    }

    // Get driver's vehicle type
    const driverDoc = await admin.firestore()
      .collection('users')
      .doc(req.userId)
      .get();

    const driverData = driverDoc.data();
    const vehicleType = driverData?.driverData?.vehicleInfo?.type || 'standard';

    // Find pending rides within radius
    const pendingRidesQuery = await admin.firestore()
      .collection('rides')
      .where('status', '==', 'pending')
      .where('vehicleType', '==', vehicleType)
      .get();

    const userLocation = { latitude: Number(latitude), longitude: Number(longitude) };
    const nearbyRides = [];

    for (const doc of pendingRidesQuery.docs) {
      const rideData = doc.data() as Ride;
      const distance = calculateDistance(userLocation, rideData.pickup);
      
      if (distance <= Number(radius)) {
        nearbyRides.push({
          ...rideData,
          distanceToPickup: distance,
        });
      }
    }

    // Sort by distance
    nearbyRides.sort((a, b) => a.distanceToPickup - b.distanceToPickup);

    const response: ApiResponse<{ rides: any[] }> = {
      success: true,
      data: { rides: nearbyRides.slice(0, 10) }, // Limit to 10 nearest rides
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error) {
    throw error;
  }
};

/**
 * Accept a ride (driver)
 */
export const acceptRide = async (req: Request, res: Response): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }

  const { rideId } = req.params;

  try {
    // Check if driver has active ride
    const activeRideQuery = await admin.firestore()
      .collection('rides')
      .where('driverId', '==', req.userId)
      .where('status', 'in', ['driver_assigned', 'driver_arrived', 'in_progress'])
      .get();

    if (!activeRideQuery.empty) {
      throw new AppError('Ya tienes un viaje activo', 409, 'ACTIVE_RIDE_EXISTS');
    }

    const rideRef = admin.firestore().collection('rides').doc(rideId);
    const rideDoc = await rideRef.get();

    if (!rideDoc.exists) {
      throw new AppError('Viaje no encontrado', 404, 'RIDE_NOT_FOUND');
    }

    const rideData = rideDoc.data() as Ride;

    if (rideData.status !== RideStatus.PENDING) {
      throw new AppError('El viaje ya no está disponible', 409, 'RIDE_NOT_AVAILABLE');
    }

    // Update ride with driver assignment
    await rideRef.update({
      driverId: req.userId,
      status: RideStatus.DRIVER_ASSIGNED,
      updatedAt: new Date(),
    });

    // Update driver status
    await admin.firestore()
      .collection('driver_status')
      .doc(req.userId)
      .update({
        isAvailable: false,
        currentRideId: rideId,
        updatedAt: new Date(),
      });

    // Send notification to passenger
    await sendRideNotification(rideData.passengerId, 'ride_assigned', {
      rideId,
      driverId: req.userId,
    });

    loggerHelpers.logRideEvent('RIDE_ACCEPTED', rideId, req.userId, {
      passengerId: rideData.passengerId,
    });

    const response: ApiResponse = {
      success: true,
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error) {
    throw error;
  }
};

/**
 * Reject a ride (driver)
 */
export const rejectRide = async (req: Request, res: Response): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }

  const { rideId } = req.params;

  try {
    const rideDoc = await admin.firestore()
      .collection('rides')
      .doc(rideId)
      .get();

    if (!rideDoc.exists) {
      throw new AppError('Viaje no encontrado', 404, 'RIDE_NOT_FOUND');
    }

    const rideData = rideDoc.data() as Ride;

    if (rideData.status !== RideStatus.PENDING) {
      throw new AppError('El viaje ya no está disponible', 409, 'RIDE_NOT_AVAILABLE');
    }

    // Log the rejection
    loggerHelpers.logRideEvent('RIDE_REJECTED', rideId, req.userId, {
      passengerId: rideData.passengerId,
    });

    // Find other nearby drivers
    const nearbyDrivers = await findNearbyDrivers(rideData.pickup, rideData.vehicleType);
    const availableDrivers = nearbyDrivers.filter(driver => driver.id !== req.userId);

    if (availableDrivers.length > 0) {
      // Send to next available driver
      await sendRideNotification(availableDrivers[0].id, 'ride_request', {
        rideId,
        pickup: rideData.pickup,
        destination: rideData.destination,
        fare: rideData.fare,
        distance: rideData.distance,
        estimatedTime: rideData.duration,
      });
    } else {
      // No more drivers available, cancel ride
      await admin.firestore()
        .collection('rides')
        .doc(rideId)
        .update({
          status: RideStatus.CANCELLED,
          cancellationReason: 'No hay conductores disponibles',
          cancelledAt: new Date(),
          updatedAt: new Date(),
        });

      // Notify passenger
      await sendRideNotification(rideData.passengerId, 'ride_cancelled', {
        rideId,
        reason: 'No hay conductores disponibles',
      });
    }

    const response: ApiResponse = {
      success: true,
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error) {
    throw error;
  }
};

/**
 * Start a ride (driver)
 */
export const startRide = async (req: Request, res: Response): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }

  const { rideId } = req.params;

  try {
    const rideRef = admin.firestore().collection('rides').doc(rideId);
    const rideDoc = await rideRef.get();

    if (!rideDoc.exists) {
      throw new AppError('Viaje no encontrado', 404, 'RIDE_NOT_FOUND');
    }

    const rideData = rideDoc.data() as Ride;

    if (rideData.driverId !== req.userId) {
      throw new AppError('Acceso denegado', 403, 'ACCESS_DENIED');
    }

    if (rideData.status !== RideStatus.DRIVER_ARRIVED) {
      throw new AppError('El viaje no puede iniciarse en este estado', 409, 'INVALID_STATUS');
    }

    // Update ride status
    await rideRef.update({
      status: RideStatus.IN_PROGRESS,
      startedAt: new Date(),
      updatedAt: new Date(),
    });

    // Send notification to passenger
    await sendRideNotification(rideData.passengerId, 'ride_started', {
      rideId,
      driverId: req.userId,
    });

    loggerHelpers.logRideEvent('RIDE_STARTED', rideId, req.userId, {
      passengerId: rideData.passengerId,
    });

    const response: ApiResponse = {
      success: true,
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error) {
    throw error;
  }
};

/**
 * Complete a ride (driver)
 */
export const completeRide = async (req: Request, res: Response): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }

  const { rideId } = req.params;
  const { finalLocation, actualDistance, actualDuration } = req.body;

  try {
    const rideRef = admin.firestore().collection('rides').doc(rideId);
    const rideDoc = await rideRef.get();

    if (!rideDoc.exists) {
      throw new AppError('Viaje no encontrado', 404, 'RIDE_NOT_FOUND');
    }

    const rideData = rideDoc.data() as Ride;

    if (rideData.driverId !== req.userId) {
      throw new AppError('Acceso denegado', 403, 'ACCESS_DENIED');
    }

    if (rideData.status !== RideStatus.IN_PROGRESS) {
      throw new AppError('El viaje no puede completarse en este estado', 409, 'INVALID_STATUS');
    }

    // Calculate final fare if actual distance/duration provided
    let finalFare = rideData.fare;
    if (actualDistance && actualDuration) {
      finalFare = calculateFare(actualDistance, actualDuration, rideData.vehicleType);
    }

    // Update ride status
    await rideRef.update({
      status: RideStatus.COMPLETED,
      completedAt: new Date(),
      updatedAt: new Date(),
      fare: finalFare,
      ...(actualDistance && { distance: actualDistance }),
      ...(actualDuration && { duration: actualDuration }),
      ...(finalLocation && { finalLocation }),
    });

    // Update driver status
    await admin.firestore()
      .collection('driver_status')
      .doc(req.userId)
      .update({
        isAvailable: true,
        currentRideId: null,
        updatedAt: new Date(),
      });

    // Update driver earnings
    await admin.firestore()
      .collection('driver_earnings')
      .doc(req.userId)
      .update({
        totalEarnings: admin.firestore.FieldValue.increment(finalFare * 0.8), // 80% to driver
        totalRides: admin.firestore.FieldValue.increment(1),
        updatedAt: new Date(),
      });

    // Update passenger stats
    await admin.firestore()
      .collection('users')
      .doc(rideData.passengerId)
      .update({
        'passengerData.totalRides': admin.firestore.FieldValue.increment(1),
        updatedAt: new Date(),
      });

    // Send notification to passenger
    await sendRideNotification(rideData.passengerId, 'ride_completed', {
      rideId,
      finalFare,
    });

    loggerHelpers.logRideEvent('RIDE_COMPLETED', rideId, req.userId, {
      passengerId: rideData.passengerId,
      finalFare,
      actualDistance,
      actualDuration,
    });

    const response: ApiResponse<{ finalFare: number }> = {
      success: true,
      data: { finalFare },
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error) {
    throw error;
  }
};

/**
 * Cancel a ride
 */
export const cancelRide = async (req: Request, res: Response): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }

  const { rideId } = req.params;
  const { reason } = req.body;

  try {
    const rideRef = admin.firestore().collection('rides').doc(rideId);
    const rideDoc = await rideRef.get();

    if (!rideDoc.exists) {
      throw new AppError('Viaje no encontrado', 404, 'RIDE_NOT_FOUND');
    }

    const rideData = rideDoc.data() as Ride;

    // Check if user can cancel this ride
    if (rideData.passengerId !== req.userId && rideData.driverId !== req.userId) {
      throw new AppError('Acceso denegado', 403, 'ACCESS_DENIED');
    }

    if ([RideStatus.COMPLETED, RideStatus.CANCELLED].includes(rideData.status)) {
      throw new AppError('El viaje no puede cancelarse', 409, 'CANNOT_CANCEL');
    }

    // Update ride status
    await rideRef.update({
      status: RideStatus.CANCELLED,
      cancellationReason: reason || 'Cancelado por usuario',
      cancelledAt: new Date(),
      updatedAt: new Date(),
    });

    // If driver was assigned, make them available again
    if (rideData.driverId) {
      await admin.firestore()
        .collection('driver_status')
        .doc(rideData.driverId)
        .update({
          isAvailable: true,
          currentRideId: null,
          updatedAt: new Date(),
        });

      // Notify the other party
      const targetUserId = req.userId === rideData.passengerId ? rideData.driverId : rideData.passengerId;
      await sendRideNotification(targetUserId, 'ride_cancelled', {
        rideId,
        reason,
        cancelledBy: req.userId,
      });
    }

    loggerHelpers.logRideEvent('RIDE_CANCELLED', rideId, req.userId, {
      reason,
      status: rideData.status,
      driverId: rideData.driverId,
      passengerId: rideData.passengerId,
    });

    const response: ApiResponse = {
      success: true,
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error) {
    throw error;
  }
};

/**
 * Update ride status
 */
export const updateRideStatus = async (req: Request, res: Response): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }

  const { rideId } = req.params;
  const { status, location, notes }: UpdateRideStatusRequest = req.body;

  try {
    const rideRef = admin.firestore().collection('rides').doc(rideId);
    const rideDoc = await rideRef.get();

    if (!rideDoc.exists) {
      throw new AppError('Viaje no encontrado', 404, 'RIDE_NOT_FOUND');
    }

    const rideData = rideDoc.data() as Ride;

    // Only driver can update status
    if (rideData.driverId !== req.userId) {
      throw new AppError('Acceso denegado', 403, 'ACCESS_DENIED');
    }

    const updates: any = {
      status,
      updatedAt: new Date(),
    };

    if (location) updates.currentLocation = location;
    if (notes) updates.notes = notes;

    await rideRef.update(updates);

    // Send appropriate notification
    let notificationType = '';
    switch (status) {
      case RideStatus.DRIVER_ARRIVED:
        notificationType = 'driver_arrived';
        break;
      default:
        notificationType = 'ride_status_update';
    }

    if (notificationType) {
      await sendRideNotification(rideData.passengerId, notificationType, {
        rideId,
        status,
        location,
      });
    }

    loggerHelpers.logRideEvent('RIDE_STATUS_UPDATED', rideId, req.userId, {
      newStatus: status,
      previousStatus: rideData.status,
    });

    const response: ApiResponse = {
      success: true,
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error) {
    throw error;
  }
};

/**
 * Update driver location during ride
 */
export const updateDriverLocation = async (req: Request, res: Response): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }

  const { rideId } = req.params;
  const { location } = req.body;

  if (!location || !validateCoordinates(location.latitude, location.longitude)) {
    throw new AppError('Ubicación válida requerida', 400, 'INVALID_LOCATION');
  }

  try {
    const rideDoc = await admin.firestore()
      .collection('rides')
      .doc(rideId)
      .get();

    if (!rideDoc.exists) {
      throw new AppError('Viaje no encontrado', 404, 'RIDE_NOT_FOUND');
    }

    const rideData = rideDoc.data() as Ride;

    if (rideData.driverId !== req.userId) {
      throw new AppError('Acceso denegado', 403, 'ACCESS_DENIED');
    }

    // Update both ride and driver status
    const batch = admin.firestore().batch();

    const rideRef = admin.firestore().collection('rides').doc(rideId);
    batch.update(rideRef, {
      currentDriverLocation: location,
      updatedAt: new Date(),
    });

    const driverStatusRef = admin.firestore()
      .collection('driver_status')
      .doc(req.userId);
    batch.update(driverStatusRef, {
      currentLocation: location,
      lastLocationUpdate: new Date(),
      updatedAt: new Date(),
    });

    await batch.commit();

    const response: ApiResponse = {
      success: true,
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error) {
    throw error;
  }
};

/**
 * Rate a ride
 */
export const rateRide = async (req: Request, res: Response): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }

  const { rideId } = req.params;
  const { rating, comment } = req.body;

  if (!validateRating(rating)) {
    throw new AppError('Calificación debe ser entre 1 y 5', 400, 'INVALID_RATING');
  }

  try {
    const rideDoc = await admin.firestore()
      .collection('rides')
      .doc(rideId)
      .get();

    if (!rideDoc.exists) {
      throw new AppError('Viaje no encontrado', 404, 'RIDE_NOT_FOUND');
    }

    const rideData = rideDoc.data() as Ride;

    if (rideData.status !== RideStatus.COMPLETED) {
      throw new AppError('Solo se pueden calificar viajes completados', 409, 'RIDE_NOT_COMPLETED');
    }

    // Check if user is part of this ride
    if (rideData.passengerId !== req.userId && rideData.driverId !== req.userId) {
      throw new AppError('Acceso denegado', 403, 'ACCESS_DENIED');
    }

    // Check if already rated
    if (rideData.rating) {
      const isPassenger = rideData.passengerId === req.userId;
      const hasRated = isPassenger ? rideData.rating.passengerRating : rideData.rating.driverRating;
      
      if (hasRated) {
        throw new AppError('Ya has calificado este viaje', 409, 'ALREADY_RATED');
      }
    }

    // Update ride rating
    const isPassenger = rideData.passengerId === req.userId;
    const ratingUpdate: any = {
      updatedAt: new Date(),
    };

    if (!rideData.rating) {
      ratingUpdate.rating = {
        passengerId: rideData.passengerId,
        driverId: rideData.driverId,
        createdAt: new Date(),
      };
    }

    if (isPassenger) {
      ratingUpdate['rating.passengerRating'] = rating;
      if (comment) ratingUpdate['rating.passengerComment'] = comment;
    } else {
      ratingUpdate['rating.driverRating'] = rating;
      if (comment) ratingUpdate['rating.driverComment'] = comment;
    }

    await admin.firestore()
      .collection('rides')
      .doc(rideId)
      .update(ratingUpdate);

    // Update user's average rating
    const targetUserId = isPassenger ? rideData.driverId : rideData.passengerId;
    if (targetUserId) {
      await updateUserRating(targetUserId, rating, isPassenger ? 'driver' : 'passenger');
    }

    loggerHelpers.logRideEvent('RIDE_RATED', rideId, req.userId, {
      rating,
      isPassenger,
      targetUserId,
    });

    const response: ApiResponse = {
      success: true,
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error) {
    throw error;
  }
};

/**
 * Get ride history
 */
export const getRideHistory = async (req: Request, res: Response): Promise<void> => {
  // Implementation similar to getUserRides but with additional filters
  return getUserRides(req, res);
};

/**
 * Get active rides
 */
export const getActiveRides = async (req: Request, res: Response): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }

  try {
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(req.userId)
      .get();

    const userData = userDoc.data();
    const userRole = userData?.role;

    let query = admin.firestore()
      .collection('rides') as any;

    // Filter by user role
    if (userRole === 'driver') {
      query = query.where('driverId', '==', req.userId);
    } else if (userRole === 'passenger') {
      query = query.where('passengerId', '==', req.userId);
    }

    // Filter by active statuses
    query = query.where('status', 'in', [
      RideStatus.PENDING,
      RideStatus.DRIVER_ASSIGNED,
      RideStatus.DRIVER_ARRIVED,
      RideStatus.IN_PROGRESS,
    ]);

    const ridesSnapshot = await query.get();
    const rides = ridesSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
    }));

    const response: ApiResponse<{ rides: any[] }> = {
      success: true,
      data: { rides },
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error) {
    throw error;
  }
};

/**
 * Get driver's active ride
 */
export const getDriverActiveRide = async (req: Request, res: Response): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }

  try {
    const driverStatusDoc = await admin.firestore()
      .collection('driver_status')
      .doc(req.userId)
      .get();

    if (!driverStatusDoc.exists) {
      throw new AppError('Estado del conductor no encontrado', 404, 'DRIVER_STATUS_NOT_FOUND');
    }

    const driverStatus = driverStatusDoc.data();
    const currentRideId = driverStatus.currentRideId;

    if (!currentRideId) {
      const response: ApiResponse<{ ride: null }> = {
        success: true,
        data: { ride: null },
        timestamp: new Date().toISOString(),
      };
      res.json(response);
      return;
    }

    const rideDoc = await admin.firestore()
      .collection('rides')
      .doc(currentRideId)
      .get();

    if (!rideDoc.exists) {
      // Clear stale ride reference
      await admin.firestore()
        .collection('driver_status')
        .doc(req.userId)
        .update({
          currentRideId: null,
          isAvailable: true,
          updatedAt: new Date(),
        });

      const response: ApiResponse<{ ride: null }> = {
        success: true,
        data: { ride: null },
        timestamp: new Date().toISOString(),
      };
      res.json(response);
      return;
    }

    const rideData = rideDoc.data();

    const response: ApiResponse<{ ride: any }> = {
      success: true,
      data: { ride: rideData },
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error) {
    throw error;
  }
};

/**
 * Emergency alert
 */
export const emergencyAlert = async (req: Request, res: Response): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }

  const { rideId } = req.params;
  const { location, message } = req.body;

  try {
    const rideDoc = await admin.firestore()
      .collection('rides')
      .doc(rideId)
      .get();

    if (!rideDoc.exists) {
      throw new AppError('Viaje no encontrado', 404, 'RIDE_NOT_FOUND');
    }

    const rideData = rideDoc.data() as Ride;

    // Check if user is part of this ride
    if (rideData.passengerId !== req.userId && rideData.driverId !== req.userId) {
      throw new AppError('Acceso denegado', 403, 'ACCESS_DENIED');
    }

    // Create emergency alert
    const emergencyRef = admin.firestore().collection('emergency_alerts').doc();
    await emergencyRef.set({
      id: emergencyRef.id,
      rideId,
      userId: req.userId,
      userRole: req.userId === rideData.passengerId ? 'passenger' : 'driver',
      location,
      message,
      status: 'active',
      createdAt: new Date(),
      updatedAt: new Date(),
    });

    // Send immediate notifications to emergency contacts and admin
    // This would integrate with emergency services API

    loggerHelpers.logSecurityEvent(
      'EMERGENCY_ALERT',
      req.userId,
      undefined,
      {
        rideId,
        location,
        message,
      }
    );

    const response: ApiResponse<{ emergencyId: string }> = {
      success: true,
      data: { emergencyId: emergencyRef.id },
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error) {
    throw error;
  }
};

/**
 * Share ride location
 */
export const shareRideLocation = async (req: Request, res: Response): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }

  const { rideId } = req.params;
  const { contacts } = req.body; // Array of phone numbers or emails

  try {
    const rideDoc = await admin.firestore()
      .collection('rides')
      .doc(rideId)
      .get();

    if (!rideDoc.exists) {
      throw new AppError('Viaje no encontrado', 404, 'RIDE_NOT_FOUND');
    }

    const rideData = rideDoc.data() as Ride;

    // Only passenger can share ride location
    if (rideData.passengerId !== req.userId) {
      throw new AppError('Solo el pasajero puede compartir la ubicación', 403, 'ACCESS_DENIED');
    }

    // Create shareable link (would integrate with a real sharing service)
    const shareToken = admin.firestore().collection('ride_shares').doc();
    await shareToken.set({
      rideId,
      passengerId: req.userId,
      contacts,
      expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000), // 24 hours
      createdAt: new Date(),
    });

    const shareUrl = `${process.env.FRONTEND_URL}/shared-ride/${shareToken.id}`;

    // Here you would send SMS/email to the contacts with the share URL
    // Integration with SMS service (Twilio) and email service would go here

    loggerHelpers.logRideEvent('RIDE_LOCATION_SHARED', rideId, req.userId, {
      contactsCount: contacts.length,
      shareToken: shareToken.id,
    });

    const response: ApiResponse<{ shareUrl: string }> = {
      success: true,
      data: { shareUrl },
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error) {
    throw error;
  }
};

// Helper functions

/**
 * Check surge pricing conditions
 */
async function checkSurgePricing(location: LocationData): Promise<{ active: boolean; multiplier: number; reason?: string }> {
  // This would implement real surge pricing logic
  // For now, return default
  return {
    active: false,
    multiplier: 1.0,
  };
}

/**
 * Update user's average rating
 */
async function updateUserRating(userId: string, newRating: number, userType: 'passenger' | 'driver'): Promise<void> {
  try {
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(userId)
      .get();

    if (!userDoc.exists) return;

    const userData = userDoc.data();
    const roleData = userType === 'passenger' ? userData.passengerData : userData.driverData;
    
    if (!roleData) return;

    const currentRating = roleData.rating || 5.0;
    const totalRides = roleData.totalRides || 0;
    
    // Calculate new average rating
    const newAverageRating = ((currentRating * totalRides) + newRating) / (totalRides + 1);

    const updatePath = userType === 'passenger' ? 'passengerData.rating' : 'driverData.rating';
    
    await admin.firestore()
      .collection('users')
      .doc(userId)
      .update({
        [updatePath]: Number(newAverageRating.toFixed(2)),
        updatedAt: new Date(),
      });
  } catch (error) {
    logger.error('Error updating user rating', { error, userId, newRating, userType });
  }
}