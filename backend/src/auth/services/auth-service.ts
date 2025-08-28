import { Request, Response } from 'express';
import * as admin from 'firebase-admin';
// import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import twilio from 'twilio';
import { OAuth2Client } from 'google-auth-library';
import appleSignin from 'apple-signin-auth';
import speakeasy from 'speakeasy';
import qrcode from 'qrcode';
import { logger, loggerHelpers } from '@shared/utils/logger';
import { AppError } from '@shared/middleware/error-handler';
import { ApiResponse, User } from '@shared/types';
import { validateEmail, validatePassword, validatePhone } from '../validators/auth-validators';
import { sendWelcomeNotification, sendPasswordResetNotification } from '../../notifications/services/notification-service';
// import { rateLimiter } from '@shared/middleware/rate-limiter';

// 🔐 Configuración de servicios externos
const twilioClient = twilio(
  process.env.TWILIO_ACCOUNT_SID || 'AC_TEST',
  process.env.TWILIO_AUTH_TOKEN || 'test_token'
);

const googleClient = new OAuth2Client(
  process.env.GOOGLE_CLIENT_ID || 'google_client_id',
  process.env.GOOGLE_CLIENT_SECRET,
  process.env.GOOGLE_REDIRECT_URI || 'http://localhost:3000/auth/google/callback'
);

// 🔑 Configuración JWT
const JWT_SECRET = process.env.JWT_SECRET || 'rappitaxi_jwt_secret_2025';
const JWT_REFRESH_SECRET = process.env.JWT_REFRESH_SECRET || 'rappitaxi_refresh_secret_2025';
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '15m';
const JWT_REFRESH_EXPIRES_IN = process.env.JWT_REFRESH_EXPIRES_IN || '30d';

// 📱 Cache de OTP en memoria (en producción usar Redis)
const otpCache = new Map<string, {
  otp: string;
  attempts: number;
  expiresAt: Date;
  verified: boolean;
}>();

// 🔄 Cache de refresh tokens
const refreshTokenCache = new Map<string, {
  userId: string;
  deviceId: string;
  expiresAt: Date;
}>();

// 🎫 Cache de sesiones 2FA
const twoFactorSessions = new Map<string, {
  userId: string;
  expiresAt: Date;
  verified: boolean;
}>();

/**
 * 📱 Enviar OTP por SMS usando Twilio
 */
const sendOTPviaSMS = async (phone: string, otp: string): Promise<void> => {
  try {
    if (process.env.NODE_ENV === 'development') {
      logger.info(`[DEV] OTP for ${phone}: ${otp}`);
      return;
    }

    await twilioClient.messages.create({
      body: `🚕 RappiTaxi - Tu código de verificación es: ${otp}. Válido por 5 minutos.`,
      from: process.env.TWILIO_PHONE_NUMBER || '+1234567890',
      to: phone
    });

    logger.info(`OTP enviado a ${phone}`);
  } catch (error) {
    logger.error('Error enviando OTP:', error);
    throw new AppError('Error enviando SMS', 500, 'SMS_SEND_ERROR');
  }
};

/**
 * 🎲 Generar OTP de 6 dígitos
 */
const generateOTP = (): string => {
  return Math.floor(100000 + Math.random() * 900000).toString();
};

/**
 * 🔐 Generar tokens JWT
 */
const generateTokens = (userId: string, role: string, deviceId?: string) => {
  const payload = { userId, role, deviceId: deviceId || crypto.randomBytes(16).toString('hex') };
  
  const accessToken = jwt.sign(payload, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN } as jwt.SignOptions);
  const refreshToken = jwt.sign(payload, JWT_REFRESH_SECRET, { expiresIn: JWT_REFRESH_EXPIRES_IN } as jwt.SignOptions);

  // Guardar refresh token en cache
  refreshTokenCache.set(refreshToken, {
    userId,
    deviceId: payload.deviceId,
    expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000) // 30 días
  });

  return { accessToken, refreshToken, deviceId: payload.deviceId };
};

/**
 * 📱 Solicitar OTP para verificación de teléfono
 */
