import { Router } from 'express';
import { authMiddleware, requireRole } from '@shared/middleware/auth';
import { body, param, query } from 'express-validator';
import { validateRequest } from '@shared/middleware/validation';
import * as dashboardController from './controllers/dashboard-controller';
import * as userManagementController from './controllers/user-management-controller';
import * as rideManagementController from './controllers/ride-management-controller';
import * as paymentManagementController from './controllers/payment-management-controller';
import * as analyticsController from './controllers/analytics-controller';
import * as supportController from './controllers/support-controller';
import * as configController from './controllers/config-controller';
import * as reportsController from './controllers/reports-controller';
import * as promotionsController from './controllers/promotions-controller';
import * as emergencyController from './controllers/emergency-controller';

const router = Router();

// Middleware para verificar permisos de admin
const adminOnly = [authMiddleware, requireRole(['admin', 'super_admin'])];
const superAdminOnly = [authMiddleware, requireRole(['super_admin'])];

// ============================================
// DASHBOARD PRINCIPAL
// ============================================

// Obtener métricas del dashboard
router.get(
  '/dashboard/metrics',
  ...adminOnly,
  query('period').optional().isIn(['today', 'week', 'month', 'quarter', 'year']),
  query('timezone').optional().isString(),
  validateRequest,
  dashboardController.getDashboardMetrics
);

// Obtener estadísticas en tiempo real
router.get(
  '/dashboard/realtime',
  ...adminOnly,
  dashboardController.getRealtimeStats
);

// Obtener alertas del sistema
router.get(
  '/dashboard/alerts',
  ...adminOnly,
  query('severity').optional().isIn(['info', 'warning', 'error', 'critical']),
  query('resolved').optional().isBoolean(),
  validateRequest,
  dashboardController.getSystemAlerts
);

// Resolver alerta
router.patch(
  '/dashboard/alerts/:alertId/resolve',
  ...adminOnly,
  param('alertId').isString(),
  body('resolution').isString().isLength({ min: 10, max: 500 }),
  validateRequest,
  dashboardController.resolveAlert
);

// ============================================
// GESTIÓN DE USUARIOS
// ============================================

// Listar todos los pasajeros
router.get(
  '/users/passengers',
  ...adminOnly,
  query('page').optional().isInt({ min: 1 }),
  query('limit').optional().isInt({ min: 1, max: 100 }),
  query('search').optional().isString(),
  query('status').optional().isIn(['active', 'inactive', 'suspended', 'banned']),
  query('verified').optional().isBoolean(),
  query('sortBy').optional().isIn(['createdAt', 'lastActive', 'totalRides', 'rating']),
  query('order').optional().isIn(['asc', 'desc']),
  validateRequest,
  userManagementController.getPassengers
);

// Obtener detalles de un pasajero
router.get(
  '/users/passengers/:passengerId',
  ...adminOnly,
  param('passengerId').isString(),
  validateRequest,
  userManagementController.getPassengerDetails
);

// Actualizar estado de pasajero
router.patch(
  '/users/passengers/:passengerId/status',
  ...adminOnly,
  param('passengerId').isString(),
  body('status').isIn(['active', 'suspended', 'banned']),
  body('reason').optional().isString().isLength({ min: 10, max: 500 }),
  validateRequest,
  userManagementController.updatePassengerStatus
);

// Listar todos los conductores
router.get(
  '/users/drivers',
  ...adminOnly,
  query('page').optional().isInt({ min: 1 }),
  query('limit').optional().isInt({ min: 1, max: 100 }),
  query('search').optional().isString(),
  query('status').optional().isIn(['pending', 'active', 'inactive', 'suspended', 'banned']),
  query('verified').optional().isBoolean(),
  query('online').optional().isBoolean(),
  query('vehicleType').optional().isIn(['economy', 'standard', 'premium', 'xl']),
  query('sortBy').optional().isIn(['createdAt', 'lastActive', 'totalRides', 'rating', 'earnings']),
  query('order').optional().isIn(['asc', 'desc']),
  validateRequest,
  userManagementController.getDrivers
);

