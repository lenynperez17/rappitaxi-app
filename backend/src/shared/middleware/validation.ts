import { Request, Response, NextFunction } from 'express';
import { validationResult } from 'express-validator';
import { AppError } from './error-handler';

/**
 * Middleware para validar requests usando express-validator
 */
export const validateRequest = (req: Request, res: Response, next: NextFunction): void => {
  const errors = validationResult(req);
  
  if (!errors.isEmpty()) {
    const errorMessages = errors.array().map(error => ({
      field: error.type === 'field' ? (error as any).path : error.type,
      message: error.msg,
      value: error.type === 'field' ? (error as any).value : undefined
    }));
    
    throw new AppError('Datos de entrada inválidos', 400, 'VALIDATION_ERROR');
  }
  
  next();
};

/**
 * Middleware para validar ID de parámetros
 */
export const validateId = (paramName: string = 'id') => {
  return (req: Request, res: Response, next: NextFunction): void => {
    const id = req.params[paramName];
    
    if (!id || typeof id !== 'string' || id.trim().length === 0) {
      throw new AppError(`${paramName} es requerido y debe ser válido`, 400, 'INVALID_ID');
    }
    
    next();
  };
};