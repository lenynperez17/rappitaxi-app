import { Request, Response } from 'express';
import * as admin from 'firebase-admin';

// Obtener perfil del conductor
export const getDriverProfile = async (req: Request, res: Response): Promise<void> => {
  try {
    const driverId = req.user?.uid;
    if (!driverId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Conductor no autenticado' }
      });
      return;
    }

    const driverDoc = await admin.firestore().collection('drivers').doc(driverId).get();
    
    if (!driverDoc.exists) {
      res.status(404).json({
        success: false,
        error: { code: 'DRIVER_NOT_FOUND', message: 'Perfil de conductor no encontrado' }
      });
      return;
    }

    const driverData = driverDoc.data();

    // Obtener estadísticas básicas del conductor
    const ridesSnapshot = await admin.firestore()
      .collection('rides')
      .where('driverId', '==', driverId)
      .where('status', '==', 'completed')
      .get();

    const ratingsSnapshot = await admin.firestore()
      .collection('ratings')
      .where('driverId', '==', driverId)
      .get();

    let totalRating = 0;
    let ratingCount = ratingsSnapshot.size;
    
    ratingsSnapshot.docs.forEach(doc => {
      totalRating += doc.data().rating || 0;
    });

    const averageRating = ratingCount > 0 ? (totalRating / ratingCount).toFixed(1) : 0;

    res.status(200).json({
      success: true,
      data: {
        id: driverId,
        firstName: driverData?.firstName,
        lastName: driverData?.lastName,
        email: driverData?.email,
        phone: driverData?.phone,
        profileImage: driverData?.profileImage,
        licenseNumber: driverData?.licenseNumber,
        experienceYears: driverData?.experienceYears,
        status: driverData?.status || 'offline',
        isVerified: driverData?.isVerified || false,
        isActive: driverData?.isActive || true,
        joinDate: driverData?.createdAt,
        lastActiveAt: driverData?.lastActiveAt,
        statistics: {
          totalTrips: ridesSnapshot.size,
          averageRating: parseFloat(averageRating.toString()),
          ratingCount,
          completionRate: driverData?.completionRate || 95.0
        }
      },
      message: 'Perfil de conductor obtenido exitosamente'
    });
  } catch (error) {
    console.error('Error al obtener perfil del conductor:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Error interno del servidor' }
    });
  }
};

// Actualizar perfil del conductor
export const updateDriverProfile = async (req: Request, res: Response): Promise<void> => {
  try {
    const driverId = req.user?.uid;
    if (!driverId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Conductor no autenticado' }
      });
      return;
    }

    const {
      firstName,
      lastName,
      phone,
      profileImage,
      licenseNumber,
      experienceYears,
      emergencyContact
    } = req.body;

    const driverRef = admin.firestore().collection('drivers').doc(driverId);
    const driverDoc = await driverRef.get();

    if (!driverDoc.exists) {
      res.status(404).json({
        success: false,
        error: { code: 'DRIVER_NOT_FOUND', message: 'Perfil de conductor no encontrado' }
      });
      return;
    }

    const updateData: any = {
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    if (firstName) updateData.firstName = firstName;
    if (lastName) updateData.lastName = lastName;
    if (phone) updateData.phone = phone;
    if (profileImage) updateData.profileImage = profileImage;
    if (licenseNumber) updateData.licenseNumber = licenseNumber;
    if (experienceYears) updateData.experienceYears = parseInt(experienceYears);
    if (emergencyContact) updateData.emergencyContact = emergencyContact;

    await driverRef.update(updateData);

    res.status(200).json({
      success: true,
      data: { driverId, updatedFields: Object.keys(updateData) },
      message: 'Perfil de conductor actualizado exitosamente'
    });
  } catch (error) {
    console.error('Error al actualizar perfil del conductor:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Error interno del servidor' }
    });
  }
};

