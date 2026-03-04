import { Request, Response, NextFunction } from 'express';
import { FirebaseService } from '../services/firebase.service';
import { logger } from '../utils/logger';

export interface AuthRequest extends Request {
  user?: {
    uid: string;
    email: string;
    role: 'passenger' | 'driver' | 'admin';
    isActive: boolean;
  };
}

const firebaseService = new FirebaseService();

export const authMiddleware = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      res.status(401).json({
        success: false,
        message: 'Token de autorización requerido'
      });
      return;
    }

    const token = authHeader.substring(7);
    const decodedToken = await firebaseService.verifyIdToken(token);
    
    if (!decodedToken) {
      res.status(401).json({
        success: false,
        message: 'Token inválido'
      });
      return;
    }

    // Obtener datos adicionales del usuario desde Firestore
    const userDoc = await firebaseService.firestore
      .collection('users')
      .doc(decodedToken.uid)
      .get();

    if (!userDoc.exists) {
      res.status(401).json({
        success: false,
        message: 'Usuario no encontrado'
      });
      return;
    }

    const userData = userDoc.data();
    
    req.user = {
      uid: decodedToken.uid,
      email: decodedToken.email || '',
      role: userData?.userType || 'passenger',
      isActive: userData?.isActive || false
    };
    
    logger.info(`🔐 User authenticated: ${req.user.email} (${req.user.role})`);
    next();
  } catch (error) {
    logger.error('❌ Auth middleware error:', error);
    res.status(401).json({
      success: false,
      message: 'Error de autenticación'
    });
  }
};

export const requireRole = (roles: string[]) => {
  return (req: AuthRequest, res: Response, next: NextFunction): void => {
    if (!req.user) {
      res.status(401).json({
        success: false,
        message: 'Usuario no autenticado'
      });
      return;
    }

    if (!roles.includes(req.user.role)) {
      res.status(403).json({
        success: false,
        message: 'Sin permisos para acceder a este recurso'
      });
      return;
    }

    next();
  };
};

export const requireAdmin = requireRole(['admin']);
export const requireDriver = requireRole(['driver', 'admin']);
export const requirePassenger = requireRole(['passenger', 'admin']);