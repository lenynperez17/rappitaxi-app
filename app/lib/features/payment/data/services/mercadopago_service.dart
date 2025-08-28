import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rappitaxi_app/shared/utils/logger.dart';

final mercadoPagoServiceProvider = Provider<MercadoPagoService>((ref) {
  return MercadoPagoService();
});

class MercadoPagoService {
  late final Dio _dio;
  final String _accessToken = dotenv.env['MERCADOPAGO_ACCESS_TOKEN'] ?? '';
  final String _publicKey = dotenv.env['MERCADOPAGO_PUBLIC_KEY'] ?? '';
  static const String _baseUrl = 'https://api.mercadopago.com';
  
  MercadoPagoService() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      headers: {
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/json',
      },
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));
    
    // Interceptor para logging
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      error: true,
    ));
  }
  
  String get publicKey => _publicKey;
  
  // Crear token de tarjeta
  Future<String> createCardToken({
    required String cardNumber,
    required String cardholderName,
    required String expirationMonth,
    required String expirationYear,
    required String securityCode,
    required String identificationType,
    required String identificationNumber,
  }) async {
    try {
      final response = await _dio.post(
        '/v1/card_tokens',
        queryParameters: {
          'public_key': _publicKey,
        },
        data: {
          'card_number': cardNumber.replaceAll(' ', ''),
          'cardholder': {
            'name': cardholderName,
            'identification': {
              'type': identificationType,
              'number': identificationNumber,
            },
          },
          'expiration_month': expirationMonth,
          'expiration_year': expirationYear,
          'security_code': securityCode,
        },
      );
      
      Logger.info('Card token created');
      return response.data['id'];
    } catch (e) {
      Logger.error('Error creating card token', e);
      throw _handleMercadoPagoError(e);
    }
  }
  
  // Crear customer (cliente)
  Future<String> createCustomer({
    required String email,
    String? firstName,
    String? lastName,
    String? phone,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await _dio.post(
        '/v1/customers',
        data: {
          'email': email,
          'first_name': firstName,
          'last_name': lastName,
          'phone': phone != null ? {'area_code': '', 'number': phone} : null,
          'metadata': metadata,
        },
      );
      
      Logger.info('Customer created', {'customerId': response.data['id']});
      return response.data['id'];
    } catch (e) {
      Logger.error('Error creating customer', e);
      throw _handleMercadoPagoError(e);
    }
  }
  
  // Asociar tarjeta a customer
  Future<Map<String, dynamic>> addCardToCustomer({
    required String customerId,
    required String cardToken,
  }) async {
    try {
      final response = await _dio.post(
        '/v1/customers/$customerId/cards',
        data: {
          'token': cardToken,
        },
      );
      
      Logger.info('Card added to customer');
      return response.data;
    } catch (e) {
      Logger.error('Error adding card to customer', e);
      throw _handleMercadoPagoError(e);
    }
  }
  
  // Crear pago
  Future<Map<String, dynamic>> createPayment({
    required double amount,
    required String description,
    required String paymentMethodId,
    required String customerId,
    String? cardId,
    required String email,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await _dio.post(
        '/v1/payments',
        data: {
          'transaction_amount': amount,
          'description': description,
          'payment_method_id': paymentMethodId,
          'payer': {
            'id': customerId,
            'email': email,
          },
          'card': cardId != null ? {'id': cardId} : null,
          'metadata': metadata,
          'capture': true,
          'statement_descriptor': 'OASIS TAXI',
        },
      );
      
      Logger.info('Payment created', {'paymentId': response.data['id']});
      return response.data;
    } catch (e) {
      Logger.error('Error creating payment', e);
      throw _handleMercadoPagoError(e);
    }
  }
  
  // Obtener métodos de pago disponibles
  Future<List<Map<String, dynamic>>> getPaymentMethods() async {
    try {
      final response = await _dio.get('/v1/payment_methods');
      
      Logger.info('Payment methods retrieved');
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      Logger.error('Error getting payment methods', e);
      throw _handleMercadoPagoError(e);
    }
  }
  
  // Obtener información de un pago
  Future<Map<String, dynamic>> getPayment(String paymentId) async {
    try {
      final response = await _dio.get('/v1/payments/$paymentId');
      
      Logger.info('Payment retrieved', {'paymentId': paymentId});
      return response.data;
    } catch (e) {
      Logger.error('Error getting payment', e);
      throw _handleMercadoPagoError(e);
    }
  }
  
  // Cancelar/Reembolsar pago
  Future<Map<String, dynamic>> refundPayment({
    required String paymentId,
    double? amount,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (amount != null) {
        data['amount'] = amount;
      }
      
      final response = await _dio.post(
        '/v1/payments/$paymentId/refunds',
        data: data.isNotEmpty ? data : null,
      );
      
      Logger.info('Payment refunded', {'paymentId': paymentId});
      return response.data;
    } catch (e) {
      Logger.error('Error refunding payment', e);
      throw _handleMercadoPagoError(e);
    }
  }
  
  // Obtener tarjetas de un customer
  Future<List<Map<String, dynamic>>> getCustomerCards(String customerId) async {
    try {
      final response = await _dio.get('/v1/customers/$customerId/cards');
      
      Logger.info('Customer cards retrieved');
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      Logger.error('Error getting customer cards', e);
      throw _handleMercadoPagoError(e);
    }
  }
  
  // Eliminar tarjeta de customer
  Future<void> removeCustomerCard({
    required String customerId,
    required String cardId,
  }) async {
    try {
      await _dio.delete('/v1/customers/$customerId/cards/$cardId');
      
      Logger.info('Card removed from customer');
    } catch (e) {
      Logger.error('Error removing card', e);
      throw _handleMercadoPagoError(e);
    }
  }
  
  // Manejo de errores de MercadoPago
  Exception _handleMercadoPagoError(dynamic error) {
    if (error is DioException) {
      final response = error.response;
      
      if (response != null) {
        final message = response.data['message'] ?? 'Error de MercadoPago';
        final cause = response.data['cause'];
        
        if (cause != null && cause is List && cause.isNotEmpty) {
          final firstCause = cause[0];
          final code = firstCause['code'];
          final description = firstCause['description'];
          
          switch (code) {
            case '205':
              return Exception('Ingresa el número de tu tarjeta');
            case '208':
              return Exception('Elige un mes válido');
            case '209':
              return Exception('Elige un año válido');
            case '212':
              return Exception('Ingresa tu documento');
            case '213':
              return Exception('Ingresa tu documento');
            case '214':
              return Exception('Ingresa tu documento');
            case '220':
              return Exception('Ingresa tu banco emisor');
            case '221':
              return Exception('Ingresa el nombre y apellido');
            case '224':
              return Exception('Ingresa el código de seguridad');
            case 'E301':
              return Exception('Número de tarjeta inválido');
            case 'E302':
              return Exception('Código de seguridad inválido');
            case '316':
              return Exception('Titular de la tarjeta inválido');
            case '322':
              return Exception('Documento inválido');
            case '323':
              return Exception('Tipo de documento inválido');
            case '324':
              return Exception('Documento inválido');
            case '325':
              return Exception('Mes inválido');
            case '326':
              return Exception('Año inválido');
            default:
              return Exception(description ?? message);
          }
        }
        
        return Exception(message);
      }
      
      if (error.type == DioExceptionType.connectionTimeout) {
        return Exception('Tiempo de conexión agotado');
      }
      
      if (error.type == DioExceptionType.receiveTimeout) {
        return Exception('Tiempo de respuesta agotado');
      }
      
      if (error.type == DioExceptionType.connectionError) {
        return Exception('Error de conexión. Verifica tu internet');
      }
    }
    
    return Exception('Error al procesar el pago');
  }
}