export const requestOTP = async (req: Request, res: Response): Promise<void> => {
  const { phone, action = 'login' } = req.body;

  if (!phone || !validatePhone(phone)) {
    throw new AppError('Número de teléfono válido requerido', 400, 'INVALID_PHONE');
  }

  try {
    // Verificar límite de intentos
    const cacheKey = `otp_${phone}`;
    const existing = otpCache.get(cacheKey);
    
    if (existing && existing.attempts >= 3 && existing.expiresAt > new Date()) {
      throw new AppError('Demasiados intentos. Intenta más tarde', 429, 'TOO_MANY_ATTEMPTS');
    }

    // Generar y enviar OTP
    const otp = generateOTP();
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000); // 5 minutos

    otpCache.set(cacheKey, {
      otp,
      attempts: (existing?.attempts || 0) + 1,
      expiresAt,
      verified: false
    });

    await sendOTPviaSMS(phone, otp);

    loggerHelpers.logSecurityEvent('OTP_REQUESTED', phone, req.ip, { action });

    const response: ApiResponse<{ phone: string; expiresIn: number }> = {
      success: true,
      data: {
        phone,
        expiresIn: 300 // 5 minutos en segundos
      },
      timestamp: new Date().toISOString()
    };

    res.json(response);
  } catch (error) {
    throw error;
  }
};

/**
 * ✅ Verificar OTP
 */
export const verifyOTP = async (req: Request, res: Response): Promise<void> => {
  const { phone, otp, deviceId } = req.body;

  if (!phone || !otp) {
    throw new AppError('Teléfono y OTP requeridos', 400, 'VALIDATION_ERROR');
  }

  try {
    const cacheKey = `otp_${phone}`;
    const cached = otpCache.get(cacheKey);

    if (!cached) {
      throw new AppError('OTP no encontrado o expirado', 400, 'OTP_NOT_FOUND');
    }

    if (cached.expiresAt < new Date()) {
      otpCache.delete(cacheKey);
      throw new AppError('OTP expirado', 400, 'OTP_EXPIRED');
    }

    if (cached.otp !== otp) {
      cached.attempts++;
      if (cached.attempts >= 3) {
        otpCache.delete(cacheKey);
        throw new AppError('Demasiados intentos fallidos', 429, 'TOO_MANY_ATTEMPTS');
      }
      throw new AppError('OTP incorrecto', 400, 'INVALID_OTP');
    }

    // Marcar como verificado
    cached.verified = true;
    otpCache.set(cacheKey, cached);

    // Buscar o crear usuario
    let user: any;
    const userQuery = await admin.firestore()
      .collection('users')
      .where('phone', '==', phone)
      .get();

    if (userQuery.empty) {
      // Crear nuevo usuario
      const userId = crypto.randomBytes(16).toString('hex');
      user = {
        id: userId,
        phone,
        phoneVerified: true,
        role: 'passenger',
        isActive: true,
        createdAt: new Date(),
        updatedAt: new Date(),
        passengerData: {
          preferredPaymentMethod: 'cash',
          rating: 5.0,
          totalRides: 0,
          favoriteDrivers: []
        }
      };

      await admin.firestore()
        .collection('users')
        .doc(userId)
        .set(user);
    } else {
      user = userQuery.docs[0].data();
      
      // Actualizar verificación de teléfono
      await admin.firestore()
        .collection('users')
        .doc(user.id)
        .update({
          phoneVerified: true,
          updatedAt: new Date()
        });
    }

    // Generar tokens
    const tokens = generateTokens(user.id, user.role, deviceId);

    // Limpiar OTP usado
    otpCache.delete(cacheKey);

    loggerHelpers.logSecurityEvent('OTP_VERIFIED', user.id, req.ip, { phone });

    const response: ApiResponse<{
      user: Partial<User>;
      tokens: typeof tokens;
    }> = {
      success: true,
      data: {
        user: {
          id: user.id,
          phone: user.phone,
          name: user.name,
          email: user.email,
          role: user.role,
          isActive: user.isActive,
          photoUrl: user.photoUrl
        },
        tokens
      },
      timestamp: new Date().toISOString()
    };

    res.json(response);
  } catch (error) {
    throw error;
  }
};

/**
 * 🔥 Login con Google OAuth
 */
