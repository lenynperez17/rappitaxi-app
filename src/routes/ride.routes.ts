import { Router, Request, Response, NextFunction } from 'express';
import { body, param, query, validationResult } from 'express-validator';
import admin from 'firebase-admin';
import { logger } from '../utils/logger';
import PaymentService from '../services/payment.service';
import { getDistance } from 'geolib';

const router = Router();
const db = admin.firestore();
const paymentService = new PaymentService();

// Tipos de datos
interface Location {
  latitude: number;
  longitude: number;
  address: string;
}

interface RideData {
  passengerId: string;
  driverId?: string;
  pickup: Location;
  destination: Location;
  status: 'pending' | 'accepted' | 'rejected' | 'in_progress' | 'completed' | 'cancelled';
  paymentMethod: 'cash' | 'card' | 'mercadopago';
  estimatedFare: number;
  finalFare?: number;
  distance?: number;
  duration?: number;
  notes?: string;
  createdAt: FirebaseFirestore.Timestamp;
  updatedAt: FirebaseFirestore.Timestamp;
  currentLocation?: FirebaseFirestore.GeoPoint;
  acceptedAt?: FirebaseFirestore.Timestamp;
  startedAt?: FirebaseFirestore.Timestamp;
  completedAt?: FirebaseFirestore.Timestamp;
  cancelledAt?: FirebaseFirestore.Timestamp;
  cancelReason?: string;
  rating?: number;
  ratingComment?: string;
}

// Middleware de validación común
const handleValidationErrors = (req: Request, res: Response, next: NextFunction): void => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    res.status(400).json({
      success: false,
      message: 'Errores de validación',
      errors: errors.array()
    });
    return;
  }
  next();
};

// Middleware para verificar autenticación
const authMiddleware = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  try {
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) {
      res.status(401).json({ success: false, message: 'Token no proporcionado' });
      return;
    }
    
    const decodedToken = await admin.auth().verifyIdToken(token);
    req['userId'] = decodedToken.uid;
    req['userRole'] = decodedToken.role || 'passenger';
    next();
  } catch (error) {
    res.status(401).json({ success: false, message: 'Token inválido' });
  }
};

// Validaciones para obtener viajes
const getRidesValidation = [
  query('status')
    .optional()
    .isIn(['pending', 'accepted', 'in_progress', 'completed', 'cancelled'])
    .withMessage('Estado inválido'),
  query('limit')
    .optional()
    .isInt({ min: 1, max: 100 })
    .withMessage('Límite debe ser un número entre 1 y 100'),
  query('page')
    .optional()
    .isInt({ min: 1 })
    .withMessage('Página debe ser un número mayor a 0'),
  handleValidationErrors
];

// Validaciones para crear viaje
const createRideValidation = [
  body('pickup')
    .isObject()
    .withMessage('Punto de recogida requerido'),
  body('pickup.latitude')
    .isFloat({ min: -90, max: 90 })
    .withMessage('Latitud de recogida debe estar entre -90 y 90'),
  body('pickup.longitude')
    .isFloat({ min: -180, max: 180 })
    .withMessage('Longitud de recogida debe estar entre -180 y 180'),
  body('pickup.address')
    .isLength({ min: 5, max: 200 })
    .withMessage('Dirección de recogida debe tener entre 5 y 200 caracteres')
    .trim(),
  body('destination')
    .isObject()
    .withMessage('Destino requerido'),
  body('destination.latitude')
    .isFloat({ min: -90, max: 90 })
    .withMessage('Latitud de destino debe estar entre -90 y 90'),
  body('destination.longitude')
    .isFloat({ min: -180, max: 180 })
    .withMessage('Longitud de destino debe estar entre -180 y 180'),
  body('destination.address')
    .isLength({ min: 5, max: 200 })
    .withMessage('Dirección de destino debe tener entre 5 y 200 caracteres')
    .trim(),
  body('paymentMethod')
    .isIn(['cash', 'card', 'mercadopago'])
    .withMessage('Método de pago debe ser cash, card o mercadopago'),
  body('vehicleType')
    .optional()
    .isIn(['standard', 'premium', 'xl'])
    .withMessage('Tipo de vehículo inválido'),
  body('notes')
    .optional()
    .isLength({ max: 500 })
    .withMessage('Las notas no pueden exceder 500 caracteres')
    .trim(),
  handleValidationErrors
];

