import { Router } from 'express';
import { Request, Response, NextFunction } from 'express';
import { authMiddleware, requireRole } from '@shared/middleware/auth';
import { rateLimiter, strictRateLimiter } from '@shared/middleware/rate-limiter';
import { asyncHandler } from '@shared/middleware/error-handler';
import {
  createPayment,
  processPayment,
  getPaymentById,
  getUserPayments,
  refundPayment,
  getPaymentMethods,
  addPaymentMethod,
  removePaymentMethod,
  setDefaultPaymentMethod,
  getWalletBalance,
  addFundsToWallet,
  withdrawFromWallet,
  getPaymentHistory,
  processWebhook,
  generatePaymentLink,
  validatePayment,
  getDriverEarnings,
  processDriverPayout,
  getPaymentAnalytics,
} from './services/payment-service';


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

// Webhook endpoints (no auth required)
router.post('/webhooks/mercadopago', asyncHandler(processWebhook));

// All other routes require authentication
router.use(authMiddleware);

// Payment processing
router.post('/', rateLimiter, asyncHandler(createPayment));
router.post('/:paymentId/process', strictRateLimiter(10, 60000), asyncHandler(processPayment)); // 10 per minute
router.post('/:paymentId/refund', requireRole(['admin']), asyncHandler(refundPayment));
router.post('/generate-link', rateLimiter, asyncHandler(generatePaymentLink));
router.post('/validate', rateLimiter, asyncHandler(validatePayment));

// Payment queries
router.get('/history', asyncHandler(getPaymentHistory));
router.get('/:paymentId', asyncHandler(getPaymentById));

// Payment methods management
router.get('/methods', asyncHandler(getPaymentMethods));
router.post('/methods', rateLimiter, asyncHandler(addPaymentMethod));
router.delete('/methods/:methodId', asyncHandler(removePaymentMethod));
router.put('/methods/:methodId/default', asyncHandler(setDefaultPaymentMethod));

// Wallet management
router.get('/wallet/balance', asyncHandler(getWalletBalance));
router.post('/wallet/add-funds', rateLimiter, asyncHandler(addFundsToWallet));
router.post('/wallet/withdraw', strictRateLimiter(5, 300000), asyncHandler(withdrawFromWallet)); // 5 per 5 minutes

// Driver earnings and payouts
router.get('/driver/earnings', requireRole(['driver', 'admin']), asyncHandler(getDriverEarnings));
router.post('/driver/payout', requireRole(['driver']), strictRateLimiter(3, 86400000), asyncHandler(processDriverPayout)); // 3 per day

// Admin routes
router.get('/admin/analytics', requireRole(['admin']), asyncHandler(getPaymentAnalytics));
router.get('/admin/user/:userId/payments', requireRole(['admin']), asyncHandler(getUserPayments));

export default router;