export const googleLogin = async (req: Request, res: Response): Promise<void> => {
  const { idToken, deviceId } = req.body;

  if (!idToken) {
    throw new AppError('Token de Google requerido', 400, 'VALIDATION_ERROR');
  }

  try {
    const ticket = await googleClient.verifyIdToken({
      idToken,
      audience: process.env.GOOGLE_CLIENT_ID
    });

    const payload = ticket.getPayload();
    if (!payload) {
      throw new AppError('Token inválido', 401, 'INVALID_TOKEN');
    }

    const { email, name, picture, sub: googleId } = payload;

    // Buscar o crear usuario
    let user: any;
    const userQuery = await admin.firestore()
      .collection('users')
      .where('email', '==', email?.toLowerCase())
      .get();

    if (userQuery.empty) {
      // Crear nuevo usuario
      const userId = crypto.randomBytes(16).toString('hex');
      user = {
        id: userId,
        email: email?.toLowerCase(),
        name,
        photoUrl: picture,
        googleId,
        role: 'passenger',
        isActive: true,
        emailVerified: true,
        createdAt: new Date(),
        updatedAt: new Date(),
        passengerData: {
          preferredPaymentMethod: 'cash',
          rating: 5.0,
          totalRides: 0,
          favoriteDrivers: []
        }
      };

      await admin.firestore()
        .collection('users')
        .doc(userId)
        .set(user);

      await sendWelcomeNotification(userId, name || 'Usuario', '');
    } else {
      user = userQuery.docs[0].data();
      
      // Actualizar información de Google
      await admin.firestore()
        .collection('users')
        .doc(user.id)
        .update({
          googleId,
          photoUrl: picture || user.photoUrl,
          updatedAt: new Date()
        });
    }

    // Generar tokens
    const tokens = generateTokens(user.id, user.role, deviceId);

    loggerHelpers.logSecurityEvent('GOOGLE_LOGIN', user.id, req.ip, { email });

    const response: ApiResponse<{
      user: Partial<User>;
      tokens: typeof tokens;
    }> = {
      success: true,
      data: {
        user: {
          id: user.id,
          email: user.email,
          name: user.name,
          role: user.role,
          isActive: user.isActive,
          photoUrl: user.photoUrl
        },
        tokens
      },
      timestamp: new Date().toISOString()
    };

    res.json(response);
  } catch (error) {
    throw error;
  }
};

/**
 * 🍎 Login con Apple Sign In
 */
export const appleLogin = async (req: Request, res: Response): Promise<void> => {
  const { identityToken, authorizationCode, deviceId, user: appleUser } = req.body;

  if (!identityToken) {
    throw new AppError('Token de Apple requerido', 400, 'VALIDATION_ERROR');
  }

  try {
    const decodedToken = await appleSignin.verifyIdToken(identityToken, {
      audience: process.env.APPLE_BUNDLE_ID || 'com.rappitaxi.app',
      ignoreExpiration: false
    });

    const { sub: appleId, email } = decodedToken;

    // Buscar o crear usuario
    let user: any;
    const userQuery = await admin.firestore()
      .collection('users')
      .where('appleId', '==', appleId)
      .get();

    if (userQuery.empty && email) {
      // Buscar por email si no se encuentra por appleId
      const emailQuery = await admin.firestore()
        .collection('users')
        .where('email', '==', email.toLowerCase())
        .get();

      if (!emailQuery.empty) {
        user = emailQuery.docs[0].data();
      }
    } else if (!userQuery.empty) {
      user = userQuery.docs[0].data();
    }

    if (!user) {
      // Crear nuevo usuario
      const userId = crypto.randomBytes(16).toString('hex');
      user = {
        id: userId,
        email: email?.toLowerCase(),
        name: appleUser?.name || 'Usuario Apple',
        appleId,
        role: 'passenger',
        isActive: true,
        emailVerified: true,
        createdAt: new Date(),
        updatedAt: new Date(),
        passengerData: {
          preferredPaymentMethod: 'cash',
          rating: 5.0,
          totalRides: 0,
          favoriteDrivers: []
        }
      };

      await admin.firestore()
        .collection('users')
        .doc(userId)
        .set(user);

      await sendWelcomeNotification(userId, user.name, '');
    } else {
      // Actualizar información de Apple
      await admin.firestore()
        .collection('users')
        .doc(user.id)
        .update({
          appleId,
          updatedAt: new Date()
        });
    }

    // Generar tokens
    const tokens = generateTokens(user.id, user.role, deviceId);

    loggerHelpers.logSecurityEvent('APPLE_LOGIN', user.id, req.ip, { appleId });

    const response: ApiResponse<{
      user: Partial<User>;
      tokens: typeof tokens;
    }> = {
      success: true,
      data: {
        user: {
          id: user.id,
          email: user.email,
          name: user.name,
          role: user.role,
          isActive: user.isActive,
          photoUrl: user.photoUrl
        },
        tokens
      },
      timestamp: new Date().toISOString()
    };

    res.json(response);
  } catch (error) {
    throw error;
  }
};

/**
 * 🔐 Habilitar 2FA
 */
