// Crash reporter for Rappi Taxi
import 'dart:convert';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class CrashReporter {
  static final CrashReporter _instance = CrashReporter._internal();
  factory CrashReporter() => _instance;
  CrashReporter._internal();

  // Initialize crash reporting
  Future<void> initialize() async {
    if (kDebugMode) {
      debugPrint('CrashReporter initialized');
    }
    
    // Enable crash collection
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
  }

  // Report error to crash reporting service
  Future<void> reportError(
    String error, {
    String? stackTrace,
    bool fatal = false,
    String? context,
    Map<String, dynamic>? additionalData,
  }) async {
    if (kDebugMode) {
      // Don't report errors in debug mode
      debugPrint('CrashReporter: $error');
      return;
    }

    // In production, send to Firebase Crashlytics
    await FirebaseCrashlytics.instance.recordError(
      error,
      stackTrace != null ? StackTrace.fromString(stackTrace) : null,
      fatal: fatal,
      information: [
        if (context != null) 'Context: $context',
        if (additionalData != null) 'Data: ${jsonEncode(additionalData)}',
      ],
    );
  }

  // Report custom message
  Future<void> recordMessage(String message) async {
    if (kDebugMode) {
      debugPrint('CrashReporter message: $message');
      return;
    }

    await FirebaseCrashlytics.instance.log(message);
  }

  // Set user identifier
  Future<void> setUserId(String userId) async {
    if (kDebugMode) {
      debugPrint('CrashReporter userId: $userId');
      return;
    }

    await FirebaseCrashlytics.instance.setUserIdentifier(userId);
  }

  // Set custom key
  Future<void> setCustomKey(String key, dynamic value) async {
    if (kDebugMode) {
      debugPrint('CrashReporter custom key: $key = $value');
      return;
    }

    await FirebaseCrashlytics.instance.setCustomKey(key, value);
  }

  // Enable/disable collection
  Future<void> setCrashlyticsCollectionEnabled(bool enabled) async {
    if (kDebugMode) {
      debugPrint('CrashReporter collection enabled: $enabled');
      return;
    }

    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(enabled);
  }
}