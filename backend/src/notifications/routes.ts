import { Router } from 'express';
import { Request, Response, NextFunction } from 'express';
import { authMiddleware, requireRole } from '@shared/middleware/auth';
import { rateLimiter, strictRateLimiter } from '@shared/middleware/rate-limiter';
import { asyncHandler } from '@shared/middleware/error-handler';
import {
  getUserNotifications,
  markNotificationAsRead,
  markAllNotificationsAsRead,
  deleteNotification,
  getUnreadCount,
  updateNotificationPreferences,
  getNotificationPreferences,
  sendTestNotification,
  registerDeviceToken,
  unregisterDeviceToken,
  sendBulkNotification,
  getNotificationHistory,
  subscribeToTopic,
  unsubscribeFromTopic,
} from './services/notification-service';


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

// Notification queries
router.get('/', asyncHandler(getUserNotifications));
router.get('/unread-count', asyncHandler(getUnreadCount));
router.get('/history', asyncHandler(getNotificationHistory));

// Notification actions
router.put('/:notificationId/read', asyncHandler(markNotificationAsRead));
router.put('/mark-all-read', asyncHandler(markAllNotificationsAsRead));
router.delete('/:notificationId', asyncHandler(deleteNotification));

// Device token management
router.post('/device-token', rateLimiter, asyncHandler(registerDeviceToken));
router.delete('/device-token', asyncHandler(unregisterDeviceToken));

// Topic subscriptions
router.post('/topics/:topic/subscribe', asyncHandler(subscribeToTopic));
router.delete('/topics/:topic/unsubscribe', asyncHandler(unsubscribeFromTopic));

// Notification preferences
router.get('/preferences', asyncHandler(getNotificationPreferences));
router.put('/preferences', asyncHandler(updateNotificationPreferences));

// Admin routes
router.post('/admin/test', requireRole(['admin']), asyncHandler(sendTestNotification));
router.post('/admin/bulk', requireRole(['admin']), strictRateLimiter(5, 300000), asyncHandler(sendBulkNotification)); // 5 per 5 minutes

export default router;