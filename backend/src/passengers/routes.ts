import { Router } from 'express';
import { authMiddleware, requireRole } from '@shared/middleware/auth';
import { body, param, query } from 'express-validator';
import { validateRequest } from '@shared/middleware/validation';
import * as authController from './controllers/auth-controller';
import * as profileController from './controllers/profile-controller';
import * as rideController from './controllers/ride-controller';
import * as favoriteController from './controllers/favorite-controller';
import * as paymentController from './controllers/payment-controller';
import * as bookingController from './controllers/booking-controller';
import * as notificationController from './controllers/notification-controller';
import * as passengerController from './controllers/passenger-controller';

const router = Router();

// Middleware para rutas protegidas
const passengerOnly = [authMiddleware, requireRole(['passenger'])];

// ============================================
// AUTENTICACIÓN
// ============================================

// Registro de nuevo pasajero
router.post(
  '/auth/register',
  body('email').isEmail().normalizeEmail(),
  body('password').isString().isLength({ min: 6 }),
  body('name').isString().isLength({ min: 2, max: 100 }),
  body('phone').isMobilePhone('any'),
  body('birthDate').optional().isISO8601(),
  validateRequest,
  authController.register
);

// Login de pasajero
router.post(
  '/auth/login',
  body('email').isEmail().normalizeEmail(),
  body('password').isString().notEmpty(),
  validateRequest,
  authController.login
);

// Login con provider social
router.post(
  '/auth/social-login',
  body('provider').isIn(['google', 'facebook', 'apple']),
  body('token').isString().notEmpty(),
  validateRequest,
  authController.socialLogin
);

// Verificar email
router.post(
  '/auth/verify-email',
  body('token').isString().notEmpty(),
  validateRequest,
  authController.verifyEmail
);

// Solicitar restablecimiento de contraseña
router.post(
  '/auth/forgot-password',
  body('email').isEmail().normalizeEmail(),
  validateRequest,
  authController.forgotPassword
);

// Restablecer contraseña
router.post(
  '/auth/reset-password',
  body('token').isString().notEmpty(),
  body('newPassword').isString().isLength({ min: 6 }),
  validateRequest,
  authController.resetPassword
);

// Refresh token
router.post(
  '/auth/refresh',
  body('refreshToken').isString().notEmpty(),
  validateRequest,
  authController.refreshToken
);

// Logout
router.post(
  '/auth/logout',
  ...passengerOnly,
  authController.logout
);

// ============================================
// PERFIL
// ============================================

// Obtener perfil del pasajero
router.get(
  '/profile',
  ...passengerOnly,
  passengerController.getProfile
);

// Actualizar perfil
router.put(
  '/profile',
  ...passengerOnly,
  body('name').optional().isString().isLength({ min: 2, max: 100 }),
  body('phone').optional().isMobilePhone('any'),
  body('birthDate').optional().isISO8601(),
  body('emergencyContact').optional().isObject(),
  body('preferences').optional().isObject(),
  validateRequest,
  passengerController.updateProfile
);

// Subir foto de perfil
router.post(
  '/profile/photo',
  ...passengerOnly,
  passengerController.uploadPhoto
);

// Eliminar cuenta
router.delete(
  '/profile',
  ...passengerOnly,
  body('password').isString().notEmpty(),
  body('reason').optional().isString(),
  validateRequest,
  passengerController.deleteAccount
);

// ============================================
// GESTIÓN DE VIAJES
// ============================================

// Estimar tarifa de viaje
router.post(
  '/rides/estimate',
  ...passengerOnly,
  body('pickup.latitude').isFloat({ min: -90, max: 90 }),
  body('pickup.longitude').isFloat({ min: -180, max: 180 }),
  body('pickup.address').isString(),
  body('destination.latitude').isFloat({ min: -90, max: 90 }),
  body('destination.longitude').isFloat({ min: -180, max: 180 }),
  body('destination.address').isString(),
  body('vehicleType').optional().isIn(['economy', 'standard', 'premium', 'xl']),
  validateRequest,
  passengerController.estimateRideFare
);

