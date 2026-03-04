import 'package:flutter/material.dart';
import '../utils/logger.dart';

class NavigationHelper {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // Navegar a solicitud de viaje (para conductores)
  static void navigateToRideRequest() {
    try {
      final context = navigatorKey.currentContext;
      if (context != null) {
        Navigator.of(context).pushNamed('/ride-request');
        AppLogger.info('Navegando a solicitud de viaje');
      }
    } catch (e) {
      AppLogger.error('Error navegando a solicitud de viaje', e);
    }
  }

  // Navegar a seguimiento de viaje
  static void navigateToTripTracking() {
    try {
      final context = navigatorKey.currentContext;
      if (context != null) {
        Navigator.of(context).pushNamed('/trip-tracking');
        AppLogger.info('Navegando a seguimiento de viaje');
      }
    } catch (e) {
      AppLogger.error('Error navegando a seguimiento de viaje', e);
    }
  }

  // Navegar a historial de viajes
  static void navigateToTripHistory() {
    try {
      final context = navigatorKey.currentContext;
      if (context != null) {
        Navigator.of(context).pushNamed('/trip-history');
        AppLogger.info('Navegando a historial de viajes');
      }
    } catch (e) {
      AppLogger.error('Error navegando a historial de viajes', e);
    }
  }

  // Navegar a ganancias (para conductores)
  static void navigateToEarnings() {
    try {
      final context = navigatorKey.currentContext;
      if (context != null) {
        Navigator.of(context).pushNamed('/earnings');
        AppLogger.info('Navegando a ganancias');
      }
    } catch (e) {
      AppLogger.error('Error navegando a ganancias', e);
    }
  }

  // Navegar a pantalla principal
  static void navigateToHome() {
    try {
      final context = navigatorKey.currentContext;
      if (context != null) {
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
        AppLogger.info('Navegando a inicio');
      }
    } catch (e) {
      AppLogger.error('Error navegando a inicio', e);
    }
  }

  // Navegar con parámetros
  static void navigateWithArguments(String route, Object? arguments) {
    try {
      final context = navigatorKey.currentContext;
      if (context != null) {
        Navigator.of(context).pushNamed(route, arguments: arguments);
        AppLogger.info('Navegando a $route con argumentos');
      }
    } catch (e) {
      AppLogger.error('Error navegando con argumentos', e);
    }
  }

  // Reemplazar ruta actual
  static void replaceWith(String route, {Object? arguments}) {
    try {
      final context = navigatorKey.currentContext;
      if (context != null) {
        Navigator.of(context).pushReplacementNamed(route, arguments: arguments);
        AppLogger.info('Reemplazando ruta con $route');
      }
    } catch (e) {
      AppLogger.error('Error reemplazando ruta', e);
    }
  }

  // Volver a la pantalla anterior
  static void goBack() {
    try {
      final context = navigatorKey.currentContext;
      if (context != null && Navigator.canPop(context)) {
        Navigator.of(context).pop();
        AppLogger.debug('Navegando hacia atrás');
      }
    } catch (e) {
      AppLogger.error('Error navegando hacia atrás', e);
    }
  }

  // Mostrar diálogo
  static Future<T?> showAppDialog<T>({
    required Widget dialog,
    bool barrierDismissible = true,
  }) async {
    try {
      final context = navigatorKey.currentContext;
      if (context != null) {
        return await showDialog<T>(
          context: context,
          barrierDismissible: barrierDismissible,
          builder: (context) => dialog,
        );
      }
      return null;
    } catch (e) {
      AppLogger.error('Error mostrando diálogo', e);
      return null;
    }
  }

  // Mostrar modal bottom sheet
  static Future<T?> showAppBottomSheet<T>({
    required Widget content,
    bool isScrollControlled = true,
  }) async {
    try {
      final context = navigatorKey.currentContext;
      if (context != null) {
        return await showModalBottomSheet<T>(
          context: context,
          isScrollControlled: isScrollControlled,
          builder: (context) => content,
        );
      }
      return null;
    } catch (e) {
      AppLogger.error('Error mostrando bottom sheet', e);
      return null;
    }
  }
}