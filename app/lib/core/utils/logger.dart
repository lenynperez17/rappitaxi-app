import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:logger/logger.dart' as log;

// Ronda 102: en release solo warning+ para NO filtrar URLs/tokens/bodies a
// stdout/logcat en producción + evitar serialización de mapas grandes en cada
// llamada. Debug ilimitado solo en debug builds.
final _logger = log.Logger(
  printer: log.PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: true,
    dateTimeFormat: log.DateTimeFormat.onlyTimeAndSinceStart,
  ),
  level: kReleaseMode ? log.Level.warning : log.Level.debug,
);

// Clase estática para logging
class Logger {
  // Ronda 102: early-return en release para evitar construir el string
  // (interpolación eager + toString de mapas grandes) en cada llamada.
  static void debug(String message, [dynamic data]) {
    if (kReleaseMode) return;
    _logger.d('$message${data != null ? ' | Data: $data' : ''}');
  }

  static void info(String message, [dynamic data]) {
    if (kReleaseMode) return;
    _logger.i('$message${data != null ? ' | Data: $data' : ''}');
  }

  static void warning(String message, [dynamic data]) {
    _logger.w('$message${data != null ? ' | Data: $data' : ''}');
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  static void verbose(String message, [dynamic data]) {
    if (kReleaseMode) return;
    _logger.t('$message${data != null ? ' | Data: $data' : ''}');
  }

  static void wtf(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }

  // Métodos específicos
  static void logEvent(String event, [Map<String, dynamic>? data]) {
    if (kReleaseMode) return;
    _logger.i('📊 Event: $event${data != null ? ' | Data: $data' : ''}');
  }

  static void logInfo(String message, [Map<String, dynamic>? data]) {
    if (kReleaseMode) return;
    _logger.i('ℹ️ Info: $message${data != null ? ' | Data: $data' : ''}');
  }

  static void logError(String message, dynamic error, [StackTrace? stackTrace]) {
    _logger.e('❌ Error: $message', error: error, stackTrace: stackTrace);
  }

  static void logWarning(String message, [dynamic data]) {
    _logger.w('⚠️ Warning: $message${data != null ? ' | Data: $data' : ''}');
  }

  static void logSuccess(String message, [dynamic data]) {
    if (kReleaseMode) return;
    _logger.i('✅ Success: $message${data != null ? ' | Data: $data' : ''}');
  }

  // Ronda 102: logNetwork silenciado en release (URLs+bodies eran leak de PII).
  static void logNetwork(String method, String url, [dynamic data]) {
    if (kReleaseMode) return;
    _logger.d('🌐 Network: $method $url${data != null ? ' | Data: $data' : ''}');
  }
}

// Mantener compatibilidad con el logger original
final logger = _logger;