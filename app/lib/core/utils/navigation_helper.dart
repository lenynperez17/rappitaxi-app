import 'package:flutter/material.dart';
import 'snackbar_helper.dart';

/// Helper centralizado para navegación consistente
class NavigationHelper {
  
  /// Navegar a una ruta con nombre
  static Future<T?> navigateTo<T>(
    BuildContext context, 
    String routeName, {
    Object? arguments,
    bool replace = false,
  }) async {
    try {
      if (replace) {
        return await Navigator.pushReplacementNamed<T, void>(
          context, 
          routeName, 
          arguments: arguments,
        );
      } else {
        return await Navigator.pushNamed<T>(
          context, 
          routeName, 
          arguments: arguments,
        );
      }
    } catch (e) {
      SnackBarHelper.showError(
        context, 
        'Error de navegación: ${e.toString()}',
      );
      return null;
    }
  }

  /// Navegar y limpiar todo el stack (para login/logout)
  static Future<T?> navigateAndClearStack<T>(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) async {
    try {
      return await Navigator.pushNamedAndRemoveUntil<T>(
        context,
        routeName,
        (route) => false,
        arguments: arguments,
      );
    } catch (e) {
      SnackBarHelper.showError(
        context,
        'Error de navegación: ${e.toString()}',
      );
      return null;
    }
  }

  /// Navegar hasta una ruta específica (limpia stack hasta esa ruta)
  static Future<T?> navigateUntil<T>(
    BuildContext context,
    String routeName,
    String untilRoute, {
    Object? arguments,
  }) async {
    try {
      return await Navigator.pushNamedAndRemoveUntil<T>(
        context,
        routeName,
        ModalRoute.withName(untilRoute),
        arguments: arguments,
      );
    } catch (e) {
      SnackBarHelper.showError(
        context,
        'Error de navegación: ${e.toString()}',
      );
      return null;
    }
  }

  /// Volver atrás con resultado opcional
  static void goBack<T>(BuildContext context, [T? result]) {
    if (Navigator.canPop(context)) {
      Navigator.pop<T>(context, result);
    } else {
      // Si no puede volver, ir a home
      navigateAndClearStack(context, '/');
    }
  }

  /// Verificar si puede volver atrás
  static bool canGoBack(BuildContext context) {
    return Navigator.canPop(context);
  }

  /// Mostrar modal bottom sheet
  static Future<T?> showBottomSheet<T>(
    BuildContext context,
    Widget child, {
    bool isScrollControlled = true,
    bool isDismissible = true,
    bool enableDrag = true,
    Color? backgroundColor,
  }) async {
    return await showModalBottomSheet<T>(
      context: context,
      builder: (context) => child,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    );
  }

  /// Mostrar diálogo personalizado
  static Future<T?> showCustomDialog<T>(
    BuildContext context,
    Widget dialog, {
    bool barrierDismissible = true,
  }) async {
    return await showDialog<T>(
      context: context,
      builder: (context) => dialog,
      barrierDismissible: barrierDismissible,
    );
  }

  /// Mostrar diálogo de confirmación
  static Future<bool> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirmar',
    String cancelText = 'Cancelar',
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive ? Colors.red : null,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Cerrar todos los diálogos abiertos
  static void closeAllDialogs(BuildContext context) {
    Navigator.popUntil(context, (route) => route is! PopupRoute);
  }

  /// Mostrar loading dialog
  static void showLoadingDialog(
    BuildContext context, {
    String message = 'Cargando...',
    bool barrierDismissible = false,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(child: Text(message)),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  /// Cerrar loading dialog
  static void hideLoadingDialog(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  /// Navegación segura con validación de argumentos
  static Future<T?> navigateToWithValidation<T>(
    BuildContext context,
    String routeName, {
    Object? arguments,
    bool Function(Object?)? validator,
    String? validationError,
  }) async {
    // Validar argumentos si se proporciona validador
    if (validator != null && !validator(arguments)) {
      SnackBarHelper.showError(
        context,
        validationError ?? 'Argumentos inválidos para la navegación',
      );
      return null;
    }

    return await navigateTo<T>(context, routeName, arguments: arguments);
  }

  // Rutas comunes - constantes para evitar typos
  static const String splashRoute = '/';
  static const String loginRoute = '/login';
  static const String registerRoute = '/register';
  static const String forgotPasswordRoute = '/forgot-password';
  
  // Rutas de pasajero
  static const String passengerHomeRoute = '/passenger/home';
  static const String passengerProfileRoute = '/passenger/profile';
  static const String paymentMethodsRoute = '/passenger/payment-methods';
  static const String tripHistoryRoute = '/passenger/trip-history';
  
  // Rutas de conductor
  static const String driverHomeRoute = '/driver/home';
  static const String driverProfileRoute = '/driver/profile';
  static const String driverWalletRoute = '/driver/wallet';
  
  // Rutas compartidas
  static const String settingsRoute = '/shared/settings';
  static const String helpCenterRoute = '/shared/help-center';
  static const String aboutRoute = '/shared/about';

  /// Métodos de conveniencia para rutas comunes
  static Future<void> goToLogin(BuildContext context) =>
      navigateAndClearStack(context, loginRoute);

  static Future<void> goToHome(BuildContext context, {bool isDriver = false}) =>
      navigateAndClearStack(
        context, 
        isDriver ? driverHomeRoute : passengerHomeRoute,
      );

  static Future<void> goToProfile(BuildContext context, {bool isDriver = false}) =>
      navigateTo(
        context, 
        isDriver ? driverProfileRoute : passengerProfileRoute,
      );

  static Future<void> goToSettings(BuildContext context) =>
      navigateTo(context, settingsRoute);
}