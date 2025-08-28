// API Exceptions for OASIS TAXI
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? errorCode;
  final dynamic originalError;

  const ApiException({
    required this.message,
    this.statusCode,
    this.errorCode,
    this.originalError,
  });

  @override
  String toString() {
    return 'ApiException: $message (Code: $statusCode${errorCode != null ? ', Error: $errorCode' : ''})';
  }
}

// Network-related exceptions
class NetworkException extends ApiException {
  const NetworkException({
    required super.message,
    super.statusCode,
    super.errorCode,
    super.originalError,
  });

  @override
  String toString() => 'NetworkException: $message';
}

class TimeoutException extends ApiException {
  const TimeoutException({
    required super.message,
    super.statusCode,
    super.errorCode,
    super.originalError,
  });

  @override
  String toString() => 'TimeoutException: $message';
}

class CancelledException extends ApiException {
  const CancelledException({
    required super.message,
    super.statusCode,
    super.errorCode,
    super.originalError,
  });

  @override
  String toString() => 'CancelledException: $message';
}

// HTTP Status Code Exceptions
class ValidationException extends ApiException {
  final Map<String, List<String>>? fieldErrors;

  const ValidationException({
    required super.message,
    super.statusCode = 400,
    super.errorCode,
    super.originalError,
    this.fieldErrors,
  });

  @override
  String toString() => 'ValidationException: $message';
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException({
    required super.message,
    super.statusCode = 401,
    super.errorCode,
    super.originalError,
  });

  @override
  String toString() => 'UnauthorizedException: $message';
}

class ForbiddenException extends ApiException {
  const ForbiddenException({
    required super.message,
    super.statusCode = 403,
    super.errorCode,
    super.originalError,
  });

  @override
  String toString() => 'ForbiddenException: $message';
}

class NotFoundException extends ApiException {
  const NotFoundException({
    required super.message,
    super.statusCode = 404,
    super.errorCode,
    super.originalError,
  });

  @override
  String toString() => 'NotFoundException: $message';
}

class ConflictException extends ApiException {
  const ConflictException({
    required super.message,
    super.statusCode = 409,
    super.errorCode,
    super.originalError,
  });

  @override
  String toString() => 'ConflictException: $message';
}

class RateLimitException extends ApiException {
  const RateLimitException({
    required super.message,
    super.statusCode = 429,
    super.errorCode,
    super.originalError,
  });

  @override
  String toString() => 'RateLimitException: $message';
}

class ServerException extends ApiException {
  const ServerException({
    required super.message,
    super.statusCode = 500,
    super.errorCode,
    super.originalError,
  });

  @override
  String toString() => 'ServerException: $message';
}

class UnknownException extends ApiException {
  const UnknownException({
    required super.message,
    super.statusCode,
    super.errorCode,
    super.originalError,
  });

  @override
  String toString() => 'UnknownException: $message';
}

// Business logic exceptions
class RideException extends ApiException {
  const RideException({
    required super.message,
    super.statusCode,
    super.errorCode,
    super.originalError,
  });

  @override
  String toString() => 'RideException: $message';
}

class PaymentException extends ApiException {
  const PaymentException({
    required super.message,
    super.statusCode,
    super.errorCode,
    super.originalError,
  });

  @override
  String toString() => 'PaymentException: $message';
}

class LocationException extends ApiException {
  const LocationException({
    required super.message,
    super.statusCode,
    super.errorCode,
    super.originalError,
  });

  @override
  String toString() => 'LocationException: $message';
}

// Utility functions for exception handling
class ExceptionHandler {
  static String getLocalizedMessage(ApiException exception) {
    switch (exception.runtimeType) {
      case NetworkException:
        return 'Error de conexión. Verifica tu conexión a internet.';
      case TimeoutException:
        return 'La solicitud ha expirado. Intenta nuevamente.';
      case UnauthorizedException:
        return 'Tu sesión ha expirado. Inicia sesión nuevamente.';
      case ForbiddenException:
        return 'No tienes permisos para realizar esta acción.';
      case NotFoundException:
        return 'El recurso solicitado no fue encontrado.';
      case ValidationException:
        return 'Datos inválidos. Verifica la información ingresada.';
      case ConflictException:
        return 'Conflicto con los datos existentes.';
      case RateLimitException:
        return 'Demasiadas solicitudes. Espera un momento e intenta nuevamente.';
      case ServerException:
        return 'Error interno del servidor. Intenta más tarde.';
      case RideException:
        return 'Error en el viaje: ${exception.message}';
      case PaymentException:
        return 'Error en el pago: ${exception.message}';
      case LocationException:
        return 'Error de ubicación: ${exception.message}';
      default:
        return exception.message.isNotEmpty 
            ? exception.message 
            : 'Ha ocurrido un error inesperado.';
    }
  }

  static bool shouldRetry(ApiException exception) {
    return exception is NetworkException ||
           exception is TimeoutException ||
           exception is ServerException;
  }

  static bool shouldLogout(ApiException exception) {
    return exception is UnauthorizedException;
  }

  static Map<String, dynamic> toJson(ApiException exception) {
    return {
      'type': exception.runtimeType.toString(),
      'message': exception.message,
      'statusCode': exception.statusCode,
      'errorCode': exception.errorCode,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}