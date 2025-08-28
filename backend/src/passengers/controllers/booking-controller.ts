import { Request, Response } from 'express';
import * as admin from 'firebase-admin';

// =========================================
// BÚSQUEDA Y ESTIMACIÓN DE PRECIOS
// =========================================

export const searchAddress = async (req: Request, res: Response): Promise<void> => {
  try {
    const { query, lat, lng, radius = 50000 } = req.query;

    if (!query) {
      res.status(400).json({ success: false, error: { code: 'INVALID_INPUT', message: 'Query de búsqueda requerido' }});
      return;
    }

    // Simulación de búsqueda de direcciones (en producción usaría Google Places API)
    const mockResults = [
      {
        place_id: 'place_001',
        description: `${query} - Lima Centro, Lima, Perú`,
        main_text: query.toString(),
        secondary_text: 'Lima Centro, Lima, Perú',
        location: {
          lat: -12.0464 + (Math.random() - 0.5) * 0.01,
          lng: -77.0428 + (Math.random() - 0.5) * 0.01
        },
        types: ['establishment', 'point_of_interest']
      },
      {
        place_id: 'place_002',
        description: `${query} - Miraflores, Lima, Perú`,
        main_text: query.toString(),
        secondary_text: 'Miraflores, Lima, Perú',
        location: {
          lat: -12.1178 + (Math.random() - 0.5) * 0.01,
          lng: -77.0311 + (Math.random() - 0.5) * 0.01
        },
        types: ['establishment', 'point_of_interest']
      },
      {
        place_id: 'place_003',
        description: `${query} - San Isidro, Lima, Perú`,
        main_text: query.toString(),
        secondary_text: 'San Isidro, Lima, Perú',
        location: {
          lat: -12.0989 + (Math.random() - 0.5) * 0.01,
          lng: -77.0349 + (Math.random() - 0.5) * 0.01
        },
        types: ['establishment', 'point_of_interest']
      }
    ];

    res.status(200).json({
      success: true,
      data: {
        predictions: mockResults,
        status: 'OK'
      },
      message: 'Direcciones encontradas exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

export const getPriceEstimate = async (req: Request, res: Response): Promise<void> => {
  try {
    const { 
      pickupLat, 
      pickupLng, 
      destinationLat, 
      destinationLng, 
      vehicleType = 'economic' 
    } = req.query;

    if (!pickupLat || !pickupLng || !destinationLat || !destinationLng) {
      res.status(400).json({ 
        success: false, 
        error: { code: 'INVALID_INPUT', message: 'Coordenadas de origen y destino requeridas' }
      });
      return;
    }

    // Calcular distancia aproximada (fórmula haversine simplificada)
    const lat1 = Number(pickupLat);
    const lon1 = Number(pickupLng);
    const lat2 = Number(destinationLat);
    const lon2 = Number(destinationLng);

    const R = 6371; // Radio de la Tierra en km
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLon = (lon2 - lon1) * Math.PI / 180;
    const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
              Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
              Math.sin(dLon/2) * Math.sin(dLon/2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
    const distance = R * c; // Distancia en km

    // Tarifas por tipo de vehículo
    const baseFares = {
      economic: { base: 5, perKm: 1.2, perMinute: 0.3 },
      standard: { base: 8, perKm: 1.8, perMinute: 0.4 },
      premium: { base: 15, perKm: 2.5, perMinute: 0.6 }
    };

    const fare = baseFares[vehicleType as keyof typeof baseFares] || baseFares.economic;
    const estimatedTime = Math.max(5, distance * 3); // ~20 km/h promedio en Lima
    const basePrice = fare.base + (distance * fare.perKm) + (estimatedTime * fare.perMinute);
    
    // Aplicar surge pricing (simulación)
    const currentHour = new Date().getHours();
    const surgeMultiplier = (currentHour >= 7 && currentHour <= 9) || (currentHour >= 17 && currentHour <= 19) 
      ? 1.5 : 1.0;

    const finalPrice = Math.round(basePrice * surgeMultiplier * 100) / 100;

    res.status(200).json({
      success: true,
      data: {
        distance: Math.round(distance * 100) / 100,
        estimatedTime: Math.round(estimatedTime),
        basePrice: Math.round(basePrice * 100) / 100,
        surgeMultiplier,
        finalPrice,
        currency: 'PEN',
        vehicleType,
        breakdown: {
          baseFare: fare.base,
          distanceFare: Math.round(distance * fare.perKm * 100) / 100,
          timeFare: Math.round(estimatedTime * fare.perMinute * 100) / 100,
          surgeFare: Math.round((finalPrice - basePrice) * 100) / 100
        }
      },
      message: 'Estimación de precio calculada exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

export const getAvailableVehicleTypes = async (req: Request, res: Response): Promise<void> => {
  try {
    const vehicleTypes = [
      {
        id: 'economic',
        name: 'Económico',
        description: 'La opción más económica',
        capacity: 4,
        priceMultiplier: 1.0,
        features: ['Aire acondicionado', 'Música'],
        estimatedArrival: '3-8 min',
        icon: 'economic_car'
      },
      {
        id: 'standard',
        name: 'Estándar',
        description: 'Comodidad y precio balanceado',
        capacity: 4,
        priceMultiplier: 1.5,
        features: ['Aire acondicionado', 'Música', 'Cargador USB'],
        estimatedArrival: '2-6 min',
        icon: 'standard_car'
      },
      {
        id: 'premium',
        name: 'Premium',
        description: 'Vehículos de lujo y confort',
        capacity: 4,
        priceMultiplier: 2.0,
        features: ['Aire acondicionado', 'Música', 'Cargador USB', 'Wi-Fi', 'Agua gratis'],
        estimatedArrival: '1-5 min',
        icon: 'premium_car'
      }
    ];

    res.status(200).json({
      success: true,
      data: vehicleTypes,
      message: 'Tipos de vehículo obtenidos exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

// =========================================
// SOLICITUD Y GESTIÓN DE VIAJES
// =========================================

export const requestRide = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }});
      return;
    }

    const {
      pickupLocation,
      destinationLocation,
      vehicleType = 'economic',
      paymentMethod = 'cash',
      estimatedPrice,
      passengerCount = 1,
      notes,
      negotiationType = 'fixed' // 'fixed' | 'negotiable'
    } = req.body;

    if (!pickupLocation || !destinationLocation) {
      res.status(400).json({ 
        success: false, 
        error: { code: 'INVALID_INPUT', message: 'Ubicación de origen y destino requeridas' }
      });
      return;
    }

    const rideId = `ride_${Date.now()}_${userId.substr(0, 8)}`;
    const rideData = {
      id: rideId,
      passengerId: userId,
      pickupLocation,
      destinationLocation,
      vehicleType,
      paymentMethod,
      estimatedPrice,
      passengerCount,
      notes: notes || '',
      negotiationType,
      status: negotiationType === 'negotiable' ? 'negotiating' : 'searching',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    // Guardar en Firestore
    await admin.firestore().collection('rides').doc(rideId).set(rideData);

    res.status(201).json({
      success: true,
      data: {
        rideId,
        ...rideData,
        message: negotiationType === 'negotiable' 
          ? 'Viaje creado. Los conductores pueden hacer ofertas.'
          : 'Viaje solicitado. Buscando conductor disponible.'
      },
      message: 'Viaje solicitado exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

export const getCurrentRide = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }});
      return;
    }

    // Buscar viaje activo del usuario
    const snapshot = await admin.firestore().collection('rides')
      .where('passengerId', '==', userId)
      .where('status', 'in', ['searching', 'negotiating', 'assigned', 'driver_arrived', 'in_progress'])
      .orderBy('createdAt', 'desc')
      .limit(1)
      .get();

    if (snapshot.empty) {
      res.status(404).json({ 
        success: false, 
        error: { code: 'NO_ACTIVE_RIDE', message: 'No tienes viajes activos' }
      });
      return;
    }

    const rideDoc = snapshot.docs[0];
    const rideData = { id: rideDoc.id, ...rideDoc.data() };

    res.status(200).json({
      success: true,
      data: rideData,
      message: 'Viaje actual obtenido exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

export const cancelRide = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    const { rideId } = req.params;
    const { reason } = req.body;

    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }});
      return;
    }

    // Verificar que el viaje existe y pertenece al usuario
    const rideDoc = await admin.firestore().collection('rides').doc(rideId).get();
    
    if (!rideDoc.exists) {
      res.status(404).json({ success: false, error: { code: 'RIDE_NOT_FOUND', message: 'Viaje no encontrado' }});
      return;
    }

    const rideData = rideDoc.data();
    if (rideData?.passengerId !== userId) {
      res.status(403).json({ success: false, error: { code: 'FORBIDDEN', message: 'No autorizado' }});
      return;
    }

    // Verificar que el viaje se puede cancelar
    const cancellableStatuses = ['searching', 'negotiating', 'assigned', 'driver_arrived'];
    if (!cancellableStatuses.includes(rideData?.status)) {
      res.status(400).json({ 
        success: false, 
        error: { code: 'CANNOT_CANCEL', message: 'No se puede cancelar el viaje en su estado actual' }
      });
      return;
    }

    // Actualizar estado del viaje
    await admin.firestore().collection('rides').doc(rideId).update({
      status: 'cancelled_by_passenger',
      cancellationReason: reason || 'Sin motivo especificado',
      cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    res.status(200).json({
      success: true,
      message: 'Viaje cancelado exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

export const updateDestination = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    const { rideId } = req.params;
    const { newDestination } = req.body;

    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }});
      return;
    }

    if (!newDestination) {
      res.status(400).json({ success: false, error: { code: 'INVALID_INPUT', message: 'Nueva destinación requerida' }});
      return;
    }

    const rideDoc = await admin.firestore().collection('rides').doc(rideId).get();
    
    if (!rideDoc.exists) {
      res.status(404).json({ success: false, error: { code: 'RIDE_NOT_FOUND', message: 'Viaje no encontrado' }});
      return;
    }

    const rideData = rideDoc.data();
    if (rideData?.passengerId !== userId) {
      res.status(403).json({ success: false, error: { code: 'FORBIDDEN', message: 'No autorizado' }});
      return;
    }

    // Solo se puede cambiar destino si el viaje está en progreso o asignado
    if (!['assigned', 'driver_arrived', 'in_progress'].includes(rideData?.status)) {
      res.status(400).json({ 
        success: false, 
        error: { code: 'CANNOT_UPDATE', message: 'No se puede cambiar destino en el estado actual' }
      });
      return;
    }

    await admin.firestore().collection('rides').doc(rideId).update({
      destinationLocation: newDestination,
      destinationUpdated: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    res.status(200).json({
      success: true,
      data: { newDestination },
      message: 'Destino actualizado exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

export const addStop = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    const { rideId } = req.params;
    const { stopLocation, estimatedWaitTime = 5 } = req.body;

    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }});
      return;
    }

    if (!stopLocation) {
      res.status(400).json({ success: false, error: { code: 'INVALID_INPUT', message: 'Ubicación de parada requerida' }});
      return;
    }

    const rideDoc = await admin.firestore().collection('rides').doc(rideId).get();
    
    if (!rideDoc.exists || rideDoc.data()?.passengerId !== userId) {
      res.status(404).json({ success: false, error: { code: 'RIDE_NOT_FOUND', message: 'Viaje no encontrado' }});
      return;
    }

    const newStop = {
      id: `stop_${Date.now()}`,
      location: stopLocation,
      estimatedWaitTime,
      addedAt: new Date(),
      status: 'pending'
    };

    await admin.firestore().collection('rides').doc(rideId).update({
      stops: admin.firestore.FieldValue.arrayUnion(newStop),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    res.status(200).json({
      success: true,
      data: newStop,
      message: 'Parada agregada exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

export const shareRide = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    const { rideId } = req.params;
    const { contacts, message } = req.body;

    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }});
      return;
    }

    const rideDoc = await admin.firestore().collection('rides').doc(rideId).get();
    
    if (!rideDoc.exists || rideDoc.data()?.passengerId !== userId) {
      res.status(404).json({ success: false, error: { code: 'RIDE_NOT_FOUND', message: 'Viaje no encontrado' }});
      return;
    }

    const shareUrl = `https://rappitaxi.com/track/${rideId}`;
    const shareData = {
      rideId,
      shareUrl,
      message: message || 'Sígueme en mi viaje con RappiTaxi',
      sharedWith: contacts || [],
      sharedAt: new Date()
    };

    res.status(200).json({
      success: true,
      data: shareData,
      message: 'Viaje compartido exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

export const triggerPanic = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    const { rideId } = req.params;
    const { location, emergencyContacts } = req.body;

    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }});
      return;
    }

    const panicAlert = {
      id: `panic_${Date.now()}`,
      userId,
      rideId: rideId || null,
      location,
      emergencyContacts: emergencyContacts || [],
      timestamp: new Date(),
      status: 'active',
      response: 'pending'
    };

    // Guardar alerta de pánico
    await admin.firestore().collection('panic_alerts').doc(panicAlert.id).set(panicAlert);

    // Si hay un viaje activo, marcarlo como emergencia
    if (rideId) {
      await admin.firestore().collection('rides').doc(rideId).update({
        emergencyAlert: true,
        panicAlertId: panicAlert.id,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }

    res.status(200).json({
      success: true,
      data: {
        alertId: panicAlert.id,
        message: 'Alerta de emergencia activada. Contactando servicios de emergencia.',
        emergencyNumber: '105', // Número de emergencia Perú
        responseTime: '2-5 minutos'
      },
      message: 'Alerta de pánico activada exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

// =========================================
// NEGOCIACIÓN DE PRECIOS (INDRIVE STYLE)
// =========================================

export const getDriverOffers = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    const { rideId } = req.params;

    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }});
      return;
    }

    // Simulación de ofertas de conductores
    const mockOffers = [
      {
        id: 'offer_001',
        driverId: 'driver_001',
        driverName: 'Carlos Mendoza',
        driverRating: 4.8,
        vehicleType: 'economic',
        vehicleModel: 'Toyota Yaris 2019',
        licensePlate: 'ABC-123',
        offeredPrice: 25.50,
        estimatedArrival: 5,
        distance: 1.2,
        message: 'Estoy muy cerca de tu ubicación',
        offerTime: new Date(Date.now() - 2 * 60 * 1000) // Hace 2 minutos
      },
      {
        id: 'offer_002',
        driverId: 'driver_002',
        driverName: 'Ana López',
        driverRating: 4.9,
        vehicleType: 'standard',
        vehicleModel: 'Nissan Versa 2020',
        licensePlate: 'XYZ-789',
        offeredPrice: 28.00,
        estimatedArrival: 3,
        distance: 0.8,
        message: 'Vehículo con aire acondicionado',
        offerTime: new Date(Date.now() - 1 * 60 * 1000) // Hace 1 minuto
      },
      {
        id: 'offer_003',
        driverId: 'driver_003',
        driverName: 'Miguel Torres',
        driverRating: 4.7,
        vehicleType: 'economic',
        vehicleModel: 'Chevrolet Spark 2018',
        licensePlate: 'DEF-456',
        offeredPrice: 23.00,
        estimatedArrival: 7,
        distance: 2.1,
        message: '',
        offerTime: new Date(Date.now() - 30 * 1000) // Hace 30 segundos
      }
    ];

    res.status(200).json({
      success: true,
      data: {
        rideId,
        offers: mockOffers,
        totalOffers: mockOffers.length,
        negotiationStatus: 'active',
        timeRemaining: 240 // 4 minutos restantes
      },
      message: 'Ofertas de conductores obtenidas exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

export const makeCounterOffer = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    const { rideId } = req.params;
    const { offerId, newPrice, message } = req.body;

    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }});
      return;
    }

    if (!offerId || !newPrice) {
      res.status(400).json({ 
        success: false, 
        error: { code: 'INVALID_INPUT', message: 'ID de oferta y nuevo precio requeridos' }
      });
      return;
    }

    const counterOffer = {
      id: `counter_${Date.now()}`,
      rideId,
      offerId,
      passengerId: userId,
      counterPrice: newPrice,
      message: message || '',
      status: 'pending',
      createdAt: new Date()
    };

    res.status(200).json({
      success: true,
      data: counterOffer,
      message: 'Contraoferta enviada exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

export const acceptOffer = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    const { rideId } = req.params;
    const { offerId, finalPrice } = req.body;

    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }});
      return;
    }

    if (!offerId) {
      res.status(400).json({ success: false, error: { code: 'INVALID_INPUT', message: 'ID de oferta requerido' }});
      return;
    }

    // Actualizar el viaje con la oferta aceptada
    await admin.firestore().collection('rides').doc(rideId).update({
      status: 'assigned',
      acceptedOfferId: offerId,
      finalPrice: finalPrice || 0,
      driverId: 'driver_002', // En producción sería el ID real del conductor
      assignedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    res.status(200).json({
      success: true,
      data: {
        rideId,
        offerId,
        finalPrice,
        status: 'assigned',
        message: 'El conductor está en camino'
      },
      message: 'Oferta aceptada exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

export const rejectOffer = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    const { rideId } = req.params;
    const { offerId, reason } = req.body;

    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }});
      return;
    }

    if (!offerId) {
      res.status(400).json({ success: false, error: { code: 'INVALID_INPUT', message: 'ID de oferta requerido' }});
      return;
    }

    res.status(200).json({
      success: true,
      data: {
        rideId,
        offerId,
        rejectedAt: new Date(),
        reason: reason || 'Sin motivo especificado'
      },
      message: 'Oferta rechazada exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

// =========================================
// HISTORIAL Y CALIFICACIONES
// =========================================

export const getRideHistory = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    const { page = 1, limit = 10, status } = req.query;

    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }});
      return;
    }

    let query = admin.firestore().collection('rides')
      .where('passengerId', '==', userId)
      .orderBy('createdAt', 'desc');

    if (status) {
      query = query.where('status', '==', status);
    }

    const snapshot = await query.limit(Number(limit)).get();
    const rides = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));

    res.status(200).json({
      success: true,
      data: {
        rides,
        pagination: {
          page: Number(page),
          limit: Number(limit),
          total: rides.length,
          hasNext: rides.length === Number(limit)
        }
      },
      message: 'Historial de viajes obtenido exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

export const getRideDetails = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    const { rideId } = req.params;

    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }});
      return;
    }

    const rideDoc = await admin.firestore().collection('rides').doc(rideId).get();
    
    if (!rideDoc.exists) {
      res.status(404).json({ success: false, error: { code: 'RIDE_NOT_FOUND', message: 'Viaje no encontrado' }});
      return;
    }

    const rideData = rideDoc.data();
    if (rideData?.passengerId !== userId) {
      res.status(403).json({ success: false, error: { code: 'FORBIDDEN', message: 'No autorizado' }});
      return;
    }

    res.status(200).json({
      success: true,
      data: { id: rideId, ...rideData },
      message: 'Detalles del viaje obtenidos exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

export const downloadReceipt = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    const { rideId } = req.params;

    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }});
      return;
    }

    // En producción, esto generaría un PDF real del recibo
    const receiptData = {
      rideId,
      downloadUrl: `https://rappitaxi.com/receipts/${rideId}.pdf`,
      generatedAt: new Date(),
      expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000) // 24 horas
    };

    res.status(200).json({
      success: true,
      data: receiptData,
      message: 'Recibo generado exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

export const reportLostItem = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    const { rideId } = req.params;
    const { itemDescription, contactInfo } = req.body;

    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }});
      return;
    }

    if (!itemDescription) {
      res.status(400).json({ success: false, error: { code: 'INVALID_INPUT', message: 'Descripción del artículo requerida' }});
      return;
    }

    const lostItemReport = {
      id: `lost_${Date.now()}`,
      rideId,
      passengerId: userId,
      itemDescription,
      contactInfo: contactInfo || {},
      status: 'reported',
      reportedAt: new Date()
    };

    await admin.firestore().collection('lost_items').doc(lostItemReport.id).set(lostItemReport);

    res.status(201).json({
      success: true,
      data: lostItemReport,
      message: 'Reporte de artículo perdido creado exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

export const rateRide = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    const { rideId } = req.params;
    const { rating, feedback, driverRating, vehicleRating } = req.body;

    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }});
      return;
    }

    if (!rating || rating < 1 || rating > 5) {
      res.status(400).json({ success: false, error: { code: 'INVALID_INPUT', message: 'Calificación debe ser entre 1 y 5' }});
      return;
    }

    const ratingData = {
      id: `rating_${Date.now()}`,
      rideId,
      passengerId: userId,
      overallRating: rating,
      driverRating: driverRating || rating,
      vehicleRating: vehicleRating || rating,
      feedback: feedback || '',
      ratedAt: new Date()
    };

    await Promise.all([
      admin.firestore().collection('ratings').doc(ratingData.id).set(ratingData),
      admin.firestore().collection('rides').doc(rideId).update({
        passengerRating: ratingData,
        ratedByPassenger: true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      })
    ]);

    res.status(200).json({
      success: true,
      data: ratingData,
      message: 'Viaje calificado exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

export const getPendingRatings = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;

    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }});
      return;
    }

    const snapshot = await admin.firestore().collection('rides')
      .where('passengerId', '==', userId)
      .where('status', '==', 'completed')
      .where('ratedByPassenger', '==', false)
      .orderBy('completedAt', 'desc')
      .limit(5)
      .get();

    const pendingRatings = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));

    res.status(200).json({
      success: true,
      data: pendingRatings,
      message: 'Calificaciones pendientes obtenidas exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

// =========================================
// VIAJES PROGRAMADOS
// =========================================

export const getScheduledRides = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    const { page = 1, limit = 10 } = req.query;

    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }});
      return;
    }

    const snapshot = await admin.firestore().collection('scheduled_rides')
      .where('passengerId', '==', userId)
      .where('status', 'in', ['scheduled', 'confirmed'])
      .orderBy('scheduledDateTime', 'asc')
      .limit(Number(limit))
      .get();

    const scheduledRides = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));

    res.status(200).json({
      success: true,
      data: {
        scheduledRides,
        pagination: {
          page: Number(page),
          limit: Number(limit),
          total: scheduledRides.length
        }
      },
      message: 'Viajes programados obtenidos exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

export const scheduleRide = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    const {
      pickupLocation,
      destinationLocation,
      scheduledDateTime,
      vehicleType = 'economic',
      paymentMethod = 'cash',
      estimatedPrice,
      notes
    } = req.body;

    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }});
      return;
    }

    if (!pickupLocation || !destinationLocation || !scheduledDateTime) {
      res.status(400).json({ 
        success: false, 
        error: { code: 'INVALID_INPUT', message: 'Origen, destino y fecha/hora programada requeridos' }
      });
      return;
    }

    const scheduledDate = new Date(scheduledDateTime);
    if (scheduledDate <= new Date()) {
      res.status(400).json({ 
        success: false, 
        error: { code: 'INVALID_DATE', message: 'La fecha debe ser futura' }
      });
      return;
    }

    const scheduledRideId = `scheduled_${Date.now()}_${userId.substr(0, 8)}`;
    const scheduledRideData = {
      id: scheduledRideId,
      passengerId: userId,
      pickupLocation,
      destinationLocation,
      scheduledDateTime: scheduledDate,
      vehicleType,
      paymentMethod,
      estimatedPrice,
      notes: notes || '',
      status: 'scheduled',
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    };

    await admin.firestore().collection('scheduled_rides').doc(scheduledRideId).set(scheduledRideData);

    res.status(201).json({
      success: true,
      data: scheduledRideData,
      message: 'Viaje programado exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

export const cancelScheduledRide = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    const { scheduledRideId } = req.params;
    const { reason } = req.body;

    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }});
      return;
    }

    const rideDoc = await admin.firestore().collection('scheduled_rides').doc(scheduledRideId).get();
    
    if (!rideDoc.exists || rideDoc.data()?.passengerId !== userId) {
      res.status(404).json({ success: false, error: { code: 'RIDE_NOT_FOUND', message: 'Viaje programado no encontrado' }});
      return;
    }

    await admin.firestore().collection('scheduled_rides').doc(scheduledRideId).update({
      status: 'cancelled',
      cancellationReason: reason || 'Sin motivo especificado',
      cancelledAt: admin.firestore.FieldValue.serverTimestamp()
    });

    res.status(200).json({
      success: true,
      message: 'Viaje programado cancelado exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

// =========================================
// VIAJES COMPARTIDOS
// =========================================

export const searchSharedRides = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    const { pickupLat, pickupLng, destinationLat, destinationLng, departureTime } = req.query;

    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }});
      return;
    }

    if (!pickupLat || !pickupLng || !destinationLat || !destinationLng) {
      res.status(400).json({ 
        success: false, 
        error: { code: 'INVALID_INPUT', message: 'Coordenadas de origen y destino requeridas' }
      });
      return;
    }

    // Simulación de viajes compartidos disponibles
    const sharedRides = [
      {
        id: 'shared_001',
        driverId: 'driver_004',
        driverName: 'Pedro Ruiz',
        driverRating: 4.6,
        vehicleModel: 'Honda Civic 2019',
        availableSeats: 2,
        estimatedPrice: 18.50, // Precio con descuento por compartir
        pickupDistance: 0.3,
        destinationDistance: 0.5,
        departureTime: new Date(Date.now() + 15 * 60 * 1000), // En 15 minutos
        route: 'Lima Centro - Miraflores',
        passengers: [
          { name: 'María S.', rating: 4.8 },
          { name: 'José L.', rating: 4.5 }
        ]
      },
      {
        id: 'shared_002',
        driverId: 'driver_005',
        driverName: 'Carmen Flores',
        driverRating: 4.9,
        vehicleModel: 'Toyota Corolla 2020',
        availableSeats: 1,
        estimatedPrice: 20.00,
        pickupDistance: 0.8,
        destinationDistance: 0.2,
        departureTime: new Date(Date.now() + 25 * 60 * 1000), // En 25 minutos
        route: 'San Isidro - Miraflores',
        passengers: [
          { name: 'Ana R.', rating: 4.7 },
          { name: 'Luis M.', rating: 4.9 },
          { name: 'Sofia T.', rating: 4.6 }
        ]
      }
    ];

    res.status(200).json({
      success: true,
      data: {
        sharedRides,
        totalResults: sharedRides.length,
        savings: {
          average: '35%',
          description: 'Ahorro promedio comparado con viaje individual'
        }
      },
      message: 'Viajes compartidos encontrados exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

export const joinSharedRide = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user?.uid;
    const { sharedRideId } = req.params;
    const { seatsRequested = 1, pickupPoint, dropoffPoint } = req.body;

    if (!userId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Usuario no autenticado' }});
      return;
    }

    if (!pickupPoint || !dropoffPoint) {
      res.status(400).json({ 
        success: false, 
        error: { code: 'INVALID_INPUT', message: 'Puntos de recogida y destino requeridos' }
      });
      return;
    }

    const joinRequest = {
      id: `join_${Date.now()}`,
      sharedRideId,
      passengerId: userId,
      seatsRequested,
      pickupPoint,
      dropoffPoint,
      status: 'pending',
      requestedAt: new Date()
    };

    res.status(200).json({
      success: true,
      data: joinRequest,
      message: 'Solicitud para unirse al viaje compartido enviada exitosamente'
    });
  } catch (error) {
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: error.message }});
  }
};

// =========================================
// FUNCIONES HEREDADAS (COMPATIBILIDAD)
// =========================================

export const createBooking = requestRide;
export const getBookings = getRideHistory;
export const updateBooking = updateDestination;