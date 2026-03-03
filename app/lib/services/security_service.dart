import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../config/oauth_config.dart';
import '../utils/logger.dart';

/// Servicio de Seguridad Enterprise para RapiTeam
/// Maneja rate limiting, bloqueo de cuentas, logs de seguridad y validaciones
class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  // Rate limiting maps
  final Map<String, List<DateTime>> _rateLimitMap = {};
  final Map<String, int> _failedAttemptsMap = {};
  final Map<String, DateTime> _lockoutMap = {};

  /// Verificar si una acción está limitada por rate limiting
  Future<bool> checkRateLimit(String action, String identifier) async {
    final key = '$action:$identifier';
    final now = DateTime.now();
    
    // Obtener límite para esta acción
    final limit = OAuthConfig.rateLimits[action] ?? 10;
    
    // Obtener intentos previos
    _rateLimitMap[key] ??= [];
    final attempts = _rateLimitMap[key]!;
    
    // Limpiar intentos antiguos (más de 1 hora)
    attempts.removeWhere((time) => now.difference(time).inHours >= 1);
    
    // Verificar si excede el límite
    if (attempts.length >= limit) {
      AppLogger.warning('Rate limit excedido', {
        'action': action,
        'identifier': identifier,
        'attempts': attempts.length,
        'limit': limit,
      });
      return false;
    }
    
    // Agregar intento actual
    attempts.add(now);
    _rateLimitMap[key] = attempts;
    
    return true;
  }

  /// Registrar intento fallido
  Future<void> recordFailedAttempt(String identifier, String attemptType) async {
    final key = '$attemptType:$identifier';
    _failedAttemptsMap[key] = (_failedAttemptsMap[key] ?? 0) + 1;
    
    final attempts = _failedAttemptsMap[key]!;
    
    // Log de seguridad
    await logSecurityEvent('FAILED_ATTEMPT', {
      'identifier': _hashIdentifier(identifier),
      'attempt_type': attemptType,
      'attempts': attempts,
    });
    
    // Bloquear después de muchos intentos
    if (attempts >= OAuthConfig.maxLoginAttempts) {
      await lockAccount(identifier, attemptType);
    }
    
    // Guardar en preferencias locales
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('failed_attempts_$key', attempts);
    await prefs.setString('last_failed_attempt_$key', DateTime.now().toIso8601String());
  }

  /// Bloquear cuenta temporalmente
  Future<void> lockAccount(String identifier, String reason) async {
    final key = '$reason:$identifier';
    final lockoutUntil = DateTime.now().add(
      Duration(minutes: OAuthConfig.lockoutDurationMinutes),
    );
    
    _lockoutMap[key] = lockoutUntil;
    
    // Guardar en preferencias
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lockout_$key', lockoutUntil.toIso8601String());
    
    // Log de seguridad crítico
    await logSecurityEvent('ACCOUNT_LOCKED', {
      'identifier': _hashIdentifier(identifier),
      'reason': reason,
      'locked_until': lockoutUntil.toIso8601String(),
    });
    
    AppLogger.warning('Cuenta bloqueada', {
      'identifier': identifier,
      'reason': reason,
      'duration_minutes': OAuthConfig.lockoutDurationMinutes,
    });
  }

  /// Verificar si una cuenta está bloqueada
  Future<bool> isAccountLocked(String identifier, String context) async {
    final key = '$context:$identifier';
    
    // Verificar en memoria
    if (_lockoutMap.containsKey(key)) {
      final lockoutUntil = _lockoutMap[key]!;
      if (DateTime.now().isBefore(lockoutUntil)) {
        return true;
      } else {
        // Limpiar bloqueo expirado
        _lockoutMap.remove(key);
        _failedAttemptsMap.remove(key);
      }
    }
    
    // Verificar en preferencias
    final prefs = await SharedPreferences.getInstance();
    final lockoutStr = prefs.getString('lockout_$key');
    
    if (lockoutStr != null) {
      final lockoutUntil = DateTime.parse(lockoutStr);
      if (DateTime.now().isBefore(lockoutUntil)) {
        _lockoutMap[key] = lockoutUntil;
        return true;
      } else {
        // Limpiar bloqueo expirado
        await prefs.remove('lockout_$key');
        await prefs.remove('failed_attempts_$key');
      }
    }
    
    return false;
  }

  /// Limpiar intentos fallidos después de login exitoso
  Future<void> clearFailedAttempts(String identifier, String context) async {
    final key = '$context:$identifier';
    
    _failedAttemptsMap.remove(key);
    _lockoutMap.remove(key);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('failed_attempts_$key');
    await prefs.remove('lockout_$key');
    await prefs.remove('last_failed_attempt_$key');
  }

  /// Validar fortaleza de contraseña
  bool validatePasswordStrength(String password) {
    if (password.length < OAuthConfig.minPasswordLength) return false;
    if (password.length > OAuthConfig.maxPasswordLength) return false;
    
    bool hasUppercase = false;
    bool hasLowercase = false;
    bool hasNumber = false;
    bool hasSpecialChar = false;
    
    for (int i = 0; i < password.length; i++) {
      final char = password[i];
      if (RegExp(r'[A-Z]').hasMatch(char)) hasUppercase = true;
      if (RegExp(r'[a-z]').hasMatch(char)) hasLowercase = true;
      if (RegExp(r'[0-9]').hasMatch(char)) hasNumber = true;
      if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(char)) hasSpecialChar = true;
    }
    
    return (!OAuthConfig.requireUppercase || hasUppercase) &&
           (!OAuthConfig.requireLowercase || hasLowercase) &&
           (!OAuthConfig.requireNumbers || hasNumber) &&
           (!OAuthConfig.requireSpecialChars || hasSpecialChar);
  }

  /// Calcular score de fortaleza de contraseña (0-100)
  int getPasswordStrengthScore(String password) {
    int score = 0;
    
    // Longitud (máximo 30 puntos)
    score += (password.length / OAuthConfig.maxPasswordLength * 30).round();
    
    // Complejidad (máximo 70 puntos)
    if (RegExp(r'[a-z]').hasMatch(password)) score += 10;
    if (RegExp(r'[A-Z]').hasMatch(password)) score += 10;
    if (RegExp(r'[0-9]').hasMatch(password)) score += 10;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) score += 20;
    if (password.length >= 12) score += 10;
    if (password.length >= 16) score += 10;
    
    // Penalización por patrones comunes
    if (RegExp(r'(.)\1{2,}').hasMatch(password)) score -= 10; // Caracteres repetidos
    if (RegExp(r'(012|123|234|345|456|567|678|789|890)').hasMatch(password)) score -= 10; // Secuencias
    if (RegExp(r'(abc|bcd|cde|def|efg|fgh|ghi|hij|ijk|jkl|klm|lmn|mno|nop|opq|pqr|qrs|rst|stu|tuv|uvw|vwx|wxy|xyz)', caseSensitive: false).hasMatch(password)) score -= 10;
    
    // Palabras comunes
    final commonPasswords = ['password', 'admin', 'rapiteam', 'taxi', '12345', 'qwerty'];
    for (final common in commonPasswords) {
      if (password.toLowerCase().contains(common)) {
        score -= 20;
        break;
      }
    }
    
    return score.clamp(0, 100);
  }

  /// Validar email contra dominios bloqueados
  bool validateEmailDomain(String email) {
    final domain = email.split('@').last.toLowerCase();
    return !OAuthConfig.blockedEmailDomains.contains(domain);
  }

  /// Registrar evento de seguridad en Firestore
  Future<void> logSecurityEvent(String eventType, Map<String, dynamic> data) async {
    try {
      await FirebaseFirestore.instance.collection('security_logs').add({
        'event_type': eventType,
        'timestamp': FieldValue.serverTimestamp(),
        'data': data,
        'ip_address': await _getIpAddress(),
        'user_agent': await _getUserAgent(),
        'device_id': await _getDeviceId(),
      });
      
      // Para eventos críticos, también notificar
      if (_isCriticalEvent(eventType)) {
        await _notifySecurityTeam(eventType, data);
      }
    } catch (e) {
      AppLogger.error('Error al registrar evento de seguridad', e);
    }
  }

  /// Verificar si la sesión ha expirado
  Future<bool> isSessionExpired() async {
    final prefs = await SharedPreferences.getInstance();
    final lastActivityStr = prefs.getString('last_activity');
    
    if (lastActivityStr == null) return true;
    
    final lastActivity = DateTime.parse(lastActivityStr);
    final now = DateTime.now();
    
    return now.difference(lastActivity).inMinutes > OAuthConfig.sessionTimeoutMinutes;
  }

  /// Actualizar última actividad
  Future<void> updateLastActivity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_activity', DateTime.now().toIso8601String());
  }

  /// Verificar integridad de datos
  Future<bool> verifyDataIntegrity(Map<String, dynamic> data, String expectedHash) async {
    final jsonStr = jsonEncode(data);
    final bytes = utf8.encode(jsonStr);
    final digest = sha256.convert(bytes);
    final calculatedHash = digest.toString();
    
    return calculatedHash == expectedHash;
  }

  /// Generar token seguro
  String generateSecureToken([int length = 32]) {
    final random = List<int>.generate(length, (i) => 
      DateTime.now().millisecondsSinceEpoch + i
    );
    final bytes = utf8.encode(random.join());
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Hash de identificador para privacidad
  String _hashIdentifier(String identifier) {
    final bytes = utf8.encode(identifier);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 8); // Solo primeros 8 caracteres
  }

  /// Obtener IP del dispositivo (simulado por privacidad)
  Future<String> _getIpAddress() async {
    // En producción, obtener IP real del dispositivo
    return 'XXX.XXX.XXX.XXX'; // Anonimizado por privacidad
  }

  /// Obtener User Agent
  Future<String> _getUserAgent() async {
    // En producción, obtener User Agent real
    return 'RapiTeam Mobile App';
  }

  /// Obtener ID del dispositivo
  Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('device_id');
    
    if (deviceId == null) {
      deviceId = generateSecureToken();
      await prefs.setString('device_id', deviceId);
    }
    
    return deviceId;
  }

  /// Verificar si es un evento crítico
  bool _isCriticalEvent(String eventType) {
    const criticalEvents = [
      'ACCOUNT_LOCKED',
      'SUSPICIOUS_ACTIVITY',
      'DATA_BREACH_ATTEMPT',
      'MULTIPLE_FAILED_LOGINS',
      'UNAUTHORIZED_ACCESS',
    ];
    
    return criticalEvents.contains(eventType);
  }

  /// Notificar al equipo de seguridad
  Future<void> _notifySecurityTeam(String eventType, Map<String, dynamic> data) async {
    // En producción, enviar notificación por email/SMS al equipo de seguridad
    AppLogger.critical('ALERTA DE SEGURIDAD', {
      'event_type': eventType,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Limpiar todos los datos de seguridad (logout)
  Future<void> clearAllSecurityData() async {
    _rateLimitMap.clear();
    _failedAttemptsMap.clear();
    _lockoutMap.clear();
    
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => 
      key.startsWith('failed_attempts_') || 
      key.startsWith('lockout_') || 
      key.startsWith('last_failed_attempt_')
    );
    
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}