// Validación para obtener viaje por ID
const getRideByIdValidation = [
  param('id')
    .isString()
    .isLength({ min: 1 })
    .withMessage('ID de viaje inválido'),
  handleValidationErrors
];

// Validación para aceptar/rechazar viaje
const acceptRejectValidation = [
  param('id')
    .isString()
    .isLength({ min: 1 })
    .withMessage('ID de viaje inválido'),
  body('reason')
    .optional()
    .isString()
    .isLength({ max: 200 })
    .withMessage('Razón no puede exceder 200 caracteres'),
  handleValidationErrors
];

// Validación para actualizar ubicación
const updateLocationValidation = [
  param('id')
    .isString()
    .isLength({ min: 1 })
    .withMessage('ID de viaje inválido'),
  body('latitude')
    .isFloat({ min: -90, max: 90 })
    .withMessage('Latitud debe estar entre -90 y 90'),
  body('longitude')
    .isFloat({ min: -180, max: 180 })
    .withMessage('Longitud debe estar entre -180 y 180'),
  handleValidationErrors
];

// Validación para negociar precio
const negotiatePriceValidation = [
  param('id')
    .isString()
    .isLength({ min: 1 })
    .withMessage('ID de viaje inválido'),
  body('proposedFare')
    .isFloat({ min: 5 })
    .withMessage('Tarifa propuesta debe ser al menos 5 soles'),
  body('message')
    .optional()
    .isString()
    .isLength({ max: 200 })
    .withMessage('Mensaje no puede exceder 200 caracteres'),
  handleValidationErrors
];

// Validación para calificar viaje
const rateRideValidation = [
  param('id')
    .isString()
    .isLength({ min: 1 })
    .withMessage('ID de viaje inválido'),
  body('rating')
    .isInt({ min: 1, max: 5 })
    .withMessage('Calificación debe ser entre 1 y 5'),
  body('comment')
    .optional()
    .isString()
    .isLength({ max: 500 })
    .withMessage('Comentario no puede exceder 500 caracteres'),
  handleValidationErrors
];

// Función auxiliar para calcular tarifa estimada
const calculateEstimatedFare = (distance: number, vehicleType: string = 'standard'): number => {
  const baseFare = 5.0; // Tarifa base
  const perKmRates = {
    standard: 2.5,
    premium: 3.5,
    xl: 4.0
  };
  
  const perKmRate = perKmRates[vehicleType] || perKmRates.standard;
  const distanceInKm = distance / 1000; // Convertir de metros a kilómetros
  const fare = baseFare + (distanceInKm * perKmRate);
  
  // Aplicar tarifa mínima
  return Math.max(fare, 7.0);
};

// GET /api/v1/rides - Obtener viajes
router.get('/', authMiddleware, getRidesValidation, async (req: Request, res: Response): Promise<void> => {
  try {
    const { status, limit = 20, page = 1 } = req.query;
    const userId = req['userId'];
    const userRole = req['userRole'];
    
    logger.info('🚗 Get rides', { userId, userRole, status, limit, page });
    
    // Construir query según el rol del usuario
    let query = db.collection('rides').where('status', '!=', 'deleted');
    
    if (userRole === 'driver') {
      query = query.where('driverId', '==', userId);
    } else if (userRole === 'passenger') {
      query = query.where('passengerId', '==', userId);
    }
    
    if (status) {
      query = query.where('status', '==', status);
    }
    
    // Aplicar paginación
    const snapshot = await query
      .orderBy('createdAt', 'desc')
      .limit(Number(limit))
      .offset((Number(page) - 1) * Number(limit))
      .get();
    
    const rides = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));
    
    res.json({
      success: true,
      message: 'Viajes obtenidos exitosamente',
      data: {
        rides,
        pagination: {
          page: Number(page),
          limit: Number(limit),
          total: rides.length
        }
      }
    });
  } catch (error) {
    logger.error('Error obteniendo viajes:', error);
    res.status(500).json({
      success: false,
      message: 'Error interno del servidor'
    });
  }
});

