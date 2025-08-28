import { createLogger, format, transports } from 'winston';

const { combine, timestamp, errors, json, colorize, simple } = format;

// Define log levels
const levels = {
  error: 0,
  warn: 1,
  info: 2,
  http: 3,
  debug: 4,
};

// Define colors for each level
const colors = {
  error: 'red',
  warn: 'yellow',
  info: 'green',
  http: 'magenta',
  debug: 'white',
};

// Create the logger
export const logger = createLogger({
  level: process.env.LOG_LEVEL || 'info',
  levels,
  format: combine(
    errors({ stack: true }),
    timestamp({ format: 'YYYY-MM-DD HH:mm:ss:ms' }),
    json()
  ),
  defaultMeta: {
    service: 'oasis-taxi-backend',
    version: process.env.npm_package_version || '1.0.0',
    environment: process.env.NODE_ENV || 'development',
  },
  transports: [
    // Console transport for development
    new transports.Console({
      format: process.env.NODE_ENV === 'development' 
        ? combine(
            colorize({ all: true }),
            simple()
          )
        : json(),
    }),
    
    // File transports for production
    ...(process.env.NODE_ENV === 'production' ? [
      new transports.File({
        filename: 'logs/error.log',
        level: 'error',
        maxsize: 5242880, // 5MB
        maxFiles: 5,
      }),
      new transports.File({
        filename: 'logs/combined.log',
        maxsize: 5242880, // 5MB
        maxFiles: 5,
      }),
    ] : []),
  ],
  exceptionHandlers: [
    new transports.File({ filename: 'logs/exceptions.log' }),
  ],
  rejectionHandlers: [
    new transports.File({ filename: 'logs/rejections.log' }),
  ],
});

// Add colors to winston
logger.addColors(colors);

// Helper functions for structured logging
export const loggerHelpers = {
  logRequest: (req: any, res: any, responseTime: number) => {
    logger.http('HTTP Request', {
      method: req.method,
      url: req.originalUrl,
      statusCode: res.statusCode,
      responseTime: `${responseTime}ms`,
      userAgent: req.get('User-Agent'),
      ip: req.ip,
      userId: req.user?.id,
    });
  },

  logError: (error: Error, context?: any) => {
    logger.error('Application Error', {
      message: error.message,
      stack: error.stack,
      context,
    });
  },

  logRideEvent: (event: string, rideId: string, userId: string, data?: any) => {
    logger.info('Ride Event', {
      event,
      rideId,
      userId,
      data,
    });
  },

  logPaymentEvent: (event: string, paymentId: string, amount: number, data?: any) => {
    logger.info('Payment Event', {
      event,
      paymentId,
      amount,
      data,
    });
  },

  logSecurityEvent: (event: string, userId?: string, ip?: string, data?: any) => {
    logger.warn('Security Event', {
      event,
      userId,
      ip,
      data,
    });
  },

  logPerformance: (operation: string, duration: number, metadata?: any) => {
    logger.info('Performance Metric', {
      operation,
      duration: `${duration}ms`,
      metadata,
    });
  },
};

export default logger;