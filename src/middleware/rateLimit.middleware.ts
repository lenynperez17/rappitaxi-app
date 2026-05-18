/**
 * 🚦 Rate Limiting Middleware
 * Control de tasa de peticiones para protección contra ataques
 */

import rateLimit from 'express-rate-limit';
import { Request, Response } from 'express';
import { logger } from '../utils/logger';

interface RateLimitOptions {
  windowMs?: number;
  max?: number;
  message?: string;
  skipSuccessfulRequests?: boolean;
  skipFailedRequests?: boolean;
}

/**
 * Crear rate limiter personalizado
 */
export const rateLimiter = (options: RateLimitOptions = {}) => {
  return rateLimit({
    windowMs: options.windowMs || 15 * 60 * 1000, // 15 minutos por defecto
    max: options.max || 100, // 100 requests por ventana por defecto
    message: options.message || 'Demasiadas peticiones, por favor intenta más tarde',
    standardHeaders: true,
    legacyHeaders: false,
    skipSuccessfulRequests: options.skipSuccessfulRequests || false,
    skipFailedRequests: options.skipFailedRequests || false,
    handler: (req: Request, res: Response) => {
      logger.warn(`⚠️ Rate limit excedido para IP: ${req.ip} - ${req.originalUrl}`);
      res.status(429).json({
        success: false,
        message: options.message || 'Demasiadas peticiones, por favor intenta más tarde',
        retryAfter: req.rateLimit?.resetTime
      });
    }
  });
};

/**
 * Rate limiters predefinidos para diferentes endpoints
 */

// Para endpoints de autenticación (login, register)
export const authRateLimiter = rateLimiter({
  windowMs: 15 * 60 * 1000, // 15 minutos
  max: 5, // 5 intentos
  message: 'Demasiados intentos de autenticación, intenta de nuevo en 15 minutos'
});

// Para creación de viajes
export const rideCreationLimiter = rateLimiter({
  windowMs: 60 * 1000, // 1 minuto
  max: 3, // 3 viajes por minuto
  message: 'No puedes crear tantos viajes tan rápido'
});

// Para envío de mensajes
export const messageLimiter = rateLimiter({
  windowMs: 60 * 1000, // 1 minuto
  max: 30, // 30 mensajes por minuto
  message: 'Estás enviando demasiados mensajes'
});

// Para API general
export const generalApiLimiter = rateLimiter({
  windowMs: 15 * 60 * 1000, // 15 minutos
  max: 500, // 500 requests
  message: 'Has excedido el límite de peticiones a la API'
});

// Para búsqueda de conductores
export const driverSearchLimiter = rateLimiter({
  windowMs: 60 * 1000, // 1 minuto
  max: 10, // 10 búsquedas por minuto
  message: 'Demasiadas búsquedas de conductores'
});

// Para actualización de ubicación
export const locationUpdateLimiter = rateLimiter({
  windowMs: 1000, // 1 segundo
  max: 2, // 2 actualizaciones por segundo
  message: 'Actualizaciones de ubicación demasiado frecuentes',
  skipSuccessfulRequests: true
});

// Para recuperación de contraseña
export const passwordResetLimiter = rateLimiter({
  windowMs: 60 * 60 * 1000, // 1 hora
  max: 3, // 3 intentos por hora
  message: 'Has solicitado demasiados resets de contraseña'
});

// Para verificación de email
export const emailVerificationLimiter = rateLimiter({
  windowMs: 60 * 60 * 1000, // 1 hora
  max: 5, // 5 intentos por hora
  message: 'Demasiados intentos de verificación de email'
});

// Para pagos
export const paymentLimiter = rateLimiter({
  windowMs: 60 * 60 * 1000, // 1 hora
  max: 20, // 20 transacciones por hora
  message: 'Has alcanzado el límite de transacciones por hora'
});

// Para uploads de archivos
export const fileUploadLimiter = rateLimiter({
  windowMs: 60 * 60 * 1000, // 1 hora
  max: 10, // 10 uploads por hora
  message: 'Has alcanzado el límite de subida de archivos'
});