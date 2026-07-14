import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'firebase_service.dart';
import 'rapi_api_client.dart';

/// SERVICIO COMPLETO DE PAGOS RAPPI TEAM - PERÚ
/// ============================================
///
/// Tras la migración al backend Node:
///  - Preferencias de MercadoPago se crean vía RapiApiClient.createRechargeCheckout
///  - Los webhooks los procesa el backend Node directamente (no Cloud Functions)
///  - Los otros endpoints legados (Yape/Plin/history/refund/withdrawal) siguen
///    exponiendo el mismo shape de datos, pero delegan al backend Node cuando
///    tenga implementación. Mientras tanto, retornan errores explícitos para no
///    romper la UI existente.
///
/// La API pública se preserva para no romper las pantallas.
class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  final FirebaseService _firebaseService = FirebaseService();

  bool _initialized = false;
  String _mercadoPagoPublicKey = '';

  /// Inicializar el servicio de pagos.
  ///
  /// Ya no se hace healthcheck de Cloud Functions — el backend Node se asume
  /// disponible cuando el usuario está autenticado.
  Future<void> initialize({bool isProduction = false}) async {
    if (_initialized) return;

    try {
      await _firebaseService.initialize();

      // La public key de MercadoPago debería servirla el backend Node en
      // cada checkout que crea. Aquí no la almacenamos como estado global
      // — se obtiene por checkout.
      _mercadoPagoPublicKey = '';
      _initialized = true;
      debugPrint(
          'PaymentService inicializado (${isProduction ? "PRODUCCIÓN" : "TEST"})');

      await _firebaseService.analytics.logEvent(
        name: 'payment_service_initialized',
        parameters: {'environment': isProduction ? 'production' : 'test'},
      );
    } catch (e) {
      debugPrint('PaymentService: error inicializando - $e');
      await _firebaseService.recordError(e, null);
      rethrow;
    }
  }

  // ============================================================================
  // MERCADOPAGO — Recarga vía backend Node
  // ============================================================================

  /// Crea una preferencia de pago MercadoPago para RECARGAS DE BILLETERA.
  ///
  /// El backend Node retorna { checkoutUrl, initPoint, preferenceId, publicKey }.
  /// La UI abre `initPoint` en un WebView.
  Future<PaymentPreferenceResult> createMercadoPagoPreference({
    required String rideId, // rechargeId — id de la transacción
    required double amount,
    required String payerEmail,
    required String payerName,
    String? description,
  }) async {
    try {
      debugPrint('PaymentService: creando preferencia MP - S/. $amount');

      final res = await RapiApiClient.instance.createRechargeCheckout(amount);
      // Formato esperado del backend:
      // { preferenceId, initPoint, publicKey, amount, platformCommission, driverEarnings }
      final preferenceId = res['preferenceId']?.toString();
      final initPoint = res['initPoint']?.toString() ??
          res['checkoutUrl']?.toString();
      final publicKey = res['publicKey']?.toString() ?? _mercadoPagoPublicKey;

      if (initPoint == null || initPoint.isEmpty) {
        return PaymentPreferenceResult.error(
            'El backend no devolvió initPoint');
      }

      if (publicKey.isNotEmpty) {
        _mercadoPagoPublicKey = publicKey;
      }

      await _firebaseService.analytics.logEvent(
        name: 'mercadopago_preference_created',
        parameters: {
          'ride_id': rideId,
          'amount': amount,
          'preference_id': preferenceId ?? '',
        },
      );

      return PaymentPreferenceResult.success(
        preferenceId: preferenceId,
        initPoint: initPoint,
        publicKey: publicKey,
        amount: amount,
        platformCommission:
            (res['platformCommission'] as num?)?.toDouble(),
        driverEarnings: (res['driverEarnings'] as num?)?.toDouble(),
      );
    } catch (e) {
      debugPrint('PaymentService: error creando preferencia MP - $e');
      await _firebaseService.recordError(e, null);
      return PaymentPreferenceResult.error('Error creando preferencia: $e');
    }
  }

  /// Abre el checkout de MercadoPago en el navegador externo.
  /// Preferible usar el WebView in-app cuando sea posible.
  Future<bool> openMercadoPagoCheckout(String initPoint) async {
    try {
      final uri = Uri.parse(initPoint);
      if (await canLaunchUrl(uri)) {
        final launched =
            await launchUrl(uri, mode: LaunchMode.externalApplication);
        await _firebaseService.analytics.logEvent(
          name: 'mercadopago_checkout_opened',
          parameters: {'init_point': initPoint, 'success': launched},
        );
        return launched;
      }
      return false;
    } catch (e) {
      debugPrint('PaymentService: error abriendo checkout - $e');
      return false;
    }
  }

  /// Procesar un pago con Checkout Bricks in-app.
  ///
  /// El backend Node debe exponer un endpoint para procesar el token
  /// generado por Bricks. Actualmente no existe en RapiApiClient, así que
  /// este método retorna un error explícito hasta que se implemente.
  Future<PaymentResult> processMercadoPagoCheckoutBricks({
    required String rideId,
    required String token,
    required String paymentMethodId,
    required String issuerId,
    required int installments,
    required double transactionAmount,
    required String payerEmail,
    required String description,
    String? payerFirstName,
    String? payerLastName,
    String? identificationType,
    String? identificationNumber,
  }) async {
    // TODO: exponer en el backend Node un endpoint POST /api/payments/bricks
    // y agregarlo a RapiApiClient. Mientras tanto, la UI debe caer a
    // openMercadoPagoCheckout(initPoint).
    debugPrint(
        'PaymentService: Checkout Bricks aún no soportado en backend Node');
    return PaymentResult(
      success: false,
      error: 'checkout_bricks_not_available',
      message:
          'El pago con Checkout Bricks aún no está disponible. Usa el checkout web.',
    );
  }

  // ============================================================================
  // YAPE — pendiente de endpoint en backend Node
  // ============================================================================

  Future<YapePaymentResult> processWithYape({
    required String rideId,
    required double amount,
    required String phoneNumber,
    String? transactionCode,
  }) async {
    if (!_validatePeruvianPhoneNumber(phoneNumber)) {
      return YapePaymentResult.error('Número de teléfono inválido para Yape');
    }
    // TODO: endpoint POST /api/payments/yape en el backend Node.
    return YapePaymentResult.error(
        'Pago con Yape aún no disponible en el backend Node');
  }

  /// Abre la app de Yape con parámetros pre-cargados.
  Future<bool> openYapeApp(
      String phoneNumber, double amount, String message) async {
    try {
      final yapeUrl =
          'yape://payment?amount=$amount&phone=$phoneNumber&message=${Uri.encodeComponent(message)}';
      final uri = Uri.parse(yapeUrl);

      if (await canLaunchUrl(uri)) {
        final launched = await launchUrl(uri);
        await _firebaseService.analytics.logEvent(
          name: 'yape_app_opened',
          parameters: {
            'amount': amount,
            'phone_number': phoneNumber,
            'success': launched,
          },
        );
        return launched;
      }
      final playStoreUri =
          Uri.parse('https://play.google.com/store/apps/details?id=com.bcp.yape');
      return await launchUrl(playStoreUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('PaymentService: error abriendo Yape - $e');
      return false;
    }
  }

  // ============================================================================
  // PLIN — pendiente de endpoint en backend Node
  // ============================================================================

  Future<PlinPaymentResult> processWithPlin({
    required String rideId,
    required double amount,
    required String phoneNumber,
  }) async {
    if (!_validatePeruvianPhoneNumber(phoneNumber)) {
      return PlinPaymentResult.error('Número de teléfono inválido para Plin');
    }
    // TODO: endpoint POST /api/payments/plin en el backend Node.
    return PlinPaymentResult.error(
        'Pago con Plin aún no disponible en el backend Node');
  }

  Future<bool> openPlinApp(
      String phoneNumber, double amount, String message) async {
    try {
      final plinUrl =
          'plin://payment?amount=$amount&phone=$phoneNumber&message=${Uri.encodeComponent(message)}';
      final uri = Uri.parse(plinUrl);

      if (await canLaunchUrl(uri)) {
        final launched = await launchUrl(uri);
        await _firebaseService.analytics.logEvent(
          name: 'plin_app_opened',
          parameters: {
            'amount': amount,
            'phone_number': phoneNumber,
            'success': launched,
          },
        );
        return launched;
      }
      final playStoreUri = Uri.parse(
          'https://play.google.com/store/apps/details?id=pe.interbank.plin');
      return await launchUrl(playStoreUri,
          mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('PaymentService: error abriendo Plin - $e');
      return false;
    }
  }

  // ============================================================================
  // HISTORIAL / ESTADO / REEMBOLSOS
  // ============================================================================

  /// Verifica estado de un pago vía backend Node.
  Future<PaymentStatusResult> checkPaymentStatus(String paymentId) async {
    // TODO: endpoint GET /api/payments/{id} en el backend Node.
    return PaymentStatusResult.error(
        'checkPaymentStatus aún no disponible en el backend Node');
  }

  /// Historial de pagos del usuario. Actualmente delegado a
  /// `listWalletTransactions` del backend Node.
  Future<List<PaymentHistoryItem>> getUserPaymentHistory(
      String userId, String role) async {
    try {
      final res = await RapiApiClient.instance.listWalletTransactions();
      final raw = (res['transactions'] as List?) ??
          (res['data'] as List?) ??
          const [];
      return raw.whereType<Map>().map((m) {
        final map = m.cast<String, dynamic>();
        return PaymentHistoryItem(
          id: (map['id'] ?? '').toString(),
          rideId: (map['rideId'] ?? '').toString(),
          amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
          paymentMethod: (map['paymentMethod'] ?? map['method'] ?? '').toString(),
          status: (map['status'] ?? '').toString(),
          createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
              DateTime.now(),
          approvedAt: DateTime.tryParse(map['approvedAt']?.toString() ?? ''),
          platformCommission:
              (map['platformCommission'] as num?)?.toDouble() ?? 0.0,
          driverEarnings: (map['driverEarnings'] as num?)?.toDouble() ?? 0.0,
        );
      }).toList();
    } catch (e) {
      debugPrint('PaymentService: error obteniendo historial - $e');
      return [];
    }
  }

  /// Solicitar reembolso. Pendiente de endpoint en backend Node.
  Future<RefundResult> processRefund({
    required String paymentId,
    double? amount,
    required String reason,
  }) async {
    // TODO: endpoint POST /api/payments/refund en el backend Node.
    return RefundResult.error(
        'processRefund aún no disponible en el backend Node');
  }

  // ============================================================================
  // CÁLCULOS Y UTILIDADES
  // ============================================================================

  double calculateFare({
    required double distanceKm,
    required int durationMinutes,
    required String vehicleType,
    bool applyDynamicPricing = false,
    double dynamicMultiplier = 1.0,
  }) {
    final baseFares = {
      'standard': 3.50,
      'premium': 5.00,
      'van': 7.00,
    };
    final perKmRates = {
      'standard': 1.20,
      'premium': 1.80,
      'van': 2.50,
    };
    final perMinuteRates = {
      'standard': 0.25,
      'premium': 0.40,
      'van': 0.60,
    };

    final baseFare = baseFares[vehicleType] ?? baseFares['standard']!;
    final perKm = perKmRates[vehicleType] ?? perKmRates['standard']!;
    final perMinute =
        perMinuteRates[vehicleType] ?? perMinuteRates['standard']!;

    double fare =
        baseFare + (distanceKm * perKm) + (durationMinutes * perMinute);

    if (applyDynamicPricing) {
      fare *= dynamicMultiplier;
    }

    return fare < 4.5 ? 4.5 : double.parse(fare.toStringAsFixed(2));
  }

  double calculatePlatformCommission(double fareAmount) {
    return double.parse((fareAmount * 0.12).toStringAsFixed(2));
  }

  double calculateDriverEarnings(double fareAmount) {
    return double.parse((fareAmount * 0.80).toStringAsFixed(2));
  }

  // ============================================================================
  // MÉTODOS AUXILIARES PRIVADOS
  // ============================================================================

  bool _validatePeruvianPhoneNumber(String phoneNumber) {
    final cleaned = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleaned.length == 9 && cleaned.startsWith('9')) {
      return RegExp(r'^9[0-9]{8}$').hasMatch(cleaned);
    }
    if (cleaned.length == 12 && cleaned.startsWith('519')) {
      return RegExp(r'^519[0-9]{8}$').hasMatch(cleaned);
    }
    return false;
  }

  List<PaymentMethodInfo> getAvailablePaymentMethods() {
    return [
      PaymentMethodInfo(
        id: 'mercadopago',
        name: 'MercadoPago',
        description: 'Visa, Mastercard, American Express',
        icon: '💳',
        isEnabled: true,
        requiresPhoneNumber: false,
      ),
      PaymentMethodInfo(
        id: 'yape',
        name: 'Yape',
        description: 'BCP - Pago instantáneo con QR',
        icon: '🟡',
        isEnabled: true,
        requiresPhoneNumber: true,
      ),
      PaymentMethodInfo(
        id: 'plin',
        name: 'Plin',
        description: 'Interbank - Pago rápido con QR',
        icon: '🟣',
        isEnabled: true,
        requiresPhoneNumber: true,
      ),
      PaymentMethodInfo(
        id: 'pagoefectivo',
        name: 'PagoEfectivo',
        description: 'Paga en Tambo+, Oxxo, Full',
        icon: '🏪',
        isEnabled: true,
        requiresPhoneNumber: false,
      ),
      PaymentMethodInfo(
        id: 'bank_transfer',
        name: 'Transferencia',
        description: 'BCP, BBVA, Interbank, Scotiabank',
        icon: '🏛️',
        isEnabled: true,
        requiresPhoneNumber: false,
      ),
      PaymentMethodInfo(
        id: 'cash',
        name: 'Efectivo',
        description: 'Pago directo al conductor',
        icon: '💵',
        isEnabled: true,
        requiresPhoneNumber: false,
      ),
    ];
  }

  // ============================================================================
  // RETIROS — pendiente de endpoint en backend Node
  // ============================================================================

  Future<WithdrawalResult> requestWithdrawal({
    required String driverId,
    required double amount,
    required String method, // 'bank_transfer', 'yape', 'plin'
    String? bankName,
    String? accountNumber,
    String? phoneNumber,
    required String accountHolderName,
    required String accountHolderDocumentNumber,
    String accountHolderDocumentType = 'DNI',
  }) async {
    try {
      // Validaciones locales
      if (method == 'bank_transfer') {
        if (bankName == null || bankName.isEmpty) {
          throw Exception('Nombre del banco es requerido');
        }
        if (accountNumber == null || accountNumber.isEmpty) {
          throw Exception('Número de cuenta es requerido');
        }
      } else if (method == 'yape' || method == 'plin') {
        if (phoneNumber == null || phoneNumber.isEmpty) {
          throw Exception('Número de teléfono es requerido para $method');
        }
        if (!RegExp(r'^9[0-9]{8}$').hasMatch(phoneNumber)) {
          throw Exception(
              'Número de teléfono inválido. Debe tener 9 dígitos y empezar con 9');
        }
      }
      if (amount < 50.0) {
        throw Exception('El monto mínimo de retiro es S/. 50.00');
      }

      // TODO: endpoint POST /api/wallet/withdraw en el backend Node.
      return WithdrawalResult(
        success: false,
        error:
            'requestWithdrawal aún no disponible en el backend Node — pendiente de implementación',
      );
    } catch (e) {
      debugPrint('PaymentService: error en requestWithdrawal - $e');
      await _firebaseService.recordError(e, StackTrace.current);
      return WithdrawalResult(success: false, error: e.toString());
    }
  }

  // Getters con validación
  bool get isInitialized => _initialized;

  String get mercadoPagoPublicKey {
    if (!_initialized) {
      throw StateError(
          'PaymentService no inicializado. Llama a initialize() primero.');
    }
    return _mercadoPagoPublicKey;
  }

  /// URL base del backend Node (para compatibilidad con código que lo consultaba).
  String get apiBaseUrl {
    if (!_initialized) {
      throw StateError(
          'PaymentService no inicializado. Llama a initialize() primero.');
    }
    return RapiApiClient.baseUrl;
  }
}

