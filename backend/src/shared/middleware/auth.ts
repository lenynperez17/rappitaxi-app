import { Request, Response, NextFunction } from 'express';
import * as admin from 'firebase-admin';
import { logger, loggerHelpers } from '@shared/utils/logger';
import { ApiError } from '@shared/types';

// Extend Request interface to include user
declare global {
  namespace Express {
    interface Request {
      user?: admin.auth.DecodedIdToken;
      userId?: string;
    }
  }
}

/**
 * Middleware to authenticate Firebase ID tokens
 */
export const authMiddleware = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      const error: ApiError = {
        code: 'UNAUTHORIZED',
        message: 'Token de autorización requerido',
      };
      
      loggerHelpers.logSecurityEvent(
        'MISSING_AUTH_TOKEN',
        undefined,
        req.ip,
        { path: req.path, method: req.method }
      );
      
      res.status(401).json({
        success: false,
        error,
        timestamp: new Date().toISOString(),
      });
      return;
    }

    const token = authHeader.split('Bearer ')[1];
    
    if (!token) {
      const error: ApiError = {
        code: 'INVALID_TOKEN_FORMAT',
        message: 'Formato de token inválido',
      };
      
      loggerHelpers.logSecurityEvent(
        'INVALID_TOKEN_FORMAT',
        undefined,
        req.ip,
        { path: req.path, method: req.method }
      );
      
      res.status(401).json({
        success: false,
        error,
        timestamp: new Date().toISOString(),
      });
      return;
    }

    // Verify the Firebase ID token
    const decodedToken = await admin.auth().verifyIdToken(token);
    
    // Check if user is active
    const userRecord = await admin.auth().getUser(decodedToken.uid);
    if (userRecord.disabled) {
      const error: ApiError = {
        code: 'USER_DISABLED',
        message: 'Usuario deshabilitado',
      };
      
      loggerHelpers.logSecurityEvent(
        'DISABLED_USER_ACCESS_ATTEMPT',
        decodedToken.uid,
        req.ip,
        { path: req.path, method: req.method }
      );
      
      res.status(403).json({
        success: false,
        error,
        timestamp: new Date().toISOString(),
      });
      return;
    }

    // Add user info to request
    req.user = decodedToken;
    req.userId = decodedToken.uid;

    logger.debug('User authenticated successfully', {
      userId: decodedToken.uid,
      email: decodedToken.email,
      path: req.path,
      method: req.method,
    });

    next();
  } catch (error: any) {
    loggerHelpers.logSecurityEvent(
      'AUTH_TOKEN_VERIFICATION_FAILED',
      undefined,
      req.ip,
      { 
        error: error.message,
        path: req.path,
        method: req.method,
      }
    );

    const apiError: ApiError = {
      code: 'INVALID_TOKEN',
      message: 'Token de autorización inválido',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined,
    };

    res.status(401).json({
      success: false,
      error: apiError,
      timestamp: new Date().toISOString(),
    });
  }
};

/**
 * Middleware to check user roles
 */
export const requireRole = (allowedRoles: string[]) => {
  return async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      if (!req.user || !req.userId) {
        const error: ApiError = {
          code: 'UNAUTHORIZED',
          message: 'Autenticación requerida',
        };
        
        res.status(401).json({
          success: false,
          error,
          timestamp: new Date().toISOString(),
        });
        return;
      }

      // Get user data from Firestore to check role
      const userDoc = await admin.firestore()
        .collection('users')
        .doc(req.userId)
        .get();

      if (!userDoc.exists) {
        const error: ApiError = {
          code: 'USER_NOT_FOUND',
          message: 'Usuario no encontrado',
        };
        
        loggerHelpers.logSecurityEvent(
          'USER_NOT_FOUND_IN_DATABASE',
          req.userId,
          req.ip,
          { path: req.path, method: req.method }
        );
        
        res.status(404).json({
          success: false,
          error,
          timestamp: new Date().toISOString(),
        });
        return;
      }

      const userData = userDoc.data();
      const userRole = userData?.role;

      if (!userRole || !allowedRoles.includes(userRole)) {
        const error: ApiError = {
          code: 'INSUFFICIENT_PERMISSIONS',
          message: 'Permisos insuficientes para acceder a este recurso',
        };
        
        loggerHelpers.logSecurityEvent(
          'INSUFFICIENT_PERMISSIONS',
          req.userId,
          req.ip,
          { 
            userRole,
            requiredRoles: allowedRoles,
            path: req.path,
            method: req.method,
          }
        );
        
        res.status(403).json({
          success: false,
          error,
          timestamp: new Date().toISOString(),
        });
        return;
      }

      // Add role to request for further use
      req.user.role = userRole;

      logger.debug('Role authorization successful', {
        userId: req.userId,
        role: userRole,
        requiredRoles: allowedRoles,
        path: req.path,
        method: req.method,
      });

      next();
    } catch (error: any) {
      loggerHelpers.logError(error, {
        context: 'Role authorization middleware',
        userId: req.userId,
        path: req.path,
        method: req.method,
      });

      const apiError: ApiError = {
        code: 'AUTHORIZATION_ERROR',
        message: 'Error de autorización',
        details: process.env.NODE_ENV === 'development' ? error.message : undefined,
      };

      res.status(500).json({
        success: false,
        error: apiError,
        timestamp: new Date().toISOString(),
      });
    }
  };
};

/**
 * Optional auth middleware - doesn't fail if no token provided
 */
export const optionalAuth = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      // No token provided, continue without authentication
      next();
      return;
    }

    const token = authHeader.split('Bearer ')[1];
    
    if (!token) {
      // Invalid token format, continue without authentication
      next();
      return;
    }

    // Try to verify the token
    const decodedToken = await admin.auth().verifyIdToken(token);
    
    // Add user info to request if token is valid
    req.user = decodedToken;
    req.userId = decodedToken.uid;

    logger.debug('Optional auth successful', {
      userId: decodedToken.uid,
      email: decodedToken.email,
      path: req.path,
      method: req.method,
    });

    next();
  } catch (error: any) {
    // Token verification failed, continue without authentication
    logger.debug('Optional auth failed, continuing without authentication', {
      error: error.message,
      path: req.path,
      method: req.method,
    });
    
    next();
  }
};

// Alias para compatibilidad con código existente
export const authenticate = authMiddleware;