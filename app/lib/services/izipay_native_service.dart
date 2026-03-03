import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../config/izypay_config.dart';

/// Resultado del pago nativo de Izipay
class IzipayPaymentResult {
  final bool success;
  final String code;
  final String message;
  final String? orderId;
  final String? transactionId;
  final String? cardBrand;
  final String? cardPan;
  final String? cardToken;
  final String? messageFriendly;
  final String? rawPayload;
  final int? millis;

  IzipayPaymentResult({
    required this.success,
    required this.code,
    required this.message,
    this.orderId,
    this.transactionId,
    this.cardBrand,
    this.cardPan,
    this.cardToken,
    this.messageFriendly,
    this.rawPayload,
    this.millis,
  });

  factory IzipayPaymentResult.fromJson(Map<String, dynamic> json) {
    final code = json['code'] as String? ?? '';
    final response = json['response'] as Map<String, dynamic>? ?? {};
    final card = response['card'] as Map<String, dynamic>? ?? {};
    final token = response['token'] as Map<String, dynamic>? ?? {};
    final header = json['header'] as Map<String, dynamic>? ?? {};
    final result = json['result'] as Map<String, dynamic>? ?? {};

    return IzipayPaymentResult(
      success: code == '00',
      code: code,
      message: json['message'] as String? ?? '',
      orderId: response['orderNumber'] as String?,
      transactionId: response['transactionId'] as String?,
      cardBrand: card['brand'] as String?,
      cardPan: card['pan'] as String?,
      cardToken: token['cardToken'] as String?,
      messageFriendly: result['messageFriendly'] as String?,
      rawPayload: json['payload'] as String?,
      millis: header['millis'] as int?,
    );
  }

  factory IzipayPaymentResult.error(String message) {
    return IzipayPaymentResult(
      success: false,
      code: 'ERROR',
      message: message,
    );
  }

  factory IzipayPaymentResult.cancelled() {
    return IzipayPaymentResult(
      success: false,
      code: 'CANCELLED',
      message: 'Pago cancelado por el usuario',
    );
  }
}

/// Servicio para pagos nativos con Izipay usando el SDK nativo Android/iOS
class IzipayNativeService {
  static const MethodChannel _channel = MethodChannel('com.rapiteam.app/izipay');

  /// Inicia un pago nativo con Izipay
  ///
  /// [amount] - Monto a cobrar (ej: 10.00)
  /// [email] - Email del comprador
  /// [firstName] - Nombre del comprador
  /// [lastName] - Apellido del comprador
  /// [phone] - Teléfono del comprador
  Future<IzipayPaymentResult> startPayment({
    required double amount,
    required String email,
    String firstName = 'Cliente',
    String lastName = 'RapiTeam',
    String phone = '999999999',
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return IzipayPaymentResult.error('Izipay solo está disponible en Android e iOS');
    }

    try {
      // Extraer shopId y publicKey de la config
      final publicKey = IzypayConfig.publicKey;
      // El shopId es la primera parte antes de ':'
      final shopId = publicKey.split(':').first;

      final config = {
        'environment': IzypayConfig.isProduction ? 'PROD' : 'SBOX',
        'action': 'pay',
        'clientId': publicKey,
        'merchantId': shopId,
        'order': {
          'currency': 'PEN',
          'amount': amount.toStringAsFixed(2),
          'email': email,
        },
        'billing': {
          'firstName': firstName,
          'lastName': lastName,
          'email': email,
          'phone': phone,
          'address': 'Lima',
          'city': 'Lima',
          'region': 'Lima',
          'country': 'PE',
          'postalCode': '15001',
          'idType': 'DNI',
          'idNumber': '00000000',
        },
        'shipping': {
          'firstName': firstName,
          'lastName': lastName,
          'email': email,
          'phone': phone,
          'address': 'Lima',
          'city': 'Lima',
          'region': 'Lima',
          'country': 'PE',
          'postalCode': '15001',
          'idType': 'DNI',
          'idNumber': '00000000',
        },
        'appearance': {
          'language': 'ESP',
          'themeColor': 'green',
          'primaryColor': '#6C63FF',
          'secondaryColor': '#6C63FF',
          'tertiaryColor': '#6C63FF',
          'logoUrl': '',
        },
      };

      debugPrint('Izipay: Iniciando pago nativo - S/. ${amount.toStringAsFixed(2)}');

      final response = await _channel.invokeMethod('startPayment', config);

      debugPrint('Izipay: Respuesta recibida del SDK nativo');

      if (response == null) {
        return IzipayPaymentResult.cancelled();
      }

      // Parsear respuesta JSON
      final Map<String, dynamic> jsonResponse;
      if (response is String) {
        jsonResponse = jsonDecode(response) as Map<String, dynamic>;
      } else if (response is Map) {
        jsonResponse = Map<String, dynamic>.from(response);
      } else {
        return IzipayPaymentResult.error('Respuesta inesperada del SDK');
      }

      debugPrint('Izipay: code=${jsonResponse['code']}, message=${jsonResponse['message']}');

      return IzipayPaymentResult.fromJson(jsonResponse);
    } on PlatformException catch (e) {
      debugPrint('Izipay: PlatformException - ${e.code}: ${e.message}');

      // Si el error contiene un JSON, intentar parsearlo
      if (e.message != null) {
        try {
          final errorJson = jsonDecode(e.message!) as Map<String, dynamic>;
          return IzipayPaymentResult.fromJson(errorJson);
        } catch (_) {
          // No es JSON, usar mensaje directo
        }
      }

      return IzipayPaymentResult.error(e.message ?? 'Error al procesar el pago');
    } catch (e) {
      debugPrint('Izipay: Error inesperado - $e');
      return IzipayPaymentResult.error('Error inesperado: $e');
    }
  }
}
