import { Request, Response } from 'express';

export const getActiveEmergencies = async (req: Request, res: Response): Promise<void> => {
  res.status(501).json({ success: false, error: { code: 'NOT_IMPLEMENTED', message: 'Funcionalidad no implementada' }});
};

export const respondToEmergency = async (req: Request, res: Response): Promise<void> => {
  res.status(501).json({ success: false, error: { code: 'NOT_IMPLEMENTED', message: 'Funcionalidad no implementada' }});
};

export const getEmergencyHistory = async (req: Request, res: Response): Promise<void> => {
  res.status(501).json({ success: false, error: { code: 'NOT_IMPLEMENTED', message: 'Funcionalidad no implementada' }});
};