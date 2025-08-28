import { Router } from 'express';
import { Request, Response, NextFunction } from 'express';
import { authMiddleware, requireRole } from '@shared/middleware/auth';
import { rateLimiter, strictRateLimiter } from '@shared/middleware/rate-limiter';
import { asyncHandler } from '@shared/middleware/error-handler';
import {
  createRide,
  getRideById,
  getUserRides,
  getNearbyRides,
  acceptRide,
  rejectRide,
  startRide,
  completeRide,
  cancelRide,
  updateRideStatus,
  updateDriverLocation,
  getRideEstimate,
  rateRide,
  getRideHistory,
  getActiveRides,
  getDriverActiveRide,
  emergencyAlert,
  shareRideLocation,
} from './services/ride-service';


// Middleware de validación para express-validator
const validateRequest = (req: Request, res: Response, next: NextFunction): void => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    res.status(400).json({
      success: false,
      error: {
        code: 'VALIDATION_ERROR',
        message: 'Datos de entrada inválidos',
        details: errors.array()
      }
    });
    return;
  }
  next();
};

const router = Router();

// All routes require authentication
router.use(authMiddleware);

// Ride creation and estimation
router.post('/estimate', rateLimiter, asyncHandler(getRideEstimate));
router.post('/', rateLimiter, requireRole(['passenger']), asyncHandler(createRide));

// Ride queries
router.get('/active', asyncHandler(getActiveRides));
router.get('/history', asyncHandler(getRideHistory));
router.get('/nearby', requireRole(['driver']), asyncHandler(getNearbyRides));
router.get('/driver/active', requireRole(['driver']), asyncHandler(getDriverActiveRide));
router.get('/:rideId', asyncHandler(getRideById));

// Ride actions
router.post('/:rideId/accept', requireRole(['driver']), asyncHandler(acceptRide));
router.post('/:rideId/reject', requireRole(['driver']), asyncHandler(rejectRide));
router.post('/:rideId/start', requireRole(['driver']), asyncHandler(startRide));
router.post('/:rideId/complete', requireRole(['driver']), asyncHandler(completeRide));
router.post('/:rideId/cancel', asyncHandler(cancelRide));
router.put('/:rideId/status', asyncHandler(updateRideStatus));
router.put('/:rideId/driver-location', requireRole(['driver']), asyncHandler(updateDriverLocation));

// Ride rating and feedback
router.post('/:rideId/rate', asyncHandler(rateRide));

// Emergency and sharing
router.post('/:rideId/emergency', strictRateLimiter(5, 60000), asyncHandler(emergencyAlert)); // 5 per minute
router.post('/:rideId/share', asyncHandler(shareRideLocation));

// Admin routes
router.get('/admin/all', requireRole(['admin']), asyncHandler(getUserRides));

export default router;