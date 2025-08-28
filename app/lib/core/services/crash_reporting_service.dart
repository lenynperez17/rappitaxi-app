import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/logger.dart';

final crashReportingServiceProvider = Provider<CrashReportingService>((ref) {
  return CrashReportingService();
});

class CrashReportingService {
  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;
  
  Future<void> initialize() async {
    try {
      // Habilitar crash reporting solo en release
      await _crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
      
      // Capturar errores de Flutter
      FlutterError.onError = (errorDetails) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
      };
      
      // Capturar errores asíncronos
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
      
      Logger.info('Crash reporting initialized');
    } catch (e) {
      Logger.error('Error initializing crash reporting', e);
    }
  }
  
  Future<void> setUserId(String userId) async {
    try {
      await _crashlytics.setUserIdentifier(userId);
      Logger.info('Crash reporting user ID set');
    } catch (e) {
      Logger.error('Error setting crash reporting user ID', e);
    }
  }
  
  Future<void> clearUserId() async {
    try {
      await _crashlytics.setUserIdentifier('');
      Logger.info('Crash reporting user ID cleared');
    } catch (e) {
      Logger.error('Error clearing crash reporting user ID', e);
    }
  }
  
  Future<void> setCustomKey(String key, dynamic value) async {
    try {
      await _crashlytics.setCustomKey(key, value);
      Logger.info('Custom key set: $key');
    } catch (e) {
      Logger.error('Error setting custom key', e);
    }
  }
  
  Future<void> log(String message) async {
    try {
      await _crashlytics.log(message);
    } catch (e) {
      Logger.error('Error logging to crashlytics', e);
    }
  }
  
  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) async {
    try {
      await _crashlytics.recordError(
        exception,
        stack,
        reason: reason,
        fatal: fatal,
      );
      
      if (fatal) {
        Logger.error('Fatal error recorded', exception, stack);
      } else {
        Logger.warning('Non-fatal error recorded: ${exception.toString()}');
      }
    } catch (e) {
      Logger.error('Error recording to crashlytics', e);
    }
  }
  
  // Helper para registrar errores de navegación
  Future<void> recordNavigationError({
    required String screen,
    required String action,
    required dynamic error,
    StackTrace? stack,
  }) async {
    await setCustomKey('last_screen', screen);
    await setCustomKey('last_action', action);
    await recordError(
      error,
      stack,
      reason: 'Navigation error: $screen - $action',
    );
  }
  
  // Helper para registrar errores de API
  Future<void> recordApiError({
    required String endpoint,
    required int? statusCode,
    required dynamic error,
    StackTrace? stack,
  }) async {
    await setCustomKey('api_endpoint', endpoint);
    if (statusCode != null) {
      await setCustomKey('api_status_code', statusCode);
    }
    await recordError(
      error,
      stack,
      reason: 'API error: $endpoint - Status: $statusCode',
    );
  }
  
  // Helper para registrar errores de pagos
  Future<void> recordPaymentError({
    required String method,
    required double amount,
    required dynamic error,
    StackTrace? stack,
  }) async {
    await setCustomKey('payment_method', method);
    await setCustomKey('payment_amount', amount);
    await recordError(
      error,
      stack,
      reason: 'Payment error: $method - Amount: $amount',
      fatal: true, // Los errores de pago son críticos
    );
  }
}