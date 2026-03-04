// Global Error Handler for RAPPI TEAM
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../exceptions/api_exceptions.dart';
import 'crash_reporter.dart';
import '../../utils/logger.dart';

class GlobalErrorHandler {
  static final GlobalErrorHandler _instance = GlobalErrorHandler._internal();
  factory GlobalErrorHandler() => _instance;
  GlobalErrorHandler._internal();

  final CrashReporter _crashReporter = CrashReporter();

  // Initialize error handling
  void initialize() {
    // Handle Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      handleFlutterError(details);
    };

    // Handle errors not caught by Flutter framework
    PlatformDispatcher.instance.onError = (error, stack) {
      handlePlatformError(error, stack);
      return true;
    };

    AppLogger.info('Global error handler initialized');
  }

  // Handle Flutter framework errors
  void handleFlutterError(FlutterErrorDetails details) {
    final errorReport = ErrorReport(
      type: ErrorType.flutter,
      error: details.exception.toString(),
      stackTrace: details.stack.toString(),
      context: details.context?.toString(),
      library: details.library,
      timestamp: DateTime.now(),
      isFatal: false,
    );

    _logError(errorReport);
    _reportError(errorReport); // Fire and forget

    // In debug mode, show the error
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
  }

  // Handle platform/Dart errors
  void handlePlatformError(Object error, StackTrace stackTrace) {
    final errorReport = ErrorReport(
      type: ErrorType.platform,
      error: error.toString(),
      stackTrace: stackTrace.toString(),
      timestamp: DateTime.now(),
      isFatal: true,
    );

    _logError(errorReport);
    _reportError(errorReport); // Fire and forget
  }

  // Handle API errors
  void handleApiError(ApiException exception, {
    String? context,
    Map<String, dynamic>? additionalData,
  }) {
    final errorReport = ErrorReport(
      type: ErrorType.api,
      error: exception.toString(),
      stackTrace: StackTrace.current.toString(),
      context: context,
      statusCode: exception.statusCode,
      errorCode: exception.errorCode,
      additionalData: {
        'originalError': exception.originalError?.toString(),
        ...?additionalData,
      },
      timestamp: DateTime.now(),
      isFatal: false,
    );

    _logError(errorReport);
    
    // Don't report common API errors to crash reporter
    if (!_isCommonApiError(exception)) {
      _reportError(errorReport);
    }
  }

  // Handle business logic errors
  void handleBusinessError(
    String error, {
    String? context,
    StackTrace? stackTrace,
    Map<String, dynamic>? additionalData,
  }) {
    final errorReport = ErrorReport(
      type: ErrorType.business,
      error: error,
      stackTrace: stackTrace?.toString() ?? StackTrace.current.toString(),
      context: context,
      additionalData: additionalData,
      timestamp: DateTime.now(),
      isFatal: false,
    );

    _logError(errorReport);
  }

  // Handle user-facing errors with UI feedback
  void handleUserError(
    String message, {
    BuildContext? context,
    ErrorSeverity severity = ErrorSeverity.error,
    Duration? duration,
    VoidCallback? onRetry,
  }) {
    AppLogger.warning('User error: $message');

    if (context != null && context.mounted) {
      _showErrorDialog(
        context,
        message,
        severity: severity,
        duration: duration,
        onRetry: onRetry,
      );
    }
  }

  // Log error details
  void _logError(ErrorReport errorReport) {
    if (errorReport.isFatal) {
      AppLogger.error('Error occurred: ${errorReport.error}',
        errorReport.error,
        errorReport.stackTrace != null ? StackTrace.fromString(errorReport.stackTrace!) : null);
    } else {
      AppLogger.warning('Warning: ${errorReport.error}');
    }

    // Also log to developer console in debug mode
    if (kDebugMode) {
      developer.log(
        errorReport.error,
        name: 'ErrorHandler',
        error: errorReport.error,
        stackTrace: StackTrace.fromString(errorReport.stackTrace ?? ''),
        level: errorReport.isFatal ? 1000 : 800,
      );
    }
  }

  // Report error to crash reporting service
  Future<void> _reportError(ErrorReport errorReport) async {
    if (kDebugMode) {
      // Don't report errors in debug mode
      return;
    }

    await _crashReporter.reportError(
      errorReport.error,
      stackTrace: errorReport.stackTrace,
      fatal: errorReport.isFatal,
      context: errorReport.context,
      additionalData: errorReport.toJson(),
    );
  }

  // Check if API error is common (not worth reporting)
  bool _isCommonApiError(ApiException exception) {
    return exception is NetworkException ||
           exception is TimeoutException ||
           exception is ValidationException ||
           (exception is UnauthorizedException && 
            exception.errorCode == 'TOKEN_EXPIRED');
  }

  // Show error dialog to user
  void _showErrorDialog(
    BuildContext context,
    String message, {
    ErrorSeverity severity = ErrorSeverity.error,
    Duration? duration,
    VoidCallback? onRetry,
  }) {
    final theme = Theme.of(context);
    
    // For snackbar-style errors
    if (severity == ErrorSeverity.warning || severity == ErrorSeverity.info) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: _getColorForSeverity(severity, theme),
          duration: duration ?? const Duration(seconds: 4),
          action: onRetry != null
              ? SnackBarAction(
                  label: 'Reintentar',
                  onPressed: onRetry,
                )
              : null,
        ),
      );
      return;
    }

    // For dialog-style errors
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          icon: Icon(
            _getIconForSeverity(severity),
            color: _getColorForSeverity(severity, theme),
            size: 32,
          ),
          title: Text(_getTitleForSeverity(severity)),
          content: Text(message),
          actions: [
            if (onRetry != null)
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  onRetry();
                },
                child: const Text('Reintentar'),
              ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  // Get color for error severity
  Color _getColorForSeverity(ErrorSeverity severity, ThemeData theme) {
    switch (severity) {
      case ErrorSeverity.info:
        return theme.colorScheme.primary;
      case ErrorSeverity.warning:
        return Colors.orange;
      case ErrorSeverity.error:
        return theme.colorScheme.error;
      case ErrorSeverity.critical:
        return Colors.red.shade700;
    }
  }

  // Get icon for error severity
  IconData _getIconForSeverity(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.info:
        return Icons.info_outline;
      case ErrorSeverity.warning:
        return Icons.warning_amber_outlined;
      case ErrorSeverity.error:
        return Icons.error_outline;
      case ErrorSeverity.critical:
        return Icons.dangerous_outlined;
    }
  }

  // Get title for error severity
  String _getTitleForSeverity(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.info:
        return 'Información';
      case ErrorSeverity.warning:
        return 'Advertencia';
      case ErrorSeverity.error:
        return 'Error';
      case ErrorSeverity.critical:
        return 'Error Crítico';
    }
  }

  // Public API for manual error reporting
  void reportError(
    dynamic error, {
    StackTrace? stackTrace,
    String? context,
    Map<String, dynamic>? additionalData,
    bool fatal = false,
  }) {
    final errorReport = ErrorReport(
      type: ErrorType.manual,
      error: error.toString(),
      stackTrace: (stackTrace ?? StackTrace.current).toString(),
      context: context,
      additionalData: additionalData,
      timestamp: DateTime.now(),
      isFatal: fatal,
    );

    _logError(errorReport);
    _reportError(errorReport);
  }

  // Get error statistics for debugging
  Map<String, dynamic> getErrorStatistics() {
    return {
      'message': 'Error statistics not available (using simple logger)',
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  // Clear error history (for debugging)
  void clearErrorHistory() {
    // Not available with simple logger
  }
}

// Error severity levels
enum ErrorSeverity {
  info,
  warning,
  error,
  critical,
}

// Error types for categorization
enum ErrorType {
  flutter,
  platform,
  api,
  business,
  manual,
}

// Error report model
class ErrorReport {
  final ErrorType type;
  final String error;
  final String? stackTrace;
  final String? context;
  final String? library;
  final int? statusCode;
  final String? errorCode;
  final Map<String, dynamic>? additionalData;
  final DateTime timestamp;
  final bool isFatal;

  ErrorReport({
    required this.type,
    required this.error,
    this.stackTrace,
    this.context,
    this.library,
    this.statusCode,
    this.errorCode,
    this.additionalData,
    required this.timestamp,
    required this.isFatal,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.toString(),
      'error': error,
      'stackTrace': stackTrace,
      'context': context,
      'library': library,
      'statusCode': statusCode,
      'errorCode': errorCode,
      'additionalData': additionalData,
      'timestamp': timestamp.toIso8601String(),
      'isFatal': isFatal,
    };
  }
}