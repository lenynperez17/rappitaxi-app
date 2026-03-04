import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  // API Configuration
  static const String apiBaseUrl = 'https://api.rapiteam.app/v1';

  // 🔐 GOOGLE MAPS API KEY - Cargada desde archivo .env
  // ============================================================================
  // ✅ CONFIGURACIÓN AUTOMÁTICA - Solo configura una vez en el archivo .env
  //
  // INSTRUCCIONES SIMPLES:
  // 1. Copia .env.example a .env en la carpeta app/
  //    Comando: cp .env.example .env
  //
  // 2. Edita .env y reemplaza GOOGLE_MAPS_API_KEY con tu API Key real
  //
  // 3. Ejecuta: flutter run
  //    ¡Sin parámetros adicionales! La app carga automáticamente el .env
  //
  // El archivo .env está en .gitignore - tus credenciales están seguras.
  //
  // La API Key debe tener restricciones configuradas en Google Cloud Console:
  // - Android: Restringir por SHA-1/SHA-256 del keystore
  // - iOS: Restringir por Bundle ID
  // - APIs habilitadas: Places API, Directions API, Geocoding API
  // ============================================================================
  // Fallback key in case .env fails to load (e.g. iOS release builds)
  static const String _fallbackGoogleMapsApiKey = 'AIzaSyCKR6lzqe9u7_dVqQn_jFon28y0MZlrIns';

  static String get googleMapsApiKey {
    final key = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
    if (key.isNotEmpty && !key.startsWith('X')) {
      return key;
    }
    return _fallbackGoogleMapsApiKey;
  }

  // Alias para compatibilidad con código existente
  static String get googlePlacesApiKey => googleMapsApiKey;
  static String get googleDirectionsApiKey => googleMapsApiKey;
  
  // Environment Configuration
  static const String environment = String.fromEnvironment('environment', defaultValue: 'development');
  
  static bool get isDevelopment => environment == 'development';
  static bool get isProduction => environment == 'production';
  
  // Configuración de timeouts
  static const int connectionTimeout = 30000; // 30 segundos
  static const int receiveTimeout = 30000; // 30 segundos
  
  // Configuración de reintentos
  static const int maxRetries = 3;
  static const int retryDelay = 1000; // 1 segundo
  
  // Configuración de cache
  static const int cacheMaxAge = 3600; // 1 hora
  static const int locationUpdateInterval = 10; // 10 segundos
  
  // Configuración de mapas
  static const double defaultZoom = 15.0;
  static const double defaultTilt = 0.0;
  static const double defaultBearing = 0.0;
  
  // Configuración de pagos
  static const double minPaymentAmount = 5.0;
  static const double maxPaymentAmount = 500.0;
  
  // Feature flags
  static const bool enableRideSharing = false;
  static const bool enableScheduledRides = false;
  static const bool enableCorporateAccounts = false;
}