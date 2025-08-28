/**
 * RappiTaxi Backend - Configuración de Producción
 * Configuraciones optimizadas y seguras para ambiente de producción
 */

const path = require('path');

module.exports = {
  // Configuración del servidor
  server: {
    port: process.env.PORT || 3000,
    host: process.env.HOST || '0.0.0.0',
    env: 'production',
    
    // Configuraciones de seguridad
    trustProxy: true,
    forceHTTPS: true,
    
    // Headers de seguridad
    securityHeaders: {
      'X-Frame-Options': 'DENY',
      'X-Content-Type-Options': 'nosniff',
      'X-XSS-Protection': '1; mode=block',
      'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
      'Referrer-Policy': 'strict-origin-when-cross-origin',
      'Content-Security-Policy': "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https:; frame-src 'none';"
    }
  },

  // Configuración de base de datos
  database: {
    // Firebase Firestore
    firebase: {
      projectId: process.env.FIREBASE_PROJECT_ID,
      privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      databaseURL: `https://${process.env.FIREBASE_PROJECT_ID}.firebaseio.com`,
      
      // Configuraciones de rendimiento
      maxIdleTime: 600000, // 10 minutos
      maxConcurrentConnections: 100,
      keepAliveTime: 300000, // 5 minutos
      
      // Configuraciones de retry
      retryConfig: {
        maxRetryAttempts: 3,
        retryDelayMs: 1000,
        maxRetryDelayMs: 10000,
        retryDelayMultiplier: 2.0,
      }
    },

    // Redis para caché y sesiones
    redis: {
      url: process.env.REDIS_URL,
      options: {
        connectTimeout: 10000,
        lazyConnect: true,
        maxRetriesPerRequest: 3,
        retryDelayOnFailover: 100,
        enableReadyCheck: false,
        
        // Pool de conexiones
        maxmemoryPolicy: 'allkeys-lru',
        keyPrefix: 'rappitaxi:',
        
        // Configuraciones de cluster si es necesario
        enableAutoPipelining: true,
        
        // TTL por defecto
        defaultTtl: 3600 // 1 hora
      }
    }
  },

  // Configuración de autenticación
  auth: {
    jwt: {
      secret: process.env.JWT_SECRET,
      expiresIn: process.env.JWT_EXPIRES_IN || '7d',
      issuer: 'rappitaxi-api',
      audience: 'rappitaxi-app',
      
      // Configuraciones de refresh token
      refreshToken: {
        secret: process.env.JWT_REFRESH_SECRET,
        expiresIn: '30d',
      },
      
      // Rate limiting para auth
      rateLimiting: {
        windowMs: 15 * 60 * 1000, // 15 minutos
        maxAttempts: 5, // 5 intentos por IP
        skipSuccessfulRequests: true,
        
        // Bloqueo progresivo
        progressiveDelay: true,
        maxDelayMs: 300000, // 5 minutos máximo
      }
    },

    // Configuración OAuth
    oauth: {
      google: {
        clientId: process.env.GOOGLE_CLIENT_ID,
        clientSecret: process.env.GOOGLE_CLIENT_SECRET,
      },
      facebook: {
        appId: process.env.FACEBOOK_APP_ID,
        appSecret: process.env.FACEBOOK_APP_SECRET,
      }
    },

    // Configuración OTP
    otp: {
      smsProvider: 'twilio', // o 'aws-sns'
      emailProvider: 'sendgrid',
      
      // Twilio configuración
      twilio: {
        accountSid: process.env.TWILIO_ACCOUNT_SID,
        authToken: process.env.TWILIO_AUTH_TOKEN,
        messagingServiceSid: process.env.TWILIO_MESSAGING_SERVICE_SID,
      },
      
      // SendGrid configuración
      sendgrid: {
        apiKey: process.env.SENDGRID_API_KEY,
        fromEmail: process.env.SENDGRID_FROM_EMAIL || 'noreply@rappitaxi.com',
        fromName: 'RappiTaxi',
      },
      
      // Configuraciones de OTP
      length: 6,
      expiresIn: 300, // 5 minutos
      maxAttempts: 3,
      cooldownPeriod: 60, // 1 minuto entre envíos
    }
  },

  // Configuración de APIs externas
  externalApis: {
    // Google Maps
    googleMaps: {
      apiKey: process.env.GOOGLE_MAPS_API_KEY,
      
      // Configuraciones de rate limiting
      rateLimiting: {
        requestsPerSecond: 50,
        requestsPerDay: 25000,
      },
      
      // Configuraciones de geocoding
      geocoding: {
        language: 'es',
        region: 'PE',
        components: 'country:PE',
      }
    },

    // MercadoPago
    mercadoPago: {
      accessToken: process.env.MERCADOPAGO_ACCESS_TOKEN,
      publicKey: process.env.MERCADOPAGO_PUBLIC_KEY,
      clientId: process.env.MERCADOPAGO_CLIENT_ID,
      clientSecret: process.env.MERCADOPAGO_CLIENT_SECRET,
      
      // Configuraciones
      environment: 'production', // 'sandbox' para testing
      
      // Webhooks
      webhookSecret: process.env.MERCADOPAGO_WEBHOOK_SECRET,
      
      // Configuraciones de pago
      currency: 'PEN',
      
      // Timeouts
      requestTimeout: 30000,
      
      // Configuraciones de retry
      maxRetries: 3,
      retryDelay: 2000,
    },

    // Notificaciones push
    fcm: {
      serverKey: process.env.FCM_SERVER_KEY,
      projectId: process.env.FIREBASE_PROJECT_ID,
      
      // Configuraciones de notificación
      defaultOptions: {
        priority: 'high',
        timeToLive: 3600, // 1 hora
        collapseKey: 'rappitaxi',
        
        // Configuraciones Android
        android: {
          priority: 'high',
          notification: {
            icon: 'ic_notification',
            color: '#FF6B6B',
            sound: 'default',
          }
        },
        
        // Configuraciones iOS
        apns: {
          payload: {
            aps: {
              badge: 1,
              sound: 'default',
            }
          }
        }
      }
    }
  },

  // Configuración de logging
  logging: {
    level: process.env.LOG_LEVEL || 'info',
    format: 'json',
    
    // Archivos de log
    files: {
      error: {
        filename: path.join(__dirname, '../logs/error.log'),
        level: 'error',
        maxsize: 10485760, // 10MB
        maxFiles: 5,
        tailable: true,
      },
      combined: {
        filename: path.join(__dirname, '../logs/combined.log'),
        maxsize: 10485760, // 10MB
        maxFiles: 10,
        tailable: true,
      }
    },

    // Configuración de transports
    transports: ['file', 'console'],
    
    // Configuración de Sentry (opcional)
    sentry: {
      dsn: process.env.SENTRY_DSN,
      environment: 'production',
      
      // Configuraciones adicionales
      beforeSend: (event) => {
        // Filtrar información sensible
        if (event.request) {
          delete event.request.headers?.authorization;
          delete event.request.headers?.cookie;
        }
        return event;
      },
      
      // Rate limiting
      sampleRate: 1.0,
      tracesSampleRate: 0.1,
    }
  },

  // Configuración de caché
  cache: {
    // Configuración global
    defaultTtl: 3600, // 1 hora
    
    // Configuraciones específicas
    ttl: {
      userProfile: 1800, // 30 minutos
      driverLocation: 60, // 1 minuto
      routes: 300, // 5 minutos
      geocoding: 86400, // 24 horas
      places: 3600, // 1 hora
      prices: 300, // 5 minutos
    },
    
    // Configuración de invalidación
    invalidation: {
      patterns: {
        userUpdate: ['user:*', 'profile:*'],
        locationUpdate: ['driver:*:location', 'nearby:*'],
        priceUpdate: ['price:*', 'surge:*'],
      }
    }
  },

  // Configuración de WebSockets
  websocket: {
    // Configuración del servidor
    server: {
      cors: {
        origin: [
          'https://rappitaxi.com',
          'https://admin.rappitaxi.com',
          'https://driver.rappitaxi.com'
        ],
        credentials: true,
      },
      
      // Configuraciones de conexión
      pingTimeout: 60000,
      pingInterval: 25000,
      upgradeTimeout: 10000,
      maxHttpBufferSize: 1048576, // 1MB
      
      // Configuraciones de transporte
      transports: ['websocket', 'polling'],
      allowEIO3: true,
    },

    // Rate limiting para WebSockets
    rateLimiting: {
      messagesPerSecond: 10,
      connectionsPerIp: 5,
      
      // Configuraciones de throttling
      throttle: {
        locationUpdates: 100, // max por minuto
        chatMessages: 30, // max por minuto
        generalEvents: 60, // max por minuto
      }
    },

    // Configuraciones de rooms y namespaces
    namespaces: {
      '/passenger': {
        maxConnections: 10000,
        rateLimiting: {
          messagesPerSecond: 5,
          connectionsPerIp: 3,
        }
      },
      '/driver': {
        maxConnections: 5000,
        rateLimiting: {
          messagesPerSecond: 15, // Más mensajes para ubicación
          connectionsPerIp: 2,
        }
      },
      '/admin': {
        maxConnections: 100,
        rateLimiting: {
          messagesPerSecond: 20,
          connectionsPerIp: 1,
        }
      }
    }
  },

  // Configuración de rate limiting
  rateLimiting: {
    // Configuración global
    global: {
      windowMs: 15 * 60 * 1000, // 15 minutos
      max: 1000, // requests por ventana
      message: {
        error: 'Demasiadas requests, intente más tarde',
        code: 'RATE_LIMIT_EXCEEDED',
      },
      
      // Headers de rate limiting
      headers: true,
      standardHeaders: true,
      legacyHeaders: false,
    },

    // Configuraciones específicas por endpoint
    endpoints: {
      auth: {
        windowMs: 15 * 60 * 1000,
        max: 5, // 5 intentos de login por 15 min
        skipSuccessfulRequests: true,
      },
      
      locationUpdate: {
        windowMs: 60 * 1000, // 1 minuto
        max: 60, // 1 por segundo máximo
        keyGenerator: (req) => req.user?.id || req.ip,
      },
      
      rideRequest: {
        windowMs: 5 * 60 * 1000, // 5 minutos
        max: 10, // máximo 10 solicitudes por 5 min
        keyGenerator: (req) => req.user?.id,
      }
    }
  },

  // Configuración de monitoreo
  monitoring: {
    // Health checks
    healthCheck: {
      timeout: 5000,
      
      checks: [
        'database',
        'redis',
        'external-apis',
        'disk-space',
        'memory-usage',
      ]
    },

    // Métricas
    metrics: {
      enabled: true,
      endpoint: '/metrics',
      
      // Configuración de Prometheus
      prometheus: {
        enabled: true,
        metricsPath: '/metrics',
        collectDefaultMetrics: true,
        requestDurationBuckets: [0.1, 0.5, 1, 2, 5],
        requestLengthBuckets: [512, 1024, 5120, 10240, 51200, 102400],
        responseLengthBuckets: [512, 1024, 5120, 10240, 51200, 102400],
      }
    },

    // New Relic (opcional)
    newRelic: {
      enabled: !!process.env.NEW_RELIC_LICENSE_KEY,
      appName: 'RappiTaxi API Production',
      
      // Configuraciones específicas
      distributedTracing: {
        enabled: true,
      },
      
      // Configuraciones de atributos
      attributes: {
        exclude: [
          'request.headers.authorization',
          'request.headers.cookie',
          'response.headers.set-cookie',
        ]
      }
    }
  },

  // Configuración de CORS
  cors: {
    origin: function(origin, callback) {
      // Lista de dominios permitidos en producción
      const allowedOrigins = [
        'https://rappitaxi.com',
        'https://www.rappitaxi.com',
        'https://admin.rappitaxi.com',
        'https://driver.rappitaxi.com',
      ];

      // Permitir requests sin origin (apps móviles)
      if (!origin || allowedOrigins.includes(origin)) {
        callback(null, true);
      } else {
        callback(new Error('No permitido por CORS'));
      }
    },
    
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
    allowedHeaders: [
      'Origin',
      'X-Requested-With',
      'Content-Type',
      'Accept',
      'Authorization',
      'X-API-Key',
    ],
    
    credentials: true,
    optionsSuccessStatus: 200,
  },

  // Configuración de uploads
  uploads: {
    // Configuración general
    maxFileSize: 10 * 1024 * 1024, // 10MB
    allowedMimeTypes: [
      'image/jpeg',
      'image/png',
      'image/webp',
      'application/pdf',
    ],
    
    // Configuración de almacenamiento
    storage: {
      provider: 'firebase', // 'aws-s3' o 'gcp-storage'
      
      firebase: {
        bucket: `${process.env.FIREBASE_PROJECT_ID}.appspot.com`,
        
        // Configuraciones de seguridad
        metadata: {
          cacheControl: 'public, max-age=31536000',
          contentDisposition: 'inline',
        }
      }
    },

    // Configuraciones específicas por tipo
    profiles: {
      maxFileSize: 2 * 1024 * 1024, // 2MB
      allowedMimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
      
      // Configuraciones de redimensionado
      resize: {
        thumbnail: { width: 150, height: 150 },
        medium: { width: 400, height: 400 },
      }
    },

    documents: {
      maxFileSize: 5 * 1024 * 1024, // 5MB
      allowedMimeTypes: ['image/jpeg', 'image/png', 'application/pdf'],
    }
  },

  // Configuración de trabajos en background
  jobs: {
    // Configuración de Bull/Redis Queue
    redis: process.env.REDIS_URL,
    
    // Configuraciones de workers
    concurrency: 5,
    
    // Trabajos periódicos
    cron: {
      // Limpiar datos expirados cada día a las 2 AM
      cleanupExpiredData: '0 2 * * *',
      
      // Generar reportes diarios a las 1 AM
      generateDailyReports: '0 1 * * *',
      
      // Actualizar caché de datos estáticos cada hora
      updateStaticDataCache: '0 * * * *',
      
      // Backup de datos críticos cada 6 horas
      backupCriticalData: '0 */6 * * *',
    },

    // Configuraciones de retry
    defaultJobOptions: {
      removeOnComplete: 100,
      removeOnFail: 50,
      attempts: 3,
      backoff: {
        type: 'exponential',
        delay: 2000,
      },
    }
  },

  // Configuración de backup
  backup: {
    enabled: true,
    
    // Configuración de backup automático
    automatic: {
      enabled: true,
      schedule: '0 2 * * *', // Diariamente a las 2 AM
      
      // Retención
      retention: {
        daily: 7,   // 7 días
        weekly: 4,  // 4 semanas
        monthly: 12, // 12 meses
      }
    },

    // Configuraciones de almacenamiento de backup
    storage: {
      provider: 'gcp-storage', // o 'aws-s3'
      
      gcp: {
        bucket: process.env.BACKUP_STORAGE_BUCKET,
        keyFilename: process.env.GOOGLE_CLOUD_KEY_FILE,
      }
    }
  }
};

// Validaciones de configuración en producción
if (process.env.NODE_ENV === 'production') {
  const requiredEnvVars = [
    'JWT_SECRET',
    'FIREBASE_PROJECT_ID',
    'FIREBASE_PRIVATE_KEY',
    'FIREBASE_CLIENT_EMAIL',
    'GOOGLE_MAPS_API_KEY',
    'MERCADOPAGO_ACCESS_TOKEN',
    'FCM_SERVER_KEY',
    'SENDGRID_API_KEY',
  ];

  for (const envVar of requiredEnvVars) {
    if (!process.env[envVar]) {
      console.error(`❌ Variable de entorno requerida no encontrada: ${envVar}`);
      process.exit(1);
    }
  }

  console.log('✅ Todas las variables de entorno requeridas están configuradas');
}