// GET /api/v1/rides/:id - Obtener viaje por ID
router.get('/:id', authMiddleware, getRideByIdValidation, async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const userId = req['userId'];
    
    logger.info('🚗 Get ride by id', { id, userId });
    
    const rideDoc = await db.collection('rides').doc(id).get();
    
    if (!rideDoc.exists) {
      res.status(404).json({
        success: false,
        message: 'Viaje no encontrado'
      });
      return;
    }
    
    const rideData = rideDoc.data() as RideData;
    
    // Verificar que el usuario tenga acceso a este viaje
    if (rideData.passengerId !== userId && rideData.driverId !== userId) {
      res.status(403).json({
        success: false,
        message: 'No tienes permiso para ver este viaje'
      });
      return;
    }
    
    res.json({
      success: true,
      message: 'Viaje obtenido exitosamente',
      data: {
        id: rideDoc.id,
        ...rideData
      }
    });
  } catch (error) {
    logger.error('Error obteniendo viaje:', error);
    res.status(500).json({
      success: false,
      message: 'Error interno del servidor'
    });
  }
});

// POST /api/v1/rides/create - Crear nuevo viaje
router.post('/create', authMiddleware, createRideValidation, async (req: Request, res: Response): Promise<void> => {
  try {
    const { pickup, destination, paymentMethod, vehicleType = 'standard', notes } = req.body;
    const passengerId = req['userId'];
    
    logger.info('🚗 Create ride', { 
      passengerId, 
      pickup: pickup.address, 
      destination: destination.address 
    });
    
    // Calcular distancia y tarifa estimada
    const distance = getDistance(
      { latitude: pickup.latitude, longitude: pickup.longitude },
      { latitude: destination.latitude, longitude: destination.longitude }
    );
    
    const estimatedFare = calculateEstimatedFare(distance, vehicleType);
    const estimatedDuration = Math.ceil(distance / 500); // Estimación simple: 500m por minuto
    
    // Crear el viaje
    const rideData: Partial<RideData> = {
      passengerId,
      pickup,
      destination,
      status: 'pending',
      paymentMethod,
      estimatedFare,
      distance,
      duration: estimatedDuration,
      notes,
      createdAt: admin.firestore.FieldValue.serverTimestamp() as FirebaseFirestore.Timestamp,
      updatedAt: admin.firestore.FieldValue.serverTimestamp() as FirebaseFirestore.Timestamp
    };
    
    const rideRef = await db.collection('rides').add(rideData);
    const rideId = rideRef.id;
    
    // Buscar conductores cercanos y notificarles
    const nearbyDrivers = await findNearbyDrivers(pickup.latitude, pickup.longitude, 5000); // 5km
    
    // Notificar a los conductores cercanos
    for (const driver of nearbyDrivers) {
      await db.collection('notifications').add({
        userId: driver.id,
        type: 'new_ride_request',
        rideId,
        message: `Nueva solicitud de viaje desde ${pickup.address}`,
        data: { pickup, destination, estimatedFare },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        read: false
      });
    }
    
    res.status(201).json({
      success: true,
      message: 'Viaje creado exitosamente',
      data: {
        rideId,
        status: 'pending',
        pickup,
        destination,
        paymentMethod,
        estimatedFare: estimatedFare.toFixed(2),
        estimatedDuration,
        distance,
        nearbyDrivers: nearbyDrivers.length
      }
    });
  } catch (error) {
    logger.error('Error creando viaje:', error);
    res.status(500).json({
      success: false,
      message: 'Error interno del servidor'
    });
  }
});