// Obtener detalles de un conductor
router.get(
  '/users/drivers/:driverId',
  ...adminOnly,
  param('driverId').isString(),
  validateRequest,
  userManagementController.getDriverDetails
);

// Actualizar estado de conductor
router.patch(
  '/users/drivers/:driverId/status',
  ...adminOnly,
  param('driverId').isString(),
  body('status').isIn(['active', 'suspended', 'banned']),
  body('reason').optional().isString().isLength({ min: 10, max: 500 }),
  validateRequest,
  userManagementController.updateDriverStatus
);

// Aprobar/Rechazar verificación de conductor
router.post(
  '/users/drivers/:driverId/verify',
  ...adminOnly,
  param('driverId').isString(),
  body('approved').isBoolean(),
  body('reason').optional().isString(),
  body('documents').optional().isObject(),
  validateRequest,
  userManagementController.verifyDriver
);

// ============================================
// GESTIÓN DE VIAJES
// ============================================

// Listar todos los viajes
router.get(
  '/rides',
  ...adminOnly,
  query('page').optional().isInt({ min: 1 }),
  query('limit').optional().isInt({ min: 1, max: 100 }),
  query('status').optional().isIn(['pending', 'accepted', 'in_progress', 'completed', 'cancelled']),
  query('passengerId').optional().isString(),
  query('driverId').optional().isString(),
  query('dateFrom').optional().isISO8601(),
  query('dateTo').optional().isISO8601(),
  query('sortBy').optional().isIn(['createdAt', 'completedAt', 'fare', 'distance']),
  query('order').optional().isIn(['asc', 'desc']),
  validateRequest,
  rideManagementController.getRides
);

// Obtener detalles de un viaje
router.get(
  '/rides/:rideId',
  ...adminOnly,
  param('rideId').isString(),
  validateRequest,
  rideManagementController.getRideDetails
);

// Monitorear viajes activos en tiempo real
router.get(
  '/rides/active',
  ...adminOnly,
  query('region').optional().isString(),
  query('vehicleType').optional().isIn(['economy', 'standard', 'premium', 'xl']),
  validateRequest,
  rideManagementController.getActiveRides
);

// Cancelar un viaje (intervención administrativa)
router.post(
  '/rides/:rideId/cancel',
  ...adminOnly,
  param('rideId').isString(),
  body('reason').isString().isLength({ min: 10, max: 500 }),
  body('refund').optional().isBoolean(),
  body('penalizeDriver').optional().isBoolean(),
  validateRequest,
  rideManagementController.cancelRide
);

// ============================================
// GESTIÓN DE PAGOS
// ============================================

// Listar transacciones
router.get(
  '/payments/transactions',
  ...adminOnly,
  query('page').optional().isInt({ min: 1 }),
  query('limit').optional().isInt({ min: 1, max: 100 }),
  query('type').optional().isIn(['ride_payment', 'refund', 'withdrawal', 'commission']),
  query('status').optional().isIn(['pending', 'processing', 'completed', 'failed']),
  query('userId').optional().isString(),
  query('dateFrom').optional().isISO8601(),
  query('dateTo').optional().isISO8601(),
  query('minAmount').optional().isFloat({ min: 0 }),
  query('maxAmount').optional().isFloat({ min: 0 }),
  validateRequest,
  paymentManagementController.getTransactions
);

// Obtener detalles de una transacción
router.get(
  '/payments/transactions/:transactionId',
  ...adminOnly,
  param('transactionId').isString(),
  validateRequest,
  paymentManagementController.getTransactionDetails
);

// Procesar retiros pendientes de conductores
router.get(
  '/payments/withdrawals/pending',
  ...adminOnly,
  query('page').optional().isInt({ min: 1 }),
  query('limit').optional().isInt({ min: 1, max: 100 }),
  validateRequest,
  paymentManagementController.getPendingWithdrawals
);

// Aprobar/Rechazar retiro
router.post(
  '/payments/withdrawals/:withdrawalId/process',
  ...adminOnly,
  param('withdrawalId').isString(),
  body('action').isIn(['approve', 'reject']),
  body('reason').optional().isString(),
  body('transactionReference').optional().isString(),
  validateRequest,
  paymentManagementController.processWithdrawal
);

