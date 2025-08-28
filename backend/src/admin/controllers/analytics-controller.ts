import { Request, Response } from 'express';

export const getRideAnalytics = async (req: Request, res: Response): Promise<void> => {
  res.status(501).json({ success: false, error: { code: 'NOT_IMPLEMENTED', message: 'Funcionalidad no implementada' }});
};

export const getUserAnalytics = async (req: Request, res: Response): Promise<void> => {
  res.status(501).json({ success: false, error: { code: 'NOT_IMPLEMENTED', message: 'Funcionalidad no implementada' }});
};

export const getFinanceAnalytics = async (req: Request, res: Response): Promise<void> => {
  res.status(501).json({ success: false, error: { code: 'NOT_IMPLEMENTED', message: 'Funcionalidad no implementada' }});
};