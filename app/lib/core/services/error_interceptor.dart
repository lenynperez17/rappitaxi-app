import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../shared/utils/logger.dart';

class ErrorInterceptor extends Interceptor {
  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) {
    // Log del error
    Logger().error(
      'API Error',
      error: err.error,
      stackTrace: err.stackTrace?.toString(),
    );
    
    // Log adicional en desarrollo
    if (kDebugMode) {
      Logger().error('API Error Details', additionalData: {
        'url': err.requestOptions.uri.toString(),
        'method': err.requestOptions.method,
        'statusCode': err.response?.statusCode,
        'errorType': err.type.toString(),
        'errorMessage': err.message,
        'responseData': err.response?.data,
      });
    }
    
    // Transformar el error para mostrar un mensaje más amigable
    String userMessage = 'Ocurrió un error inesperado';
    
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        userMessage = 'La conexión tardó demasiado. Por favor, intenta nuevamente.';
        break;
        
      case DioExceptionType.badResponse:
        final statusCode = err.response?.statusCode ?? 0;
        final serverMessage = err.response?.data?['message'];
        
        if (serverMessage != null && serverMessage is String) {
          userMessage = serverMessage;
        } else {
          if (statusCode >= 400 && statusCode < 500) {
            userMessage = 'Error en la solicitud. Por favor, verifica los datos.';
          } else if (statusCode >= 500) {
            userMessage = 'Error del servidor. Por favor, intenta más tarde.';
          }
        }
        break;
        
      case DioExceptionType.cancel:
        userMessage = 'Solicitud cancelada';
        break;
        
      case DioExceptionType.unknown:
        if (err.error.toString().contains('SocketException')) {
          userMessage = 'Sin conexión a internet. Por favor, verifica tu conexión.';
        } else {
          userMessage = 'Error de conexión. Por favor, intenta nuevamente.';
        }
        break;
        
      default:
        userMessage = 'Ocurrió un error. Por favor, intenta nuevamente.';
    }
    
    // Crear un nuevo DioException con el mensaje amigable
    final modifiedError = DioException(
      requestOptions: err.requestOptions,
      response: Response(
        requestOptions: err.requestOptions,
        data: {
          'message': userMessage,
          'originalError': err.response?.data,
        },
        statusCode: err.response?.statusCode,
      ),
      type: err.type,
      error: err.error,
      stackTrace: err.stackTrace,
    );
    
    handler.next(modifiedError);
  }
}