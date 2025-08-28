import { Request, Response } from 'express';

export const generateReport = async (req: Request, res: Response): Promise<void> => {
  res.status(501).json({ success: false, error: { code: 'NOT_IMPLEMENTED', message: 'Funcionalidad no implementada' }});
};

export const getScheduledReports = async (req: Request, res: Response): Promise<void> => {
  res.status(501).json({ success: false, error: { code: 'NOT_IMPLEMENTED', message: 'Funcionalidad no implementada' }});
};

export const scheduleReport = async (req: Request, res: Response): Promise<void> => {
  res.status(501).json({ success: false, error: { code: 'NOT_IMPLEMENTED', message: 'Funcionalidad no implementada' }});
};