// Solicitar viaje
router.post(
  '/rides/request',
  ...passengerOnly,
  body('pickup.latitude').isFloat({ min: -90, max: 90 }),
  body('pickup.longitude').isFloat({ min: -180, max: 180 }),
  body('pickup.address').isString(),
  body('destination.latitude').isFloat({ min: -90, max: 90 }),
  body('destination.longitude').isFloat({ min: -180, max: 180 }),
  body('destination.address').isString(),
  body('vehicleType').isIn(['economy', 'standard', 'premium', 'xl']),
  body('paymentMethod').isIn(['cash', 'card', 'wallet']),
  body('estimatedFare').isFloat({ min: 0 }),
  body('notes').optional().isString().isLength({ max: 500 }),
  body('stops').optional().isArray(),
  validateRequest,
  passengerController.requestRide
);

// Obtener viaje actual
router.get(
  '/rides/current',
  ...passengerOnly,
  passengerController.getCurrentRide
);

// Obtener detalles de un viaje
router.get(
  '/rides/:rideId',
  ...passengerOnly,
  param('rideId').isString(),
  validateRequest,
  passengerController.getRideDetails
);

// Cancelar viaje
router.post(
  '/rides/:rideId/cancel',
  ...passengerOnly,
  param('rideId').isString(),
  body('reason').isString().isLength({ min: 3, max: 500 }),
  validateRequest,
  passengerController.cancelRide
);

// Calificar viaje
router.post(
  '/rides/:rideId/rate',
  ...passengerOnly,
  param('rideId').isString(),
  body('rating').isInt({ min: 1, max: 5 }),
  body('comment').optional().isString().isLength({ max: 500 }),
  body('tip').optional().isFloat({ min: 0 }),
  body('tags').optional().isArray(),
  validateRequest,
  passengerController.rateRide
);

// Obtener historial de viajes
router.get(
  '/rides/history',
  ...passengerOnly,
  query('page').optional().isInt({ min: 1 }),
  query('limit').optional().isInt({ min: 1, max: 50 }),
  query('dateFrom').optional().isISO8601(),
  query('dateTo').optional().isISO8601(),
  query('status').optional().isIn(['completed', 'cancelled']),
  validateRequest,
  passengerController.getRideHistory
);

// Reportar problema con viaje
router.post(
  '/rides/:rideId/report',
  ...passengerOnly,
  param('rideId').isString(),
  body('category').isIn(['safety', 'driver_behavior', 'vehicle', 'route', 'payment', 'other']),
  body('description').isString().isLength({ min: 10, max: 1000 }),
  body('attachments').optional().isArray(),
  validateRequest,
  passengerController.reportRideIssue
);

// ============================================
// LUGARES FAVORITOS
// ============================================

// Obtener lugares favoritos
router.get(
  '/favorites',
  ...passengerOnly,
  favoriteController.getFavorites
);

// Agregar lugar favorito
router.post(
  '/favorites',
  ...passengerOnly,
  body('name').isString().isLength({ min: 1, max: 50 }),
  body('address').isString(),
  body('latitude').isFloat({ min: -90, max: 90 }),
  body('longitude').isFloat({ min: -180, max: 180 }),
  body('type').isIn(['home', 'work', 'custom']),
  body('icon').optional().isString(),
  validateRequest,
  favoriteController.addFavorite
);

// Actualizar lugar favorito
router.put(
  '/favorites/:favoriteId',
  ...passengerOnly,
  param('favoriteId').isString(),
  body('name').optional().isString().isLength({ min: 1, max: 50 }),
  body('address').optional().isString(),
  body('icon').optional().isString(),
  validateRequest,
  favoriteController.updateFavorite
);

// Eliminar lugar favorito
router.delete(
  '/favorites/:favoriteId',
  ...passengerOnly,
  param('favoriteId').isString(),
  validateRequest,
  favoriteController.removeFavorite
);

// ============================================
// MÉTODOS DE PAGO
// ============================================

// Obtener métodos de pago
router.get(
  '/payment-methods',
  ...passengerOnly,
  paymentController.getPaymentMethods
);

// Agregar tarjeta
router.post(
  '/payment-methods/card',
  ...passengerOnly,
  body('token').isString().notEmpty(),
  body('cardHolder').isString().isLength({ min: 3, max: 100 }),
  body('isDefault').optional().isBoolean(),
  validateRequest,
  paymentController.addCard
);

// Eliminar tarjeta
router.delete(
  '/payment-methods/card/:cardId',
  ...passengerOnly,
  param('cardId').isString(),
  validateRequest,
  paymentController.removeCard
);

// Establecer método de pago por defecto
router.patch(
  '/payment-methods/:methodId/default',
  ...passengerOnly,
  param('methodId').isString(),
  validateRequest,
  paymentController.setDefaultPaymentMethod
);

