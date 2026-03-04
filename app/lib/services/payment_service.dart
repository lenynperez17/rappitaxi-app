import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_service.dart';

/// SERVICIO COMPLETO DE PAGOS RAPPI TEAM - PERÚ
/// ============================================
/// 
/// Funcionalidades implementadas:
/// ✅ MercadoPago (preferencias y webhooks)
/// ✅ Yape (código QR y validación)
/// ✅ Plin (código QR y validación)
/// ✅ Comisiones automáticas (20% plataforma)
/// ✅ Reembolsos completos
/// ✅ Historial de pagos
/// ✅ Verificación de estado de pago
class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  final FirebaseService _firebaseService = FirebaseService();

  bool _initialized = false;
  String _apiBaseUrl = '';
  String _mercadoPagoPublicKey = '';

  // ✅ PROJECT ID DE FIREBASE CONFIGURADO
  static const String _firebaseProjectId = 'rapi-team';

  // URLs de Firebase Functions - PERÚ
  static const String _localApi = 'http://localhost:5001/$_firebaseProjectId/us-central1';
  static const String _productionApi = 'https://us-central1-$_firebaseProjectId.cloudfunctions.net';

  /// Inicializar el servicio de pagos
  Future<void> initialize({bool isProduction = false}) async {
    if (_initialized) return;

    try {
      _apiBaseUrl = isProduction ? _productionApi : _localApi;

      await _firebaseService.initialize();

      // ✅ CORRECCIÓN SEGURIDAD: Obtener public key desde Cloud Functions (NO hardcodeada)
      debugPrint('💳 PaymentService: Obteniendo config de MercadoPago desde backend...');
      try {
        final configResponse = await http.get(
          Uri.parse('$_apiBaseUrl/getMercadoPagoConfig'),
        ).timeout(const Duration(seconds: 10));

        if (configResponse.statusCode == 200) {
          final configData = jsonDecode(configResponse.body);

          if (configData['success'] == true) {
            _mercadoPagoPublicKey = configData['publicKey'];
            debugPrint('✅ MercadoPago public key obtenida - Env: ${configData['environment']}');
          } else {
            throw Exception('Error obteniendo config: ${configData['error']}');
          }
        } else {
          throw Exception('Error HTTP ${configResponse.statusCode} obteniendo config');
        }
      } catch (e) {
        debugPrint('❌ CRÍTICO: No se pudo obtener config de MercadoPago - $e');

        await _firebaseService.crashlytics.recordError(
          Exception('Config de MercadoPago no disponible: $e'),
          StackTrace.current,
          fatal: true,
        );

        _initialized = false;
        throw Exception('No se pudo obtener configuración de MercadoPago. Verifica que Cloud Functions estén desplegadas.');
      }

      // ✅ CORRECCIÓN: Validar que Cloud Functions estén disponibles
      debugPrint('💳 PaymentService: Validando disponibilidad de Cloud Functions...');
      try {
        final healthCheck = await http.get(
          Uri.parse('$_apiBaseUrl/healthCheck'),
        ).timeout(const Duration(seconds: 5));

        if (healthCheck.statusCode != 200) {
          throw Exception('Cloud Functions no responden (Status: ${healthCheck.statusCode})');
        }

        debugPrint('✅ Cloud Functions disponibles y funcionando');
      } catch (e) {
        debugPrint('❌ CRÍTICO: Cloud Functions NO disponibles - $e');
        debugPrint('⚠️ PAGOS DESHABILITADOS - Despliega Cloud Functions primero');

        await _firebaseService.crashlytics.recordError(
          Exception('Cloud Functions no disponibles en $_apiBaseUrl'),
          StackTrace.current,
          fatal: true,
        );

        // NO marcar como inicializado si Cloud Functions no están
        _initialized = false;
        throw Exception('Cloud Functions no disponibles. Despliega functions con: firebase deploy --only functions');
      }

      _initialized = true;
      debugPrint('💳 PaymentService: Inicializado correctamente - ${isProduction ? "PRODUCCIÓN" : "TEST"}');

      await _firebaseService.analytics.logEvent(
        name: 'payment_service_initialized',
        parameters: {
          'environment': isProduction ? 'production' : 'test'
        },
      );

    } catch (e) {
      debugPrint('💳 PaymentService: Error inicializando - $e');
      await _firebaseService.crashlytics.recordError(e, null);
      rethrow; // Re-lanzar el error para que la app sepa que falló
    }
  }

  // ============================================================================
  // MERCADOPAGO - PREFERENCIAS DE PAGO
  // ============================================================================

  /// Crear preferencia de pago con MercadoPago
  Future<PaymentPreferenceResult> createMercadoPagoPreference({
    required String rideId,
    required double amount,
    required String payerEmail,
    required String payerName,
    String? description,
  }) async {
    try {
      debugPrint('💳 PaymentService: Creando preferencia MercadoPago - S/. amount');

      // Get real Firebase user ID for balance crediting
      final firebaseUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

      final response = await http.post(
        Uri.parse('$_apiBaseUrl/createRechargePreference'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'userId': firebaseUserId, // Real Firebase Auth UID
          'rechargeId': rideId, // Transaction tracking ID (RECARGA_...)
          'amount': amount,
          'email': payerEmail,
          'firstName': payerName.split(' ').first,
          'lastName': payerName.split(' ').length > 1 ? payerName.split(' ').last : '',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success']) {
          final resultData = data['data'];
          
          await _firebaseService.analytics.logEvent(
            name: 'mercadopago_preference_created',
            parameters: {
              'ride_id': rideId,
              'amount': amount,
              'preference_id': resultData['preferenceId'],
            },
          );

          return PaymentPreferenceResult.success(
            preferenceId: resultData['preferenceId'],
            initPoint: resultData['initPoint'],
            publicKey: resultData['publicKey'],
            amount: amount,
            platformCommission: resultData['platformCommission'],
            driverEarnings: resultData['driverEarnings'],
          );
        } else {
          return PaymentPreferenceResult.error(data['message'] ?? 'Error creando preferencia');
        }
      } else {
        return PaymentPreferenceResult.error('Error de conectividad: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('💳 PaymentService: Error creando preferencia MercadoPago - $e');
      await _firebaseService.crashlytics.recordError(e, null);
      return PaymentPreferenceResult.error('Error creando preferencia: $e');
    }
  }

  /// Abrir checkout de MercadoPago (DEPRECADO - usar Checkout Bricks in-app)
  Future<bool> openMercadoPagoCheckout(String initPoint) async {
    try {
      final uri = Uri.parse(initPoint);
      if (await canLaunchUrl(uri)) {
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

        await _firebaseService.analytics.logEvent(
          name: 'mercadopago_checkout_opened',
          parameters: {
            'init_point': initPoint,
            'success': launched,
          },
        );

        return launched;
      } else {
        return false;
      }
    } catch (e) {
      debugPrint('💳 PaymentService: Error abriendo checkout MercadoPago - $e');
      return false;
    }
  }

  /// Procesar pago con MercadoPago Checkout Bricks (in-app)
  ///
  /// Este método procesa un pago usando el token generado por Checkout Bricks
  /// directamente dentro de la aplicación, sin abrir navegador externo.
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
    try {
      debugPrint('💳 PaymentService: Procesando pago Checkout Bricks - S/. $transactionAmount');

      // Build payer object with identification for anti-fraud
      final payerData = <String, dynamic>{
        'email': payerEmail,
      };
      if (payerFirstName != null && payerFirstName.isNotEmpty) {
        payerData['first_name'] = payerFirstName;
      }
      if (payerLastName != null && payerLastName.isNotEmpty) {
        payerData['last_name'] = payerLastName;
      }
      if (identificationType != null && identificationNumber != null) {
        payerData['identification'] = {
          'type': identificationType,
          'number': identificationNumber,
        };
      }

      // Llamar al backend de Firebase Functions para procesar el pago
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/processMercadoPagoBricks'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${await _getAuthToken()}',
        },
        body: jsonEncode({
          'rideId': rideId,
          'token': token,
          'payment_method_id': paymentMethodId,
          'issuer_id': issuerId,
          'installments': installments,
          'transaction_amount': transactionAmount,
          'payer': payerData,
          'description': description,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);

        // Log analytics
        await _firebaseService.analytics.logEvent(
          name: 'mercadopago_bricks_payment_processed',
          parameters: {
            'ride_id': rideId,
            'amount': transactionAmount,
            'status': data['status'],
            'payment_id': data['paymentId'],
          },
        );

        return PaymentResult(
          success: true,
          paymentId: data['paymentId']?.toString(), // Convertir int a String si es necesario
          status: data['status']?.toString(),
          message: data['message']?.toString() ?? 'Pago procesado exitosamente',
        );
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Error al procesar el pago');
      }
    } catch (e) {
      debugPrint('💳 PaymentService: Error procesando Checkout Bricks - $e');

      return PaymentResult(
        success: false,
        error: e.toString(),
        message: 'Error al procesar el pago: $e',
      );
    }
  }

  /// Obtener token de autenticación del usuario actual
  Future<String?> _getAuthToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        return await user.getIdToken();
      }
      return null;
    } catch (e) {
      debugPrint('💳 PaymentService: Error obteniendo token de auth - $e');
      return null;
    }
  }

  // ============================================================================
  // YAPE - PAGOS CON CÓDIGO QR
  // ============================================================================

  /// Procesar pago con Yape
  Future<YapePaymentResult> processWithYape({
    required String rideId,
    required double amount,
    required String phoneNumber,
    String? transactionCode,
  }) async {
    try {
      debugPrint('📱 PaymentService: Procesando pago con Yape - S/. amount');

      // Validar número de teléfono peruano
      if (!_validatePeruvianPhoneNumber(phoneNumber)) {
        return YapePaymentResult.error('Número de teléfono inválido para Yape');
      }

      final response = await http.post(
        Uri.parse('$_apiBaseUrl/payments/process-yape'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'rideId': rideId,
          'amount': amount,
          'phoneNumber': phoneNumber,
          'transactionCode': transactionCode,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success']) {
          final resultData = data['data'];
          
          await _firebaseService.analytics.logEvent(
            name: 'yape_payment_initiated',
            parameters: {
              'ride_id': rideId,
              'amount': amount,
              'payment_id': resultData['paymentId'],
            },
          );

          return YapePaymentResult.success(
            paymentId: resultData['paymentId'],
            qrUrl: resultData['yapeData']['qrUrl'],
            phoneNumber: resultData['yapeData']['phoneNumber'],
            amount: amount,
            instructions: resultData['instructions'],
            platformCommission: resultData['platformCommission'],
            driverEarnings: resultData['driverEarnings'],
          );
        } else {
          return YapePaymentResult.error(data['message'] ?? 'Error procesando pago con Yape');
        }
      } else {
        return YapePaymentResult.error('Error de conectividad: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('📱 PaymentService: Error procesando pago con Yape - $e');
      await _firebaseService.crashlytics.recordError(e, null);
      return YapePaymentResult.error('Error procesando pago con Yape: $e');
    }
  }

  /// Abrir app de Yape con código QR
  Future<bool> openYapeApp(String phoneNumber, double amount, String message) async {
    try {
      final yapeUrl = 'yape://payment?amount=$amount&phone=$phoneNumber&message=${Uri.encodeComponent(message)}';
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
      } else {
        // Fallback: abrir Play Store para descargar Yape
        final playStoreUri = Uri.parse('https://play.google.com/store/apps/details?id=com.bcp.yape');
        return await launchUrl(playStoreUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('📱 PaymentService: Error abriendo app Yape - $e');
      return false;
    }
  }

  // ============================================================================
  // PLIN - PAGOS CON CÓDIGO QR
  // ============================================================================

  /// Procesar pago con Plin
  Future<PlinPaymentResult> processWithPlin({
    required String rideId,
    required double amount,
    required String phoneNumber,
  }) async {
    try {
      debugPrint('📱 PaymentService: Procesando pago con Plin - S/. amount');

      // Validar número de teléfono peruano
      if (!_validatePeruvianPhoneNumber(phoneNumber)) {
        return PlinPaymentResult.error('Número de teléfono inválido para Plin');
      }

      final response = await http.post(
        Uri.parse('$_apiBaseUrl/payments/process-plin'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'rideId': rideId,
          'amount': amount,
          'phoneNumber': phoneNumber,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success']) {
          final resultData = data['data'];
          
          await _firebaseService.analytics.logEvent(
            name: 'plin_payment_initiated',
            parameters: {
              'ride_id': rideId,
              'amount': amount,
              'payment_id': resultData['paymentId'],
            },
          );

          return PlinPaymentResult.success(
            paymentId: resultData['paymentId'],
            qrUrl: resultData['plinData']['qrUrl'],
            phoneNumber: resultData['plinData']['phoneNumber'],
            amount: amount,
            instructions: resultData['instructions'],
            platformCommission: resultData['platformCommission'],
            driverEarnings: resultData['driverEarnings'],
          );
        } else {
          return PlinPaymentResult.error(data['message'] ?? 'Error procesando pago con Plin');
        }
      } else {
        return PlinPaymentResult.error('Error de conectividad: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('📱 PaymentService: Error procesando pago con Plin - $e');
      await _firebaseService.crashlytics.recordError(e, null);
      return PlinPaymentResult.error('Error procesando pago con Plin: $e');
    }
  }

  /// Abrir app de Plin
  Future<bool> openPlinApp(String phoneNumber, double amount, String message) async {
    try {
      final plinUrl = 'plin://payment?amount=$amount&phone=$phoneNumber&message=${Uri.encodeComponent(message)}';
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
      } else {
        // Fallback: abrir Play Store para descargar Plin
        final playStoreUri = Uri.parse('https://play.google.com/store/apps/details?id=pe.interbank.plin');
        return await launchUrl(playStoreUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('📱 PaymentService: Error abriendo app Plin - $e');
      return false;
    }
  }

  // ============================================================================
  // VERIFICACIÓN Y ESTADO DE PAGOS
  // ============================================================================

  /// Verificar estado de pago
  Future<PaymentStatusResult> checkPaymentStatus(String paymentId) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/payments/status/$paymentId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success']) {
          final paymentData = data['data'];
          
          return PaymentStatusResult.success(
            id: paymentData['id'],
            status: paymentData['status'],
            amount: (paymentData['amount'] as num?)?.toDouble() ?? 0.0,
            paymentMethod: paymentData['paymentMethod'],
            platformCommission: (paymentData['platformCommission'] as num?)?.toDouble() ?? 0.0,
            driverEarnings: (paymentData['driverEarnings'] as num?)?.toDouble() ?? 0.0,
            createdAt: DateTime.parse(paymentData['createdAt']),
            approvedAt: paymentData['approvedAt'] != null 
              ? DateTime.parse(paymentData['approvedAt']) 
              : null,
            refundedAt: paymentData['refundedAt'] != null 
              ? DateTime.parse(paymentData['refundedAt']) 
              : null,
          );
        } else {
          return PaymentStatusResult.error(data['message'] ?? 'Error obteniendo estado del pago');
        }
      } else {
        return PaymentStatusResult.error('Error de conectividad: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('💳 PaymentService: Error verificando estado - $e');
      return PaymentStatusResult.error('Error verificando estado: $e');
    }
  }

  /// Obtener historial de pagos de usuario
  Future<List<PaymentHistoryItem>> getUserPaymentHistory(String userId, String role) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/payments/history/$userId?role=$role'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success']) {
          final List<dynamic> payments = data['data'];
          
          return payments.map((payment) => PaymentHistoryItem(
            id: payment['id'],
            rideId: payment['rideId'],
            amount: (payment['amount'] as num?)?.toDouble() ?? 0.0,
            paymentMethod: payment['paymentMethod'],
            status: payment['status'],
            createdAt: DateTime.parse(payment['createdAt']),
            approvedAt: payment['approvedAt'] != null
              ? DateTime.parse(payment['approvedAt'])
              : null,
            platformCommission: (payment['platformCommission'] as num?)?.toDouble() ?? 0.0,
            driverEarnings: (payment['driverEarnings'] as num?)?.toDouble() ?? 0.0,
          )).toList();
        } else {
          return [];
        }
      } else {
        return [];
      }
    } catch (e) {
      debugPrint('💳 PaymentService: Error obteniendo historial - $e');
      return [];
    }
  }

  // ============================================================================
  // REEMBOLSOS
  // ============================================================================

  /// Procesar reembolso
  Future<RefundResult> processRefund({
    required String paymentId,
    double? amount,
    required String reason,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/payments/refund'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'paymentId': paymentId,
          if (amount != null) 'amount': amount,
          'reason': reason,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success']) {
          final resultData = data['data'];
          
          await _firebaseService.analytics.logEvent(
            name: 'refund_processed',
            parameters: {
              'payment_id': paymentId,
              'refund_amount': resultData['refundAmount'],
              'reason': reason,
            },
          );

          return RefundResult.success(
            refundAmount: (resultData['refundAmount'] as num?)?.toDouble() ?? 0.0,
            status: resultData['status'],
          );
        } else {
          return RefundResult.error(data['message'] ?? 'Error procesando reembolso');
        }
      } else {
        return RefundResult.error('Error de conectividad: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('💳 PaymentService: Error procesando reembolso - $e');
      await _firebaseService.crashlytics.recordError(e, null);
      return RefundResult.error('Error procesando reembolso: $e');
    }
  }

  // ============================================================================
  // CÁLCULOS Y UTILIDADES
  // ============================================================================

  /// Calcular tarifa del viaje
  double calculateFare({
    required double distanceKm,
    required int durationMinutes,
    required String vehicleType,
    bool applyDynamicPricing = false,
    double dynamicMultiplier = 1.0,
  }) {
    // 🇵🇪 TARIFAS COMPETITIVAS PARA LIMA, PERÚ (2024)
    // Basadas en tarifas de mercado actual (Uber, DiDi, InDrive)
    final baseFares = {
      'standard': 3.50,    // Tarifa base competitiva S/3.50
      'premium': 5.00,     // Premium (autos nuevos) S/5.00  
      'van': 7.00,         // Van familiar (6-8 personas) S/7.00
    };

    // Tarifas por kilómetro - Competitivas con el mercado
    final perKmRates = {
      'standard': 1.20,    // S/1.20/km (competitivo)
      'premium': 1.80,     // S/1.80/km (premium)
      'van': 2.50,         // S/2.50/km (van familiar)
    };

    // Tarifas por minuto - Tiempo de espera y tráfico
    final perMinuteRates = {
      'standard': 0.25,    // S/0.25/min (tráfico Lima)
      'premium': 0.40,     // S/0.40/min (premium)
      'van': 0.60,         // S/0.60/min (van familiar)
    };

    final baseFare = baseFares[vehicleType] ?? baseFares['standard']!;
    final perKm = perKmRates[vehicleType] ?? perKmRates['standard']!;
    final perMinute = perMinuteRates[vehicleType] ?? perMinuteRates['standard']!;

    double fare = baseFare + (distanceKm * perKm) + (durationMinutes * perMinute);
    
    // Aplicar pricing dinámico si está habilitado
    if (applyDynamicPricing) {
      fare *= dynamicMultiplier;
    }
    
    // Tarifa mínima competitiva S/4.50 (ajustada para Perú)
    return fare < 4.5 ? 4.5 : double.parse(fare.toStringAsFixed(2));
  }

  /// Calcular comisión de la plataforma (20%)
  double calculatePlatformCommission(double fareAmount) {
    return double.parse((fareAmount * 0.20).toStringAsFixed(2));
  }

  /// Calcular ganancias del conductor
  double calculateDriverEarnings(double fareAmount) {
    return double.parse((fareAmount * 0.80).toStringAsFixed(2));
  }

  // ============================================================================
  // MÉTODOS AUXILIARES PRIVADOS
  // ============================================================================

  /// Validar número de teléfono peruano
  bool _validatePeruvianPhoneNumber(String phoneNumber) {
    // Remover espacios y caracteres especiales
    final cleaned = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    
    // Formato peruano: 9XXXXXXXX (9 dígitos, empezando con 9)
    if (cleaned.length == 9 && cleaned.startsWith('9')) {
      return RegExp(r'^9[0-9]{8}$').hasMatch(cleaned);
    }
    
    // Formato con código país: +519XXXXXXXX
    if (cleaned.length == 12 && cleaned.startsWith('519')) {
      return RegExp(r'^519[0-9]{8}$').hasMatch(cleaned);
    }
    
    return false;
  }

  /// Obtener métodos de pago disponibles para Perú
  List<PaymentMethodInfo> getAvailablePaymentMethods() {
    return [
      // MercadoPago - Tarjetas y métodos digitales
      PaymentMethodInfo(
        id: 'mercadopago',
        name: 'MercadoPago',
        description: 'Visa, Mastercard, American Express',
        icon: '💳',
        isEnabled: true,
        requiresPhoneNumber: false,
      ),
      
      // Billeteras digitales populares en Perú
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
      
      // Métodos bancarios Perú (via MercadoPago)
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
      
      // Efectivo - siempre disponible
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
  // RETIROS - MONEY OUT API DE MERCADOPAGO
  // ============================================================================

  /// Solicitar retiro de ganancias con MercadoPago Money Out API
  ///
  /// Soporta:
  /// - Transferencias bancarias (BCP, BBVA, Interbank, Scotiabank)
  /// - Yape (instantáneo)
  /// - Plin (instantáneo)
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
      debugPrint('💸 PaymentService: Solicitando retiro - S/. amount via $method');

      // Validar parámetros según el método
      if (method == 'bank_transfer') {
        if (bankName == null || bankName.isEmpty) {
          throw Exception('Nombre del banco es requerido para transferencia bancaria');
        }
        if (accountNumber == null || accountNumber.isEmpty) {
          throw Exception('Número de cuenta es requerido para transferencia bancaria');
        }
      } else if (method == 'yape' || method == 'plin') {
        if (phoneNumber == null || phoneNumber.isEmpty) {
          throw Exception('Número de teléfono es requerido para $method');
        }
        if (!RegExp(r'^9[0-9]{8}$').hasMatch(phoneNumber)) {
          throw Exception('Número de teléfono inválido. Debe tener 9 dígitos y empezar con 9');
        }
      }

      // Validar monto mínimo
      if (amount < 50.0) {
        throw Exception('El monto mínimo de retiro es S/. 50.00');
      }

      // Preparar datos según el método
      final Map<String, dynamic> requestData = {
        'driverId': driverId,
        'amount': amount,
        'method': method,
        'accountHolderName': accountHolderName,
        'accountHolderDocumentType': accountHolderDocumentType,
        'accountHolderDocumentNumber': accountHolderDocumentNumber,
      };

      if (method == 'bank_transfer') {
        requestData['bankName'] = bankName;
        requestData['bankAccount'] = accountNumber;
      } else {
        requestData['phoneNumber'] = phoneNumber;
      }

      // Llamar a Firebase Function
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/requestWithdrawal'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestData),
      );

      debugPrint('💸 Response status: ${response.statusCode}');
      debugPrint('💸 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true) {
          debugPrint('✅ Retiro procesado exitosamente: ${data['data']['withdrawalId']}');

          await _firebaseService.analytics.logEvent(
            name: 'withdrawal_requested',
            parameters: {
              'driver_id': driverId,
              'amount': amount,
              'method': method,
              'withdrawal_id': data['data']['withdrawalId'],
            },
          );

          return WithdrawalResult(
            success: true,
            withdrawalId: data['data']['withdrawalId'],
            transferId: data['data']['transferId'],
            status: data['data']['status'],
            amount: amount,
          );
        } else {
          throw Exception(data['error'] ?? 'Error desconocido al procesar retiro');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Error del servidor: ${response.statusCode}');
      }

    } catch (e) {
      debugPrint('❌ PaymentService: Error en requestWithdrawal - $e');

      await _firebaseService.crashlytics.recordError(e, StackTrace.current);

      return WithdrawalResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  // Getters con validación
  bool get isInitialized => _initialized;

  String get mercadoPagoPublicKey {
    if (!_initialized || _mercadoPagoPublicKey.isEmpty) {
      throw StateError('PaymentService no inicializado. Llama a initialize() primero.');
    }
    return _mercadoPagoPublicKey;
  }

  String get apiBaseUrl {
    if (!_initialized || _apiBaseUrl.isEmpty) {
      throw StateError('PaymentService no inicializado. Llama a initialize() primero.');
    }
    return _apiBaseUrl;
  }
}

