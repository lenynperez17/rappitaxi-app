/**
 * 🔐 Auth Routes - Sistema de Autenticación Enterprise
 * Manejo completo de autenticación, registro y gestión de sesiones
 */

import { Router } from 'express';
import { body, validationResult } from 'express-validator';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { firebaseService } from '../services/firebase.service';
import { logger } from '../utils/logger';
import { authMiddleware } from '../middleware/auth.middleware';
import crypto from 'crypto';
import nodemailer from 'nodemailer';
import * as admin from 'firebase-admin';

const router = Router();

// Configuración de email para envío de notificaciones
const emailTransporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST || 'smtp.gmail.com',
  port: parseInt(process.env.SMTP_PORT || '587'),
  secure: false,
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS
  }
});

// ========== INTERFACES ==========

interface RegisterData {
  email: string;
  password: string;
  displayName: string;
  role: 'passenger' | 'driver';
  phoneNumber?: string;
  vehicleInfo?: {
    brand: string;
    model: string;
    year: number;
    plate: string;
    color: string;
    type: 'sedan' | 'suv' | 'pickup' | 'van';
  };
}

interface LoginResponse {
  success: boolean;
  token: string;
  refreshToken: string;
  user: any;
  expiresIn: number;
}

// ========== REGISTRO ==========

/**
 * POST /api/auth/register
 * Registro de nuevo usuario (pasajero o conductor)
 */
router.post('/register',
  [
    body('email').isEmail().normalizeEmail(),
    body('password')
      .isLength({ min: 8 })
      .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/)
      .withMessage('La contraseña debe tener al menos 8 caracteres, mayúsculas, minúsculas, números y caracteres especiales'),
    body('displayName').notEmpty().trim().escape(),
    body('role').isIn(['passenger', 'driver']),
    body('phoneNumber').optional().isMobilePhone('any'),
    body('vehicleInfo').optional().isObject()
  ],
  async (req, res) => {
    try {
      // Validar entrada
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ 
          success: false, 
          errors: errors.array() 
        });
      }

      const { email, password, displayName, role, phoneNumber, vehicleInfo }: RegisterData = req.body;

      // Verificar si el usuario ya existe
      const db = firebaseService.firestore;
      const existingUser = await db.collection('users')
        .where('email', '==', email)
        .limit(1)
        .get();

      if (!existingUser.empty) {
        return res.status(409).json({
          success: false,
          message: 'El email ya está registrado'
        });
      }

      // Hash de la contraseña
      const salt = await bcrypt.genSalt(12);
      const hashedPassword = await bcrypt.hash(password, salt);

      // Crear usuario en Firebase Auth
      const firebaseUser = await firebaseService.createUser(email, password, displayName, role);

      // Datos adicionales según el rol
      let additionalData: any = {};
      
      if (role === 'driver' && vehicleInfo) {
        // Crear documento de conductor
        await db.collection('drivers').doc(firebaseUser.uid).set({
          uid: firebaseUser.uid,
          email,
          displayName,
          phoneNumber,
          vehicleInfo: {
            ...vehicleInfo,
            verifiedAt: null,
            isVerified: false
          },
          location: null,
          isOnline: false,
          isAvailable: false,
          rating: 5.0,
          totalRides: 0,
          earnings: 0,
          documents: {
            driverLicense: null,
            vehicleRegistration: null,
            insurance: null,
            criminalRecord: null
          },
          bankAccount: null,
          createdAt: new Date(),
          updatedAt: new Date()
        });

        additionalData = { vehicleInfo };
      }

      const emailVerificationToken = crypto.randomBytes(32).toString('hex');

      // Guardar información adicional en la base de datos local
      await db.collection('auth_users').doc(firebaseUser.uid).set({
        uid: firebaseUser.uid,
        email,
        passwordHash: hashedPassword,
        role,
        phoneNumber,
        emailVerified: false,
        emailVerificationToken,
        passwordResetToken: null,
        passwordResetExpires: null,
        twoFactorSecret: null,
        twoFactorEnabled: false,
        loginAttempts: 0,
        lockUntil: null,
        lastLogin: null,
        refreshTokens: [],
        devices: [],
        ...additionalData,
        createdAt: new Date(),
        updatedAt: new Date()
      });

      // Generar tokens
      const token = jwt.sign(
        { 
          uid: firebaseUser.uid, 
          email, 
          role,
          verified: false 
        },
        process.env.JWT_SECRET!,
        { expiresIn: process.env.JWT_EXPIRES_IN || '24h' }
      );

      const refreshToken = jwt.sign(
        { uid: firebaseUser.uid, type: 'refresh' },
        process.env.JWT_SECRET!,
        { expiresIn: '30d' }
      );

      // Guardar refresh token
      await db.collection('auth_users').doc(firebaseUser.uid).update({
        refreshTokens: admin.firestore.FieldValue.arrayUnion({
          token: refreshToken,
          createdAt: new Date(),
          userAgent: req.headers['user-agent'],
          ip: req.ip
        })
      });

      // Enviar email de verificación
      const verificationUrl = `${process.env.FRONTEND_URL}/verify-email?token=${emailVerificationToken}&uid=${firebaseUser.uid}`;
      if (process.env.SMTP_USER && process.env.SMTP_PASS) {
        await emailTransporter.sendMail({
          from: process.env.SMTP_USER,
          to: email,
          subject: 'Verifica tu cuenta - Rappi Team',
          html: `
            <h1>Bienvenido a Rappi Team</h1>
            <p>Por favor verifica tu cuenta haciendo clic en el siguiente enlace:</p>
            <a href="${verificationUrl}" style="background-color: #4CAF50; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;">Verificar Email</a>
            <p>O copia y pega este enlace: ${verificationUrl}</p>
            <p>Este enlace expira en 24 horas.</p>
          `
        }).catch(error => {
          logger.error('Error enviando email de verificación:', error);
        });
      }

      logger.info(`✅ Usuario registrado exitosamente: ${firebaseUser.uid} - ${email}`);

      res.status(201).json({
        success: true,
        message: 'Usuario registrado exitosamente. Por favor verifica tu email.',
        token,
        refreshToken,
        user: {
          uid: firebaseUser.uid,
          email,
          displayName,
          role,
          phoneNumber,
          emailVerified: false,
          ...additionalData
        }
      });

    } catch (error: any) {
      logger.error('Error en registro:', error);
      res.status(500).json({
        success: false,
        message: 'Error registrando usuario',
        error: process.env.NODE_ENV === 'development' ? error.message : undefined
      });
    }
  }
);

