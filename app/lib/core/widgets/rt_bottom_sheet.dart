import 'package:flutter/material.dart';

import '../design/rt_colors.dart';
import '../design/rt_tokens.dart';
import '../design/rt_typography.dart';

/// Helper con métodos estaticos para mostrar bottom sheets estilizados.
/// Aplica el design system de RapiTeam: bordes redondeados arriba,
/// drag handle, fondo surface y tipografia Inter.
class RtBottomSheet {
  RtBottomSheet._();

  /// Muestra un bottom sheet modal generico con drag handle.
  ///
  /// [child] es el contenido a mostrar dentro del sheet.
  /// [isDismissible] permite cerrar tocando fuera (por defecto true).
  /// [enableDrag] permite cerrar arrastrando hacia abajo (por defecto true).
  /// [isScrollControlled] permite que el sheet ocupe más del 50% de pantalla.
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    bool isDismissible = true,
    bool enableDrag = true,
    bool isScrollControlled = false,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      isScrollControlled: isScrollControlled,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: RtRadius.sheetTop),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDragHandle(),
              child,
            ],
          ),
        );
      },
    );
  }

  /// Muestra un bottom sheet de confirmación con titulo, descripción
  /// y dos botones (cancelar / confirmar).
  ///
  /// [confirmLabel] es el texto del boton de accion (por defecto "Confirmar").
  /// [onConfirm] se ejecuta al presionar el boton de confirmación.
  static Future<bool?> showConfirm(
    BuildContext context, {
    required String title,
    required String description,
    String confirmLabel = 'Confirmar',
    required VoidCallback onConfirm,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: RtRadius.sheetTop),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              RtSpacing.xl,
              0,
              RtSpacing.xl,
              RtSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDragHandle(),
                const SizedBox(height: RtSpacing.base),
                Text(
                  title,
                  style: RtTypo.headingMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: RtSpacing.sm),
                Text(
                  description,
                  style: RtTypo.bodyMedium.copyWith(color: RtColors.neutral500),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: RtSpacing.xl),
                _buildConfirmButtons(context, confirmLabel, onConfirm),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Drag handle visual: barra centrada de 40x4
  static Widget _buildDragHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: RtColors.neutral300,
        borderRadius: RtRadius.borderFull,
      ),
    );
  }

  /// Botones de cancelar y confirmar en fila horizontal
  static Widget _buildConfirmButtons(
    BuildContext context,
    String confirmLabel,
    VoidCallback onConfirm,
  ) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: RtSpacing.md),
              side: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark
                    ? RtColors.neutral600
                    : RtColors.neutral300,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: RtRadius.borderMd,
              ),
            ),
            child: Text(
              'Cancelar',
              style: RtTypo.labelLarge.copyWith(
                color: Theme.of(context).brightness == Brightness.dark
                    ? RtColors.neutral300
                    : RtColors.neutral600,
              ),
            ),
          ),
        ),
        const SizedBox(width: RtSpacing.md),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context, true);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: RtColors.brand,
              foregroundColor: RtColors.white,
              padding: const EdgeInsets.symmetric(vertical: RtSpacing.md),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: RtRadius.borderMd,
              ),
            ),
            child: Text(
              confirmLabel,
              style: RtTypo.labelLarge.copyWith(
                color: RtColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
