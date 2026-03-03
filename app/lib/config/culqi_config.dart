// Configuración de Culqi - Pasarela de Pagos Peruana
// =====================================================
//
// IMPORTANTE: Las llaves de Culqi se obtienen de:
// 1. Ir a CulqiPanel: https://panel.culqi.com
// 2. Desarrollo > API Keys
// 3. Copiar Public Key (pk_test_xxx o pk_live_xxx)
//
// Las llaves privadas (sk_xxx) SOLO deben estar en el backend (Cloud Functions)
// NUNCA incluir la private key en código cliente

import 'package:flutter/foundation.dart';

/// Configuración de Culqi para Flutter
class CulqiConfig {
  // ==================== LLAVES PÚBLICAS ====================
  // Estas llaves son seguras para incluir en código cliente
  // La private key está SOLO en Cloud Functions (.env)

  /// Public Key de prueba (sandbox)
  /// Formato: pk_test_XXXXXXXX
  static const String publicKeyTest = 'pk_test_e94078b9d4c5b786';

  /// Public Key de producción (live)
  /// Formato: pk_live_XXXXXXXX
  /// NOTA: Configurar con la llave real de producción antes de lanzar
  static const String publicKeyProd = '';

  /// Determina si estamos en modo producción
  static bool get isProduction => kReleaseMode && publicKeyProd.isNotEmpty;

  /// Retorna la Public Key según el ambiente
  static String get publicKey => isProduction ? publicKeyProd : publicKeyTest;

  // ==================== URLs DE CULQI ====================

  /// URL base de la API de Culqi
  static const String apiBaseUrl = 'https://api.culqi.com/v2';

  /// URL del CDN de Culqi Checkout JS
  static const String checkoutJsUrl = 'https://js.culqi.com/checkout-js';

  /// URL del CDN de Culqi (versión 3)
  static const String culqiJsUrl = 'https://checkout.culqi.com/js/v3';

  // ==================== URLs DE CLOUD FUNCTIONS ====================
  // Estos endpoints son servidos por Firebase Cloud Functions

  /// URL base de Cloud Functions (se configura automáticamente)
  static String get functionsBaseUrl {
    // En desarrollo usar el emulador si está disponible
    if (kDebugMode) {
      return 'https://us-central1-rapi-team.cloudfunctions.net';
    }
    return 'https://us-central1-rapi-team.cloudfunctions.net';
  }

  /// Endpoint para obtener configuración de Culqi
  static String get configEndpoint => '$functionsBaseUrl/getCulqiConfig';

  /// Endpoint para crear cargo
  static String get createChargeEndpoint => '$functionsBaseUrl/createCulqiCharge';

  /// Endpoint para procesar recarga
  static String get rechargeEndpoint => '$functionsBaseUrl/processCulqiRecharge';

  /// Endpoint para crear reembolso
  static String get refundEndpoint => '$functionsBaseUrl/createCulqiRefund';

  /// Endpoint para crear cliente
  static String get createCustomerEndpoint => '$functionsBaseUrl/createCulqiCustomer';

  /// Endpoint para guardar tarjeta
  static String get saveCardEndpoint => '$functionsBaseUrl/saveCulqiCard';

  /// Endpoint para obtener tarjetas
  static String get getCardsEndpoint => '$functionsBaseUrl/getCulqiCards';

  // ==================== CONFIGURACIÓN DE CHECKOUT ====================

  /// Título mostrado en el checkout
  static const String checkoutTitle = 'RapiTeam';

  /// Descripción del comercio
  static const String merchantDescription = 'Servicio de transporte';

  /// Moneda por defecto (Soles peruanos)
  static const String defaultCurrency = 'PEN';

  /// Logo del comercio para el checkout (URL)
  static const String merchantLogo = '';

  /// Color primario del checkout (hex sin #)
  static const String primaryColor = 'FF6B00';

  // ==================== MÉTODOS DE PAGO HABILITADOS ====================

  /// Habilitar pago con tarjeta
  static const bool enableCard = true;

  /// Habilitar pago con Yape
  static const bool enableYape = true;

  /// Habilitar pago con PagoEfectivo (banca móvil)
  static const bool enableBancaMovil = true;

  /// Habilitar pago con billetera
  static const bool enableBilletera = true;

  /// Habilitar Cuotéalo BCP
  static const bool enableCuotealo = false;

  // ==================== CONFIGURACIÓN DE MONTOS ====================

  /// Monto mínimo de recarga en soles
  static const double minRechargeAmount = 5.0;

  /// Monto máximo de recarga en soles
  static const double maxRechargeAmount = 5000.0;

  /// Montos predefinidos de recarga (en soles)
  static const List<double> predefinedRechargeAmounts = [
    10.0,
    20.0,
    50.0,
    100.0,
  ];