export const enable2FA = async (req: Request, res: Response): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }

  try {
    // Generar secreto 2FA
    const secret = speakeasy.generateSecret({
      name: `RappiTaxi (${req.userEmail || req.userId})`,
      issuer: 'RappiTaxi'
    });

    // Guardar secreto en usuario
    await admin.firestore()
      .collection('users')
      .doc(req.userId)
      .update({
        twoFactorSecret: secret.base32,
        twoFactorEnabled: false, // Se activa después de verificar
        updatedAt: new Date()
      });

    // Generar código QR
    const qrCodeUrl = await qrcode.toDataURL(secret.otpauth_url!);

    loggerHelpers.logSecurityEvent('2FA_SETUP_INITIATED', req.userId, req.ip);

    const response: ApiResponse<{
      secret: string;
      qrCode: string;
      manualEntry: string;
    }> = {
      success: true,
      data: {
        secret: secret.base32,
        qrCode: qrCodeUrl,
        manualEntry: secret.otpauth_url!
      },
      timestamp: new Date().toISOString()
    };

    res.json(response);
  } catch (error) {
    throw error;
  }
};

/**
 * ✅ Verificar y activar 2FA
 */
export const verify2FA = async (req: Request, res: Response): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }

  const { token } = req.body;

  if (!token) {
    throw new AppError('Token 2FA requerido', 400, 'VALIDATION_ERROR');
  }

  try {
    // Obtener secreto del usuario
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(req.userId)
      .get();

    if (!userDoc.exists) {
      throw new AppError('Usuario no encontrado', 404, 'USER_NOT_FOUND');
    }

    const userData = userDoc.data() as any;

    if (!userData.twoFactorSecret) {
      throw new AppError('2FA no configurado', 400, '2FA_NOT_CONFIGURED');
    }

    // Verificar token
    const verified = speakeasy.totp.verify({
      secret: userData.twoFactorSecret,
      encoding: 'base32',
      token,
      window: 2
    });

    if (!verified) {
      throw new AppError('Token 2FA inválido', 400, 'INVALID_2FA_TOKEN');
    }

    // Activar 2FA si es la primera vez
    if (!userData.twoFactorEnabled) {
      await admin.firestore()
        .collection('users')
        .doc(req.userId)
        .update({
          twoFactorEnabled: true,
          updatedAt: new Date()
        });

      loggerHelpers.logSecurityEvent('2FA_ENABLED', req.userId, req.ip);
    }

    // Crear sesión 2FA verificada
    const sessionId = crypto.randomBytes(32).toString('hex');
    twoFactorSessions.set(sessionId, {
      userId: req.userId,
      expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000), // 24 horas
      verified: true
    });

    const response: ApiResponse<{ sessionId: string; verified: boolean }> = {
      success: true,
      data: {
        sessionId,
        verified: true
      },
      timestamp: new Date().toISOString()
    };

    res.json(response);
  } catch (error) {
    throw error;
  }
};

/**
 * 🔄 Refrescar tokens
 */
export const refreshTokens = async (req: Request, res: Response): Promise<void> => {
  const { refreshToken, deviceId } = req.body;

  if (!refreshToken) {
    throw new AppError('Refresh token requerido', 400, 'VALIDATION_ERROR');
  }

  try {
    // Verificar refresh token
    const decoded = jwt.verify(refreshToken, JWT_REFRESH_SECRET) as any;

    // Verificar en cache
    const cached = refreshTokenCache.get(refreshToken);
    if (!cached || cached.userId !== decoded.userId) {
      throw new AppError('Token inválido', 401, 'INVALID_TOKEN');
    }

    // Obtener usuario
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(decoded.userId)
      .get();

    if (!userDoc.exists) {
      throw new AppError('Usuario no encontrado', 404, 'USER_NOT_FOUND');
    }

    const userData = userDoc.data() as User;

    if (!userData.isActive) {
      throw new AppError('Cuenta desactivada', 403, 'ACCOUNT_DISABLED');
    }

    // Generar nuevos tokens
    const newTokens = generateTokens(userData.id, userData.role, deviceId || decoded.deviceId);

    // Invalidar refresh token anterior
    refreshTokenCache.delete(refreshToken);

    const response: ApiResponse<typeof newTokens> = {
      success: true,
      data: newTokens,
      timestamp: new Date().toISOString()
    };

    res.json(response);
  } catch (error) {
    if (error instanceof jwt.TokenExpiredError) {
      throw new AppError('Refresh token expirado', 401, 'TOKEN_EXPIRED');
    }
    throw error;
  }
};

/**
 * Register a new user
 */
