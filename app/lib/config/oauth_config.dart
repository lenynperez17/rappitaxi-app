// Configuracion de OAuth Providers para Autenticacion
//
// IMPORTANTE: Para que la autenticacion funcione correctamente, debes:
//
// 1. GOOGLE SIGN IN:
//    - Ir a Firebase Console > Authentication > Sign-in method
//    - Habilitar Google como proveedor
//    - Configurar SHA-1 y SHA-256 en Firebase Console
//    - Agregar com.rapiteam.app al proyecto de Google Cloud Console
//    - Descargar google-services.json actualizado
//
// 2. PHONE AUTH:
//    - Habilitar Phone Authentication en Firebase Console
//    - Para Android: configurar SHA-1 y SHA-256
//    - Para iOS: configurar APNs Authentication Key
//    - Verificar que el proyecto tenga habilitado Phone Auth en Firebase Console

class OAuthConfig {
  // ==================== CONFIGURACIÓN OAUTH REAL - FIREBASE ====================
  // ✅ CONFIGURACIÓN REAL extraída de google-services.json
  // NOTA: Estos valores están en git, NO son secretos (son Client IDs públicos)
  // Los secretos reales están en Firebase Console backend

  // Google Sign In - ✅ CONFIGURADO DESDE FIREBASE (proyecto rapi-team)
  // Web Client ID extraído de google-services.json (client_type: 3)
  static const String googleWebClientId = '52925359166-ksndlq97t4lbi0dd1bmeu67697eou1dg.apps.googleusercontent.com';

  // Android Client ID extraído de google-services.json (client_type: 1)
  // ✅ ACTUALIZADO: Client ID con SHA-1 del keystore de release
  static const String googleAndroidClientId = '52925359166-bcq342paiellpmm8abis65nhap1qf42v.apps.googleusercontent.com';

  // iOS Client ID - Extraído de GoogleService-Info.plist (REVERSED_CLIENT_ID)
  static const String googleIosClientId = '52925359166-tlfbqf1hoi62o07ghu52v3giidgvr2e8.apps.googleusercontent.com';

  // Verificar si las credenciales OAuth estan configuradas
  static bool get isGoogleConfigured =>
    googleWebClientId.isNotEmpty &&
    !googleWebClientId.contains('YOUR_GOOGLE');
  
  // Configuración de seguridad
  // ✅ AJUSTADO: Más intentos y bloqueo más corto para mejor UX
  static const int maxLoginAttempts = 10;
  static const int lockoutDurationMinutes = 5;
  static const int otpTimeoutSeconds = 60;
  static const int sessionTimeoutMinutes = 60;
  
  // Validación de contraseñas
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 128;
  static const bool requireUppercase = true;
  static const bool requireLowercase = true;
  static const bool requireNumbers = true;
  static const bool requireSpecialChars = true;
  
  // Dominios de email bloqueados (temporales)
  static const List<String> blockedEmailDomains = [
    'tempmail.com',
    'guerrillamail.com',
    '10minutemail.com',
    'mailinator.com',
    'throwaway.email',
    'yopmail.com',
    'trashmail.com',
    'fakeinbox.com',
    'maildrop.cc',
    'getairmail.com',
  ];
  
  // Configuración de Rate Limiting
  static const Map<String, int> rateLimits = {
    'login_attempts_per_hour': 10,
    'password_reset_per_day': 5,
    'otp_requests_per_hour': 5,
    'api_calls_per_minute': 60,
  };
  
  // Configuración de sesión
  static const bool enableBiometricAuth = true;
  static const bool enableRememberMe = true;
  static const bool enableTwoFactorAuth = true;
  static const bool forceEmailVerification = true;
  static const bool forcePhoneVerification = false;
  
  // URLs de términos y políticas
  static const String termsOfServiceUrl = 'https://darkorchid-crane-575563.hostingersite.com/terminos/';
  static const String privacyPolicyUrl = 'https://darkorchid-crane-575563.hostingersite.com/privacidad/';
  static const String deleteAccountUrl = 'https://darkorchid-crane-575563.hostingersite.com/eliminar-cuenta/';
  static const String cookiesPolicyUrl = 'https://darkorchid-crane-575563.hostingersite.com/cookies/';
  static const String websiteUrl = 'https://darkorchid-crane-575563.hostingersite.com/';
  static const String supportEmail = 'soporte@rapiteam.app';
  static const String supportPhone = '+51 901 039 918';
}

