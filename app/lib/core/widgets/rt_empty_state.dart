import 'package:flutter/material.dart';

import '../design/rt_colors.dart';
import '../design/rt_tokens.dart';
import '../design/rt_typography.dart';

/// Widget para mostrar estados vacios con icono, titulo,
/// descripción opcional y boton de accion
class RtEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double iconSize;

  const RtEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
    this.iconSize = 64,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: RtSpacing.xxl,
        vertical: RtSpacing.xxxl,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icono en contenedor circular
          Container(
            width: iconSize + RtSpacing.xxl,
            height: iconSize + RtSpacing.xxl,
            decoration: BoxDecoration(
              color: RtColors.neutral100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: iconSize,
              color: RtColors.neutral400,
            ),
          ),

          const SizedBox(height: RtSpacing.xl),

          // Titulo
          Text(
            title,
            style: RtTypo.headingSmall.copyWith(color: RtColors.neutral800),
            textAlign: TextAlign.center,
          ),

          // Descripción opcional
          if (description != null) ...[
            const SizedBox(height: RtSpacing.sm),
            Text(
              description!,
              style: RtTypo.bodyMedium.copyWith(color: RtColors.neutral500),
              textAlign: TextAlign.center,
            ),
          ],

          // Boton de accion opcional
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: RtSpacing.xl),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: RtColors.brand,
                side: const BorderSide(color: RtColors.brand),
                shape: RoundedRectangleBorder(
                  borderRadius: RtRadius.borderMd,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: RtSpacing.xl,
                  vertical: RtSpacing.md,
                ),
              ),
              child: Text(actionLabel!, style: RtTypo.labelLarge),
            ),
          ],
        ],
      ),
    );
  }
}