// Procesar reembolso
router.post(
  '/payments/refunds',
  ...adminOnly,
  body('rideId').isString(),
  body('amount').isFloat({ min: 0 }),
  body('reason').isString().isLength({ min: 10, max: 500 }),
  validateRequest,
  paymentManagementController.processRefund
);

// ============================================
// ANALYTICS Y REPORTES
// ============================================

// Obtener analytics generales
router.get(
  '/analytics/overview',
  ...adminOnly,
  query('period').isIn(['today', 'week', 'month', 'quarter', 'year']),
  query('compareWith').optional().isIn(['previous_period', 'last_year']),
  validateRequest,
  analyticsController.getAnalyticsOverview
);

// Obtener analytics de ingresos
router.get(
  '/analytics/revenue',
  ...adminOnly,
  query('dateFrom').isISO8601(),
  query('dateTo').isISO8601(),
  query('groupBy').optional().isIn(['day', 'week', 'month']),
  query('breakdown').optional().isIn(['ride_type', 'payment_method', 'region']),
  validateRequest,
  analyticsController.getRevenueAnalytics
);

// Obtener analytics de usuarios
router.get(
  '/analytics/users',
  ...adminOnly,
  query('userType').isIn(['passengers', 'drivers', 'both']),
  query('metric').isIn(['growth', 'retention', 'activity', 'satisfaction']),
  query('dateFrom').isISO8601(),
  query('dateTo').isISO8601(),
  validateRequest,
  analyticsController.getUserAnalytics
);

// Obtener heatmap de actividad
router.get(
  '/analytics/heatmap',
  ...adminOnly,
  query('type').isIn(['pickups', 'dropoffs', 'demand']),
  query('dateFrom').optional().isISO8601(),
  query('dateTo').optional().isISO8601(),
  query('resolution').optional().isIn(['high', 'medium', 'low']),
  validateRequest,
  analyticsController.getActivityHeatmap
);

// Generar reporte personalizado
router.post(
  '/reports/generate',
  ...adminOnly,
  body('type').isIn(['financial', 'operations', 'users', 'compliance', 'custom']),
  body('format').isIn(['pdf', 'excel', 'csv']),
  body('dateFrom').isISO8601(),
  body('dateTo').isISO8601(),
  body('includeCharts').optional().isBoolean(),
  body('sections').optional().isArray(),
  validateRequest,
  reportsController.generateReport
);

// ============================================
// SOPORTE Y TICKETS
// ============================================

// Listar tickets de soporte
router.get(
  '/support/tickets',
  ...adminOnly,
  query('page').optional().isInt({ min: 1 }),
  query('limit').optional().isInt({ min: 1, max: 100 }),
  query('status').optional().isIn(['open', 'in_progress', 'resolved', 'closed']),
  query('priority').optional().isIn(['low', 'medium', 'high', 'urgent']),
  query('category').optional().isString(),
  query('assignedTo').optional().isString(),
  validateRequest,
  supportController.getTickets
);

// Obtener detalles de un ticket
router.get(
  '/support/tickets/:ticketId',
  ...adminOnly,
  param('ticketId').isString(),
  validateRequest,
  supportController.getTicketDetails
);

// Responder a un ticket
router.post(
  '/support/tickets/:ticketId/reply',
  ...adminOnly,
  param('ticketId').isString(),
  body('message').isString().isLength({ min: 1, max: 5000 }),
  body('attachments').optional().isArray(),
  validateRequest,
  supportController.replyToTicket
);

// Actualizar estado de ticket
router.patch(
  '/support/tickets/:ticketId/status',
  ...adminOnly,
  param('ticketId').isString(),
  body('status').isIn(['open', 'in_progress', 'resolved', 'closed']),
  body('resolution').optional().isString(),
  validateRequest,
  supportController.updateTicketStatus
);

// ============================================
// CONFIGURACIÓN DEL SISTEMA
// ============================================

// Obtener configuración actual
router.get(
  '/config',
  ...adminOnly,
  query('section').optional().isString(),
  validateRequest,
  configController.getConfig
);

// Actualizar configuración
router.put(
  '/config/:section',
  ...superAdminOnly,
  param('section').isString(),
  body('settings').isObject(),
  validateRequest,
  configController.updateConfig
);

