import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../config/app_config.dart';
import 'auth_interceptor.dart';
import 'error_interceptor.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(milliseconds: AppConfig.connectionTimeout),
      receiveTimeout: const Duration(milliseconds: AppConfig.receiveTimeout),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );
  
  // Interceptors
  dio.interceptors.addAll([
    AuthInterceptor(),
    ErrorInterceptor(),
    if (AppConfig.isDevelopment)
      PrettyDioLogger(
        requestHeader: true,
        requestBody: true,
        responseBody: true,
        responseHeader: false,
        error: true,
        compact: true,
      ),
  ]);
  
  return dio;
});

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(ref.watch(dioProvider));
});

class ApiService {
  final Dio _dio;
  
  ApiService(this._dio);
  
  // Generic GET request
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic)? parser,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
      );
      
      if (parser != null) {
        return parser(response.data);
      }
      
      return response.data as T;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
  
  // Generic POST request
  Future<T> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic)? parser,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      
      if (parser != null) {
        return parser(response.data);
      }
      
      return response.data as T;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
  
  // Generic PUT request
  Future<T> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic)? parser,
  }) async {
    try {
      final response = await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      
      if (parser != null) {
        return parser(response.data);
      }
      
      return response.data as T;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
  
  // Generic DELETE request
  Future<T> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic)? parser,
  }) async {
    try {
      final response = await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      
      if (parser != null) {
        return parser(response.data);
      }
      
      return response.data as T;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
  
  // File upload
  Future<T> upload<T>(
    String path, {
    required FormData formData,
    Map<String, dynamic>? queryParameters,
    Options? options,
    void Function(int, int)? onSendProgress,
    T Function(dynamic)? parser,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: formData,
        queryParameters: queryParameters,
        options: options,
        onSendProgress: onSendProgress,
      );
      
      if (parser != null) {
        return parser(response.data);
      }
      
      return response.data as T;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
  
  // Error handling
  Exception _handleError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return TimeoutException('La conexión tardó demasiado');
        
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode ?? 0;
        final message = error.response?.data['message'] ?? 'Error del servidor';
        
        if (statusCode == 401) {
          return UnauthorizedException(message);
        } else if (statusCode == 403) {
          return ForbiddenException(message);
        } else if (statusCode == 404) {
          return NotFoundException(message);
        } else if (statusCode >= 400 && statusCode < 500) {
          return BadRequestException(message);
        } else {
          return ServerException(message);
        }
        
      case DioExceptionType.cancel:
        return CancelledException('Solicitud cancelada');
        
      case DioExceptionType.unknown:
        if (error.error.toString().contains('SocketException')) {
          return NetworkException('Sin conexión a internet');
        }
        return UnknownException('Error desconocido');
        
      default:
        return UnknownException('Error desconocido');
    }
  }
}

// Custom exceptions
class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
  
  @override
  String toString() => message;
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  
  @override
  String toString() => message;
}

class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException(this.message);
  
  @override
  String toString() => message;
}

class ForbiddenException implements Exception {
  final String message;
  ForbiddenException(this.message);
  
  @override
  String toString() => message;
}

class NotFoundException implements Exception {
  final String message;
  NotFoundException(this.message);
  
  @override
  String toString() => message;
}

class BadRequestException implements Exception {
  final String message;
  BadRequestException(this.message);
  
  @override
  String toString() => message;
}

class ServerException implements Exception {
  final String message;
  ServerException(this.message);
  
  @override
  String toString() => message;
}

class CancelledException implements Exception {
  final String message;
  CancelledException(this.message);
  
  @override
  String toString() => message;
}

class UnknownException implements Exception {
  final String message;
  UnknownException(this.message);
  
  @override
  String toString() => message;
}