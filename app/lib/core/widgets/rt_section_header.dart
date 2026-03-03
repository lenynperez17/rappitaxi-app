import 'package:flutter/material.dart';

import '../design/rt_colors.dart';
import '../design/rt_tokens.dart';
import '../design/rt_typography.dart';

/// Encabezado de seccion con titulo, subtitulo opcional y accion
/// Ideal para separar secciones en listas o pantallas de contenido
class RtSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsets? padding;

  const RtSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.actionLabel,
    this.onAction,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(
        horizontal: RtSpacing.base,
        vertical: RtSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Titulo y subtitulo
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: RtTypo.headingSmall.copyWith(
                    color: RtColors.neutral900,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: RtTypo.bodySmall.copyWith(
                      color: RtColors.neutral500,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Accion: widget personalizado o texto con onAction
          if (action != null)
            action!
          else if (actionLabel != null && onAction != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: RtTypo.labelMedium.copyWith(color: RtColors.brand),
              ),
            ),
        ],
      ),
    );
  }
}