// POST /api/v1/rides/:id/accept - Aceptar viaje (conductor)
router.post('/:id/accept', authMiddleware, acceptRejectValidation, async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const driverId = req['userId'];
    
    logger.info('🚗 Accept ride', { rideId: id, driverId });
    
    const rideRef = db.collection('rides').doc(id);
    const rideDoc = await rideRef.get();
    
    if (!rideDoc.exists) {
      res.status(404).json({
        success: false,
        message: 'Viaje no encontrado'
      });
      return;
    }
    
    const rideData = rideDoc.data() as RideData;
    
    // Verificar que el viaje esté pendiente
    if (rideData.status !== 'pending') {
      res.status(400).json({
        success: false,
        message: 'Este viaje ya no está disponible'
      });
      return;
    }
    
    // Actualizar el viaje
    await rideRef.update({
      status: 'accepted',
      driverId,
      acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    // Obtener información del conductor
    const driverDoc = await db.collection('users').doc(driverId).get();
    const driverData = driverDoc.data();
    
    // Notificar al pasajero
    await db.collection('notifications').add({
      userId: rideData.passengerId,
      type: 'ride_accepted',
      rideId: id,
      message: `Tu viaje ha sido aceptado por ${driverData?.name || 'un conductor'}`,
      data: { 
        driverId,
        driverName: driverData?.name,
        driverPhoto: driverData?.photoUrl,
        driverRating: driverData?.rating,
        vehicleInfo: driverData?.vehicle
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      read: false
    });
    
    res.json({
      success: true,
      message: 'Viaje aceptado exitosamente',
      data: {
        rideId: id,
        status: 'accepted',
        passengerId: rideData.passengerId
      }
    });
  } catch (error) {
    logger.error('Error aceptando viaje:', error);
    res.status(500).json({
      success: false,
      message: 'Error interno del servidor'
    });
  }
});

// POST /api/v1/rides/:id/reject - Rechazar viaje (conductor)
router.post('/:id/reject', authMiddleware, acceptRejectValidation, async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const { reason } = req.body;
    const driverId = req['userId'];
    
    logger.info('🚗 Reject ride', { rideId: id, driverId, reason });
    
    // Registrar rechazo
    await db.collection('ride_rejections').add({
      rideId: id,
      driverId,
      reason,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });
    
    res.json({
      success: true,
      message: 'Viaje rechazado'
    });
  } catch (error) {
    logger.error('Error rechazando viaje:', error);
    res.status(500).json({
      success: false,
      message: 'Error interno del servidor'
    });
  }
});

// POST /api/v1/rides/:id/start - Iniciar viaje
router.post('/:id/start', authMiddleware, getRideByIdValidation, async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const driverId = req['userId'];
    
    logger.info('🚗 Start ride', { rideId: id, driverId });
    
    const rideRef = db.collection('rides').doc(id);
    const rideDoc = await rideRef.get();
    
    if (!rideDoc.exists) {
      res.status(404).json({
        success: false,
        message: 'Viaje no encontrado'
      });
      return;
    }
    
    const rideData = rideDoc.data() as RideData;
    
    // Verificar que el conductor sea el asignado
    if (rideData.driverId !== driverId) {
      res.status(403).json({
        success: false,
        message: 'No tienes permiso para iniciar este viaje'
      });
      return;
    }
    
    // Verificar que el viaje esté aceptado
    if (rideData.status !== 'accepted') {
      res.status(400).json({
        success: false,
        message: 'El viaje debe estar aceptado para poder iniciarse'
      });
      return;
    }
    
    // Actualizar el viaje
    await rideRef.update({
      status: 'in_progress',
      startedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    // Notificar al pasajero
    await db.collection('notifications').add({
      userId: rideData.passengerId,
      type: 'ride_started',
      rideId: id,
      message: 'Tu viaje ha comenzado',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      read: false
    });
    
    res.json({
      success: true,
      message: 'Viaje iniciado exitosamente',
      data: {
        rideId: id,
        status: 'in_progress'
      }
    });
  } catch (error) {
    logger.error('Error iniciando viaje:', error);
    res.status(500).json({
      success: false,
      message: 'Error interno del servidor'
    });
  }
});