// ========== LOGIN ==========

/**
 * POST /api/auth/login
 * Inicio de sesión con email y contraseña
 */
router.post('/login',
  [
    body('email').isEmail().normalizeEmail(),
    body('password').notEmpty()
  ],
  async (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ 
          success: false, 
          errors: errors.array() 
        });
      }

      const { email, password } = req.body;
      const db = firebaseService.firestore;

      // Buscar usuario
      const userSnapshot = await db.collection('auth_users')
        .where('email', '==', email)
        .limit(1)
        .get();

      if (userSnapshot.empty) {
        return res.status(401).json({
          success: false,
          message: 'Credenciales inválidas'
        });
      }

      const userDoc = userSnapshot.docs[0];
      const userData = userDoc.data();

      // Verificar si la cuenta está bloqueada
      if (userData.lockUntil && userData.lockUntil.toDate() > new Date()) {
        return res.status(423).json({
          success: false,
          message: `Cuenta bloqueada. Intenta de nuevo en ${Math.ceil((userData.lockUntil.toDate().getTime() - new Date().getTime()) / 60000)} minutos`
        });
      }

      // Verificar contraseña
      const isValidPassword = await bcrypt.compare(password, userData.passwordHash);

      if (!isValidPassword) {
        // Incrementar intentos fallidos
        const attempts = userData.loginAttempts + 1;
        const updates: any = { 
          loginAttempts: attempts,
          updatedAt: new Date()
        };

        // Bloquear después de 5 intentos
        if (attempts >= 5) {
          updates.lockUntil = new Date(Date.now() + 30 * 60 * 1000); // 30 minutos
          logger.warn(`⚠️ Cuenta bloqueada por múltiples intentos fallidos: ${email}`);
        }

        await userDoc.ref.update(updates);

        return res.status(401).json({
          success: false,
          message: 'Credenciales inválidas',
          attemptsLeft: Math.max(0, 5 - attempts)
        });
      }

      // Login exitoso - resetear intentos
      await userDoc.ref.update({
        loginAttempts: 0,
        lockUntil: null,
        lastLogin: new Date(),
        updatedAt: new Date()
      });

      // Obtener datos completos del usuario
      const fullUserData = await firebaseService.getUserById(userDoc.id);

      // Generar tokens
      const token = jwt.sign(
        { 
          uid: userDoc.id, 
          email: userData.email, 
          role: userData.role,
          verified: userData.emailVerified 
        },
        process.env.JWT_SECRET!,
        { expiresIn: process.env.JWT_EXPIRES_IN || '24h' }
      );

      const refreshToken = jwt.sign(
        { uid: userDoc.id, type: 'refresh' },
        process.env.JWT_SECRET!,
        { expiresIn: '30d' }
      );

      // Guardar refresh token y dispositivo
      await userDoc.ref.update({
        refreshTokens: admin.firestore.FieldValue.arrayUnion({
          token: refreshToken,
          createdAt: new Date(),
          userAgent: req.headers['user-agent'],
          ip: req.ip
        }),
        devices: admin.firestore.FieldValue.arrayUnion({
          userAgent: req.headers['user-agent'],
          ip: req.ip,
          lastSeen: new Date()
        })
      });

      logger.info(`✅ Login exitoso: ${userDoc.id} - ${email}`);

      const response: LoginResponse = {
        success: true,
        token,
        refreshToken,
        user: {
          uid: userDoc.id,
          ...fullUserData,
          passwordHash: undefined,
          refreshTokens: undefined
        },
        expiresIn: 86400 // 24 horas en segundos
      };

      res.json(response);

    } catch (error: any) {
      logger.error('Error en login:', error);
      res.status(500).json({
        success: false,
        message: 'Error iniciando sesión',
        error: process.env.NODE_ENV === 'development' ? error.message : undefined
      });
    }
  }
);

