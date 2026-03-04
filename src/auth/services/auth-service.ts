import { Request, Response } from 'express';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import * as bcrypt from 'bcryptjs';
import * as jwt from 'jsonwebtoken';

const auth = getAuth();
const db = getFirestore();

// Determinar la colección de usuarios según el entorno
const USERS_COLLECTION = process.env.NODE_ENV === 'test' ? 'test_users' : 'users';

// Interfaces
interface RegisterUserData {
  email: string;
  password: string;
  firstName: string;
  lastName: string;
  phoneNumber: string;
  role: 'passenger' | 'driver';
  licenseNumber?: string;
  vehicleInfo?: {
    make: string;
    model: string;
    year: number;
    licensePlate: string;
    color: string;
  };
}

interface LoginUserData {
  email: string;
  password: string;
}

interface UserProfileUpdate {
  firstName?: string;
  lastName?: string;
  phoneNumber?: string;
}

// Validation helpers
const validateEmail = (email: string): boolean => {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
};

const validatePassword = (password: string): boolean => {
  // At least 8 characters, 1 uppercase, 1 lowercase, 1 number
  const passwordRegex = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)[a-zA-Z\d@$!%*?&]{8,}$/;
  return passwordRegex.test(password);
};

const validatePhoneNumber = (phoneNumber: string): boolean => {
  // International phone number format (E.164)
  const phoneRegex = /^\+[1-9]\d{1,14}$/;
  return phoneRegex.test(phoneNumber);
};


// Error classes
class ValidationError extends Error {
  statusCode = 400;
  code = 'VALIDATION_ERROR';
  
  constructor(message: string, public field?: string) {
    super(message);
    this.name = 'ValidationError';
  }
}

class UnauthorizedError extends Error {
  statusCode = 401;
  code = 'UNAUTHORIZED';
  
  constructor(message: string = 'Unauthorized') {
    super(message);
    this.name = 'UnauthorizedError';
  }
}

class ConflictError extends Error {
  statusCode = 409;
  code = 'EMAIL_ALREADY_EXISTS';
  
  constructor(message: string) {
    super(message);
    this.name = 'ConflictError';
  }
}

class ForbiddenError extends Error {
  statusCode = 403;
  code = 'ACCOUNT_INACTIVE';
  
  constructor(message: string) {
    super(message);
    this.name = 'ForbiddenError';
  }
}

