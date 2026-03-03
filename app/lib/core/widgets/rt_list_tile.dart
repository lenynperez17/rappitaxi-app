import 'package:flutter/material.dart';

import '../design/rt_colors.dart';
import '../design/rt_tokens.dart';
import '../design/rt_typography.dart';

/// ListTile personalizado que sigue el design system RapiTeam
/// Soporta icono leading con fondo sutil, trailing con chevron y modo denso
class RtListTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final IconData? leadingIcon;
  final Color? leadingIconColor;
  final Widget? trailing;
  final bool showChevron;
  final VoidCallback? onTap;
  final bool dense;

  const RtListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.leadingIcon,
    this.leadingIconColor,
    this.trailing,
    this.showChevron = false,
    this.onTap,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final verticalPadding = dense ? RtSpacing.sm : RtSpacing.md;

    return InkWell(
      onTap: onTap,
      borderRadius: RtRadius.borderMd,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: RtSpacing.base,
          vertical: verticalPadding,
        ),
        child: Row(
          children: [
            // Leading: widget personalizado o icono con fondo
            if (leading != null || leadingIcon != null) ...[
              _buildLeading(),
              const SizedBox(width: RtSpacing.md),
            ],

            // Contenido central: titulo y subtitulo
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: RtTypo.titleMedium.copyWith(
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

            // Trailing: widget personalizado o chevron
            if (trailing != null) ...[
              const SizedBox(width: RtSpacing.sm),
              trailing!,
            ] else if (showChevron) ...[
              const SizedBox(width: RtSpacing.sm),
              Icon(
                Icons.chevron_right_rounded,
                color: RtColors.neutral400,
                size: RtIconSize.md,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Construye el widget leading: si hay leadingIcon lo envuelve
  /// en un contenedor con fondo sutil, sino usa el leading directo
  Widget _buildLeading() {
    if (leading != null) return leading!;

    final color = leadingIconColor ?? RtColors.brand;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: RtRadius.borderSm,
      ),
      child: Icon(
        leadingIcon,
        color: color,
        size: RtIconSize.sm,
      ),
    );
  }
}
