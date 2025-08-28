import { Request, Response, NextFunction } from 'express';
import { logger, loggerHelpers } from '@shared/utils/logger';
import { ApiError, ApiResponse } from '@shared/types';

/**
 * Custom error class for API errors
 */
export class AppError extends Error {
  public statusCode: number;
  public code: string;
  public isOperational: boolean;

  constructor(message: string, statusCode: number = 500, code?: string) {
    super(message);
    this.statusCode = statusCode;
    this.code = code || 'INTERNAL_ERROR';
    this.isOperational = true;

    Error.captureStackTrace(this, this.constructor);
  }
}

/**
 * Global error handling middleware
 */
export const errorHandler = (
  error: Error | AppError,
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  let statusCode = 500;
  let code = 'INTERNAL_ERROR';
  let message = 'Error interno del servidor';

  // Handle different types of errors
  if (error instanceof AppError) {
    statusCode = error.statusCode;
    code = error.code;
    message = error.message;
  } else if (error.name === 'ValidationError') {
    statusCode = 400;
    code = 'VALIDATION_ERROR';
    message = 'Datos de entrada inválidos';
  } else if (error.name === 'MongoError' || error.name === 'MongoServerError') {
    statusCode = 500;
    code = 'DATABASE_ERROR';
    message = 'Error de base de datos';
  } else if (error.name === 'CastError') {
    statusCode = 400;
    code = 'INVALID_ID';
    message = 'ID inválido';
  } else if (error.name === 'JsonWebTokenError') {
    statusCode = 401;
    code = 'INVALID_TOKEN';
    message = 'Token inválido';
  } else if (error.name === 'TokenExpiredError') {
    statusCode = 401;
    code = 'TOKEN_EXPIRED';
    message = 'Token expirado';
  } else if (error.message.includes('ENOTFOUND') || error.message.includes('ECONNREFUSED')) {
    statusCode = 503;
    code = 'SERVICE_UNAVAILABLE';
    message = 'Servicio no disponible';
  } else if (error.message.includes('timeout')) {
    statusCode = 408;
    code = 'REQUEST_TIMEOUT';
    message = 'Tiempo de espera agotado';
  }

  // Log the error
  loggerHelpers.logError(error, {
    statusCode,
    code,
    path: req.path,
    method: req.method,
    userId: req.userId,
    ip: req.ip,
    userAgent: req.get('User-Agent'),
  });

  // Create API error response
  const apiError: ApiError = {
    code,
    message,
    details: process.env.NODE_ENV === 'development' ? error.stack : undefined,
  };

  const response: ApiResponse = {
    success: false,
    error: apiError,
    timestamp: new Date().toISOString(),
  };

  res.status(statusCode).json(response);
};

/**
 * 404 error handler
 */
export const notFoundHandler = (req: Request, res: Response): void => {
  const apiError: ApiError = {
    code: 'NOT_FOUND',
    message: 'Recurso no encontrado',
  };

  const response: ApiResponse = {
    success: false,
    error: apiError,
    timestamp: new Date().toISOString(),
  };

  logger.warn('404 Not Found', {
    path: req.path,
    method: req.method,
    userId: req.userId,
    ip: req.ip,
  });

  res.status(404).json(response);
};

/**
 * Async error wrapper to catch async errors in route handlers
 */
export const asyncHandler = (fn: Function) => {
  return (req: Request, res: Response, next: NextFunction) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
};

/**
 * Validation error helper
 */
export const createValidationError = (details: any[]): AppError => {
  const message = details.map(detail => detail.message).join(', ');
  return new AppError(message, 400, 'VALIDATION_ERROR');
};

/**
 * Authorization error helper
 */
export const createAuthError = (message: string = 'No autorizado'): AppError => {
  return new AppError(message, 401, 'UNAUTHORIZED');
};

/**
 * Forbidden error helper
 */
export const createForbiddenError = (message: string = 'Acceso denegado'): AppError => {
  return new AppError(message, 403, 'FORBIDDEN');
};

/**
 * Not found error helper
 */
export const createNotFoundError = (resource: string = 'Recurso'): AppError => {
  return new AppError(`${resource} no encontrado`, 404, 'NOT_FOUND');
};

/**
 * Conflict error helper
 */
export const createConflictError = (message: string = 'Conflicto'): AppError => {
  return new AppError(message, 409, 'CONFLICT');
};

/**
 * Too many requests error helper
 */
export const createRateLimitError = (message: string = 'Demasiadas solicitudes'): AppError => {
  return new AppError(message, 429, 'TOO_MANY_REQUESTS');
};

/**
 * Service unavailable error helper
 */
export const createServiceUnavailableError = (message: string = 'Servicio no disponible'): AppError => {
  return new AppError(message, 503, 'SERVICE_UNAVAILABLE');
};