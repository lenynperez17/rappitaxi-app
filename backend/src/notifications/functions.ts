import * as functions from 'firebase-functions';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { rateLimiter } from '@shared/middleware/rate-limiter';
import { errorHandler, notFoundHandler } from '@shared/middleware/error-handler';
import { logger } from '@shared/utils/logger';
import notificationsRoutes from './routes';

// Create Express app for notifications microservice
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
    logger.http('Notifications Service Request', {
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
    service: 'notifications',
    timestamp: new Date().toISOString(),
  });
});

// API routes
app.use('/api/notifications', notificationsRoutes);

// Error handling
app.use(notFoundHandler);
app.use(errorHandler);

// Export Cloud Function
export const notifications = functions
  .region('us-central1')
  .runWith({
    timeoutSeconds: 60,
    memory: '512MB',
    maxInstances: 100,
  })
  .https
  .onRequest(app);