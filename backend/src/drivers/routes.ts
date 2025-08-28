import { Router } from 'express';
import { authMiddleware, requireRole } from '@shared/middleware/auth';
import { body, param, query } from 'express-validator';
import { validateRequest } from '@shared/middleware/validation';
import { uploadSingle, uploadMultiple } from '@shared/middleware/upload';
import * as driverController from './controllers/driver-controller';
import * as vehicleController from './controllers/vehicle-controller';
import * as documentsController from './controllers/documents-controller';
import * as earningsController from './controllers/earnings-controller';
import * as scheduleController from './controllers/schedule-controller';

const router = Router();

// Middleware para conductores autenticados
const driverOnly = [authMiddleware, requireRole(['driver'])];

// ============================================
// GESTIÓN DE PERFIL
// ============================================

// Obtener perfil del conductor
router.get(
  '/profile',
  ...driverOnly,
  driverController.getProfile
);

// Actualizar perfil del conductor
router.put(
  '/profile',
  ...driverOnly,
  body('name').optional().isString().isLength({ min: 2, max: 100 }),
  body('phone').optional().isMobilePhone('any'),
  body('email').optional().isEmail().normalizeEmail(),
  body('emergencyContact').optional().isObject(),
  body('bankAccount').optional().isObject(),
  validateRequest,
  driverController.updateProfile
);

// Subir foto de perfil
router.post(
  '/profile/photo',
  ...driverOnly,
  uploadSingle('photo'),
  driverController.uploadProfilePhoto
);

// ============================================
// ESTADO Y DISPONIBILIDAD
// ============================================

// Obtener estado actual
router.get(
  '/status',
  ...driverOnly,
  driverController.getCurrentStatus
);

// Cambiar estado (online/offline/busy)
router.patch(
  '/status',
  ...driverOnly,
  body('status').isIn(['online', 'offline', 'busy']),
  body('reason').optional().isString(),
  validateRequest,
  driverController.updateStatus
);

// Actualizar ubicación
router.post(
  '/location',
  ...driverOnly,
  body('latitude').isFloat({ min: -90, max: 90 }),
  body('longitude').isFloat({ min: -180, max: 180 }),
  body('heading').optional().isFloat({ min: 0, max: 360 }),
  body('speed').optional().isFloat({ min: 0 }),
  body('accuracy').optional().isFloat({ min: 0 }),
  validateRequest,
  driverController.updateLocation
);

// ============================================
// GESTIÓN DE VIAJES
// ============================================

// Obtener viajes disponibles cercanos
router.get(
  '/rides/available',
  ...driverOnly,
  query('latitude').isFloat({ min: -90, max: 90 }),
  query('longitude').isFloat({ min: -180, max: 180 }),
  query('radius').optional().isInt({ min: 1, max: 50 }),
  validateRequest,
  driverController.getNearbyRides
);

// Aceptar solicitud de viaje
router.post(
  '/rides/:rideId/accept',
  ...driverOnly,
  param('rideId').isString(),
  body('estimatedArrival').optional().isInt({ min: 1, max: 60 }),
  validateRequest,
  driverController.acceptRide
);

// Rechazar solicitud de viaje
router.post(
  '/rides/:rideId/reject',
  ...driverOnly,
  param('rideId').isString(),
  body('reason').optional().isString(),
  validateRequest,
  driverController.rejectRide
);

// Obtener viaje actual
router.get(
  '/rides/current',
  ...driverOnly,
  driverController.getCurrentRide
);

// Actualizar estado del viaje
router.patch(
  '/rides/:rideId/status',
  ...driverOnly,
  param('rideId').isString(),
  body('status').isIn(['arrived_at_pickup', 'ride_started', 'arrived_at_destination', 'completed']),
  body('location').optional().isObject(),
  validateRequest,
  driverController.updateRideStatus
);

// Completar viaje
router.post(
  '/rides/:rideId/complete',
  ...driverOnly,
  param('rideId').isString(),
  body('finalFare').isFloat({ min: 0 }),
  body('distance').isFloat({ min: 0 }),
  body('duration').isInt({ min: 0 }),
  body('waitTime').optional().isInt({ min: 0 }),
  body('tolls').optional().isFloat({ min: 0 }),
  validateRequest,
  driverController.completeRide
);

