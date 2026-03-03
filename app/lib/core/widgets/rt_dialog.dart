import 'package:flutter/material.dart';

import '../design/rt_colors.dart';
import '../design/rt_tokens.dart';
import '../design/rt_typography.dart';

/// Utilidad para mostrar dialogos estilizados con el design system RapiTeam
/// Todos los métodos son estaticos y usan showDialog internamente
class RtDialog {
  RtDialog._();

  /// Dialogo general con titulo, contenido y botones de accion
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required Widget content,
    String confirmLabel = 'Aceptar',
    String? cancelLabel,
    VoidCallback? onConfirm,
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: RtRadius.borderLg),
          titlePadding: const EdgeInsets.fromLTRB(
            RtSpacing.xl, RtSpacing.xl, RtSpacing.xl, RtSpacing.sm,
          ),
          contentPadding: const EdgeInsets.fromLTRB(
            RtSpacing.xl, 0, RtSpacing.xl, RtSpacing.xl,
          ),
          title: Text(title, style: RtTypo.headingSmall),
          content: content,
          actions: [
            if (cancelLabel != null)
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  cancelLabel,
                  style: RtTypo.labelLarge.copyWith(
                    color: RtColors.neutral600,
                  ),
                ),
              ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
                onConfirm?.call();
              },
              child: Text(
                confirmLabel,
                style: RtTypo.labelLarge.copyWith(
                  color: isDestructive ? RtColors.error : RtColors.brand,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Dialogo de confirmación con titulo, descripción y boton de confirmar
  static Future<bool?> confirm(
    BuildContext context, {
    required String title,
    String? description,
    String confirmLabel = 'Confirmar',
    VoidCallback? onConfirm,
  }) {
    return show(
      context,
      title: title,
      content: description != null
          ? Text(
              description,
              style: RtTypo.bodyMedium.copyWith(color: RtColors.neutral600),
            )
          : const SizedBox.shrink(),
      confirmLabel: confirmLabel,
      cancelLabel: 'Cancelar',
      onConfirm: onConfirm,
    );
  }

  /// Dialogo de éxito con icono de check verde
  static Future<void> success(
    BuildContext context, {
    required String title,
    String? description,
  }) {
    return _showIconDialog(
      context,
      icon: Icons.check_circle_rounded,
      iconColor: RtColors.success,
      iconBackgroundColor: RtColors.successLight,
      title: title,
      description: description,
    );
  }

  /// Dialogo de error con icono X rojo
  static Future<void> error(
    BuildContext context, {
    required String title,
    String? description,
  }) {
    return _showIconDialog(
      context,
      icon: Icons.cancel_rounded,
      iconColor: RtColors.error,
      iconBackgroundColor: RtColors.errorLight,
      title: title,
      description: description,
    );
  }

  /// Dialogo interno con icono centrado
  static Future<void> _showIconDialog(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required Color iconBackgroundColor,
    required String title,
    String? description,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: RtRadius.borderLg),
          contentPadding: const EdgeInsets.all(RtSpacing.xl),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icono en contenedor circular
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: iconBackgroundColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 36, color: iconColor),
              ),

              const SizedBox(height: RtSpacing.base),

              // Titulo
              Text(
                title,
                style: RtTypo.headingSmall,
                textAlign: TextAlign.center,
              ),

              // Descripción opcional
              if (description != null) ...[
                const SizedBox(height: RtSpacing.sm),
                Text(
                  description,
                  style: RtTypo.bodyMedium.copyWith(
                    color: RtColors.neutral600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: RtSpacing.xl),

              // Boton de cerrar
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Aceptar',
                    style: RtTypo.labelLarge.copyWith(color: RtColors.brand),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
