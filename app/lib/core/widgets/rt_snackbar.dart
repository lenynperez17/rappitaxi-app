import 'package:flutter/material.dart';

import '../design/rt_colors.dart';
import '../design/rt_tokens.dart';
import '../design/rt_typography.dart';

/// Tipos de snackbar con icono y color asociados
enum RtSnackbarType {
  success,
  error,
  warning,
  info,
}

/// Utilidad para mostrar snackbars estilizados con el design system RapiTeam
class RtSnackbar {
  RtSnackbar._();

  /// Muestra un snackbar flotante con icono y color según el tipo
  static void show(
    BuildContext context, {
    required String message,
    RtSnackbarType type = RtSnackbarType.info,
  }) {
    final config = _configForType(type);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: config.backgroundColor,
          shape: RoundedRectangleBorder(borderRadius: RtRadius.borderMd),
          duration: const Duration(seconds: 3),
          margin: const EdgeInsets.all(RtSpacing.base),
          content: Row(
            children: [
              Icon(config.icon, color: config.foregroundColor, size: RtIconSize.sm),
              const SizedBox(width: RtSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: RtTypo.bodyMedium.copyWith(
                    color: config.foregroundColor,
                  ),
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'Cerrar',
            textColor: config.foregroundColor,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
  }

  /// Devuelve la configuración visual según el tipo de snackbar
  static _SnackbarConfig _configForType(RtSnackbarType type) {
    switch (type) {
      case RtSnackbarType.success:
        return _SnackbarConfig(
          icon: Icons.check_circle_rounded,
          backgroundColor: RtColors.successDark,
          foregroundColor: RtColors.white,
        );
      case RtSnackbarType.error:
        return _SnackbarConfig(
          icon: Icons.error_rounded,
          backgroundColor: RtColors.errorDark,
          foregroundColor: RtColors.white,
        );
      case RtSnackbarType.warning:
        return _SnackbarConfig(
          icon: Icons.warning_rounded,
          backgroundColor: RtColors.warningDark,
          foregroundColor: RtColors.white,
        );
      case RtSnackbarType.info:
        return _SnackbarConfig(
          icon: Icons.info_rounded,
          backgroundColor: RtColors.infoDark,
          foregroundColor: RtColors.white,
        );
    }
  }
}

/// Configuración interna para cada tipo de snackbar
class _SnackbarConfig {
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;

  const _SnackbarConfig({
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
  });
}