// Obtener balance de wallet
router.get(
  '/wallet/balance',
  ...passengerOnly,
  paymentController.getWalletBalance
);

// Recargar wallet
router.post(
  '/wallet/topup',
  ...passengerOnly,
  body('amount').isFloat({ min: 10, max: 1000 }),
  body('paymentMethodId').isString(),
  validateRequest,
  paymentController.topUpWallet
);

// Historial de transacciones
router.get(
  '/wallet/transactions',
  ...passengerOnly,
  query('page').optional().isInt({ min: 1 }),
  query('limit').optional().isInt({ min: 1, max: 50 }),
  query('type').optional().isIn(['topup', 'payment', 'refund', 'cashback']),
  query('dateFrom').optional().isISO8601(),
  query('dateTo').optional().isISO8601(),
  validateRequest,
  paymentController.getTransactionHistory
);

// ============================================
// RESERVAS PROGRAMADAS
// ============================================

// Crear reserva programada
router.post(
  '/bookings',
  ...passengerOnly,
  body('pickup.latitude').isFloat({ min: -90, max: 90 }),
  body('pickup.longitude').isFloat({ min: -180, max: 180 }),
  body('pickup.address').isString(),
  body('destination.latitude').isFloat({ min: -90, max: 90 }),
  body('destination.longitude').isFloat({ min: -180, max: 180 }),
  body('destination.address').isString(),
  body('scheduledTime').isISO8601().isAfter(),
  body('vehicleType').isIn(['economy', 'standard', 'premium', 'xl']),
  body('paymentMethod').isIn(['cash', 'card', 'wallet']),
  body('recurrence').optional().isObject(),
  body('notes').optional().isString().isLength({ max: 500 }),
  validateRequest,
  bookingController.createBooking
);

// Obtener reservas programadas
router.get(
  '/bookings',
  ...passengerOnly,
  query('status').optional().isIn(['pending', 'confirmed', 'completed', 'cancelled']),
  query('dateFrom').optional().isISO8601(),
  query('dateTo').optional().isISO8601(),
  validateRequest,
  bookingController.getBookings
);

// Obtener detalles de reserva
router.get(
  '/bookings/:bookingId',
  ...passengerOnly,
  param('bookingId').isString(),
  validateRequest,
  bookingController.getBookingDetails
);

// Actualizar reserva
router.put(
  '/bookings/:bookingId',
  ...passengerOnly,
  param('bookingId').isString(),
  body('scheduledTime').optional().isISO8601().isAfter(),
  body('vehicleType').optional().isIn(['economy', 'standard', 'premium', 'xl']),
  body('notes').optional().isString().isLength({ max: 500 }),
  validateRequest,
  bookingController.updateBooking
);

// Cancelar reserva
router.delete(
  '/bookings/:bookingId',
  ...passengerOnly,
  param('bookingId').isString(),
  body('reason').optional().isString(),
  validateRequest,
  bookingController.cancelBooking
);

// ============================================
// NOTIFICACIONES
// ============================================

// Obtener notificaciones
router.get(
  '/notifications',
  ...passengerOnly,
  query('page').optional().isInt({ min: 1 }),
  query('limit').optional().isInt({ min: 1, max: 50 }),
  query('unreadOnly').optional().isBoolean(),
  query('type').optional().isIn(['ride', 'payment', 'promotion', 'system']),
  validateRequest,
  passengerController.getNotifications
);

// Marcar notificación como leída
router.patch(
  '/notifications/:notificationId/read',
  ...passengerOnly,
  param('notificationId').isString(),
  validateRequest,
  passengerController.markNotificationAsRead
);

// Marcar todas como leídas
router.patch(
  '/notifications/read-all',
  ...passengerOnly,
  passengerController.markAllNotificationsAsRead
);

// Actualizar preferencias de notificaciones
router.put(
  '/notifications/preferences',
  ...passengerOnly,
  body('email').optional().isObject(),
  body('push').optional().isObject(),
  body('sms').optional().isObject(),
  validateRequest,
  passengerController.updateNotificationPreferences
);

// Registrar token FCM para push notifications
router.post(
  '/notifications/fcm-token',
  ...passengerOnly,
  body('token').isString().notEmpty(),
  body('platform').isIn(['ios', 'android', 'web']),
  validateRequest,
  passengerController.registerFCMToken
);

export default router;