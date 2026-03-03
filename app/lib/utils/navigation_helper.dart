import 'package:flutter/material.dart';
import '../utils/logger.dart';

/// NavigationHelper con GlobalKey para navegación desde notificaciones (sin BuildContext)
class NavigationHelper {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static void navigateToRideRequest() {
    _navigateTo('/driver/home');
  }

  static void navigateToTripTracking() {
    _navigateTo('/shared/trip-tracking');
  }

  static void navigateToTripHistory() {
    _navigateTo('/passenger/trip-history');
  }

  static void navigateToEarnings() {
    _navigateTo('/driver/earnings-details');
  }

  static void navigateToHome() {
    try {
      final context = navigatorKey.currentContext;
      if (context != null) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      AppLogger.error('Error navegando a inicio', e);
    }
  }

  static void _navigateTo(String route) {
    try {
      final context = navigatorKey.currentContext;
      if (context != null) {
        Navigator.of(context).pushNamed(route);
      }
    } catch (e) {
      AppLogger.error('Error navegando a $route', e);
    }
  }

  static void navigateWithArguments(String route, Object? arguments) {
    try {
      final context = navigatorKey.currentContext;
      if (context != null) {
        Navigator.of(context).pushNamed(route, arguments: arguments);
      }
    } catch (e) {
      AppLogger.error('Error navegando con argumentos', e);
    }
  }

  static void goBack() {
    try {
      final context = navigatorKey.currentContext;
      if (context != null && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      AppLogger.error('Error navegando hacia atrás', e);
    }
  }
}