import 'package:flutter/material.dart';

import '../design/rt_colors.dart';
import '../design/rt_tokens.dart';
import '../design/rt_typography.dart';

/// Card de estadistica con icono, valor, label y delta opcional.
/// Soporta fondo con gradiente para destacar metricas importantes.
class RtStatsCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final String? delta;
  final bool? deltaPositive;
  final LinearGradient? gradient;

  const RtStatsCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.iconColor = RtColors.brand,
    this.delta,
    this.deltaPositive,
    this.gradient,
  });

  bool get _hasGradient => gradient != null;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(RtSpacing.base),
      decoration: BoxDecoration(
        gradient: gradient,
        color: _hasGradient ? null : _surfaceColor(isDark),
        borderRadius: RtRadius.borderMd,
        boxShadow: _hasGradient ? RtShadow.medium() : RtShadow.soft(isDark: isDark),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildIconCircle(),
          const SizedBox(height: RtSpacing.md),
          _buildValue(),
          const SizedBox(height: RtSpacing.xs),
          _buildLabel(),
          if (delta != null) ...[
            const SizedBox(height: RtSpacing.sm),
            _buildDelta(),
          ],
        ],
      ),
    );
  }

  /// Icono dentro de un circulo con color al 10% de opacidad
  Widget _buildIconCircle() {
    final Color circleColor = _hasGradient
        ? RtColors.white.withValues(alpha: 0.2)
        : iconColor.withValues(alpha: 0.1);
    final Color iconTint = _hasGradient ? RtColors.white : iconColor;

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: circleColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: RtIconSize.md, color: iconTint),
    );
  }

  /// Valor principal en tipografia displaySmall
  Widget _buildValue() {
    return Text(
      value,
      style: RtTypo.displaySmall.copyWith(
        color: _hasGradient ? RtColors.white : null,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// Label descriptivo en tipografia bodySmall
  Widget _buildLabel() {
    return Text(
      label,
      style: RtTypo.bodySmall.copyWith(
        color: _hasGradient
            ? RtColors.white.withValues(alpha: 0.8)
            : RtColors.neutral500,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// Badge de delta (variacion porcentual)
  Widget _buildDelta() {
    final bool isPositive = deltaPositive ?? true;
    final Color deltaColor = isPositive ? RtColors.success : RtColors.error;
    final IconData deltaIcon = isPositive
        ? Icons.trending_up_rounded
        : Icons.trending_down_rounded;

    final Color bgColor = _hasGradient
        ? RtColors.white.withValues(alpha: 0.2)
        : deltaColor.withValues(alpha: 0.1);
    final Color fgColor = _hasGradient ? RtColors.white : deltaColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: RtRadius.borderFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(deltaIcon, size: 14, color: fgColor),
          const SizedBox(width: 2),
          Text(
            delta!,
            style: RtTypo.labelSmall.copyWith(
              color: fgColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _surfaceColor(bool isDark) {
    return isDark ? RtColors.neutral900 : RtColors.white;
  }
}