// Register user
export const registerUser = async (req: Request, res: Response) => {
  try {
    const userData: RegisterUserData = req.body;

    // Validation
    if (!validateEmail(userData.email)) {
      throw new ValidationError('Invalid email format', 'email');
    }

    if (!validatePassword(userData.password)) {
      throw new ValidationError('Password must be at least 8 characters with uppercase, lowercase and number', 'password');
    }

    if (!validatePhoneNumber(userData.phoneNumber)) {
      throw new ValidationError('Invalid phone number format', 'phoneNumber');
    }

    // Check if user already exists
    try {
      await auth.getUserByEmail(userData.email);
      throw new ConflictError('Email already exists');
    } catch (error: any) {
      if (error.code !== 'auth/user-not-found') {
        throw error;
      }
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(userData.password, 12);

    // Create user in Firebase Auth
    const userRecord = await auth.createUser({
      email: userData.email,
      password: userData.password,
      displayName: `${userData.firstName} ${userData.lastName}`,
      phoneNumber: userData.phoneNumber,
    });

    // Create user document in Firestore
    const userDoc = {
      uid: userRecord.uid,
      email: userData.email,
      firstName: userData.firstName,
      lastName: userData.lastName,
      phoneNumber: userData.phoneNumber,
      role: userData.role,
      isActive: true,
      hashedPassword,
      createdAt: new Date(),
      updatedAt: new Date(),
      ...(userData.role === 'driver' && {
        licenseNumber: userData.licenseNumber,
        vehicleInfo: userData.vehicleInfo,
        isVerified: false,
      }),
    };

    await db.collection(USERS_COLLECTION).doc(userRecord.uid).set(userDoc);

    // Generate JWT token
    const token = jwt.sign(
      { uid: userRecord.uid, role: userData.role },
      process.env.JWT_SECRET || 'fallback-secret',
      { expiresIn: '24h' }
    );

    res.status(201).json({
      success: true,
      data: {
        user: {
          uid: userRecord.uid,
          email: userData.email,
          firstName: userData.firstName,
          lastName: userData.lastName,
          role: userData.role,
          isActive: true,
        },
        token,
      },
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    throw error;
  }
};

// Login user
export const loginUser = async (req: Request, res: Response) => {
  try {
    const { email, password }: LoginUserData = req.body;

    // Get user by email
    let userRecord;
    try {
      userRecord = await auth.getUserByEmail(email);
    } catch (error) {
      throw new UnauthorizedError('Invalid credentials');
    }

    // Get user document from Firestore
    const userDoc = await db.collection(USERS_COLLECTION).doc(userRecord.uid).get();
    
    if (!userDoc.exists) {
      throw new UnauthorizedError('Invalid credentials');
    }

    const userData = userDoc.data()!;

    // Check if user is active
    if (!userData.isActive) {
      throw new ForbiddenError('Account is inactive');
    }

    // Verify password
    const isValidPassword = await bcrypt.compare(password, userData.hashedPassword);
    if (!isValidPassword) {
      throw new UnauthorizedError('Invalid credentials');
    }

    // Generate JWT token
    const token = jwt.sign(
      { uid: userRecord.uid, role: userData.role },
      process.env.JWT_SECRET || 'fallback-secret',
      { expiresIn: '24h' }
    );

    res.status(200).json({
      success: true,
      data: {
        user: {
          uid: userRecord.uid,
          email: userData.email,
          firstName: userData.firstName,
          lastName: userData.lastName,
          role: userData.role,
          isActive: userData.isActive,
        },
        token,
      },
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    throw error;
  }
};

// Reset password
export const resetPassword = async (req: Request, res: Response) => {
  try {
    const { email } = req.body;

    // Send password reset email (Firebase handles this)
    try {
      await auth.generatePasswordResetLink(email);
    } catch (error) {
      // Don't reveal if email exists for security reasons
      console.log('Password reset attempted for:', email);
    }

    res.status(200).json({
      success: true,
      message: 'If the email exists, a password reset link has been sent',
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    throw error;
  }
};

// Update user profile
export const updateUserProfile = async (req: Request, res: Response) => {
  try {
    const userId = (req as any).userId;
    
    if (!userId) {
      throw new UnauthorizedError('Authentication required');
    }

    const updates: UserProfileUpdate = req.body;

    // Validation
    if (updates.phoneNumber && !validatePhoneNumber(updates.phoneNumber)) {
      throw new ValidationError('Invalid phone number format', 'phoneNumber');
    }

    // Update user document
    const updateData: any = {
      ...updates,
      updatedAt: new Date(),
    };

    await db.collection(USERS_COLLECTION).doc(userId).update(updateData);

    // Get updated user data
    const userDoc = await db.collection(USERS_COLLECTION).doc(userId).get();
    const userData = userDoc.data()!;

    res.status(200).json({
      success: true,
      data: {
        user: {
          uid: userId,
          email: userData.email,
          firstName: userData.firstName,
          lastName: userData.lastName,
          phoneNumber: userData.phoneNumber,
          role: userData.role,
          isActive: userData.isActive,
        },
      },
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    throw error;
  }
};

// Delete user account
export const deleteUserAccount = async (req: Request, res: Response) => {
  try {
    const userId = (req as any).userId;
    
    if (!userId) {
      throw new UnauthorizedError('Authentication required');
    }

    // Soft delete - mark as inactive
    await db.collection(USERS_COLLECTION).doc(userId).update({
      isActive: false,
      deletedAt: new Date(),
      updatedAt: new Date(),
    });

    // Could also delete from Firebase Auth if needed
    // await auth.deleteUser(userId);

    res.status(200).json({
      success: true,
      message: 'Account has been successfully deleted',
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    throw error;
  }
};