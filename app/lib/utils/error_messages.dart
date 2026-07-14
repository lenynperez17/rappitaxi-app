/// Utility para transformar excepciones crudas en mensajes user-friendly.
///
/// Antes de este helper, muchos SnackBars mostraban `Exception: TimeoutException
/// after 30s` o `PlatformException(sign_in_failed, ...)` — user-hostile.
///
/// Uso:
///   ScaffoldMessenger.of(context).showSnackBar(SnackBar(
///     content: Text(userFriendlyError(e)),
///     backgroundColor: Colors.red,
///   ));
///
/// Mapea excepciones conocidas a mensajes en español; si no hay match,
/// devuelve un mensaje genérico (no expone stack ni tipos internos).
library;

import 'dart:async';
import 'dart:io';

import '../services/rapi_api_client.dart' show RapiApiException;

String userFriendlyError(Object? error, {String? fallback}) {
  final defaultMsg = fallback ?? 'Ocurrió un error inesperado. Intenta de nuevo.';
  if (error == null) return defaultMsg;

  // RapiApiException del backend Node — tiene code + message ya humanizados
  if (error is RapiApiException) {
    // Códigos conocidos → mensajes específicos
    switch (error.code) {
      case 'insufficient_funds':
      case 'insufficient_balance':
        return 'Saldo insuficiente en tu wallet.';
      case 'fare_exceeds_cap':
        return 'El monto propuesto excede el máximo permitido.';
      case 'invalid_credentials':
        return 'Credenciales incorrectas.';
      case 'rate_limited':
      case 'ip_rate_limited':
        return 'Demasiados intentos. Espera unos minutos.';
      case 'invalid_phone':
        return 'Número de teléfono inválido.';
      case 'invalid_code':
      case 'code_incorrect':
        return 'El código ingresado es incorrecto.';
      case 'code_expired':
        return 'El código expiró. Solicita uno nuevo.';
      case 'not_found':
        return 'Recurso no encontrado.';
      case 'forbidden':
        return 'No tienes permisos para esta acción.';
      case 'driver_busy':
        return 'Ya tienes un viaje activo. Complétalo antes de aceptar otro.';
      case 'cannot_accept_own_ride':
        return 'No puedes aceptar tu propio viaje.';
      case 'ride_closed':
      case 'invalid_status':
        return 'El viaje ya no está disponible.';
      case 'already_taken':
      case 'ride_already_assigned':
        return 'Otro conductor ya tomó este viaje.';
      case 'documents_missing_or_not_approved':
        return 'Un administrador debe aprobar tus documentos primero.';
      case 'no_active_vehicle':
        return 'Registra un vehículo activo antes de continuar.';
      default:
        return error.message?.isNotEmpty == true
            ? error.message!
            : defaultMsg;
    }
  }

  // Errores de red comunes
  if (error is TimeoutException) {
    return 'La solicitud tardó demasiado. Verifica tu conexión.';
  }
  if (error is SocketException) {
    return 'Sin conexión a internet. Revisa tu red.';
  }
  if (error is HttpException) {
    return 'Error de red. Intenta de nuevo.';
  }
  if (error is FormatException) {
    return 'Respuesta inesperada del servidor. Intenta de nuevo.';
  }

  // Fallback: no exponer toString() del error crudo
  return defaultMsg;
}