// ============================================================================
// CLASES DE DATOS Y RESULTADOS
// ============================================================================

class PaymentPreferenceResult {
  final bool success;
  final String? preferenceId;
  final String? initPoint;
  final String? publicKey;
  final double? amount;
  final double? platformCommission;
  final double? driverEarnings;
  final String? error;

  PaymentPreferenceResult.success({
    required this.preferenceId,
    required this.initPoint,
    required this.publicKey,
    required this.amount,
    required this.platformCommission,
    required this.driverEarnings,
  })  : success = true,
        error = null;

  PaymentPreferenceResult.error(this.error)
      : success = false,
        preferenceId = null,
        initPoint = null,
        publicKey = null,
        amount = null,
        platformCommission = null,
        driverEarnings = null;
}

class PaymentResult {
  final bool success;
  final String? paymentId;
  final String? status;
  final String? message;
  final String? error;

  PaymentResult({
    required this.success,
    this.paymentId,
    this.status,
    this.message,
    this.error,
  });
}

class YapePaymentResult {
  final bool success;
  final String? paymentId;
  final String? qrUrl;
  final String? phoneNumber;
  final double? amount;
  final String? instructions;
  final double? platformCommission;
  final double? driverEarnings;
  final String? error;

  YapePaymentResult.success({
    required this.paymentId,
    required this.qrUrl,
    required this.phoneNumber,
    required this.amount,
    required this.instructions,
    required this.platformCommission,
    required this.driverEarnings,
  })  : success = true,
        error = null;