// Obtener estado del conductor
export const getDriverStatus = async (req: Request, res: Response): Promise<void> => {
  try {
    const driverId = req.user?.uid;
    if (!driverId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Conductor no autenticado' }
      });
      return;
    }

    const driverDoc = await admin.firestore().collection('drivers').doc(driverId).get();
    
    if (!driverDoc.exists) {
      res.status(404).json({
        success: false,
        error: { code: 'DRIVER_NOT_FOUND', message: 'Conductor no encontrado' }
      });
      return;
    }

    const driverData = driverDoc.data();

    // Obtener viaje activo si existe
    const activeRideSnapshot = await admin.firestore()
      .collection('rides')
      .where('driverId', '==', driverId)
      .where('status', 'in', ['accepted', 'on_way', 'arrived', 'in_progress'])
      .limit(1)
      .get();

    const activeRide = activeRideSnapshot.empty ? null : {
      id: activeRideSnapshot.docs[0].id,
      ...activeRideSnapshot.docs[0].data()
    };

    res.status(200).json({
      success: true,
      data: {
        driverId,
        status: driverData?.status || 'offline', // online, offline, busy, on_trip
        isVerified: driverData?.isVerified || false,
        isActive: driverData?.isActive || true,
        canAcceptRides: driverData?.status === 'online' && driverData?.isVerified,
        currentLocation: driverData?.currentLocation,
        lastActiveAt: driverData?.lastActiveAt,
        activeRide,
        workingHours: driverData?.workingHours || {
          start: '06:00',
          end: '22:00',
          isFlexible: true
        }
      },
      message: 'Estado del conductor obtenido exitosamente'
    });
  } catch (error) {
    console.error('Error al obtener estado del conductor:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Error interno del servidor' }
    });
  }
};

// Actualizar estado del conductor
export const updateDriverStatus = async (req: Request, res: Response): Promise<void> => {
  try {
    const driverId = req.user?.uid;
    if (!driverId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Conductor no autenticado' }
      });
      return;
    }

    const { status, workingHours } = req.body;

    if (!status || !['online', 'offline', 'busy'].includes(status)) {
      res.status(400).json({
        success: false,
        error: { code: 'INVALID_STATUS', message: 'Estado inválido' }
      });
      return;
    }

    const driverRef = admin.firestore().collection('drivers').doc(driverId);
    const driverDoc = await driverRef.get();

    if (!driverDoc.exists) {
      res.status(404).json({
        success: false,
        error: { code: 'DRIVER_NOT_FOUND', message: 'Conductor no encontrado' }
      });
      return;
    }

    const driverData = driverDoc.data();

    // Verificar si el conductor puede cambiar a online
    if (status === 'online') {
      if (!driverData?.isVerified) {
        res.status(403).json({
          success: false,
          error: { code: 'NOT_VERIFIED', message: 'Conductor no verificado' }
        });
        return;
      }

      if (!driverData?.isActive) {
        res.status(403).json({
          success: false,
          error: { code: 'ACCOUNT_INACTIVE', message: 'Cuenta inactiva' }
        });
        return;
      }
    }

    const updateData: any = {
      status,
      lastActiveAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    if (workingHours) {
      updateData.workingHours = workingHours;
    }

    // Si se pone offline, limpiar ubicación actual
    if (status === 'offline') {
      updateData.currentLocation = null;
    }

    await driverRef.update(updateData);

    res.status(200).json({
      success: true,
      data: { 
        driverId, 
        newStatus: status,
        canAcceptRides: status === 'online' && driverData?.isVerified
      },
      message: `Estado del conductor cambiado a ${status} exitosamente`
    });
  } catch (error) {
    console.error('Error al actualizar estado del conductor:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Error interno del servidor' }
    });
  }
};

