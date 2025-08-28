import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? '';
  static String get googleMapsApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  static String get mercadoPagoPublicKey => dotenv.env['MERCADOPAGO_PUBLIC_KEY'] ?? '';
  static String get environment => dotenv.env['ENVIRONMENT'] ?? 'development';
  
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
  
  // Validación de configuración
  static void validate() {
    if (apiBaseUrl.isEmpty) {
      throw Exception('API_BASE_URL no está configurado');
    }
    if (googleMapsApiKey.isEmpty) {
      throw Exception('GOOGLE_MAPS_API_KEY no está configurado');
    }
    if (isProduction && mercadoPagoPublicKey.isEmpty) {
      throw Exception('MERCADOPAGO_PUBLIC_KEY no está configurado para producción');
    }
  }
}