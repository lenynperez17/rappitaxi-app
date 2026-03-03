import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/rt_colors.dart';
import '../design/rt_tokens.dart';
import '../design/rt_typography.dart';

/// Campo de texto reutilizable del design system de RapiTeam.
///
/// Wrapper de [TextFormField] que aplica automáticamente los tokens
/// del design system (colores, radii, tipografia) y agrega una
/// animacion de color en el prefixIcon al enfocar el campo.
///
/// Ejemplo de uso:
/// ```dart
/// RtTextField(
///   controller: _emailController,
///   label: 'Correo electronico',
///   hint: 'tu@email.com',
///   prefixIcon: Icons.email_outlined,
///   keyboardType: TextInputType.emailAddress,
///   validator: (v) => v!.isEmpty ? 'Campo requerido' : null,
/// )
/// ```
class RtTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helperText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final int? maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final String? initialValue;
  final VoidCallback? onTap;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;

  const RtTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helperText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.autofillHints,
    this.textInputAction,
    this.focusNode,
    this.initialValue,
    this.onTap,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  State<RtTextField> createState() => _RtTextFieldState();
}

class _RtTextFieldState extends State<RtTextField> {
  late final FocusNode _effectiveFocusNode;
  bool _hasFocus = false;

  // Indica si se debe gestionar el FocusNode internamente
  bool get _ownsNode => widget.focusNode == null;

  @override
  void initState() {
    super.initState();
    _effectiveFocusNode = widget.focusNode ?? FocusNode();
    _effectiveFocusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(RtTextField oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Si el FocusNode externo cambio, actualizar la suscripcion
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.removeListener(_onFocusChanged);
      if (_ownsNode) {
        // Se paso de externo a interno: crear uno nuevo
        _effectiveFocusNode.removeListener(_onFocusChanged);
        _effectiveFocusNode.dispose();
      }
      final newNode = widget.focusNode ?? FocusNode();
      newNode.addListener(_onFocusChanged);
      // ignore: invalid_use_of_protected_member
      setState(() {});
    }
  }

  @override
  void dispose() {
    _effectiveFocusNode.removeListener(_onFocusChanged);
    if (_ownsNode) {
      _effectiveFocusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChanged() {
    setState(() => _hasFocus = _effectiveFocusNode.hasFocus);
  }

  // ════════════════════════════════════════════
  // COLORES DEL CAMPO
  // ════════════════════════════════════════════

  Color get _prefixIconColor {
    if (!widget.enabled) return RtColors.neutral400;
    if (_hasFocus) return RtColors.brand;
    return RtColors.neutral500;
  }

  Color get _fillColor {
    if (!widget.enabled || widget.readOnly) {
      return RtColors.neutral100;
    }
    return RtColors.white;
  }

  // ════════════════════════════════════════════
  // DECORACION DEL INPUT
  // ════════════════════════════════════════════

  InputDecoration get _decoration {
    final borderRadius = BorderRadius.circular(RtRadius.md);

    return InputDecoration(
      labelText: widget.label,
      hintText: widget.hint,
      helperText: widget.helperText,
      helperMaxLines: 2,
      counterText: widget.maxLength != null ? null : '',
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      filled: true,
      fillColor: _fillColor,

      // Tipografia
      labelStyle: RtTypo.bodyMedium.copyWith(color: RtColors.neutral500),
      hintStyle: RtTypo.bodyMedium.copyWith(color: RtColors.neutral400),
      helperStyle: RtTypo.bodySmall.copyWith(color: RtColors.neutral500),
      floatingLabelStyle: RtTypo.labelMedium.copyWith(
        color: _hasFocus ? RtColors.brand : RtColors.neutral500,
      ),
      errorStyle: RtTypo.bodySmall.copyWith(color: RtColors.error),

      // Padding interno
      contentPadding: const EdgeInsets.symmetric(
        horizontal: RtSpacing.base,
        vertical: RtSpacing.base,
      ),

      // Icono prefijo con animacion de color
      prefixIcon: widget.prefixIcon != null
          ? AnimatedSwitcher(
              duration: RtDuration.fast,
              child: Icon(
                widget.prefixIcon,
                key: ValueKey<Color>(_prefixIconColor),
                color: _prefixIconColor,
                size: RtIconSize.md,
              ),
            )
          : null,

      suffixIcon: widget.suffixIcon,

      // Bordes
      border: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: const BorderSide(color: RtColors.neutral300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: const BorderSide(color: RtColors.neutral300, width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: const BorderSide(color: RtColors.brand, width: 2.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: const BorderSide(color: RtColors.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: const BorderSide(color: RtColors.error, width: 2.0),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: const BorderSide(color: RtColors.neutral200, width: 1.0),
      ),
    );
  }

  // ════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: _effectiveFocusNode,
      initialValue: widget.controller == null ? widget.initialValue : null,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      obscureText: widget.obscureText,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      maxLength: widget.maxLength,
      keyboardType: widget.keyboardType,
      textCapitalization: widget.textCapitalization,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      inputFormatters: widget.inputFormatters,
      onChanged: widget.onChanged,
      onTap: widget.onTap,
      onFieldSubmitted: widget.onFieldSubmitted,
      validator: widget.validator,
      style: RtTypo.bodyLarge.copyWith(color: RtColors.neutral900),
      cursorColor: RtColors.brand,
      decoration: _decoration,
    );
  }
}