// Cancelar viaje
router.post(
  '/rides/:rideId/cancel',
  ...driverOnly,
  param('rideId').isString(),
  body('reason').isString().isLength({ min: 3, max: 500 }),
  body('category').isIn(['passenger_no_show', 'vehicle_issue', 'emergency', 'other']),
  validateRequest,
  driverController.cancelRide
);

// Obtener historial de viajes
router.get(
  '/rides/history',
  ...driverOnly,
  query('page').optional().isInt({ min: 1 }),
  query('limit').optional().isInt({ min: 1, max: 50 }),
  query('dateFrom').optional().isISO8601(),
  query('dateTo').optional().isISO8601(),
  query('status').optional().isIn(['completed', 'cancelled']),
  validateRequest,
  driverController.getRideHistory
);

// Obtener métricas de rendimiento
router.get(
  '/metrics',
  ...driverOnly,
  query('period').optional().isIn(['today', 'week', 'month', 'year']),
  validateRequest,
  driverController.getDriverMetrics
);

// ============================================
// GESTIÓN DE VEHÍCULO
// ============================================

// Obtener vehículo actual
router.get(
  '/vehicle',
  ...driverOnly,
  vehicleController.getCurrentVehicle
);

// Registrar nuevo vehículo
router.post(
  '/vehicle',
  ...driverOnly,
  body('make').isString().isLength({ min: 2, max: 50 }),
  body('model').isString().isLength({ min: 2, max: 50 }),
  body('year').isInt({ min: 1990, max: new Date().getFullYear() + 1 }),
  body('color').isString().isLength({ min: 3, max: 30 }),
  body('plateNumber').isString().isLength({ min: 5, max: 20 }),
  body('capacity').isInt({ min: 1, max: 8 }),
  body('vehicleType').isIn(['economy', 'standard', 'premium', 'xl']),
  validateRequest,
  vehicleController.registerVehicle
);

// Actualizar vehículo
router.put(
  '/vehicle/:vehicleId',
  ...driverOnly,
  param('vehicleId').isString(),
  body('color').optional().isString().isLength({ min: 3, max: 30 }),
  body('capacity').optional().isInt({ min: 1, max: 8 }),
  body('features').optional().isArray(),
  validateRequest,
  vehicleController.updateVehicle
);

// Subir fotos del vehículo
router.post(
  '/vehicle/:vehicleId/photos',
  ...driverOnly,
  param('vehicleId').isString(),
  uploadMultiple('photos', 5),
  vehicleController.uploadVehiclePhotos
);

// ============================================
// GESTIÓN DE DOCUMENTOS
// ============================================

// Obtener documentos del conductor
router.get(
  '/documents',
  ...driverOnly,
  documentsController.getDocuments
);

// Subir documento
router.post(
  '/documents',
  ...driverOnly,
  body('type').isIn(['license', 'insurance', 'registration', 'background_check', 'vehicle_inspection']),
  body('expiryDate').optional().isISO8601(),
  uploadSingle('document'),
  validateRequest,
  documentsController.uploadDocument
);

// Actualizar documento
router.put(
  '/documents/:documentId',
  ...driverOnly,
  param('documentId').isString(),
  body('expiryDate').optional().isISO8601(),
  uploadSingle('document'),
  validateRequest,
  documentsController.updateDocument
);

// Obtener estado de verificación
router.get(
  '/verification-status',
  ...driverOnly,
  documentsController.getVerificationStatus
);

// ============================================
// GANANCIAS Y PAGOS
// ============================================

// Obtener resumen de ganancias
router.get(
  '/earnings/summary',
  ...driverOnly,
  query('period').optional().isIn(['today', 'week', 'month', 'year']),
  query('dateFrom').optional().isISO8601(),
  query('dateTo').optional().isISO8601(),
  validateRequest,
  earningsController.getEarningsSummary
);