// POST /api/v1/rides/:id/complete - Completar viaje
router.post('/:id/complete', authMiddleware, getRideByIdValidation, async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const { finalFare } = req.body;
    const driverId = req['userId'];
    
    logger.info('🚗 Complete ride', { rideId: id, driverId, finalFare });
    
    const rideRef = db.collection('rides').doc(id);
    const rideDoc = await rideRef.get();
    
    if (!rideDoc.exists) {
      res.status(404).json({
        success: false,
        message: 'Viaje no encontrado'
      });
      return;
    }
    
    const rideData = rideDoc.data() as RideData;
    
    // Verificar que el conductor sea el asignado
    if (rideData.driverId !== driverId) {
      res.status(403).json({
        success: false,
        message: 'No tienes permiso para completar este viaje'
      });
      return;
    }
    
    // Verificar que el viaje esté en progreso
    if (rideData.status !== 'in_progress') {
      res.status(400).json({
        success: false,
        message: 'El viaje debe estar en progreso para poder completarse'
      });
      return;
    }
    
    // Calcular tarifa final si no se proporciona
    const fare = finalFare || rideData.estimatedFare;
    
    // Actualizar el viaje
    await rideRef.update({
      status: 'completed',
      finalFare: fare,
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    // Procesar pago si no es efectivo
    if (rideData.paymentMethod !== 'cash') {
      // TODO: Procesar pago automático
      logger.info('Procesando pago automático', { method: rideData.paymentMethod, amount: fare });
    }
    
    // Calcular comisión de la plataforma
    const commission = paymentService.calculatePlatformCommission(fare, 'standard');
    
    // Registrar transacción
    await db.collection('transactions').add({
      rideId: id,
      driverId,
      passengerId: rideData.passengerId,
      amount: fare,
      platformCommission: commission.platformCommission,
      driverEarnings: commission.driverEarnings,
      paymentMethod: rideData.paymentMethod,
      status: rideData.paymentMethod === 'cash' ? 'pending' : 'processing',
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    // Notificar al pasajero
    await db.collection('notifications').add({
      userId: rideData.passengerId,
      type: 'ride_completed',
      rideId: id,
      message: `Tu viaje ha sido completado. Total: S/ ${fare.toFixed(2)}`,
      data: { finalFare: fare },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      read: false
    });
    
    res.json({
      success: true,
      message: 'Viaje completado exitosamente',
      data: {
        rideId: id,
        status: 'completed',
        finalFare: fare,
        driverEarnings: commission.driverEarnings
      }
    });
  } catch (error) {
    logger.error('Error completando viaje:', error);
    res.status(500).json({
      success: false,
      message: 'Error interno del servidor'
    });
  }
});

// POST /api/v1/rides/:id/cancel - Cancelar viaje
router.post('/:id/cancel', authMiddleware, acceptRejectValidation, async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const { reason } = req.body;
    const userId = req['userId'];
    const userRole = req['userRole'];
    
    logger.info('🚗 Cancel ride', { rideId: id, userId, reason });
    
    const rideRef = db.collection('rides').doc(id);
    const rideDoc = await rideRef.get();
    
    if (!rideDoc.exists) {
      res.status(404).json({
        success: false,
        message: 'Viaje no encontrado'
      });
      return;
    }
    
    const rideData = rideDoc.data() as RideData;
    
    // Verificar permisos
    if (userRole === 'driver' && rideData.driverId !== userId) {
      res.status(403).json({
        success: false,
        message: 'No tienes permiso para cancelar este viaje'
      });
      return;
    }
    
    if (userRole === 'passenger' && rideData.passengerId !== userId) {
      res.status(403).json({
        success: false,
        message: 'No tienes permiso para cancelar este viaje'
      });
      return;
    }
    
    // Verificar que el viaje no esté completado
    if (rideData.status === 'completed') {
      res.status(400).json({
        success: false,
        message: 'No se puede cancelar un viaje completado'
      });
      return;
    }
    
    // Actualizar el viaje
    await rideRef.update({
      status: 'cancelled',
      cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
      cancelledBy: userId,
      cancelReason: reason,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    // Determinar a quién notificar
    const notifyUserId = userRole === 'driver' ? rideData.passengerId : rideData.driverId;
    
    if (notifyUserId) {
      await db.collection('notifications').add({
        userId: notifyUserId,
        type: 'ride_cancelled',
        rideId: id,
        message: `El viaje ha sido cancelado${reason ? ': ' + reason : ''}`,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        read: false
      });
    }
    
    res.json({
      success: true,
      message: 'Viaje cancelado exitosamente'
    });
  } catch (error) {
    logger.error('Error cancelando viaje:', error);
    res.status(500).json({
      success: false,
      message: 'Error interno del servidor'
    });
  }
});

// POST /api/v1/rides/:id/location - Actualizar ubicación del conductor
router.post('/:id/location', authMiddleware, updateLocationValidation, async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const { latitude, longitude } = req.body;
    const driverId = req['userId'];
    
    logger.debug('📍 Update location', { rideId: id, lat: latitude, lng: longitude });
    
    const rideRef = db.collection('rides').doc(id);
    const rideDoc = await rideRef.get();
    
    if (!rideDoc.exists) {
      res.status(404).json({
        success: false,
        message: 'Viaje no encontrado'
      });
      return;
    }
    
    const rideData = rideDoc.data() as RideData;
    
    // Verificar que el conductor sea el asignado
    if (rideData.driverId !== driverId) {
      res.status(403).json({
        success: false,
        message: 'No autorizado'
      });
      return;
    }
    
    // Actualizar ubicación
    await rideRef.update({
      currentLocation: new admin.firestore.GeoPoint(latitude, longitude),
      lastLocationUpdate: admin.firestore.FieldValue.serverTimestamp()
    });
    
    // También actualizar la ubicación del conductor en su perfil
    await db.collection('users').doc(driverId).update({
      currentLocation: new admin.firestore.GeoPoint(latitude, longitude),
      lastSeen: admin.firestore.FieldValue.serverTimestamp()
    });
    
    res.json({
      success: true,
      message: 'Ubicación actualizada'
    });
  } catch (error) {
    logger.error('Error actualizando ubicación:', error);
    res.status(500).json({
      success: false,
      message: 'Error interno del servidor'
    });
  }
});

