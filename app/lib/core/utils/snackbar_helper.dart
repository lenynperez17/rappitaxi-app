import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Helper centralizado para mostrar SnackBars consistentes
class SnackBarHelper {
  
  /// Mostrar SnackBar de éxito
  static void showSuccess(BuildContext context, String message, {int duration = 3}) {
    _showSnackBar(
      context, 
      message, 
      AppColors.rappiOrange, 
      Icons.check_circle_outline,
      duration
    );
  }

  /// Mostrar SnackBar de error
  static void showError(BuildContext context, String message, {int duration = 4}) {
    _showSnackBar(
      context, 
      message, 
      Colors.red, 
      Icons.error_outline,
      duration
    );
  }

  /// Mostrar SnackBar de advertencia
  static void showWarning(BuildContext context, String message, {int duration = 3}) {
    _showSnackBar(
      context, 
      message, 
      Colors.orange, 
      Icons.warning_outlined,
      duration
    );
  }

  /// Mostrar SnackBar informativo
  static void showInfo(BuildContext context, String message, {int duration = 3}) {
    _showSnackBar(
      context, 
      message, 
      Colors.blue, 
      Icons.info_outline,
      duration
    );
  }

  /// Mostrar SnackBar personalizado
  static void showCustom(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    Color? textColor,
    IconData? icon,
    int duration = 3,
    SnackBarAction? action,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: textColor ?? colorScheme.onPrimary, size: 20),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: textColor ?? colorScheme.onPrimary,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor ?? AppColors.rappiBlack,
        duration: Duration(seconds: duration),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        action: action,
      ),
    );
  }

  /// Helper privado para mostrar SnackBar base
  static void _showSnackBar(
    BuildContext context,
    String message,
    Color backgroundColor,
    IconData icon,
    int duration,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: colorScheme.onPrimary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: colorScheme.onPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: Duration(seconds: duration),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Limpiar SnackBars existentes
  static void clear(BuildContext context) {
    ScaffoldMessenger.of(context).clearSnackBars();
  }

  /// Mostrar SnackBar con acción
  static void showWithAction(
    BuildContext context,
    String message,
    String actionLabel,
    VoidCallback onActionPressed, {
    Color? backgroundColor,
    int duration = 5,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    showCustom(
      context,
      message,
      backgroundColor: backgroundColor,
      duration: duration,
      action: SnackBarAction(
        label: actionLabel,
        textColor: colorScheme.onPrimary,
        onPressed: onActionPressed,
      ),
    );
  }
}