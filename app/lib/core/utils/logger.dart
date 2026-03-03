import 'package:logger/logger.dart' as log;

final _logger = log.Logger(
  printer: log.PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: true,
    dateTimeFormat: log.DateTimeFormat.onlyTimeAndSinceStart,
  ),
  level: log.Level.debug,
);

// Clase estática para logging
class Logger {
  static void debug(String message, [dynamic data]) {
    _logger.d('$message${data != null ? ' | Data: $data' : ''}');
  }
  
  static void info(String message, [dynamic data]) {
    _logger.i('$message${data != null ? ' | Data: $data' : ''}');
  }
  
  static void warning(String message, [dynamic data]) {
    _logger.w('$message${data != null ? ' | Data: $data' : ''}');
  }
  
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }
  
  static void verbose(String message, [dynamic data]) {
    _logger.t('$message${data != null ? ' | Data: $data' : ''}');
  }
  
  static void wtf(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }
  
  // Métodos específicos
  static void logEvent(String event, [Map<String, dynamic>? data]) {
    _logger.i('📊 Event: $event${data != null ? ' | Data: $data' : ''}');
  }
  
  static void logInfo(String message, [Map<String, dynamic>? data]) {
    _logger.i('ℹ️ Info: $message${data != null ? ' | Data: $data' : ''}');
  }
  
  static void logError(String message, dynamic error, [StackTrace? stackTrace]) {
    _logger.e('❌ Error: $message', error: error, stackTrace: stackTrace);
  }
  
  static void logWarning(String message, [dynamic data]) {
    _logger.w('⚠️ Warning: $message${data != null ? ' | Data: $data' : ''}');
  }
  
  static void logSuccess(String message, [dynamic data]) {
    _logger.i('✅ Success: $message${data != null ? ' | Data: $data' : ''}');
  }
  
  static void logNetwork(String method, String url, [dynamic data]) {
    _logger.d('🌐 Network: $method $url${data != null ? ' | Data: $data' : ''}');
  }
}

// Mantener compatibilidad con el logger original
final logger = _logger;