// Obtener ubicación del conductor
export const getDriverLocation = async (req: Request, res: Response): Promise<void> => {
  try {
    const driverId = req.user?.uid;
    if (!driverId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Conductor no autenticado' }
      });
      return;
    }

    const driverDoc = await admin.firestore().collection('drivers').doc(driverId).get();
    
    if (!driverDoc.exists) {
      res.status(404).json({
        success: false,
        error: { code: 'DRIVER_NOT_FOUND', message: 'Conductor no encontrado' }
      });
      return;
    }

    const driverData = driverDoc.data();
    const location = driverData?.currentLocation;

    if (!location) {
      res.status(404).json({
        success: false,
        error: { code: 'LOCATION_NOT_FOUND', message: 'Ubicación no disponible' }
      });
      return;
    }

    res.status(200).json({
      success: true,
      data: {
        driverId,
        location: {
          latitude: location.latitude,
          longitude: location.longitude,
          heading: location.heading || 0,
          speed: location.speed || 0,
          accuracy: location.accuracy || 10,
          timestamp: location.timestamp
        },
        lastUpdate: driverData?.lastLocationUpdate
      },
      message: 'Ubicación del conductor obtenida exitosamente'
    });
  } catch (error) {
    console.error('Error al obtener ubicación del conductor:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Error interno del servidor' }
    });
  }
};

// Actualizar ubicación del conductor
export const updateDriverLocation = async (req: Request, res: Response): Promise<void> => {
  try {
    const driverId = req.user?.uid;
    if (!driverId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Conductor no autenticado' }
      });
      return;
    }

    const { latitude, longitude, heading, speed, accuracy } = req.body;

    if (!latitude || !longitude) {
      res.status(400).json({
        success: false,
        error: { code: 'INVALID_INPUT', message: 'Latitud y longitud son requeridas' }
      });
      return;
    }

    const driverRef = admin.firestore().collection('drivers').doc(driverId);
    const driverDoc = await driverRef.get();

    if (!driverDoc.exists) {
      res.status(404).json({
        success: false,
        error: { code: 'DRIVER_NOT_FOUND', message: 'Conductor no encontrado' }
      });
      return;
    }

    const locationData = {
      latitude: parseFloat(latitude.toString()),
      longitude: parseFloat(longitude.toString()),
      heading: heading ? parseFloat(heading.toString()) : 0,
      speed: speed ? parseFloat(speed.toString()) : 0,
      accuracy: accuracy ? parseFloat(accuracy.toString()) : 10,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    };

    await driverRef.update({
      currentLocation: locationData,
      lastLocationUpdate: admin.firestore.FieldValue.serverTimestamp(),
      lastActiveAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // También actualizar en colección de ubicaciones para tracking
    await admin.firestore().collection('driver_locations').doc(driverId).set({
      driverId,
      ...locationData,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    res.status(200).json({
      success: true,
      data: { driverId, location: locationData },
      message: 'Ubicación del conductor actualizada exitosamente'
    });
  } catch (error) {
    console.error('Error al actualizar ubicación del conductor:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Error interno del servidor' }
    });
  }
};

// Obtener conductores cercanos (método auxiliar para pasajeros)
export const getNearbyDrivers = async (req: Request, res: Response): Promise<void> => {
  try {
    const { latitude, longitude, radius = 5 } = req.query;

    if (!latitude || !longitude) {
      res.status(400).json({
        success: false,
        error: { code: 'INVALID_INPUT', message: 'Latitud y longitud son requeridas' }
      });
      return;
    }

    const lat = parseFloat(latitude as string);
    const lng = parseFloat(longitude as string);
    const radiusKm = parseFloat(radius as string) || 5;

    // Obtener conductores online en la zona (simulado por simplicidad)
    const driversSnapshot = await admin.firestore()
      .collection('drivers')
      .where('status', '==', 'online')
      .where('isVerified', '==', true)
      .where('isActive', '==', true)
      .limit(20)
      .get();

    const nearbyDrivers = driversSnapshot.docs
      .map(doc => {
        const driverData = doc.data();
        const location = driverData.currentLocation;
        
        if (!location) return null;

        // Cálculo simple de distancia (habría que usar una librería más precisa en producción)
        const distance = Math.sqrt(
          Math.pow(lat - location.latitude, 2) + 
          Math.pow(lng - location.longitude, 2)
        ) * 111; // Aproximación km por grado

        if (distance <= radiusKm) {
          return {
            id: doc.id,
            firstName: driverData.firstName,
            lastName: driverData.lastName,
            profileImage: driverData.profileImage,
            rating: driverData.averageRating || 4.5,
            vehicleType: driverData.vehicleType || 'standard',
            location: {
              latitude: location.latitude,
              longitude: location.longitude
            },
            distance: Math.round(distance * 100) / 100,
            eta: Math.ceil(distance * 2) // Estimación simple: 2 min por km
          };
        }
        return null;
      })
      .filter(driver => driver !== null)
      .sort((a, b) => a!.distance - b!.distance);

    res.status(200).json({
      success: true,
      data: { 
        drivers: nearbyDrivers,
        totalCount: nearbyDrivers.length,
        searchRadius: radiusKm
      },
      message: 'Conductores cercanos obtenidos exitosamente'
    });
  } catch (error) {
    console.error('Error al obtener conductores cercanos:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Error interno del servidor' }
    });
  }
};

