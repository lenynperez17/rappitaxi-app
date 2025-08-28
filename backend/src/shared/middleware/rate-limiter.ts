import { Request, Response, NextFunction } from 'express';
import NodeCache from 'node-cache';
import { logger, loggerHelpers } from '@shared/utils/logger';
import { ApiError, ApiResponse } from '@shared/types';

// Create cache for rate limiting
const rateLimitCache = new NodeCache({
  stdTTL: parseInt(process.env.RATE_LIMIT_WINDOW_MS || '900000') / 1000, // 15 minutes in seconds
  checkperiod: 120, // Check for expired keys every 2 minutes
});

interface RateLimitInfo {
  count: number;
  resetTime: number;
}

/**
 * Rate limiting middleware
 */
export const rateLimiter = (req: Request, res: Response, next: NextFunction): void => {
  const windowMs = parseInt(process.env.RATE_LIMIT_WINDOW_MS || '900000'); // 15 minutes
  const maxRequests = parseInt(process.env.RATE_LIMIT_MAX_REQUESTS || '100');
  
  // Skip rate limiting for health checks
  if (req.path === '/health') {
    next();
    return;
  }

  // Create identifier (IP + User ID if available)
  const identifier = req.userId ? `${req.ip}:${req.userId}` : req.ip;
  const key = `rate_limit:${identifier}`;
  
  const now = Date.now();
  const resetTime = now + windowMs;
  
  // Get current rate limit info
  let rateLimitInfo = rateLimitCache.get<RateLimitInfo>(key);
  
  if (!rateLimitInfo) {
    // First request in window
    rateLimitInfo = {
      count: 1,
      resetTime,
    };
    rateLimitCache.set(key, rateLimitInfo);
  } else {
    // Increment count
    rateLimitInfo.count++;
    rateLimitCache.set(key, rateLimitInfo);
  }

  // Set response headers
  res.set({
    'X-RateLimit-Limit': maxRequests.toString(),
    'X-RateLimit-Remaining': Math.max(0, maxRequests - rateLimitInfo.count).toString(),
    'X-RateLimit-Reset': new Date(rateLimitInfo.resetTime).toISOString(),
  });

  // Check if limit exceeded
  if (rateLimitInfo.count > maxRequests) {
    loggerHelpers.logSecurityEvent(
      'RATE_LIMIT_EXCEEDED',
      req.userId,
      req.ip,
      {
        path: req.path,
        method: req.method,
        count: rateLimitInfo.count,
        limit: maxRequests,
      }
    );

    const apiError: ApiError = {
      code: 'TOO_MANY_REQUESTS',
      message: 'Demasiadas solicitudes. Intenta nuevamente más tarde.',
      details: {
        limit: maxRequests,
        windowMs,
        resetTime: new Date(rateLimitInfo.resetTime).toISOString(),
      },
    };

    const response: ApiResponse = {
      success: false,
      error: apiError,
      timestamp: new Date().toISOString(),
    };

    res.status(429).json(response);
    return;
  }

  logger.debug('Rate limit check passed', {
    identifier,
    count: rateLimitInfo.count,
    limit: maxRequests,
    path: req.path,
    method: req.method,
  });

  next();
};

/**
 * Stricter rate limiter for sensitive endpoints
 */
export const strictRateLimiter = (maxRequests: number = 10, windowMs: number = 300000) => {
  return (req: Request, res: Response, next: NextFunction): void => {
    const identifier = req.userId ? `${req.ip}:${req.userId}` : req.ip;
    const key = `strict_rate_limit:${identifier}`;
    
    const now = Date.now();
    const resetTime = now + windowMs;
    
    let rateLimitInfo = rateLimitCache.get<RateLimitInfo>(key);
    
    if (!rateLimitInfo) {
      rateLimitInfo = {
        count: 1,
        resetTime,
      };
      rateLimitCache.set(key, rateLimitInfo, windowMs / 1000);
    } else {
      rateLimitInfo.count++;
      rateLimitCache.set(key, rateLimitInfo, windowMs / 1000);
    }

    res.set({
      'X-RateLimit-Limit': maxRequests.toString(),
      'X-RateLimit-Remaining': Math.max(0, maxRequests - rateLimitInfo.count).toString(),
      'X-RateLimit-Reset': new Date(rateLimitInfo.resetTime).toISOString(),
    });

    if (rateLimitInfo.count > maxRequests) {
      loggerHelpers.logSecurityEvent(
        'STRICT_RATE_LIMIT_EXCEEDED',
        req.userId,
        req.ip,
        {
          path: req.path,
          method: req.method,
          count: rateLimitInfo.count,
          limit: maxRequests,
        }
      );

      const apiError: ApiError = {
        code: 'TOO_MANY_REQUESTS',
        message: 'Demasiadas solicitudes para este endpoint sensible.',
        details: {
          limit: maxRequests,
          windowMs,
          resetTime: new Date(rateLimitInfo.resetTime).toISOString(),
        },
      };

      const response: ApiResponse = {
        success: false,
        error: apiError,
        timestamp: new Date().toISOString(),
      };

      res.status(429).json(response);
      return;
    }

    next();
  };
};

/**
 * Rate limiter for authentication endpoints
 */
export const authRateLimiter = strictRateLimiter(5, 300000); // 5 requests per 5 minutes

/**
 * Rate limiter for password reset endpoints
 */
export const passwordResetRateLimiter = strictRateLimiter(3, 900000); // 3 requests per 15 minutes

/**
 * Clear rate limit for a specific identifier (useful for testing)
 */
export const clearRateLimit = (identifier: string): void => {
  rateLimitCache.del(`rate_limit:${identifier}`);
  rateLimitCache.del(`strict_rate_limit:${identifier}`);
};

/**
 * Get rate limit info for a specific identifier
 */
export const getRateLimitInfo = (identifier: string): RateLimitInfo | undefined => {
  return rateLimitCache.get<RateLimitInfo>(`rate_limit:${identifier}`);
};