  // ==================== TARJETAS DE PRUEBA ====================
  // Usar SOLO en ambiente de prueba (sandbox)

  /// Tarjeta de prueba - Aprobada
  static const Map<String, String> testCardApproved = {
    'number': '4111111111111111',
    'cvv': '123',
    'expMonth': '09',
    'expYear': '2025',
    'email': 'test@culqi.com',
  };

  /// Tarjeta de prueba - Rechazada
  static const Map<String, String> testCardDeclined = {
    'number': '4000000000000002',
    'cvv': '123',
    'expMonth': '09',
    'expYear': '2025',
    'email': 'test@culqi.com',
  };

  /// Tarjeta de prueba - Fondos insuficientes
  static const Map<String, String> testCardInsufficientFunds = {
    'number': '4000000000000051',
    'cvv': '123',
    'expMonth': '09',
    'expYear': '2025',
    'email': 'test@culqi.com',
  };

  // ==================== VALIDACIONES ====================

  /// Verifica si la configuración de Culqi está lista
  static bool get isConfigured {
    final key = publicKey;
    return key.isNotEmpty && (key.startsWith('pk_test_') || key.startsWith('pk_live_'));
  }

  /// Verifica si estamos en modo sandbox
  static bool get isSandbox => publicKey.startsWith('pk_test_');

  /// Convierte monto en soles a céntimos (Culqi usa céntimos)
  static int solesToCents(double soles) {
    return (soles * 100).round();
  }

  /// Convierte céntimos a soles
  static double centsToSoles(int cents) {
    return cents / 100.0;
  }

  /// Formatea monto en soles
  static String formatAmount(double soles) {
    return 'S/ ${soles.toStringAsFixed(2)}';
  }
}

/// Códigos de error de Culqi
class CulqiErrorCodes {
  // Errores de tarjeta
  static const String cardDeclined = 'card_declined';
  static const String insufficientFunds = 'insufficient_funds';
  static const String invalidCvv = 'invalid_cvv';
  static const String invalidExpiryDate = 'invalid_expiry_date';
  static const String invalidCardNumber = 'invalid_card_number';
  static const String expiredCard = 'expired_card';
  static const String lostCard = 'lost_card';
  static const String stolenCard = 'stolen_card';
  static const String fraudulent = 'fraudulent';

  // Errores de procesamiento
  static const String processingError = 'processing_error';
  static const String apiError = 'api_error';
  static const String networkError = 'network_error';

  // Errores de autenticación
  static const String invalidApiKey = 'invalid_api_key';
  static const String authenticationError = 'authentication_error';

  /// Obtiene mensaje de error en español
  static String getMessage(String? code) {
    switch (code) {
      case cardDeclined:
        return 'La tarjeta fue rechazada. Intenta con otra tarjeta.';
      case insufficientFunds:
        return 'Fondos insuficientes. Verifica el saldo de tu tarjeta.';
      case invalidCvv:
        return 'CVV inválido. Verifica el código de seguridad.';
      case invalidExpiryDate:
        return 'Fecha de vencimiento inválida.';
      case invalidCardNumber:
        return 'Número de tarjeta inválido.';
      case expiredCard:
        return 'La tarjeta está vencida.';
      case lostCard:
        return 'La tarjeta fue reportada como perdida.';
      case stolenCard:
        return 'La tarjeta fue reportada como robada.';
      case fraudulent:
        return 'Transacción sospechosa. Contacta a tu banco.';
      case processingError:
        return 'Error al procesar el pago. Intenta de nuevo.';
      case apiError:
        return 'Error del servidor. Intenta más tarde.';
      case networkError:
        return 'Error de conexión. Verifica tu internet.';
      case invalidApiKey:
        return 'Error de configuración. Contacta a soporte.';
      case authenticationError:
        return 'Error de autenticación. Inicia sesión de nuevo.';
      default:
        return 'Error desconocido. Intenta de nuevo o contacta a soporte.';
    }
  }
}

/// Estados de cargos de Culqi
class CulqiChargeStatus {
  static const String successful = 'successful';
  static const String declined = 'declined';
  static const String pending = 'pending';
  static const String refunded = 'refunded';
  static const String partiallyRefunded = 'partially_refunded';
  static const String disputed = 'disputed';

  /// Verifica si el cargo fue exitoso
  static bool isSuccessful(String? status) {
    return status == successful;
  }

  /// Obtiene descripción del estado en español
  static String getDescription(String? status) {
    switch (status) {
      case successful:
        return 'Pago exitoso';
      case declined:
        return 'Pago rechazado';
      case pending:
        return 'Pago pendiente';
      case refunded:
        return 'Reembolsado';
      case partiallyRefunded:
        return 'Reembolso parcial';
      case disputed:
        return 'En disputa';
      default:
        return 'Estado desconocido';
    }
  }
}