export const registerUser = async (req: Request, res: Response): Promise<void> => {
  const { email, password, name, phone, role = 'passenger' } = req.body;

  // Validate input
  if (!email || !password || !name || !phone) {
    throw new AppError('Todos los campos son requeridos', 400, 'VALIDATION_ERROR');
  }

  if (!validateEmail(email)) {
    throw new AppError('Email inválido', 400, 'INVALID_EMAIL');
  }

  if (!validatePassword(password)) {
    throw new AppError('La contraseña debe tener al menos 8 caracteres, incluir mayúsculas, minúsculas y números', 400, 'INVALID_PASSWORD');
  }

  if (!validatePhone(phone)) {
    throw new AppError('Número de teléfono inválido', 400, 'INVALID_PHONE');
  }

  if (!['passenger', 'driver'].includes(role)) {
    throw new AppError('Rol inválido', 400, 'INVALID_ROLE');
  }

  try {
    // Check if user already exists
    const existingUser = await admin.firestore()
      .collection('users')
      .where('email', '==', email.toLowerCase())
      .get();

    if (!existingUser.empty) {
      throw new AppError('El usuario ya existe', 409, 'USER_EXISTS');
    }

    // Check if phone already exists
    const existingPhone = await admin.firestore()
      .collection('users')
      .where('phone', '==', phone)
      .get();

    if (!existingPhone.empty) {
      throw new AppError('El número de teléfono ya está registrado', 409, 'PHONE_EXISTS');
    }

    // Create Firebase Auth user
    const userRecord = await admin.auth().createUser({
      email: email.toLowerCase(),
      password,
      displayName: name,
      emailVerified: false,
    });

    // Create user document in Firestore
    const userData: Partial<User> = {
      id: userRecord.uid,
      email: email.toLowerCase(),
      phone,
      name,
      role: role as 'passenger' | 'driver',
      isActive: true,
      createdAt: new Date(),
      updatedAt: new Date(),
    };

    // Initialize role-specific data
    if (role === 'passenger') {
      userData.passengerData = {
        preferredPaymentMethod: 'cash',
        rating: 5.0,
        totalRides: 0,
        favoriteDrivers: [],
      };
    } else if (role === 'driver') {
      userData.driverData = {
        licenseNumber: '',
        licenseExpiry: new Date(),
        vehicleInfo: {
          make: '',
          model: '',
          year: 0,
          color: '',
          licensePlate: '',
          type: 'standard',
          capacity: 4,
          photos: [],
        },
        documents: [],
        bankAccount: {
          bankName: '',
          accountNumber: '',
          accountType: '',
          verified: false,
        },
        rating: 5.0,
        totalRides: 0,
        totalEarnings: 0,
        isOnline: false,
        isAvailable: false,
        serviceAreas: [],
      };
    }

    await admin.firestore()
      .collection('users')
      .doc(userRecord.uid)
      .set(userData);

    // Generate email verification link
    const verificationLink = await admin.auth().generateEmailVerificationLink(email);

    // Send welcome notification
    await sendWelcomeNotification(userRecord.uid, name, verificationLink);

    loggerHelpers.logSecurityEvent(
      'USER_REGISTERED',
      userRecord.uid,
      req.ip,
      { email, role }
    );

    const response: ApiResponse<{ user: Partial<User>; verificationLink: string }> = {
      success: true,
      data: {
        user: {
          id: userRecord.uid,
          email: userData.email,
          name: userData.name,
          role: userData.role,
          isActive: userData.isActive,
        },
        verificationLink,
      },
      timestamp: new Date().toISOString(),
    };

    res.status(201).json(response);
  } catch (error: any) {
    if (error.code === 'auth/email-already-exists') {
      throw new AppError('El email ya está registrado', 409, 'EMAIL_EXISTS');
    }
    throw error;
  }
};

/**
 * Login user
 */
