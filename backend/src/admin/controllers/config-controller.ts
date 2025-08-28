import { Request, Response } from 'express';

export const getPricingConfig = async (req: Request, res: Response): Promise<void> => {
  res.status(501).json({ success: false, error: { code: 'NOT_IMPLEMENTED', message: 'Funcionalidad no implementada' }});
};

export const updatePricingConfig = async (req: Request, res: Response): Promise<void> => {
  res.status(501).json({ success: false, error: { code: 'NOT_IMPLEMENTED', message: 'Funcionalidad no implementada' }});
};

export const getZonesConfig = async (req: Request, res: Response): Promise<void> => {
  res.status(501).json({ success: false, error: { code: 'NOT_IMPLEMENTED', message: 'Funcionalidad no implementada' }});
};

export const createZone = async (req: Request, res: Response): Promise<void> => {
  res.status(501).json({ success: false, error: { code: 'NOT_IMPLEMENTED', message: 'Funcionalidad no implementada' }});
};

export const updateZone = async (req: Request, res: Response): Promise<void> => {
  res.status(501).json({ success: false, error: { code: 'NOT_IMPLEMENTED', message: 'Funcionalidad no implementada' }});
};

export const getCommissionsConfig = async (req: Request, res: Response): Promise<void> => {
  res.status(501).json({ success: false, error: { code: 'NOT_IMPLEMENTED', message: 'Funcionalidad no implementada' }});
};

export const updateCommissions = async (req: Request, res: Response): Promise<void> => {
  res.status(501).json({ success: false, error: { code: 'NOT_IMPLEMENTED', message: 'Funcionalidad no implementada' }});
};