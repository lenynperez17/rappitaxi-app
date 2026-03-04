import { Request, Response, NextFunction } from 'express';

export const notFoundHandler = (
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  res.status(404).json({
    success: false,
    message: `Endpoint ${req.originalUrl} no encontrado`,
    timestamp: new Date().toISOString()
  });
};