  YapePaymentResult.error(this.error)
      : success = false,
        paymentId = null,
        qrUrl = null,
        phoneNumber = null,
        amount = null,
        instructions = null,
        platformCommission = null,
        driverEarnings = null;
}

class PlinPaymentResult {
  final bool success;
  final String? paymentId;
  final String? qrUrl;
  final String? phoneNumber;
  final double? amount;
  final String? instructions;
  final double? platformCommission;
  final double? driverEarnings;
  final String? error;

  PlinPaymentResult.success({
    required this.paymentId,
    required this.qrUrl,
    required this.phoneNumber,
    required this.amount,
    required this.instructions,
    required this.platformCommission,
    required this.driverEarnings,
  })  : success = true,
        error = null;

  PlinPaymentResult.error(this.error)
      : success = false,
        paymentId = null,
        qrUrl = null,
        phoneNumber = null,
        amount = null,
        instructions = null,
        platformCommission = null,
        driverEarnings = null;
}

class PaymentStatusResult {
  final bool success;
  final String? id;
  final String? status;
  final double? amount;
  final String? paymentMethod;
  final double? platformCommission;
  final double? driverEarnings;
  final DateTime? createdAt;
  final DateTime? approvedAt;
  final DateTime? refundedAt;
  final String? error;

  PaymentStatusResult.success({
    required this.id,
    required this.status,
    required this.amount,
    required this.paymentMethod,
    required this.platformCommission,
    required this.driverEarnings,
    required this.createdAt,
    this.approvedAt,
    this.refundedAt,
  })  : success = true,
        error = null;

