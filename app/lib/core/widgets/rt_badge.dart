import 'package:flutter/material.dart';

import '../design/rt_colors.dart';
import '../design/rt_tokens.dart';
import '../design/rt_typography.dart';

/// Variantes visuales del badge
enum RtBadgeVariant {
  filled,
  outlined,
  subtle,
}

/// Badge compacto en forma de pastilla (pill)
/// Soporta variantes filled, outlined y subtle
class RtBadge extends StatelessWidget {
  final String label;
  final Color color;
  final RtBadgeVariant variant;
  final IconData? icon;
  final VoidCallback? onTap;

  const RtBadge({
    super.key,
    required this.label,
    this.color = RtColors.brand,
    this.variant = RtBadgeVariant.filled,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: _backgroundColor,
          border: variant == RtBadgeVariant.outlined
              ? Border.all(color: color)
              : null,
          borderRadius: RtRadius.borderFull,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: RtIconSize.xs, color: _foregroundColor),
              const SizedBox(width: RtSpacing.xs),
            ],
            Text(
              label,
              style: RtTypo.labelSmall.copyWith(color: _foregroundColor),
            ),
          ],
        ),
      ),
    );
  }

  Color get _backgroundColor {
    switch (variant) {
      case RtBadgeVariant.filled:
        return color;
      case RtBadgeVariant.outlined:
        return RtColors.transparent;
      case RtBadgeVariant.subtle:
        return color.withValues(alpha: 0.1);
    }
  }

  Color get _foregroundColor {
    switch (variant) {
      case RtBadgeVariant.filled:
        return RtColors.white;
      case RtBadgeVariant.outlined:
        return color;
      case RtBadgeVariant.subtle:
        return color;
    }
  }
}
