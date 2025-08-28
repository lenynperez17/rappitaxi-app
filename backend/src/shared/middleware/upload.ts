import { Request, Response, NextFunction } from 'express';
import multer from 'multer';
import { AppError } from './error-handler';
import path from 'path';

// Configuración de multer para subida de archivos
const storage = multer.memoryStorage();

const fileFilter = (req: any, file: any, cb: any) => {
  // Tipos de archivo permitidos
  const allowedMimeTypes = [
    'image/jpeg',
    'image/png', 
    'image/webp',
    'application/pdf',
    'audio/mpeg',
    'audio/wav'
  ];
  
  if (allowedMimeTypes.includes(file.mimetype)) {
    cb(null, true);
  } else {
    cb(new AppError('Tipo de archivo no permitido', 400, 'INVALID_FILE_TYPE'), false);
  }
};

const upload = multer({
  storage,
  fileFilter,
  limits: {
    fileSize: 5 * 1024 * 1024 // 5MB max
  }
});

/**
 * Middleware para subir un solo archivo
 */
export const uploadSingle = (fieldName: string) => {
  return upload.single(fieldName);
};

/**
 * Middleware para subir múltiples archivos
 */
export const uploadMultiple = (fieldName: string, maxCount: number = 5) => {
  return upload.array(fieldName, maxCount);
};

/**
 * Middleware general de upload (alias para compatibilidad)
 */
export const uploadMiddleware = upload.single('file');

/**
 * Middleware para validar archivo subido
 */
export const validateUpload = (req: Request, res: Response, next: NextFunction): void => {
  if (!req.file && !req.files) {
    throw new AppError('Archivo es requerido', 400, 'FILE_REQUIRED');
  }
  
  next();
};

/**
 * Tipos de archivo permitidos
 */
export const ALLOWED_FILE_TYPES = {
  IMAGES: ['image/jpeg', 'image/png', 'image/webp'],
  DOCUMENTS: ['application/pdf'],
  AUDIO: ['audio/mpeg', 'audio/wav']
};