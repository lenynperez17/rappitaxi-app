import 'package:flutter/material.dart';

import '../design/rt_colors.dart';
import '../design/rt_tokens.dart';

/// Variantes visuales disponibles para RtCard
enum RtCardVariant {
  /// Sombra suave con fondo surface
  elevated,

  /// Borde neutral200 sin sombra
  outlined,

  /// Fondo neutral100 (claro) o neutral800 (oscuro)
  filled,
}

/// Card reutilizable del design system RapiTeam.
/// Soporta 3 variantes visuales, animacion de tap y dark mode automático.
class RtCard extends StatefulWidget {
  final Widget child;
  final RtCardVariant variant;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final BorderRadius? _borderRadius;

  /// Resuelve el borderRadius: usa el valor proporcionado o RtRadius.borderMd
  BorderRadius get borderRadius => _borderRadius ?? RtRadius.borderMd;

  const RtCard({
    super.key,
    required this.child,
    this.variant = RtCardVariant.elevated,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    BorderRadius? borderRadius,
  }) : _borderRadius = borderRadius;

  @override
  State<RtCard> createState() => _RtCardState();
}

class _RtCardState extends State<RtCard> {
  bool _isPressed = false;

  bool get _isTappable => widget.onTap != null;

  void _handleTapDown(TapDownDetails details) {
    if (!_isTappable) return;
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails details) {
    if (!_isTappable) return;
    setState(() => _isPressed = false);
  }

  void _handleTapCancel() {
    if (!_isTappable) return;
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedScale(
      scale: _isPressed ? 0.98 : 1.0,
      duration: RtDuration.fast,
      curve: RtCurve.enter,
      child: Container(
        margin: widget.margin,
        decoration: _buildDecoration(isDark),
        child: Material(
          color: Colors.transparent,
          borderRadius: widget.borderRadius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onTapDown: _handleTapDown,
            onTapUp: _handleTapUp,
            onTapCancel: _handleTapCancel,
            borderRadius: widget.borderRadius,
            splashColor: _isTappable
                ? RtColors.brand.withValues(alpha: 0.08)
                : Colors.transparent,
            highlightColor: Colors.transparent,
            child: Padding(
              padding: widget.padding,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _buildDecoration(bool isDark) {
    switch (widget.variant) {
      case RtCardVariant.elevated:
        return BoxDecoration(
          color: isDark ? RtColors.neutral900 : RtColors.white,
          borderRadius: widget.borderRadius,
          boxShadow: RtShadow.soft(isDark: isDark),
        );

      case RtCardVariant.outlined:
        return BoxDecoration(
          color: isDark ? RtColors.neutral900 : RtColors.white,
          borderRadius: widget.borderRadius,
          border: Border.all(
            color: isDark ? RtColors.neutral700 : RtColors.neutral200,
          ),
        );

      case RtCardVariant.filled:
        return BoxDecoration(
          color: isDark ? RtColors.neutral800 : RtColors.neutral100,
          borderRadius: widget.borderRadius,
        );
    }
  }
}
