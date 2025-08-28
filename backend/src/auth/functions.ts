import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { rateLimiter } from '@shared/middleware/rate-limiter';
import { errorHandler, notFoundHandler } from '@shared/middleware/error-handler';
import { logger } from '@shared/utils/logger';
import authRoutes from './routes';

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp();
}

// Create Express app for auth microservice
const app = express();

// Security middleware
app.use(helmet());
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000'],
  credentials: true,
}));

// Request parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Rate limiting
app.use(rateLimiter);

// Logging middleware
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    logger.http('Auth Service Request', {
      method: req.method,
      url: req.originalUrl,
      statusCode: res.statusCode,
      duration: `${duration}ms`,
      userAgent: req.get('User-Agent'),
      ip: req.ip,
    });
  });
  next();
});

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    service: 'auth',
    timestamp: new Date().toISOString(),
  });
});

// API routes
app.use('/api/auth', authRoutes);

// Error handling
app.use(notFoundHandler);
app.use(errorHandler);

// Export Cloud Function
export const auth = functions
  .region('us-central1')
  .runWith({
    timeoutSeconds: 60,
    memory: '512MB',
    maxInstances: 50,
  })
  .https
  .onRequest(app);

// Background functions for auth events
export const onUserCreate = functions
  .region('us-central1')
  .auth
  .user()
  .onCreate(async (user) => {
    try {
      logger.info('New user created', {
        userId: user.uid,
        email: user.email,
        emailVerified: user.emailVerified,
      });

      // Additional user creation logic can be added here
      // For example, creating default user settings, sending welcome emails, etc.
      
    } catch (error: any) {
      logger.error('Error in onUserCreate trigger', {
        error: error.message,
        userId: user.uid,
      });
    }
  });

export const onUserDelete = functions
  .region('us-central1')
  .auth
  .user()
  .onDelete(async (user) => {
    try {
      logger.info('User deleted', {
        userId: user.uid,
        email: user.email,
      });

      // Clean up user data from Firestore
      await admin.firestore()
        .collection('users')
        .doc(user.uid)
        .delete();

      // Clean up related data (rides, payments, etc.)
      const batch = admin.firestore().batch();

      // Delete user's rides
      const ridesQuery = await admin.firestore()
        .collection('rides')
        .where('passengerId', '==', user.uid)
        .get();

      ridesQuery.docs.forEach(doc => {
        batch.delete(doc.ref);
      });

      const driverRidesQuery = await admin.firestore()
        .collection('rides')
        .where('driverId', '==', user.uid)
        .get();

      driverRidesQuery.docs.forEach(doc => {
        batch.delete(doc.ref);
      });

      // Delete user's notifications
      const notificationsQuery = await admin.firestore()
        .collection('notifications')
        .where('userId', '==', user.uid)
        .get();

      notificationsQuery.docs.forEach(doc => {
        batch.delete(doc.ref);
      });

      // Delete user's payments
      const paymentsQuery = await admin.firestore()
        .collection('payments')
        .where('userId', '==', user.uid)
        .get();

      paymentsQuery.docs.forEach(doc => {
        batch.delete(doc.ref);
      });

      await batch.commit();

      logger.info('User data cleaned up successfully', {
        userId: user.uid,
      });

    } catch (error: any) {
      logger.error('Error in onUserDelete trigger', {
        error: error.message,
        userId: user.uid,
      });
    }
  });