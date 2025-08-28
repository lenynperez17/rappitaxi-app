import { Request, Response, NextFunction } from 'express';

export const authorize = (roles: string[]) => {
  return (req: Request, res: Response, next: NextFunction): void => {
    // Placeholder para autorización
    // En implementación real verificaría el rol del usuario
    next();
  };
};