export const loginUser = async (req: Request, res: Response): Promise<void> => {
  const { email, password } = req.body;

  if (!email || !password) {
    throw new AppError('Email y contraseña son requeridos', 400, 'VALIDATION_ERROR');
  }

  try {
    // Get user from Firestore
    const userQuery = await admin.firestore()
      .collection('users')
      .where('email', '==', email.toLowerCase())
      .get();

    if (userQuery.empty) {
      throw new AppError('Credenciales inválidas', 401, 'INVALID_CREDENTIALS');
    }

    const userDoc = userQuery.docs[0];
    const userData = userDoc.data() as User;

    if (!userData.isActive) {
      throw new AppError('Cuenta desactivada', 403, 'ACCOUNT_DISABLED');
    }

    // Get Firebase Auth user
    const userRecord = await admin.auth().getUser(userData.id);

    if (userRecord.disabled) {
      throw new AppError('Cuenta deshabilitada', 403, 'ACCOUNT_DISABLED');
    }

    // Generate custom token for login
    const customToken = await admin.auth().createCustomToken(userData.id, {
      role: userData.role,
      email: userData.email,
    });

    // Update last login
    await admin.firestore()
      .collection('users')
      .doc(userData.id)
      .update({
        updatedAt: new Date(),
        ...(userData.role === 'admin' && { 'adminData.lastLogin': new Date() }),
      });

    loggerHelpers.logSecurityEvent(
      'USER_LOGIN',
      userData.id,
      req.ip,
      { email, role: userData.role }
    );

    const response: ApiResponse<{ user: Partial<User>; token: string }> = {
      success: true,
      data: {
        user: {
          id: userData.id,
          email: userData.email,
          name: userData.name,
          role: userData.role,
          isActive: userData.isActive,
          photoUrl: userData.photoUrl,
        },
        token: customToken,
      },
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error: any) {
    if (error.code === 'auth/user-not-found') {
      throw new AppError('Credenciales inválidas', 401, 'INVALID_CREDENTIALS');
    }
    throw error;
  }
};

/**
 * Refresh token
 */
export const refreshToken = async (req: Request, res: Response): Promise<void> => {
  const { refreshToken } = req.body;

  if (!refreshToken) {
    throw new AppError('Refresh token requerido', 400, 'VALIDATION_ERROR');
  }

  try {
    // Verify refresh token and generate new custom token
    const decodedToken = await admin.auth().verifyIdToken(refreshToken);
    
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(decodedToken.uid)
      .get();

    if (!userDoc.exists) {
      throw new AppError('Usuario no encontrado', 404, 'USER_NOT_FOUND');
    }

    const userData = userDoc.data() as User;

    if (!userData.isActive) {
      throw new AppError('Cuenta desactivada', 403, 'ACCOUNT_DISABLED');
    }

    const newToken = await admin.auth().createCustomToken(userData.id, {
      role: userData.role,
      email: userData.email,
    });

    const response: ApiResponse<{ token: string }> = {
      success: true,
      data: { token: newToken },
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error) {
    throw new AppError('Token inválido', 401, 'INVALID_TOKEN');
  }
};

/**
 * Logout user
 */
export const logoutUser = async (req: Request, res: Response): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }

  try {
    // Revoke refresh tokens
    await admin.auth().revokeRefreshTokens(req.userId);

    loggerHelpers.logSecurityEvent(
      'USER_LOGOUT',
      req.userId,
      req.ip,
      { timestamp: new Date().toISOString() }
    );

    const response: ApiResponse = {
      success: true,
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error) {
    throw new AppError('Error al cerrar sesión', 500, 'LOGOUT_ERROR');
  }
};

/**
 * Get user profile
 */
export const getUserProfile = async (req: Request, res: Response): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }

  try {
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(req.userId)
      .get();

    if (!userDoc.exists) {
      throw new AppError('Usuario no encontrado', 404, 'USER_NOT_FOUND');
    }

    const userData = userDoc.data() as User;

    const response: ApiResponse<{ user: User }> = {
      success: true,
      data: { user: userData },
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error) {
    throw error;
  }
};

/**
 * Update user profile
 */
export const updateProfile = async (req: Request, res: Response): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }

  const { name, phone, photoUrl } = req.body;
  const updates: any = { updatedAt: new Date() };

  if (name) updates.name = name;
  if (phone && validatePhone(phone)) updates.phone = phone;
  if (photoUrl) updates.photoUrl = photoUrl;

  try {
    await admin.firestore()
      .collection('users')
      .doc(req.userId)
      .update(updates);

    // Update Firebase Auth profile
    const authUpdates: any = {};
    if (name) authUpdates.displayName = name;
    if (photoUrl) authUpdates.photoURL = photoUrl;

    if (Object.keys(authUpdates).length > 0) {
      await admin.auth().updateUser(req.userId, authUpdates);
    }

    const response: ApiResponse = {
      success: true,
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error) {
    throw new AppError('Error al actualizar perfil', 500, 'UPDATE_ERROR');
  }
};

/**
 * Change password
 */
