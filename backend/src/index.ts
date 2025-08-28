import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import http from 'http';
import { Server } from 'socket.io';
import admin from 'firebase-admin';
import dotenv from 'dotenv';
import path from 'path';

// Cargar variables de entorno
dotenv.config();

// Importar rutas
import authRoutes from './auth/routes';
import ridesRoutes from './rides/routes';
import paymentsRoutes from './payments/routes';
import notificationsRoutes from './notifications/routes';
import driversRoutes from './drivers/routes';
import passengersRoutes from './passengers/routes';
import adminRoutes from './admin/routes';
import chatRoutes from './chat/routes';
import negotiationRoutes from './negotiation/routes';
import trackingRoutes from './tracking/routes';
import supportRoutes from './support/routes';
import ratingsRoutes from './ratings/routes';
import walletRoutes from './wallet/routes';
import promoRoutes from './promo/routes';
import analyticsRoutes from './analytics/routes';

// Importar middleware
import { errorHandler } from './shared/middleware/error-handler';
import { rateLimiter } from './shared/middleware/rate-limiter';
import { authMiddleware } from './shared/middleware/auth';
import { requestLogger, errorLogger } from './shared/middleware/logging';
import { websocketHandler } from './websocket/handler';

// Inicializar Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    databaseURL: process.env.FIREBASE_DATABASE_URL
  });
}

// Crear aplicación Express
const app = express();
const server = http.createServer(app);

// Configurar WebSocket con Socket.io
const io = new Server(server, {
  cors: {
    origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000'],
    credentials: true
  }
});

// Configurar middleware global
app.use(helmet());
app.use(compression());
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000'],
  credentials: true
}));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(requestLogger);

// Rate limiting global
app.use('/api', rateLimiter);

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    service: 'RappiTaxi API',
    version: process.env.API_VERSION || '1.0.0',
    environment: process.env.NODE_ENV || 'production'
  });
});

// Montar rutas API
const apiRouter = express.Router();

apiRouter.use('/auth', authRoutes);
apiRouter.use('/rides', ridesRoutes);
apiRouter.use('/payments', paymentsRoutes);
apiRouter.use('/notifications', notificationsRoutes);
apiRouter.use('/drivers', driversRoutes);
apiRouter.use('/passengers', passengersRoutes);
apiRouter.use('/admin', adminRoutes);
apiRouter.use('/chat', chatRoutes);
apiRouter.use('/negotiation', negotiationRoutes);
apiRouter.use('/tracking', trackingRoutes);
apiRouter.use('/support', supportRoutes);
apiRouter.use('/ratings', ratingsRoutes);
apiRouter.use('/wallet', walletRoutes);
apiRouter.use('/promo', promoRoutes);
apiRouter.use('/analytics', analyticsRoutes);

app.use('/api/v1', apiRouter);

// Manejo de WebSocket
io.on('connection', (socket) => {
  websocketHandler(io, socket);
});

// Manejo de errores global
app.use(errorHandler);

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    success: false,
    error: 'Endpoint no encontrado',
    path: req.originalUrl
  });
});

// Puerto y servidor
const PORT = process.env.PORT || 5000;

server.listen(PORT, () => {
  console.log(`
    🚕 RappiTaxi Backend Server
    ⚡ Servidor corriendo en puerto ${PORT}
    🌍 Entorno: ${process.env.NODE_ENV || 'production'}
    📊 API Version: ${process.env.API_VERSION || '1.0.0'}
    🔌 WebSocket: Habilitado
    🔐 Firebase Admin: Inicializado
    ✅ Servidor listo para producción
  `);
});

// Manejo de señales de terminación
process.on('SIGTERM', () => {
  console.log('SIGTERM recibido. Cerrando servidor...');
  server.close(() => {
    console.log('Servidor cerrado correctamente');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('SIGINT recibido. Cerrando servidor...');
  server.close(() => {
    console.log('Servidor cerrado correctamente');
    process.exit(0);
  });
});

export { io, server };