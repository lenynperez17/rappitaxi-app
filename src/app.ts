import express, { Application, Request, Response, NextFunction } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';
import { createServer } from 'http';
import { Server as SocketIOServer } from 'socket.io';
import dotenv from 'dotenv';

// Import routes
import authRoutes from './routes/auth.routes';
import rideRoutes from './routes/ride.routes';
import paymentRoutes from './routes/payment.routes';
import driverRoutes from './routes/driver.routes';
import adminRoutes from './routes/admin.routes';
import chatRoutes from './routes/chat.routes';

// Import middleware
import { errorHandler } from './middleware/error.middleware';
import { notFoundHandler } from './middleware/notFound.middleware';
import { authMiddleware } from './middleware/auth.middleware';

// Import services
import { FirebaseService } from './services/firebase.service';
import { SocketService } from './services/socket.service';
import { logger } from './utils/logger';

// Load environment variables
dotenv.config();

class App {
  public app: Application;
  public server: import('http').Server;
  public io: SocketIOServer;
  private firebaseService: FirebaseService;
  private socketService: SocketService;

  constructor() {
    this.app = express();
    this.server = createServer(this.app);
    this.io = new SocketIOServer(this.server, {
      cors: {
        origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000'],
        methods: ['GET', 'POST'],
        credentials: true
      }
    });
    
    this.firebaseService = new FirebaseService();
    this.socketService = new SocketService(this.io);
    
    this.initializeMiddlewares();
    this.initializeRoutes();
    this.initializeErrorHandling();
    this.initializeSocket();
  }

  private initializeMiddlewares(): void {
    // Security headers
    this.app.use(helmet({
      contentSecurityPolicy: {
        directives: {
          defaultSrc: ["'self'"],
          styleSrc: ["'self'", "'unsafe-inline'"],
          scriptSrc: ["'self'"],
          imgSrc: ["'self'", "data:", "https:"],
        },
      },
      hsts: {
        maxAge: 31536000,
        includeSubDomains: true,
        preload: true
      }
    }));

    // CORS configuration
    const allowedOrigins = [
      'https://rapiteam.app',
      'https://admin.rapiteam.app',
      'https://driver.rapiteam.app',
      ...(process.env.NODE_ENV === 'development' ? ['http://localhost:3000'] : [])
    ];

    this.app.use(cors({
      origin: (origin, callback) => {
        if (!origin || allowedOrigins.includes(origin)) {
          callback(null, true);
        } else {
          callback(new Error('No permitido por CORS'));
        }
      },
      credentials: true,
      methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
    }));

    // Rate limiting
    const limiter = rateLimit({
      windowMs: 15 * 60 * 1000, // 15 minutos
      max: 100, // máximo 100 requests por ventana
      message: 'Demasiadas peticiones desde esta IP',
      standardHeaders: true,
      legacyHeaders: false,
    });

    this.app.use(limiter);

    // Body parsing
    this.app.use(express.json({ limit: '10mb' }));
    this.app.use(express.urlencoded({ extended: true, limit: '10mb' }));

    // Compression
    this.app.use(compression());

    // Logging
    if (process.env.NODE_ENV !== 'test') {
      this.app.use(morgan('combined', {
        stream: {
          write: (message: string) => logger.info(message.trim())
        }
      }));
    }

    // Health check
    this.app.get('/health', (req: Request, res: Response) => {
      res.status(200).json({
        status: 'OK',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        environment: process.env.NODE_ENV || 'development'
      });
    });
  }

  private initializeRoutes(): void {
    const apiPrefix = '/api/v1';

    // Public routes
    this.app.use(`${apiPrefix}/auth`, authRoutes);
    
    // Protected routes (temporalmente sin authMiddleware para testing)
    this.app.use(`${apiPrefix}/rides`, rideRoutes);
    this.app.use(`${apiPrefix}/payments`, paymentRoutes);
    this.app.use(`${apiPrefix}/drivers`, driverRoutes);
    this.app.use(`${apiPrefix}/admin`, adminRoutes);
    this.app.use(`${apiPrefix}/chat`, chatRoutes);
  }

  private initializeErrorHandling(): void {
    // 404 handler
    this.app.use(notFoundHandler);
    
    // Global error handler
    this.app.use(errorHandler);
  }

  private initializeSocket(): void {
    this.socketService.initialize();
  }

  public listen(): void {
    const port = process.env.PORT || 3000;
    
    this.server.listen(port, () => {
      logger.info(`🚀 RapiTeam Backend iniciado en puerto ${port}`);
      logger.info(`🌍 Entorno: ${process.env.NODE_ENV || 'development'}`);
      logger.info(`📚 API Docs: http://localhost:${port}/api/v1`);
    });
  }

  public getApp(): Application {
    return this.app;
  }

  public getServer() {
    return this.server;
  }
}

// Create and start the application
const app = new App();

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM received. Shutting down gracefully...');
  app.getServer().close(() => {
    logger.info('Process terminated');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  logger.info('SIGINT received. Shutting down gracefully...');
  app.getServer().close(() => {
    logger.info('Process terminated');
    process.exit(0);
  });
});

// Start the server if this file is run directly
if (require.main === module) {
  app.listen();
}

export default app;