// GET /api/v1/rides/nearby-drivers - Buscar conductores cercanos
router.get('/nearby-drivers', authMiddleware, async (req: Request, res: Response): Promise<void> => {
  try {
    const { lat, lng, radius = 5000 } = req.query;
    
    if (!lat || !lng) {
      res.status(400).json({
        success: false,
        message: 'Latitud y longitud son requeridas'
      });
      return;
    }
    
    logger.info('🚗 Find nearby drivers', { lat, lng, radius });
    
    const drivers = await findNearbyDrivers(
      parseFloat(lat as string),
      parseFloat(lng as string),
      parseInt(radius as string)
    );
    
    res.json({
      success: true,
      message: 'Conductores cercanos encontrados',
      data: {
        drivers,
        count: drivers.length
      }
    });
  } catch (error) {
    logger.error('Error buscando conductores:', error);
    res.status(500).json({
      success: false,
      message: 'Error interno del servidor'
    });
  }
});

// POST /api/v1/rides/:id/negotiate - Negociar precio
router.post('/:id/negotiate', authMiddleware, negotiatePriceValidation, async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const { proposedFare, message } = req.body;
    const userId = req['userId'];
    
    logger.info('💰 Negotiate fare', { rideId: id, proposedFare, userId });
    
    const rideDoc = await db.collection('rides').doc(id).get();
    
    if (!rideDoc.exists) {
      res.status(404).json({
        success: false,
        message: 'Viaje no encontrado'
      });
      return;
    }
    
    const rideData = rideDoc.data() as RideData;
    
    // Crear registro de negociación
    await db.collection('fare_negotiations').add({
      rideId: id,
      proposedBy: userId,
      proposedFare,
      message,
      originalFare: rideData.estimatedFare,
      status: 'pending',
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    // Determinar a quién notificar
    const notifyUserId = userId === rideData.passengerId ? rideData.driverId : rideData.passengerId;
    
    if (notifyUserId) {
      await db.collection('notifications').add({
        userId: notifyUserId,
        type: 'fare_negotiation',
        rideId: id,
        message: `Nueva propuesta de tarifa: S/ ${proposedFare.toFixed(2)}`,
        data: { proposedFare, message },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        read: false
      });
    }
    
    res.json({
      success: true,
      message: 'Propuesta de tarifa enviada',
      data: {
        proposedFare,
        status: 'pending'
      }
    });
  } catch (error) {
    logger.error('Error negociando tarifa:', error);
    res.status(500).json({
      success: false,
      message: 'Error interno del servidor'
    });
  }
});