// Obtener detalles de ganancias
router.get(
  '/earnings/details',
  ...driverOnly,
  query('page').optional().isInt({ min: 1 }),
  query('limit').optional().isInt({ min: 1, max: 100 }),
  query('dateFrom').optional().isISO8601(),
  query('dateTo').optional().isISO8601(),
  query('type').optional().isIn(['ride', 'tip', 'bonus', 'adjustment']),
  validateRequest,
  earningsController.getEarningsDetails
);

// Obtener balance actual
router.get(
  '/earnings/balance',
  ...driverOnly,
  earningsController.getCurrentBalance
);

// Solicitar retiro
router.post(
  '/earnings/withdraw',
  ...driverOnly,
  body('amount').isFloat({ min: 10, max: 5000 }),
  body('method').isIn(['bank_transfer', 'mercadopago', 'yape', 'plin']),
  body('accountDetails').isObject(),
  validateRequest,
  earningsController.requestWithdrawal
);

// Historial de retiros
router.get(
  '/earnings/withdrawals',
  ...driverOnly,
  query('page').optional().isInt({ min: 1 }),
  query('limit').optional().isInt({ min: 1, max: 50 }),
  query('status').optional().isIn(['pending', 'processing', 'completed', 'failed']),
  validateRequest,
  earningsController.getWithdrawalHistory
);

// Obtener reportes fiscales
router.get(
  '/earnings/tax-report',
  ...driverOnly,
  query('year').isInt({ min: 2020, max: new Date().getFullYear() }),
  query('month').optional().isInt({ min: 1, max: 12 }),
  validateRequest,
  earningsController.getTaxReport
);

// ============================================
// HORARIOS Y DISPONIBILIDAD
// ============================================

// Obtener horario configurado
router.get(
  '/schedule',
  ...driverOnly,
  scheduleController.getSchedule
);

// Configurar horario
router.put(
  '/schedule',
  ...driverOnly,
  body('monday').optional().isObject(),
  body('tuesday').optional().isObject(),
  body('wednesday').optional().isObject(),
  body('thursday').optional().isObject(),
  body('friday').optional().isObject(),
  body('saturday').optional().isObject(),
  body('sunday').optional().isObject(),
  body('autoOffline').optional().isBoolean(),
  validateRequest,
  scheduleController.setSchedule
);

// Establecer tiempo de descanso
router.post(
  '/schedule/break',
  ...driverOnly,
  body('startTime').isISO8601(),
  body('endTime').isISO8601(),
  body('reason').optional().isString(),
  validateRequest,
  scheduleController.setBreak
);

// Obtener estadísticas de horas trabajadas
router.get(
  '/schedule/stats',
  ...driverOnly,
  query('period').isIn(['week', 'month']),
  query('dateFrom').optional().isISO8601(),
  validateRequest,
  scheduleController.getWorkingStats
);

// ============================================
// CALIFICACIONES Y FEEDBACK
// ============================================

// Obtener calificaciones recibidas
router.get(
  '/ratings',
  ...driverOnly,
  query('page').optional().isInt({ min: 1 }),
  query('limit').optional().isInt({ min: 1, max: 50 }),
  query('minRating').optional().isInt({ min: 1, max: 5 }),
  query('maxRating').optional().isInt({ min: 1, max: 5 }),
  validateRequest,
  driverController.getRatings
);

// Obtener resumen de calificaciones
router.get(
  '/ratings/summary',
  ...driverOnly,
  query('period').optional().isIn(['week', 'month', 'year', 'all']),
  validateRequest,
  driverController.getRatingSummary
);

// Responder a una calificación
router.post(
  '/ratings/:ratingId/response',
  ...driverOnly,
  param('ratingId').isString(),
  body('response').isString().isLength({ min: 10, max: 500 }),
  validateRequest,
  driverController.respondToRating
);

// Reportar calificación injusta
router.post(
  '/ratings/:ratingId/dispute',
  ...driverOnly,
  param('ratingId').isString(),
  body('reason').isIn(['unfair', 'discriminatory', 'false_information', 'other']),
  body('description').isString().isLength({ min: 20, max: 1000 }),
  validateRequest,
  driverController.disputeRating
);

export default router;