  PaymentStatusResult.error(this.error)
      : success = false,
        id = null,
        status = null,
        amount = null,
        paymentMethod = null,
        platformCommission = null,
        driverEarnings = null,
        createdAt = null,
        approvedAt = null,
        refundedAt = null;
}

class PaymentHistoryItem {
  final String id;
  final String rideId;
  final double amount;
  final String paymentMethod;
  final String status;
  final DateTime createdAt;
  final DateTime? approvedAt;
  final double platformCommission;
  final double driverEarnings;

  PaymentHistoryItem({
    required this.id,
    required this.rideId,
    required this.amount,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
    this.approvedAt,
    required this.platformCommission,
    required this.driverEarnings,
  });
}

class RefundResult {
  final bool success;
  final double? refundAmount;
  final String? status;
  final String? error;

  RefundResult.success({
    required this.refundAmount,
    required this.status,
  })  : success = true,
        error = null;

  RefundResult.error(this.error)
      : success = false,
        refundAmount = null,
        status = null;
}

class PaymentMethodInfo {
  final String id;
  final String name;
  final String description;
  final String icon;
  final bool isEnabled;
  final bool requiresPhoneNumber;

  PaymentMethodInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.isEnabled,
    required this.requiresPhoneNumber,
  });
}

class WithdrawalResult {
  final bool success;
  final String? withdrawalId;
  final String? transferId;
  final String? status;
  final double? amount;
  final String? error;

  WithdrawalResult({
    required this.success,
    this.withdrawalId,
    this.transferId,
    this.status,
    this.amount,
    this.error,
  });
}

enum PaymentStatus {
  pending,
  processing,
  approved,
  rejected,
  refunded,
  cancelled,
}

enum PaymentMethod {
  mercadopago,
  yape,
  plin,
  cash,
}
