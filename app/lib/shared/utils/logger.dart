// Logger utility for Rappi Taxi
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import '../models/log_entry_model.dart';

class Logger {
  static final Logger _instance = Logger._internal();
  factory Logger() => _instance;
  Logger._internal();

  final List<LogEntry> _logs = [];
  final int _maxLogs = 1000; // Maximum number of logs to keep in memory
  LogLevel _minLogLevel = kDebugMode ? LogLevel.debug : LogLevel.info;

  // Set minimum log level
  void setMinLogLevel(LogLevel level) {
    _minLogLevel = level;
  }

  // Debug level logging
  void debug(String message, {
    String? tag,
    dynamic error,
    String? stackTrace,
    Map<String, dynamic>? additionalData,
  }) {
    log(LogLevel.debug, message,
        tag: tag, error: error, stackTrace: stackTrace, additionalData: additionalData);
  }

  // Info level logging
  void info(String message, {
    String? tag,
    dynamic error,
    String? stackTrace,
    Map<String, dynamic>? additionalData,
  }) {
    log(LogLevel.info, message,
        tag: tag, error: error, stackTrace: stackTrace, additionalData: additionalData);
  }

  // Warning level logging
  void warn(String message, {
    String? tag,
    dynamic error,
    String? stackTrace,
    Map<String, dynamic>? additionalData,
  }) {
    log(LogLevel.warn, message,
        tag: tag, error: error, stackTrace: stackTrace, additionalData: additionalData);
  }

  // Error level logging
  void error(String message, {
    String? tag,
    dynamic error,
    String? stackTrace,
    Map<String, dynamic>? additionalData,
  }) {
    log(LogLevel.error, message,
        tag: tag, error: error, stackTrace: stackTrace, additionalData: additionalData);
  }

  // Generic log method
  void log(LogLevel level, String message, {
    String? tag,
    dynamic error,
    String? stackTrace,
    Map<String, dynamic>? additionalData,
  }) {
    // Check if log level meets minimum threshold
    if (level.index < _minLogLevel.index) {
      return;
    }

    final logEntry = LogEntry(
      level: level,
      message: message,
      tag: tag ?? 'RAPPI_TAXI',
      error: error?.toString(),
      stackTrace: stackTrace,
      additionalData: additionalData,
      timestamp: DateTime.now(),
    );

    // Add to memory logs
    _addToMemoryLogs(logEntry);

    // Output to console
    _outputToConsole(logEntry);

    // Send to remote logging service in production
    if (!kDebugMode && level.index >= LogLevel.warn.index) {
      _sendToRemoteLogger(logEntry);
    }
  }

  // Add log entry to memory storage
  void _addToMemoryLogs(LogEntry logEntry) {
    _logs.add(logEntry);

    // Remove old logs if exceeding maximum
    if (_logs.length > _maxLogs) {
      _logs.removeAt(0);
    }
  }

  // Output log to console/developer tools
  void _outputToConsole(LogEntry logEntry) {
    final emoji = _getEmojiForLevel(logEntry.level);
    final timestamp = _formatTimestamp(logEntry.timestamp);
    final tag = logEntry.tag;
    final message = logEntry.message;

    String logOutput = '$emoji [$timestamp] [$tag] $message';

    if (logEntry.error != null) {
      logOutput += '\nError: ${logEntry.error}';
    }

    if (logEntry.additionalData != null && logEntry.additionalData!.isNotEmpty) {
      logOutput += '\nData: ${jsonEncode(logEntry.additionalData)}';
    }

    if (logEntry.stackTrace != null) {
      logOutput += '\nStack: ${logEntry.stackTrace}';
    }

    // Use developer.log for better integration with Flutter DevTools
    developer.log(
      logOutput,
      name: tag,
      time: logEntry.timestamp,
      level: _getDeveloperLogLevel(logEntry.level),
      error: logEntry.error,
      stackTrace: logEntry.stackTrace != null
          ? StackTrace.fromString(logEntry.stackTrace!)
          : null,
    );

    // Also output to console in debug mode for immediate visibility
    if (kDebugMode) {
      // Use print only in debug mode for immediate console output
      // This is acceptable as it's wrapped in kDebugMode check
      debugPrint(logOutput);
    }
  }

  // Send log to remote logging service
  void _sendToRemoteLogger(LogEntry logEntry) {
    // TODO: Implement remote logging service integration
    // This could be Firebase Crashlytics, Sentry, or a custom logging service
    // For now, we'll just store the log for potential batch upload
  }