// Obtener métricas del conductor
export const getDriverMetrics = async (req: Request, res: Response): Promise<void> => {
  try {
    const driverId = req.user?.uid;
    if (!driverId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Conductor no autenticado' }
      });
      return;
    }

    const { period = 'week' } = req.query; // week, month, year

    let startDate = new Date();
    switch (period) {
      case 'week':
        startDate.setDate(startDate.getDate() - 7);
        break;
      case 'month':
        startDate.setMonth(startDate.getMonth() - 1);
        break;
      case 'year':
        startDate.setFullYear(startDate.getFullYear() - 1);
        break;
    }

    // Obtener viajes del período
    const ridesSnapshot = await admin.firestore()
      .collection('rides')
      .where('driverId', '==', driverId)
      .where('createdAt', '>=', startDate)
      .get();

    const completedRides = ridesSnapshot.docs.filter(doc => doc.data().status === 'completed');
    const cancelledRides = ridesSnapshot.docs.filter(doc => doc.data().status === 'cancelled');

    let totalEarnings = 0;
    let totalDistance = 0;
    let totalDuration = 0;

    completedRides.forEach(doc => {
      const ride = doc.data();
      totalEarnings += ride.finalPrice || ride.estimatedPrice || 0;
      totalDistance += ride.distance || 0;
      totalDuration += ride.duration || 0;
    });

    // Obtener ratings del período
    const ratingsSnapshot = await admin.firestore()
      .collection('ratings')
      .where('driverId', '==', driverId)
      .where('createdAt', '>=', startDate)
      .get();

    let totalRating = 0;
    ratingsSnapshot.docs.forEach(doc => {
      totalRating += doc.data().rating || 0;
    });

    const averageRating = ratingsSnapshot.size > 0 ? 
      (totalRating / ratingsSnapshot.size).toFixed(1) : '0.0';

    const metrics = {
      period: period as string,
      totalTrips: ridesSnapshot.size,
      completedTrips: completedRides.length,
      cancelledTrips: cancelledRides.length,
      completionRate: ridesSnapshot.size > 0 ? 
        ((completedRides.length / ridesSnapshot.size) * 100).toFixed(1) : '0.0',
      totalEarnings: Math.round(totalEarnings * 100) / 100,
      averageEarningsPerTrip: completedRides.length > 0 ? 
        Math.round((totalEarnings / completedRides.length) * 100) / 100 : 0,
      totalDistance: Math.round(totalDistance * 100) / 100,
      totalDuration: Math.round(totalDuration),
      averageRating: parseFloat(averageRating.toString()),
      totalRatings: ratingsSnapshot.size,
      efficiency: {
        averageDistancePerTrip: completedRides.length > 0 ? 
          (totalDistance / completedRides.length).toFixed(1) : '0.0',
        averageDurationPerTrip: completedRides.length > 0 ? 
          Math.round(totalDuration / completedRides.length) : 0
      }
    };

    res.status(200).json({
      success: true,
      data: { metrics },
      message: 'Métricas del conductor obtenidas exitosamente'
    });
  } catch (error) {
    console.error('Error al obtener métricas del conductor:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Error interno del servidor' }
    });
  }
};