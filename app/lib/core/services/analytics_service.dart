import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/logger.dart';

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService();
});

class AnalyticsService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  
  FirebaseAnalyticsObserver get observer => FirebaseAnalyticsObserver(
    analytics: _analytics,
  );
  
  // User Properties
  Future<void> setUserId(String userId) async {
    try {
      await _analytics.setUserId(id: userId.isEmpty ? null : userId);
      Logger.info('Analytics user ID set: ${userId.isNotEmpty ? "User set" : "User cleared"}');
    } catch (e) {
      Logger.error('Error setting user ID', e);
    }
  }
  
  Future<void> setUserProperty({
    required String name,
    required String value,
  }) async {
    try {
      await _analytics.setUserProperty(name: name, value: value);
      Logger.info('User property set: $name = $value');
    } catch (e) {
      Logger.error('Error setting user property', e);
    }
  }
  
  // Authentication Events
  Future<void> logLogin({required String method}) async {
    try {
      await _analytics.logLogin(loginMethod: method);
      Logger.info('Login logged: $method');
    } catch (e) {
      Logger.error('Error logging login', e);
    }
  }
  
  Future<void> logSignUp({required String method}) async {
    try {
      await _analytics.logSignUp(signUpMethod: method);
      Logger.info('Sign up logged: $method');
    } catch (e) {
      Logger.error('Error logging sign up', e);
    }
  }
  
  Future<void> logLogout() async {
    try {
      await _analytics.logEvent(name: 'logout');
      Logger.info('Logout logged');
    } catch (e) {
      Logger.error('Error logging logout', e);
    }
  }
  
  // Ride Events
  Future<void> logRideRequested({
    required String pickupAddress,
    required String destinationAddress,
    required String vehicleType,
    required double estimatedFare,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'ride_requested',
        parameters: {
          'pickup': pickupAddress,
          'destination': destinationAddress,
          'vehicle_type': vehicleType,
          'estimated_fare': estimatedFare,
        },
      );
      Logger.info('Ride request logged');
    } catch (e) {
      Logger.error('Error logging ride request', e);
    }
  }
  
  Future<void> logRideStarted({
    required String rideId,
    required String driverId,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'ride_started',
        parameters: {
          'ride_id': rideId,
          'driver_id': driverId,
        },
      );
      Logger.info('Ride start logged');
    } catch (e) {
      Logger.error('Error logging ride start', e);
    }
  }
  
  Future<void> logRideCompleted({
    required String rideId,
    required double fare,
    required double distance,
    required int duration,
    required double rating,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'ride_completed',
        parameters: {
          'ride_id': rideId,
          'fare': fare,
          'distance': distance,
          'duration': duration,
          'rating': rating,
        },
      );
      Logger.info('Ride completion logged');
    } catch (e) {
      Logger.error('Error logging ride completion', e);
    }
  }
  
  Future<void> logRideCancelled({
    required String rideId,
    required String reason,
    required String cancelledBy,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'ride_cancelled',
        parameters: {
          'ride_id': rideId,
          'reason': reason,
          'cancelled_by': cancelledBy,
        },
      );
      Logger.info('Ride cancellation logged');
    } catch (e) {
      Logger.error('Error logging ride cancellation', e);
    }
  }
  
  // Payment Events
  Future<void> logPaymentMethodAdded(String paymentType) async {
    try {
      await _analytics.logEvent(
        name: 'payment_method_added',
        parameters: {
          'payment_type': paymentType,
        },
      );
      Logger.info('Payment method added: $paymentType');
    } catch (e) {
      Logger.error('Error logging payment method', e);
    }
  }
  
  Future<void> logPaymentCompleted({
    required String rideId,
    required String paymentMethod,
    required double amount,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'payment_completed',
        parameters: {
          'ride_id': rideId,
          'payment_method': paymentMethod,
          'amount': amount,
        },
      );
      Logger.info('Payment logged');
    } catch (e) {
      Logger.error('Error logging payment', e);
    }
  }
  
  // App Events
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass,
      );
      Logger.info('Screen view logged: $screenName');
    } catch (e) {
      Logger.error('Error logging screen view', e);
    }
  }
  
  Future<void> logAppOpen() async {
    try {
      await _analytics.logAppOpen();
      Logger.info('App open logged');
    } catch (e) {
      Logger.error('Error logging app open', e);
    }
  }
  
  Future<void> logSearch(String searchTerm) async {
    try {
      await _analytics.logSearch(searchTerm: searchTerm);
      Logger.info('Search logged: $searchTerm');
    } catch (e) {
      Logger.error('Error logging search', e);
    }
  }
  
  // Generic Event
  Future<void> logEvent({
    required String name,
    Map<String, dynamic>? parameters,
  }) async {
    try {
      await _analytics.logEvent(
        name: name,
        parameters: parameters,
      );
      Logger.info('Event logged: $name');
    } catch (e) {
      Logger.error('Error logging event', e);
    }
  }
}