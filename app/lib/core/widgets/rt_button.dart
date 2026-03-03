import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/rt_colors.dart';
import '../design/rt_tokens.dart';
import '../design/rt_typography.dart';

/// Variantes visuales del boton
enum RtButtonVariant { primary, secondary, outlined, ghost, danger }

/// Tamanos disponibles del boton
enum RtButtonSize { small, medium, large }

/// Boton reutilizable del design system de RapiTeam.
///
/// Soporta 5 variantes visuales, 3 tamanos, estado de carga,
/// icono opcional y animacion de press (scale).
///
/// Ejemplo de uso:
/// ```dart
/// RtButton(
///   label: 'Solicitar viaje',
///   onPressed: () => _requestRide(),
///   variant: RtButtonVariant.primary,
///   icon: Icons.local_taxi,
/// )
/// ```
class RtButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final RtButtonVariant variant;
  final RtButtonSize size;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;

  const RtButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = RtButtonVariant.primary,
    this.size = RtButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
  });

  @override
  State<RtButton> createState() => _RtButtonState();
}

class _RtButtonState extends State<RtButton> {
  bool _isPressed = false;

  bool get _isDisabled => widget.onPressed == null;
  bool get _isInteractive => !_isDisabled && !widget.isLoading;

  // ════════════════════════════════════════════
  // DIMENSIONES SEGUN TAMANO
  // ════════════════════════════════════════════

  double get _height {
    switch (widget.size) {
      case RtButtonSize.small:
        return 40.0;
      case RtButtonSize.medium:
        return 48.0;
      case RtButtonSize.large:
        return 56.0;
    }
  }

  EdgeInsets get _padding {
    switch (widget.size) {
      case RtButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: RtSpacing.md, vertical: RtSpacing.sm);
      case RtButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: RtSpacing.base, vertical: RtSpacing.md);
      case RtButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: RtSpacing.xl, vertical: RtSpacing.base);
    }
  }

  TextStyle get _textStyle {
    switch (widget.size) {
      case RtButtonSize.small:
        return RtTypo.labelMedium;
      case RtButtonSize.medium:
        return RtTypo.labelLarge;
      case RtButtonSize.large:
        return RtTypo.titleLarge.copyWith(fontWeight: FontWeight.w600);
    }
  }

  double get _iconSize {
    switch (widget.size) {
      case RtButtonSize.small:
        return RtIconSize.xs;
      case RtButtonSize.medium:
        return RtIconSize.sm;
      case RtButtonSize.large:
        return RtIconSize.md;
    }
  }

  double get _loaderSize {
    switch (widget.size) {
      case RtButtonSize.small:
        return 16.0;
      case RtButtonSize.medium:
        return 20.0;
      case RtButtonSize.large:
        return 24.0;
    }
  }

  // ════════════════════════════════════════════
  // COLORES SEGUN VARIANTE
  // ════════════════════════════════════════════

  Color get _backgroundColor {
    switch (widget.variant) {
      case RtButtonVariant.primary:
        return RtColors.brand;
      case RtButtonVariant.secondary:
        return RtColors.neutral900;
      case RtButtonVariant.outlined:
        return RtColors.transparent;
      case RtButtonVariant.ghost:
        return RtColors.transparent;
      case RtButtonVariant.danger:
        return RtColors.error;
    }
  }

  Color get _foregroundColor {
    switch (widget.variant) {
      case RtButtonVariant.primary:
        return RtColors.white;
      case RtButtonVariant.secondary:
        return RtColors.white;
      case RtButtonVariant.outlined:
        return RtColors.brand;
      case RtButtonVariant.ghost:
        return RtColors.brand;
      case RtButtonVariant.danger:
        return RtColors.white;
    }
  }

  BorderSide? get _borderSide {
    if (widget.variant == RtButtonVariant.outlined) {
      return const BorderSide(color: RtColors.brand, width: 1.5);
    }
    return null;
  }

  // ════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final content = _buildContent();

    return AnimatedScale(
      scale: _isPressed ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 100),
      curve: RtCurve.enter,
      child: AnimatedOpacity(
        opacity: _isDisabled ? 0.5 : 1.0,
        duration: RtDuration.fast,
        child: SizedBox(
          width: widget.isFullWidth ? double.infinity : null,
          height: _height,
          child: GestureDetector(
            onTapDown: _isInteractive ? (_) => _setPressed(true) : null,
            onTapUp: _isInteractive ? (_) => _setPressed(false) : null,
            onTapCancel: _isInteractive ? () => _setPressed(false) : null,
            child: MaterialButton(
              onPressed: _isInteractive ? _handleTap : null,
              color: _backgroundColor,
              textColor: _foregroundColor,
              disabledColor: _backgroundColor,
              disabledTextColor: _foregroundColor,
              elevation: 0,
              focusElevation: 0,
              hoverElevation: 0,
              highlightElevation: 0,
              padding: _padding,
              shape: RoundedRectangleBorder(
                borderRadius: RtRadius.borderMd,
                side: _borderSide ?? BorderSide.none,
              ),
              splashColor: _foregroundColor.withValues(alpha: 0.1),
              highlightColor: _foregroundColor.withValues(alpha: 0.05),
              child: content,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (widget.isLoading) {
      return SizedBox(
        width: _loaderSize,
        height: _loaderSize,
        child: CircularProgressIndicator(
          strokeWidth: 2.0,
          valueColor: AlwaysStoppedAnimation<Color>(_foregroundColor),
        ),
      );
    }

    final labelWidget = Text(
      widget.label,
      style: _textStyle.copyWith(color: _foregroundColor),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    if (widget.icon == null) {
      return labelWidget;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(widget.icon, size: _iconSize, color: _foregroundColor),
        const SizedBox(width: RtSpacing.sm),
        Flexible(child: labelWidget),
      ],
    );
  }

  /// Ejecuta haptic feedback según la variante y luego invoca el callback.
  /// La variante [danger] usa mediumImpact para reforzar la gravedad de la accion.
  /// Las demas variantes usan lightImpact como feedback sutil.
  void _handleTap() {
    if (!_isInteractive) return;

    if (widget.variant == RtButtonVariant.danger) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }

    widget.onPressed?.call();
  }

  void _setPressed(bool value) {
    setState(() => _isPressed = value);
  }
}