// POST /api/v1/rides/:id/rate - Calificar viaje
router.post('/:id/rate', authMiddleware, rateRideValidation, async (req: Request, res: Response): Promise<void> => {
  try {
    const { id } = req.params;
    const { rating, comment } = req.body;
    const userId = req['userId'];
    const userRole = req['userRole'];
    
    logger.info('⭐ Rate ride', { rideId: id, rating, userId });
    
    const rideDoc = await db.collection('rides').doc(id).get();
    
    if (!rideDoc.exists) {
      res.status(404).json({
        success: false,
        message: 'Viaje no encontrado'
      });
      return;
    }
    
    const rideData = rideDoc.data() as RideData;
    
    // Verificar que el viaje esté completado
    if (rideData.status !== 'completed') {
      res.status(400).json({
        success: false,
        message: 'Solo se pueden calificar viajes completados'
      });
      return;
    }
    
    // Verificar que el usuario participó en el viaje
    if (rideData.passengerId !== userId && rideData.driverId !== userId) {
      res.status(403).json({
        success: false,
        message: 'No tienes permiso para calificar este viaje'
      });
      return;
    }
    
    // Crear calificación
    const ratingData = {
      rideId: id,
      ratedBy: userId,
      ratedUser: userRole === 'passenger' ? rideData.driverId : rideData.passengerId,
      rating,
      comment,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    };
    
    await db.collection('ratings').add(ratingData);
    
    // Actualizar promedio de calificación del usuario calificado
    if (ratingData.ratedUser) {
      await updateUserRating(ratingData.ratedUser);
    }
    
    // Actualizar el viaje con la calificación
    const updateField = userRole === 'passenger' ? 'passengerRating' : 'driverRating';
    await db.collection('rides').doc(id).update({
      [updateField]: rating,
      [`${updateField}Comment`]: comment
    });
    
    res.json({
      success: true,
      message: 'Calificación registrada exitosamente',
      data: {
        rating,
        comment
      }
    });
  } catch (error) {
    logger.error('Error calificando viaje:', error);
    res.status(500).json({
      success: false,
      message: 'Error interno del servidor'
    });
  }
});

// Función auxiliar para buscar conductores cercanos
async function findNearbyDrivers(lat: number, lng: number, radiusInMeters: number) {
  try {
    // Obtener todos los conductores activos
    const driversSnapshot = await db.collection('users')
      .where('role', '==', 'driver')
      .where('isOnline', '==', true)
      .where('isAvailable', '==', true)
      .get();
    
    const nearbyDrivers = [];
    
    for (const doc of driversSnapshot.docs) {
      const driver = doc.data();
      
      if (driver.currentLocation) {
        const driverLat = driver.currentLocation.latitude;
        const driverLng = driver.currentLocation.longitude;
        
        // Calcular distancia
        const distance = getDistance(
          { latitude: lat, longitude: lng },
          { latitude: driverLat, longitude: driverLng }
        );
        
        // Si está dentro del radio, agregar a la lista
        if (distance <= radiusInMeters) {
          nearbyDrivers.push({
            id: doc.id,
            name: driver.name,
            photoUrl: driver.photoUrl,
            rating: driver.rating || 0,
            totalTrips: driver.totalTrips || 0,
            vehicle: driver.vehicle,
            distance,
            location: {
              latitude: driverLat,
              longitude: driverLng
            }
          });
        }
      }
    }
    
    // Ordenar por distancia
    nearbyDrivers.sort((a, b) => a.distance - b.distance);
    
    return nearbyDrivers;
  } catch (error) {
    logger.error('Error buscando conductores cercanos:', error);
    return [];
  }
}

// Función auxiliar para actualizar rating promedio del usuario
async function updateUserRating(userId: string) {
  try {
    const ratingsSnapshot = await db.collection('ratings')
      .where('ratedUser', '==', userId)
      .get();
    
    if (ratingsSnapshot.empty) return;
    
    let totalRating = 0;
    let count = 0;
    
    ratingsSnapshot.forEach(doc => {
      const rating = doc.data().rating;
      if (rating) {
        totalRating += rating;
        count++;
      }
    });
    
    const averageRating = count > 0 ? totalRating / count : 0;
    
    await db.collection('users').doc(userId).update({
      rating: Math.round(averageRating * 10) / 10, // Redondear a 1 decimal
      totalRatings: count
    });
    
  } catch (error) {
    logger.error('Error actualizando rating del usuario:', error);
  }
}