// ========== REFRESH TOKEN ==========

/**
 * POST /api/auth/refresh
 * Renovar token de acceso usando refresh token
 */
router.post('/refresh',
  [body('refreshToken').notEmpty()],
  async (req, res) => {
    try {
      const { refreshToken } = req.body;

      // Verificar refresh token
      const decoded = jwt.verify(refreshToken, process.env.JWT_SECRET!) as any;
      
      if (decoded.type !== 'refresh') {
        return res.status(401).json({
          success: false,
          message: 'Token inválido'
        });
      }

      const db = firebaseService.firestore;
      const userDoc = await db.collection('auth_users').doc(decoded.uid).get();

      if (!userDoc.exists) {
        return res.status(404).json({
          success: false,
          message: 'Usuario no encontrado'
        });
      }

      const userData = userDoc.data()!;

      // Verificar que el refresh token está en la lista
      const tokenExists = userData.refreshTokens?.some((t: any) => t.token === refreshToken);

      if (!tokenExists) {
        logger.warn(`⚠️ Intento de usar refresh token no válido: ${decoded.uid}`);
        return res.status(401).json({
          success: false,
          message: 'Token de actualización inválido'
        });
      }

      // Generar nuevo access token
      const newToken = jwt.sign(
        { 
          uid: decoded.uid, 
          email: userData.email, 
          role: userData.role,
          verified: userData.emailVerified 
        },
        process.env.JWT_SECRET!,
        { expiresIn: process.env.JWT_EXPIRES_IN || '24h' }
      );

      res.json({
        success: true,
        token: newToken,
        expiresIn: 86400
      });

    } catch (error) {
      logger.error('Error renovando token:', error);
      res.status(401).json({
        success: false,
        message: 'Error renovando token'
      });
    }
  }
);

// ========== LOGOUT ==========

/**
 * POST /api/auth/logout
 * Cerrar sesión y revocar tokens
 */
router.post('/logout', 
  authMiddleware,
  async (req: any, res) => {
    try {
      const { refreshToken } = req.body;
      const userId = req.user.uid;

      const db = firebaseService.firestore;
      const userRef = db.collection('auth_users').doc(userId);

      if (refreshToken) {
        // Remover refresh token específico
        const userDoc = await userRef.get();
        const userData = userDoc.data()!;
        const updatedTokens = userData.refreshTokens?.filter((t: any) => t.token !== refreshToken) || [];
        
        await userRef.update({
          refreshTokens: updatedTokens
        });
      }

      logger.info(`✅ Logout exitoso: ${userId}`);

      res.json({
        success: true,
        message: 'Sesión cerrada exitosamente'
      });

    } catch (error) {
      logger.error('Error en logout:', error);
      res.status(500).json({
        success: false,
        message: 'Error cerrando sesión'
      });
    }
  }
);

// ========== PERFIL DE USUARIO ==========

/**
 * GET /api/auth/profile
 * Obtener perfil del usuario actual
 */
router.get('/profile', 
  authMiddleware,
  async (req: any, res) => {
    try {
      const userId = req.user.uid;
      const user = await firebaseService.getUserById(userId);

      res.json({
        success: true,
        user: {
          ...user,
          passwordHash: undefined,
          refreshTokens: undefined
        }
      });

    } catch (error) {
      logger.error('Error obteniendo perfil:', error);
      res.status(500).json({
        success: false,
        message: 'Error obteniendo perfil'
      });
    }
  }
);

/**
 * PUT /api/auth/profile
 * Actualizar perfil del usuario
 */
router.put('/profile',
  authMiddleware,
  [
    body('displayName').optional().trim().escape(),
    body('phoneNumber').optional().isMobilePhone('any'),
    body('profile').optional().isObject()
  ],
  async (req: any, res) => {
    try {
      const userId = req.user.uid;
      const updates = req.body;

      // Remover campos que no se pueden actualizar
      delete updates.uid;
      delete updates.email;
      delete updates.role;
      delete updates.passwordHash;

      await firebaseService.updateUserProfile(userId, updates);

      const updatedUser = await firebaseService.getUserById(userId);

      res.json({
        success: true,
        message: 'Perfil actualizado exitosamente',
        user: {
          ...updatedUser,
          passwordHash: undefined,
          refreshTokens: undefined
        }
      });

    } catch (error) {
      logger.error('Error actualizando perfil:', error);
      res.status(500).json({
        success: false,
        message: 'Error actualizando perfil'
      });
    }
  }
);

export default router;