  // Get emoji for log level
  String _getEmojiForLevel(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return '🐛';
      case LogLevel.info:
        return 'ℹ️';
      case LogLevel.warn:
        return '⚠️';
      case LogLevel.error:
        return '❌';
    }
  }

  // Format timestamp for display
  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
           '${timestamp.minute.toString().padLeft(2, '0')}:'
           '${timestamp.second.toString().padLeft(2, '0')}.'
           '${timestamp.millisecond.toString().padLeft(3, '0')}';
  }

  // Convert to developer log level
  int _getDeveloperLogLevel(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 500;
      case LogLevel.info:
        return 800;
      case LogLevel.warn:
        return 900;
      case LogLevel.error:
        return 1000;
    }
  }

  // Get all logs
  List<LogEntry> getAllLogs() {
    return List.unmodifiable(_logs);
  }

  // Get logs by level
  List<LogEntry> getLogsByLevel(LogLevel level) {
    return _logs.where((log) => log.level == level).toList();
  }

  // Get logs by tag
  List<LogEntry> getLogsByTag(String tag) {
    return _logs.where((log) => log.tag == tag).toList();
  }

  // Get logs in date range
  List<LogEntry> getLogsByDateRange(DateTime start, DateTime end) {
    return _logs.where((log) => 
        log.timestamp.isAfter(start) && log.timestamp.isBefore(end)
    ).toList();
  }

  // Get recent logs
  List<LogEntry> getRecentLogs({int count = 100}) {
    final startIndex = _logs.length > count ? _logs.length - count : 0;
    return _logs.sublist(startIndex);
  }

  // Search logs by message content
  List<LogEntry> searchLogs(String query) {
    return _logs.where((log) => 
        log.message.toLowerCase().contains(query.toLowerCase()) ||
        (log.error?.toLowerCase().contains(query.toLowerCase()) ?? false)
    ).toList();
  }

  // Clear all logs
  void clearLogs() {
    _logs.clear();
  }

  // Get log statistics
  Map<LogLevel, int> getLogStatistics() {
    final stats = <LogLevel, int>{};
    for (final level in LogLevel.values) {
      stats[level] = _logs.where((log) => log.level == level).length;
    }
    return stats;
  }

  // Get log count for specific level
  int getLogCount(LogLevel level) {
    return _logs.where((log) => log.level == level).length;
  }

  // Get total log count
  int getTotalLogCount() {
    return _logs.length;
  }

  // Get latest log for specific level
  LogEntry? getLastLog(LogLevel level) {
    final levelLogs = _logs.where((log) => log.level == level);
    return levelLogs.isNotEmpty ? levelLogs.last : null;
  }

  // Export logs as JSON
  String exportLogsAsJson({
    LogLevel? minLevel,
    DateTime? startDate,
    DateTime? endDate,
    String? tag,
  }) {
    var filteredLogs = _logs.asMap().entries.map((entry) => {
      'index': entry.key,
      ...entry.value.toJson(),
    });

    if (minLevel != null) {
      filteredLogs = filteredLogs.where((log) => 
          LogLevel.values.indexOf(LogLevel.values.firstWhere((level) => 
              level.toString() == log['level'])) >= minLevel.index);
    }

    if (startDate != null) {
      filteredLogs = filteredLogs.where((log) => 
          DateTime.parse(log['timestamp'] as String).isAfter(startDate));
    }

    if (endDate != null) {
      filteredLogs = filteredLogs.where((log) => 
          DateTime.parse(log['timestamp'] as String).isBefore(endDate));
    }

    if (tag != null) {
      filteredLogs = filteredLogs.where((log) => log['tag'] == tag);
    }

    return jsonEncode({
      'logs': filteredLogs.toList(),
      'exportedAt': DateTime.now().toIso8601String(),
      'totalCount': filteredLogs.length,
    });
  }

  // Performance logging helpers
  void logPerformance(String operation, Duration duration, {
    Map<String, dynamic>? metrics,
  }) {
    info('Performance: $operation completed in ${duration.inMilliseconds}ms',
        tag: 'PERFORMANCE',
        additionalData: {
          'operation': operation,
          'durationMs': duration.inMilliseconds,
          'durationMicros': duration.inMicroseconds,
          ...?metrics,
        });
  }

  // API request/response logging
  void logApiRequest(String method, String url, {
    Map<String, dynamic>? headers,
    dynamic body,
    int? statusCode,
    Duration? duration,
  }) {
    final data = <String, dynamic>{
      'method': method,
      'url': url,
      if (headers != null) 'headers': headers,
      if (body != null) 'body': body,
      if (statusCode != null) 'statusCode': statusCode,
      if (duration != null) 'durationMs': duration.inMilliseconds,
    };

    final level = statusCode != null && statusCode >= 400 ? LogLevel.warn : LogLevel.info;
    log(level, 'API $method $url${statusCode != null ? ' -> $statusCode' : ''}',
        tag: 'API', additionalData: data);
  }

  // Navigation logging
  void logNavigation(String from, String to, {
    Map<String, dynamic>? arguments,
  }) {
    info('Navigation: $from -> $to',
        tag: 'NAVIGATION',
        additionalData: {
          'from': from,
          'to': to,
          if (arguments != null) 'arguments': arguments,
        });
  }

  // User action logging
  void logUserAction(String action, {
    String? screen,
    Map<String, dynamic>? context,
  }) {
    info('User action: $action${screen != null ? ' on $screen' : ''}',
        tag: 'USER_ACTION',
        additionalData: {
          'action': action,
          if (screen != null) 'screen': screen,
          ...?context,
        });
  }
}

// LogLevel is imported from log_entry_model.dart