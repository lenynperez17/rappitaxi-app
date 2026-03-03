// Crash reporter for RapiTeam
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/logger.dart';

class CrashReporter {
  static final CrashReporter _instance = CrashReporter._internal();
  factory CrashReporter() => _instance;
  CrashReporter._internal();

  static const String _crashLogKey = 'crash_logs';
  static const int _maxStoredCrashes = 50;
  bool _isEnabled = true;
  String? _userId;

  // Initialize crash reporting
  Future<void> initialize() async {
    if (kDebugMode) {
      debugPrint('CrashReporter initialized (Local Mode)');
    }
    
    // Enable crash collection only in release mode
    _isEnabled = !kDebugMode;
    
    // Load and clean old crash logs
    await _cleanOldCrashLogs();
  }

  // Report error to crash reporting service
  Future<void> reportError(
    String error, {
    String? stackTrace,
    bool fatal = false,
    String? context,
    Map<String, dynamic>? additionalData,
  }) async {
    if (!_isEnabled) {
      // In debug mode, just log the error
      AppLogger.error('CrashReporter: $error', error, stackTrace != null ? StackTrace.fromString(stackTrace) : null);
      return;
    }

    // Create crash report
    final crashReport = {
      'timestamp': DateTime.now().toIso8601String(),
      'error': error,
      'stackTrace': stackTrace,
      'fatal': fatal,
      'context': context,
      'additionalData': additionalData,
      'userId': _userId,
      'platform': defaultTargetPlatform.toString(),
    };

    // Store crash report locally
    await _storeCrashReport(crashReport);
    
    // Log the error
    AppLogger.error(
      'Crash reported: $error',
      error,
      stackTrace != null ? StackTrace.fromString(stackTrace) : null,
    );
  }

  // Report custom message
  Future<void> recordMessage(String message) async {
    if (!_isEnabled) {
      debugPrint('CrashReporter message: $message');
      return;
    }

    // Store as a non-fatal message
    await reportError(
      message,
      fatal: false,
      context: 'custom_message',
    );
  }

  // Set user identifier
  Future<void> setUserId(String userId) async {
    _userId = userId;
    
    if (kDebugMode) {
      debugPrint('CrashReporter userId set: $userId');
    }
  }

  // Set custom key (stored with next crash report)
  final Map<String, dynamic> _customKeys = {};
  
  Future<void> setCustomKey(String key, dynamic value) async {
    _customKeys[key] = value;
    
    if (kDebugMode) {
      debugPrint('CrashReporter custom key: $key = $value');
    }
  }

  // Enable/disable collection
  Future<void> setCrashlyticsCollectionEnabled(bool enabled) async {
    _isEnabled = enabled && !kDebugMode;
    
    if (kDebugMode) {
      debugPrint('CrashReporter collection enabled: $_isEnabled');
    }
  }

  // Store crash report locally
  Future<void> _storeCrashReport(Map<String, dynamic> crashReport) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get existing crash logs
      final existingLogs = prefs.getStringList(_crashLogKey) ?? [];
      
      // Add custom keys to the report
      if (_customKeys.isNotEmpty) {
        crashReport['customKeys'] = _customKeys;
      }
      
      // Add new crash report
      existingLogs.add(jsonEncode(crashReport));
      
      // Keep only the most recent crashes
      while (existingLogs.length > _maxStoredCrashes) {
        existingLogs.removeAt(0);
      }
      
      // Save back to preferences
      await prefs.setStringList(_crashLogKey, existingLogs);
    } catch (e) {
      debugPrint('Failed to store crash report: $e');
    }
  }

  // Clean old crash logs
  Future<void> _cleanOldCrashLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingLogs = prefs.getStringList(_crashLogKey) ?? [];
      
      if (existingLogs.isEmpty) return;
      
      final now = DateTime.now();
      final filteredLogs = <String>[];
      
      for (final logStr in existingLogs) {
        try {
          final log = jsonDecode(logStr) as Map<String, dynamic>;
          final timestamp = DateTime.parse(log['timestamp'] as String);
          
          // Keep logs from the last 7 days
          if (now.difference(timestamp).inDays < 7) {
            filteredLogs.add(logStr);
          }
        } catch (e) {
          // Skip invalid logs
          continue;
        }
      }
      
      await prefs.setStringList(_crashLogKey, filteredLogs);
    } catch (e) {
      debugPrint('Failed to clean crash logs: $e');
    }
  }

  // Get stored crash reports (for debugging or sending to server)
  Future<List<Map<String, dynamic>>> getStoredCrashReports() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logs = prefs.getStringList(_crashLogKey) ?? [];
      
      return logs.map((log) {
        try {
          return jsonDecode(log) as Map<String, dynamic>;
        } catch (e) {
          return <String, dynamic>{};
        }
      }).where((log) => log.isNotEmpty).toList();
    } catch (e) {
      debugPrint('Failed to get crash reports: $e');
      return [];
    }
  }

  // Clear all stored crash reports
  Future<void> clearStoredCrashReports() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_crashLogKey);
    } catch (e) {
      debugPrint('Failed to clear crash reports: $e');
    }
  }
}