// RappiTaxi - Configuración optimizada para producción
// Este archivo contiene todas las configuraciones específicas de producción

class ProductionConfig {
  // URL del API de producción
  static const String apiBaseUrl = 'https://api.rappitaxi.com';
  static const String wsBaseUrl = 'wss://api.rappitaxi.com';
  
  // Configuración de timeouts (optimizados para producción)
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration wsConnectionTimeout = Duration(seconds: 10);
  static const Duration wsHeartbeatInterval = Duration(seconds: 30);
  
  // Configuración de caché (más agresiva en producción)
  static const Duration cacheMaxAge = Duration(hours: 24);
  static const Duration locationCacheMaxAge = Duration(minutes: 5);
  static const Duration userProfileCacheMaxAge = Duration(hours: 6);
  
  // Configuración de geolocalización
  static const double locationAccuracyMeters = 10.0;
  static const Duration locationUpdateInterval = Duration(seconds: 10);
  static const double significantLocationChangeMeters = 50.0;
  
  // Configuración de mapas
  static const double defaultMapZoom = 15.0;
  static const double trackingMapZoom = 17.0;
  static const Duration mapAnimationDuration = Duration(milliseconds: 800);
  
  // Configuración de notificaciones
  static const String fcmVapidKey = 'YOUR_PRODUCTION_VAPID_KEY';
  static const bool enablePushNotifications = true;
  static const bool enableLocalNotifications = true;
  
  // Configuración de logging (reducido para producción)
  static const bool enableDebugLogs = false;
  static const bool enableErrorReporting = true;
  static const bool enablePerformanceMonitoring = true;
  static const bool enableAnalytics = true;
  
  // Configuración de seguridad
  static const bool enableSSLPinning = true;
  static const bool enableCertificatePinning = true;
  static const bool enableJailbreakDetection = true;
  static const bool enableScreenshotBlocking = true;
  
  // Configuración de rendimiento
  static const int maxConcurrentRequests = 5;
  static const Duration retryDelay = Duration(seconds: 2);
  static const int maxRetryAttempts = 3;
  
  // Configuración de imágenes
  static const int imageQuality = 85; // 0-100
  static const int maxImageWidth = 1024;
  static const int maxImageHeight = 1024;
  static const Duration imageCacheDuration = Duration(days: 7);
  
  // Configuración de pagos
  static const String mercadoPagoPublicKey = 'YOUR_PRODUCTION_MP_PUBLIC_KEY';
  static const bool enableTestPayments = false;
  static const Duration paymentTimeout = Duration(minutes: 5);
  
  // Configuración de funciones experimentales
  static const bool enableBetaFeatures = false;
  static const bool enableDeveloperMode = false;
  static const bool showPerformanceOverlay = false;
  
  // Configuración de Analytics
  static const String mixpanelToken = 'YOUR_PRODUCTION_MIXPANEL_TOKEN';
  static const String amplitudeApiKey = 'YOUR_PRODUCTION_AMPLITUDE_KEY';
  static const bool enableCrashReporting = true;
  
  // URLs de términos y privacidad
  static const String termsOfServiceUrl = 'https://rappitaxi.com/terminos';
  static const String privacyPolicyUrl = 'https://rappitaxi.com/privacidad';
  static const String supportUrl = 'https://rappitaxi.com/soporte';
  static const String supportEmail = 'soporte@rappitaxi.com';
  static const String supportPhone = '+51 1 234-5678';
  
  // Configuración de versioning
  static const String minimumAppVersion = '1.0.0';
  static const bool enforceAppUpdate = true;
  static const String updateUrl = 'https://rappitaxi.com/actualizar';
  
  // Feature flags para producción
  static const Map<String, bool> featureFlags = {
    'enable_price_negotiation': true,
    'enable_surge_pricing': true,
    'enable_scheduled_rides': true,
    'enable_shared_rides': true,
    'enable_ride_sharing': true,
    'enable_driver_tips': true,
    'enable_ride_insurance': false, // Pendiente implementación
    'enable_corporate_accounts': false, // Próxima versión
    'enable_multi_language': false, // v2.0
    'enable_driver_rewards': true,
    'enable_passenger_rewards': true,
    'enable_referral_system': true,
    'enable_promotions': true,
    'enable_loyalty_program': false, // v2.0
  };
  
  // Configuración de rate limiting (lado cliente)
  static const Map<String, int> rateLimits = {
    'location_updates_per_minute': 30,
    'api_requests_per_minute': 100,
    'websocket_messages_per_minute': 60,
    'image_uploads_per_hour': 10,
    'support_messages_per_hour': 5,
  };
  
  // Configuración de emergencia
  static const String emergencyNumber = '911';
  static const List<String> emergencyContacts = [
    '+51 1 234-5678', // Soporte RappiTaxi
    '+51 1 234-5679', // Emergencias 24h
  ];
  
  // Configuración de ciudades disponibles
  static const List<Map<String, dynamic>> availableCities = [
    {
      'id': 'lima',
      'name': 'Lima',
      'country': 'Perú',
      'center': {'lat': -12.0464, 'lng': -77.0428},
      'bounds': {
        'northeast': {'lat': -11.8, 'lng': -76.8},
        'southwest': {'lat': -12.3, 'lng': -77.3},
      },
      'timezone': 'America/Lima',
      'currency': 'PEN',
      'active': true,
    },
    // Agregar más ciudades según expansión
  ];
  
  // Configuración de monitoreo y métricas
  static const Duration metricsReportingInterval = Duration(minutes: 5);
  static const bool enableRealTimeMetrics = true;
  static const bool enableUserBehaviorTracking = true; // Con consentimiento
  
  // Configuración de optimización de batería
  static const bool enableBatteryOptimization = true;
  static const Duration backgroundLocationInterval = Duration(minutes: 2);
  static const Duration foregroundLocationInterval = Duration(seconds: 10);
  
  // Validación de configuración para producción
  static bool validateProductionConfig() {
    // Verificar que las URLs no sean de desarrollo
    if (apiBaseUrl.contains('localhost') || 
        apiBaseUrl.contains('127.0.0.1') ||
        apiBaseUrl.contains('staging')) {
      throw Exception('URL de API no debe ser localhost o staging en producción');
    }
    
    // Verificar que debugging esté deshabilitado
    if (enableDebugLogs) {
      throw Exception('Debug logs debe estar deshabilitado en producción');
    }
    
    // Verificar que funciones de desarrollo estén deshabilitadas
    if (enableDeveloperMode || showPerformanceOverlay) {
      throw Exception('Funciones de desarrollo deben estar deshabilitadas en producción');
    }
    
    // Verificar que SSL esté habilitado
    if (!enableSSLPinning) {
      throw Exception('SSL Pinning debe estar habilitado en producción');
    }
    
    // Verificar que reporting esté habilitado
    if (!enableErrorReporting) {
      throw Exception('Error reporting debe estar habilitado en producción');
    }
    
    return true;
  }
  
  // Obtener configuración según el entorno
  static Map<String, dynamic> getEnvironmentConfig() {
    return {
      'environment': 'production',
      'debug': false,
      'apiUrl': apiBaseUrl,
      'wsUrl': wsBaseUrl,
      'enableLogging': enableDebugLogs,
      'enableSSL': enableSSLPinning,
      'enableAnalytics': enableAnalytics,
      'features': featureFlags,
      'limits': rateLimits,
      'version': minimumAppVersion,
    };
  }
}