// Gestionar tarifas
router.get(
  '/config/pricing',
  ...adminOnly,
  query('vehicleType').optional().isIn(['economy', 'standard', 'premium', 'xl']),
  query('region').optional().isString(),
  validateRequest,
  configController.getPricing
);

// Actualizar tarifas
router.put(
  '/config/pricing',
  ...superAdminOnly,
  body('vehicleType').isIn(['economy', 'standard', 'premium', 'xl']),
  body('baseFare').optional().isFloat({ min: 0 }),
  body('perKm').optional().isFloat({ min: 0 }),
  body('perMinute').optional().isFloat({ min: 0 }),
  body('minimumFare').optional().isFloat({ min: 0 }),
  body('surgeMultiplier').optional().isFloat({ min: 1, max: 5 }),
  validateRequest,
  configController.updatePricing
);

// ============================================
// PROMOCIONES Y CUPONES
// ============================================

// Listar promociones
router.get(
  '/promotions',
  ...adminOnly,
  query('page').optional().isInt({ min: 1 }),
  query('limit').optional().isInt({ min: 1, max: 100 }),
  query('status').optional().isIn(['draft', 'active', 'scheduled', 'expired']),
  query('type').optional().isIn(['discount', 'cashback', 'freeride', 'referral']),
  validateRequest,
  promotionsController.getPromotions
);

// Crear nueva promoción
router.post(
  '/promotions',
  ...adminOnly,
  body('name').isString().isLength({ min: 3, max: 100 }),
  body('description').isString().isLength({ min: 10, max: 500 }),
  body('type').isIn(['discount', 'cashback', 'freeride', 'referral']),
  body('value').isFloat({ min: 0 }),
  body('isPercentage').optional().isBoolean(),
  body('maxDiscount').optional().isFloat({ min: 0 }),
  body('minRideAmount').optional().isFloat({ min: 0 }),
  body('validFrom').isISO8601(),
  body('validTo').isISO8601(),
  body('usageLimit').optional().isInt({ min: 1 }),
  body('userLimit').optional().isInt({ min: 1 }),
  body('targetUsers').optional().isArray(),
  body('conditions').optional().isObject(),
  validateRequest,
  promotionsController.createPromotion
);

// Actualizar promoción
router.put(
  '/promotions/:promotionId',
  ...adminOnly,
  param('promotionId').isString(),
  body('name').optional().isString().isLength({ min: 3, max: 100 }),
  body('description').optional().isString().isLength({ min: 10, max: 500 }),
  body('status').optional().isIn(['draft', 'active', 'scheduled', 'expired']),
  body('validTo').optional().isISO8601(),
  body('usageLimit').optional().isInt({ min: 1 }),
  validateRequest,
  promotionsController.updatePromotion
);

// ============================================
// SISTEMA DE EMERGENCIAS
// ============================================

// Obtener emergencias activas
router.get(
  '/emergencies/active',
  ...adminOnly,
  query('severity').optional().isIn(['low', 'medium', 'high', 'critical']),
  validateRequest,
  emergencyController.getActiveEmergencies
);

// Obtener detalles de emergencia
router.get(
  '/emergencies/:emergencyId',
  ...adminOnly,
  param('emergencyId').isString(),
  validateRequest,
  emergencyController.getEmergencyDetails
);

// Responder a emergencia
router.post(
  '/emergencies/:emergencyId/respond',
  ...adminOnly,
  param('emergencyId').isString(),
  body('action').isIn(['acknowledge', 'dispatch', 'escalate', 'resolve']),
  body('notes').optional().isString().isLength({ min: 10, max: 1000 }),
  body('dispatchUnits').optional().isArray(),
  validateRequest,
  emergencyController.respondToEmergency
);

// Actualizar protocolo de emergencia
router.put(
  '/emergencies/protocols/:protocolId',
  ...superAdminOnly,
  param('protocolId').isString(),
  body('name').optional().isString(),
  body('triggers').optional().isArray(),
  body('actions').optional().isArray(),
  body('contacts').optional().isArray(),
  validateRequest,
  emergencyController.updateProtocol
);

export default router;