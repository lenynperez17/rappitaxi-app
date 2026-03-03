/// Helper para manejo de errores de Firestore y Firebase Storage
/// Convierte errores técnicos a mensajes amigables en español
class FirestoreErrorHandler {
  /// Convierte un error de Firebase a un mensaje amigable en español
  static String getSpanishMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    // Errores de permisos
    if (errorStr.contains('permission-denied') || errorStr.contains('permission_denied')) {
      return 'No tienes permisos para realizar esta acción. Por favor, inicia sesión nuevamente.';
    }

    // Documento no encontrado
    if (errorStr.contains('not-found') || errorStr.contains('not_found')) {
      return 'El recurso solicitado no existe.';
    }

    // Documento ya existe
    if (errorStr.contains('already-exists') || errorStr.contains('already_exists')) {
      return 'Este registro ya existe.';
    }

    // Límite de solicitudes
    if (errorStr.contains('resource-exhausted') || errorStr.contains('resource_exhausted')) {
      return 'Demasiadas solicitudes. Intenta de nuevo en unos minutos.';
    }

    // Servicio no disponible
    if (errorStr.contains('unavailable')) {
      return 'Servicio no disponible. Verifica tu conexión a internet.';
    }

    // Timeout
    if (errorStr.contains('deadline-exceeded') || errorStr.contains('deadline_exceeded') || errorStr.contains('timeout')) {
      return 'La operación tardó demasiado. Verifica tu conexión e intenta nuevamente.';
    }

    // Usuario no autenticado
    if (errorStr.contains('unauthenticated')) {
      return 'Tu sesión ha expirado. Por favor, inicia sesión nuevamente.';
    }

    // Argumento inválido
    if (errorStr.contains('invalid-argument') || errorStr.contains('invalid_argument')) {
      return 'Datos inválidos. Por favor, verifica la información ingresada.';
    }

    // Operación cancelada
    if (errorStr.contains('cancelled') || errorStr.contains('canceled')) {
      return 'La operación fue cancelada.';
    }

    // Sin conexión
    if (errorStr.contains('network') || errorStr.contains('connection') || errorStr.contains('internet')) {
      return 'Error de conexión. Verifica tu conexión a internet.';
    }

    // Error de Storage - archivo muy grande
    if (errorStr.contains('object-too-large') || errorStr.contains('payload-too-large')) {
      return 'El archivo es demasiado grande. El tamaño máximo permitido es 10MB.';
    }

    // Error de Storage - tipo no permitido
    if (errorStr.contains('invalid-content-type') || errorStr.contains('unsupported')) {
      return 'Tipo de archivo no permitido. Usa formatos JPG, PNG o PDF.';
    }

    // Error de autenticación de email
    if (errorStr.contains('email-already-in-use')) {
      return 'Este correo electrónico ya está registrado.';
    }

    // Error de contraseña débil
    if (errorStr.contains('weak-password')) {
      return 'La contraseña es muy débil. Usa al menos 8 caracteres con mayúsculas, minúsculas y números.';
    }

    // Email inválido
    if (errorStr.contains('invalid-email')) {
      return 'El correo electrónico no es válido.';
    }

    // Usuario no encontrado
    if (errorStr.contains('user-not-found')) {
      return 'No existe una cuenta con este correo electrónico.';
    }

    // Contraseña incorrecta
    if (errorStr.contains('wrong-password')) {
      return 'La contraseña es incorrecta.';
    }

    // Demasiados intentos
    if (errorStr.contains('too-many-requests')) {
      return 'Demasiados intentos fallidos. Intenta de nuevo más tarde.';
    }

    // Error genérico
    return 'Ocurrió un error inesperado. Por favor, intenta nuevamente.';
  }

  /// Verifica si el error es de tipo permission-denied
  static bool isPermissionDenied(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('permission-denied') || errorStr.contains('permission_denied');
  }

  /// Verifica si el error es de conexión/red
  static bool isNetworkError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('network') ||
        errorStr.contains('connection') ||
        errorStr.contains('internet') ||
        errorStr.contains('unavailable') ||
        errorStr.contains('timeout');
  }

  /// Verifica si el error es de autenticación
  static bool isAuthError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('unauthenticated') ||
        errorStr.contains('permission-denied') ||
        errorStr.contains('user-not-found') ||
        errorStr.contains('wrong-password');
  }

  /// Verifica si se debe reintentar la operación
  static bool shouldRetry(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('unavailable') ||
        errorStr.contains('deadline-exceeded') ||
        errorStr.contains('resource-exhausted');
  }
}
