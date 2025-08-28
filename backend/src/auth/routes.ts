import { Router } from 'express';
import { Request, Response, NextFunction } from 'express';
import { authMiddleware, requireRole } from '@shared/middleware/auth';
import { authRateLimiter, passwordResetRateLimiter } from '@shared/middleware/rate-limiter';
import { asyncHandler } from '@shared/middleware/error-handler';
import {
  registerUser,
  loginUser,
  refreshToken,
  refreshTokens, // Nueva función con JWT propios
  logoutUser,
  updateProfile,
  changePassword,
  requestPasswordReset,
  resetPassword,
  verifyEmail,
  resendVerificationEmail,
  updateUserRole,
  getUserProfile,
  deactivateUser,
  reactivateUser,
  deleteUserAccount,
  // 🆕 Nuevos endpoints OTP/OAuth/2FA
  requestOTP,
  verifyOTP,
  googleLogin,
  appleLogin,
  enable2FA,
  verify2FA,
} from './services/auth-service';


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

// 📱 OTP Authentication routes
router.post('/otp/request', authRateLimiter, asyncHandler(requestOTP));
router.post('/otp/verify', authRateLimiter, asyncHandler(verifyOTP));
router.post('/otp/resend', authRateLimiter, asyncHandler(requestOTP)); // Reutiliza requestOTP

// 🔐 OAuth routes
router.post('/google', authRateLimiter, asyncHandler(googleLogin));
router.post('/apple', authRateLimiter, asyncHandler(appleLogin));

// Classic authentication (email/password)
router.post('/register', authRateLimiter, asyncHandler(registerUser));
router.post('/login', authRateLimiter, asyncHandler(loginUser));
router.post('/refresh', authRateLimiter, asyncHandler(refreshTokens)); // Usa nueva función
router.post('/refresh-token', authRateLimiter, asyncHandler(refreshToken)); // Legacy

// Password management
router.post('/password/request-reset', passwordResetRateLimiter, asyncHandler(requestPasswordReset));
router.post('/password/reset', passwordResetRateLimiter, asyncHandler(resetPassword));
router.post('/forgot-password', passwordResetRateLimiter, asyncHandler(requestPasswordReset)); // Alias

// Email verification
router.post('/email/verify', asyncHandler(verifyEmail));
router.post('/email/resend-verification', authRateLimiter, asyncHandler(resendVerificationEmail));
router.post('/verify-email', asyncHandler(verifyEmail)); // Alias

// Protected routes (requieren autenticación)
router.use(authMiddleware);
router.post('/logout', asyncHandler(logoutUser));
router.get('/profile', asyncHandler(getUserProfile));
router.put('/profile', asyncHandler(updateProfile));
router.put('/password/change', authRateLimiter, asyncHandler(changePassword));
router.post('/change-password', authRateLimiter, asyncHandler(changePassword)); // Alias

// 🔐 Two-Factor Authentication (2FA)
router.post('/2fa/enable', asyncHandler(enable2FA));
router.post('/2fa/verify', asyncHandler(verify2FA));
router.post('/2fa/disable', asyncHandler(verify2FA)); // Reutiliza verify con flag

// Admin only routes
router.put('/users/:userId/role', requireRole(['admin']), asyncHandler(updateUserRole));
router.put('/users/:userId/deactivate', requireRole(['admin']), asyncHandler(deactivateUser));
router.put('/users/:userId/reactivate', requireRole(['admin']), asyncHandler(reactivateUser));
router.delete('/users/:userId', requireRole(['admin']), asyncHandler(deleteUserAccount));

export default router;