// POST /api/v1/rides/search-drivers - Buscar conductores disponibles
router.post('/search-drivers', [
  body('lat').isFloat({ min: -90, max: 90 }).withMessage('Latitud inválida'),
  body('lng').isFloat({ min: -180, max: 180 }).withMessage('Longitud inválida'),
  body('radius').optional().isInt({ min: 1, max: 50 }).withMessage('Radio debe estar entre 1 y 50 km'),
  handleValidationErrors
], async (req: Request, res: Response): Promise<void> => {
  try {
    const { lat, lng, radius = 10 } = req.body;
    const radiusInMeters = radius * 1000; // Convertir a metros

    logger.info(`Buscando conductores en radio de ${radius}km desde (${lat}, ${lng})`);

    // Buscar conductores cercanos usando la función existente
    const nearbyDrivers = await findNearbyDrivers(lat, lng, radiusInMeters);

    // Obtener información adicional de cada conductor
    const driversWithDetails = [];
    for (const driver of nearbyDrivers) {
      const driverDoc = await db.collection('users').doc(driver.id).get();
      const driverData = driverDoc.data();
      
      if (driverData) {
        driversWithDetails.push({
          id: driver.id,
          name: driverData.name,
          photoUrl: driverData.photoUrl,
          rating: driverData.rating || 0,
          totalTrips: driverData.totalTrips || 0,
          acceptanceRate: driverData.acceptanceRate || 100,
          estimatedArrival: Math.ceil(driver.distance / 1000 * 2), // Estimación simple: 2 min por km
          distance: driver.distance,
          location: driver.location,
          vehicle: {
            brand: driverData.vehicle?.brand || '',
            model: driverData.vehicle?.model || '',
            year: driverData.vehicle?.year || '',
            plate: driverData.vehicle?.plate || '',
            color: driverData.vehicle?.color || ''
          }
        });
      }
    }

    res.json({
      success: true,
      message: `${driversWithDetails.length} conductores encontrados`,
      data: {
        drivers: driversWithDetails,
        searchRadius: radius,
        searchLocation: { lat, lng }
      }
    });

  } catch (error) {
    logger.error('Error buscando conductores:', error);
    res.status(500).json({
      success: false,
      message: 'Error interno del servidor'
    });
  }
});

// POST /api/v1/rides/:id/broadcast - Broadcast de solicitud a conductores cercanos
router.post('/:id/broadcast', [
  param('id').isString().withMessage('ID de viaje requerido'),
  body('lat').isFloat({ min: -90, max: 90 }).withMessage('Latitud inválida'),
  body('lng').isFloat({ min: -180, max: 180 }).withMessage('Longitud inválida'),
  body('radius').optional().isInt({ min: 1, max: 20 }).withMessage('Radio debe estar entre 1 y 20 km'),
  handleValidationErrors
], async (req: Request, res: Response): Promise<void> => {
  try {
    const { id: rideId } = req.params;
    const { lat, lng, radius = 15 } = req.body;
    const radiusInMeters = radius * 1000;

    // Verificar que el viaje existe y pertenece al usuario
    const rideDoc = await db.collection('rides').doc(rideId).get();
    if (!rideDoc.exists) {
      res.status(404).json({
        success: false,
        message: 'Viaje no encontrado'
      });
      return;
    }

    const rideData = rideDoc.data() as RideData;
    if (rideData.passengerId !== (req as any).user.uid) {
      res.status(403).json({
        success: false,
        message: 'No autorizado'
      });
      return;
    }

    // Buscar conductores cercanos
    const nearbyDrivers = await findNearbyDrivers(lat, lng, radiusInMeters);

    // Crear notificaciones para cada conductor cercano
    const notifications = [];
    for (const driver of nearbyDrivers.slice(0, 10)) { // Limitar a 10 conductores
      const notificationData = {
        driverId: driver.id,
        type: 'ride_request',
        title: '🚖 Nueva Solicitud de Viaje',
        message: `Solicitud a ${Math.ceil(driver.distance/1000)} km de tu ubicación`,
        rideId,
        data: {
          passengerId: rideData.passengerId,
          pickup: rideData.pickup,
          destination: rideData.destination,
          estimatedFare: rideData.estimatedFare,
          paymentMethod: rideData.paymentMethod,
          distance: driver.distance
        },
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        isRead: false,
        priority: 'high'
      };

      notifications.push(notificationData);
      
      // Guardar notificación en Firestore
      await db.collection('driver_notifications').add(notificationData);
    }

    // Actualizar estado del viaje
    await db.collection('rides').doc(rideId).update({
      status: 'searching',
      broadcastedAt: admin.firestore.FieldValue.serverTimestamp(),
      driversNotified: nearbyDrivers.length
    });

    res.json({
      success: true,
      message: `Solicitud enviada a ${nearbyDrivers.length} conductores cercanos`,
      data: {
        driversNotified: nearbyDrivers.length,
        rideId
      }
    });

  } catch (error) {
    logger.error('Error haciendo broadcast:', error);
    res.status(500).json({
      success: false,
      message: 'Error interno del servidor'
    });
  }
});

export default router;