/// Mensajes de error personalizados en español
class AuthErrorMessages {
  static const Map<String, String> messages = {
    // Errores de Firebase Auth
    'user-not-found': 'No existe una cuenta con este email. Por favor regístrate primero.',
    'wrong-password': 'Contraseña incorrecta. Verifica e intenta nuevamente.',
    'email-already-in-use': 'Este email ya está registrado. ¿Olvidaste tu contraseña?',
    'invalid-email': 'El formato del email no es válido.',
    'weak-password': 'La contraseña es muy débil. Usa al menos 8 caracteres con mayúsculas, minúsculas, números y símbolos.',
    'network-request-failed': 'Error de conexión. Verifica tu internet e intenta de nuevo.',
    'too-many-requests': 'Demasiados intentos. Por favor espera unos minutos antes de intentar de nuevo.',
    'user-disabled': 'Esta cuenta ha sido deshabilitada. Contacta a soporte para más información.',
    'operation-not-allowed': 'Esta operación no está permitida. Contacta a soporte.',
    'invalid-verification-code': 'El código de verificación es inválido.',
    'invalid-verification-id': 'El ID de verificación es inválido.',
    'invalid-phone-number': 'El número de teléfono no es válido.',
    'missing-phone-number': 'Por favor ingresa un número de teléfono.',
    'quota-exceeded': 'Se ha excedido la cuota de verificaciones. Intenta más tarde.',
    'app-not-authorized': 'La aplicación no está autorizada para usar Firebase Authentication.',
    
    // Errores personalizados
    'account-locked': 'Tu cuenta ha sido bloqueada temporalmente por seguridad. Intenta de nuevo en 5 minutos.',
    'email-not-verified': 'Por favor verifica tu email antes de iniciar sesión. Revisa tu bandeja de entrada.',
    'phone-not-verified': 'Por favor verifica tu número de teléfono para continuar.',
    'invalid-otp': 'El código OTP es inválido o ha expirado.',
    'session-expired': 'Tu sesión ha expirado. Por favor inicia sesión nuevamente.',
    'biometric-not-available': 'La autenticación biométrica no está disponible en este dispositivo.',
    'biometric-not-enrolled': 'No hay datos biométricos registrados. Configúralos en los ajustes del dispositivo.',
    'invalid-credentials': 'Credenciales inválidas. Verifica tu información e intenta de nuevo.',
    'social-login-cancelled': 'Inicio de sesión cancelado.',
    'social-login-failed': 'Error al iniciar sesión con redes sociales. Intenta con otro método.',
    
    // Mensajes de validación
    'invalid-phone-format': 'El número debe ser peruano y empezar con 9 (9 dígitos en total).',
    'invalid-name-format': 'El nombre debe contener al menos nombre y apellido.',
    'password-mismatch': 'Las contraseñas no coinciden.',
    'terms-not-accepted': 'Debes aceptar los términos y condiciones para continuar.',
    'age-requirement': 'Debes tener al menos 18 años para registrarte.',
  };
  
  static String getMessage(String code) {
    return messages[code] ?? 'Error desconocido. Por favor contacta a soporte.';
  }
}

/// Regex patterns para validación
class ValidationPatterns {
  // Email válido
  static final RegExp emailPattern = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );
  
  // ==================== VALIDACIÓN TELEFÓNICA PERUANA ESTRICTA ====================
  // Patrón ESTRICTO para números peruanos móviles ÚNICAMENTE
  // Solo acepta números que empiecen con 9 y tengan exactamente 9 dígitos
  static final RegExp peruPhonePattern = RegExp(
    r'^9[0-9]{8}$',
  );
  
  // Patrón completo con código de país para Firebase Auth
  static final RegExp peruPhoneWithCountryCode = RegExp(
    r'^\+51\s?9[0-9]{8}$',
  );
  
  // Operadores móviles válidos en Perú (primer dígito después del 9)
  static final Set<String> validPeruMobileOperators = {
    '90', '91', '92', '93', '94', '95', '96', '97', '98', '99' // Todos los códigos válidos
  };
  
  // Validación ESTRICTA de números peruanos
  static bool isValidPeruMobile(String phone) {
    // Limpiar número (remover espacios, guiones, paréntesis)
    final cleanPhone = phone.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    
    // Verificar si empieza con código de país
    String localNumber = cleanPhone;
    if (cleanPhone.startsWith('51')) {
      localNumber = cleanPhone.substring(2);
    }
    
    // Debe tener exactamente 9 dígitos y empezar con 9
    if (!peruPhonePattern.hasMatch(localNumber)) {
      return false;
    }
    
    // Verificar que el operador móvil sea válido
    final operatorCode = localNumber.substring(0, 2);
    return validPeruMobileOperators.contains(operatorCode);
  }
  
  // Formatear número para Firebase Auth
  static String formatForFirebaseAuth(String phone) {
    final cleanPhone = phone.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    String localNumber = cleanPhone;
    
    if (cleanPhone.startsWith('51')) {
      localNumber = cleanPhone.substring(2);
    }
    
    return '+51$localNumber';
  }
  
  // Contraseña fuerte
  static final RegExp strongPasswordPattern = RegExp(
    r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$',
  );
  
  // Nombre completo (al menos 2 palabras)
  static final RegExp fullNamePattern = RegExp(
    r'^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]{2,}\s+[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]{2,}',
  );
  
  // Solo letras con acentos
  static final RegExp onlyLettersPattern = RegExp(
    r'^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$',
  );
  
  // Solo números
  static final RegExp onlyNumbersPattern = RegExp(
    r'^[0-9]+$',
  );
  
  // DNI peruano (8 dígitos)
  static final RegExp dniPattern = RegExp(
    r'^[0-9]{8}$',
  );
  
  // RUC peruano (11 dígitos)
  static final RegExp rucPattern = RegExp(
    r'^(10|20)[0-9]{9}$',
  );
  
  // Placa de vehículo peruana
  static final RegExp vehiclePlatePattern = RegExp(
    r'^[A-Z]{3}-[0-9]{3}$',
  );
}