export const changePassword = async (req: Request, res: Response): Promise<void> => {
  if (!req.userId) {
    throw new AppError('Usuario no autenticado', 401, 'UNAUTHORIZED');
  }

  const { currentPassword, newPassword } = req.body;

  if (!currentPassword || !newPassword) {
    throw new AppError('Contraseña actual y nueva son requeridas', 400, 'VALIDATION_ERROR');
  }

  if (!validatePassword(newPassword)) {
    throw new AppError('La nueva contraseña debe tener al menos 8 caracteres, incluir mayúsculas, minúsculas y números', 400, 'INVALID_PASSWORD');
  }

  try {
    // Update password
    await admin.auth().updateUser(req.userId, {
      password: newPassword,
    });

    // Revoke all refresh tokens to force re-login
    await admin.auth().revokeRefreshTokens(req.userId);

    loggerHelpers.logSecurityEvent(
      'PASSWORD_CHANGED',
      req.userId,
      req.ip,
      { timestamp: new Date().toISOString() }
    );

    const response: ApiResponse = {
      success: true,
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error) {
    throw new AppError('Error al cambiar contraseña', 500, 'PASSWORD_CHANGE_ERROR');
  }
};

/**
 * Request password reset
 */
export const requestPasswordReset = async (req: Request, res: Response): Promise<void> => {
  const { email } = req.body;

  if (!email || !validateEmail(email)) {
    throw new AppError('Email válido requerido', 400, 'INVALID_EMAIL');
  }

  try {
    // Check if user exists
    const userQuery = await admin.firestore()
      .collection('users')
      .where('email', '==', email.toLowerCase())
      .get();

    if (userQuery.empty) {
      // Don't reveal if user exists or not
      const response: ApiResponse = {
        success: true,
        timestamp: new Date().toISOString(),
      };
      res.json(response);
      return;
    }

    const userData = userQuery.docs[0].data() as User;

    // Generate password reset link
    const resetLink = await admin.auth().generatePasswordResetLink(email);

    // Send password reset notification
    await sendPasswordResetNotification(userData.id, userData.name, resetLink);

    loggerHelpers.logSecurityEvent(
      'PASSWORD_RESET_REQUESTED',
      userData.id,
      req.ip,
      { email }
    );

    const response: ApiResponse = {
      success: true,
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error) {
    throw new AppError('Error al solicitar restablecimiento', 500, 'PASSWORD_RESET_ERROR');
  }
};

/**
 * Reset password
 */
export const resetPassword = async (req: Request, res: Response): Promise<void> => {
  const { oobCode, newPassword } = req.body;

  if (!oobCode || !newPassword) {
    throw new AppError('Código y nueva contraseña son requeridos', 400, 'VALIDATION_ERROR');
  }

  if (!validatePassword(newPassword)) {
    throw new AppError('La contraseña debe tener al menos 8 caracteres, incluir mayúsculas, minúsculas y números', 400, 'INVALID_PASSWORD');
  }

  try {
    // Verify the password reset code and get email
    const email = await admin.auth().verifyPasswordResetCode(oobCode);
    
    // Reset the password
    await admin.auth().confirmPasswordReset(oobCode, newPassword);

    // Get user and log the event
    const userQuery = await admin.firestore()
      .collection('users')
      .where('email', '==', email.toLowerCase())
      .get();

    if (!userQuery.empty) {
      const userData = userQuery.docs[0].data() as User;
      
      loggerHelpers.logSecurityEvent(
        'PASSWORD_RESET_COMPLETED',
        userData.id,
        req.ip,
        { email }
      );
    }

    const response: ApiResponse = {
      success: true,
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error: any) {
    if (error.code === 'auth/invalid-action-code' || error.code === 'auth/expired-action-code') {
      throw new AppError('Código de restablecimiento inválido o expirado', 400, 'INVALID_RESET_CODE');
    }
    throw new AppError('Error al restablecer contraseña', 500, 'PASSWORD_RESET_ERROR');
  }
};

/**
 * Verify email
 */
export const verifyEmail = async (req: Request, res: Response): Promise<void> => {
  const { oobCode } = req.body;

  if (!oobCode) {
    throw new AppError('Código de verificación requerido', 400, 'VALIDATION_ERROR');
  }

  try {
    // Apply the email verification code
    await admin.auth().applyActionCode(oobCode);

    const response: ApiResponse = {
      success: true,
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error: any) {
    if (error.code === 'auth/invalid-action-code' || error.code === 'auth/expired-action-code') {
      throw new AppError('Código de verificación inválido o expirado', 400, 'INVALID_VERIFICATION_CODE');
    }
    throw new AppError('Error al verificar email', 500, 'EMAIL_VERIFICATION_ERROR');
  }
};

/**
 * Resend verification email
 */
export const resendVerificationEmail = async (req: Request, res: Response): Promise<void> => {
  const { email } = req.body;

  if (!email || !validateEmail(email)) {
    throw new AppError('Email válido requerido', 400, 'INVALID_EMAIL');
  }

  try {
    // Generate new verification link
    const verificationLink = await admin.auth().generateEmailVerificationLink(email);

    // Get user data
    const userQuery = await admin.firestore()
      .collection('users')
      .where('email', '==', email.toLowerCase())
      .get();

    if (!userQuery.empty) {
      const userData = userQuery.docs[0].data() as User;
      
      // Send verification notification
      await sendWelcomeNotification(userData.id, userData.name, verificationLink);
    }

    const response: ApiResponse = {
      success: true,
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error) {
    throw new AppError('Error al reenviar verificación', 500, 'RESEND_VERIFICATION_ERROR');
  }
};

/**
 * Update user role (Admin only)
 */
export const updateUserRole = async (req: Request, res: Response): Promise<void> => {
  const { userId } = req.params;
  const { role } = req.body;

  if (!['passenger', 'driver', 'admin'].includes(role)) {
    throw new AppError('Rol inválido', 400, 'INVALID_ROLE');
  }

  try {
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(userId)
      .get();

    if (!userDoc.exists) {
      throw new AppError('Usuario no encontrado', 404, 'USER_NOT_FOUND');
    }

    await admin.firestore()
      .collection('users')
      .doc(userId)
      .update({
        role,
        updatedAt: new Date(),
      });

    loggerHelpers.logSecurityEvent(
      'USER_ROLE_UPDATED',
      req.userId,
      req.ip,
      { targetUserId: userId, newRole: role }
    );

    const response: ApiResponse = {
      success: true,
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error) {
    throw error;
  }
};

/**
 * Deactivate user (Admin only)
 */
export const deactivateUser = async (req: Request, res: Response): Promise<void> => {
  const { userId } = req.params;

  try {
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(userId)
      .get();

    if (!userDoc.exists) {
      throw new AppError('Usuario no encontrado', 404, 'USER_NOT_FOUND');
    }

    // Update Firestore
    await admin.firestore()
      .collection('users')
      .doc(userId)
      .update({
        isActive: false,
        updatedAt: new Date(),
      });

    // Disable Firebase Auth user
    await admin.auth().updateUser(userId, { disabled: true });

    // Revoke all refresh tokens
    await admin.auth().revokeRefreshTokens(userId);

    loggerHelpers.logSecurityEvent(
      'USER_DEACTIVATED',
      req.userId,
      req.ip,
      { targetUserId: userId }
    );

    const response: ApiResponse = {
      success: true,
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error) {
    throw error;
  }
};

/**
 * Reactivate user (Admin only)
 */
export const reactivateUser = async (req: Request, res: Response): Promise<void> => {
  const { userId } = req.params;

  try {
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(userId)
      .get();

    if (!userDoc.exists) {
      throw new AppError('Usuario no encontrado', 404, 'USER_NOT_FOUND');
    }

    // Update Firestore
    await admin.firestore()
      .collection('users')
      .doc(userId)
      .update({
        isActive: true,
        updatedAt: new Date(),
      });

    // Enable Firebase Auth user
    await admin.auth().updateUser(userId, { disabled: false });

    loggerHelpers.logSecurityEvent(
      'USER_REACTIVATED',
      req.userId,
      req.ip,
      { targetUserId: userId }
    );

    const response: ApiResponse = {
      success: true,
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error) {
    throw error;
  }
};

/**
 * Delete user account (Admin only)
 */
export const deleteUserAccount = async (req: Request, res: Response): Promise<void> => {
  const { userId } = req.params;

  try {
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(userId)
      .get();

    if (!userDoc.exists) {
      throw new AppError('Usuario no encontrado', 404, 'USER_NOT_FOUND');
    }

    // Delete from Firebase Auth
    await admin.auth().deleteUser(userId);

    // Delete from Firestore
    await admin.firestore()
      .collection('users')
      .doc(userId)
      .delete();

    loggerHelpers.logSecurityEvent(
      'USER_DELETED',
      req.userId,
      req.ip,
      { targetUserId: userId }
    );

    const response: ApiResponse = {
      success: true,
      timestamp: new Date().toISOString(),
    };

    res.json(response);
  } catch (error) {
    throw error;
  }
};