// ============================================================================
// CLASES DE DATOS Y RESULTADOS
// ============================================================================

/// Resultado de creación de preferencia de MercadoPago
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
  }) : success = true, error = null;

  PaymentPreferenceResult.error(this.error)
      : success = false,
        preferenceId = null,
        initPoint = null,
        publicKey = null,
        amount = null,
        platformCommission = null,
        driverEarnings = null;
}

/// Resultado de procesamiento de pago (genérico)
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

/// Resultado de pago con Yape
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
  }) : success = true, error = null;

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

/// Resultado de pago con Plin
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
  }) : success = true, error = null;

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

/// Resultado de verificación de estado de pago
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
  }) : success = true, error = null;

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

/// Item del historial de pagos
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

/// Resultado de reembolso
class RefundResult {
  final bool success;
  final double? refundAmount;
  final String? status;
  final String? error;

  RefundResult.success({
    required this.refundAmount,
    required this.status,
  }) : success = true, error = null;

  RefundResult.error(this.error)
      : success = false,
        refundAmount = null,
        status = null;
}

/// Información de método de pago
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

/// Resultado de solicitud de retiro
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

/// Estados de pago
enum PaymentStatus {
  pending,
  processing,
  approved,
  rejected,
  refunded,
  cancelled,
}

/// Métodos de pago disponibles
enum PaymentMethod {
  mercadopago,
  yape,
  plin,
  cash,
}