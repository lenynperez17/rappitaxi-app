import 'package:flutter/material.dart';
import 'rt_colors.dart';
import 'rt_tokens.dart';

/// Extensiones de BuildContext para acceso rápido al design system
extension RtThemeContext on BuildContext {
  // ════════════════════════════════════════════
  // ACCESOS RÁPIDOS AL TEMA
  // ════════════════════════════════════════════
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  // ════════════════════════════════════════════
  // COLORES ADAPTATIVOS (cambian con dark/light)
  // ════════════════════════════════════════════

  /// Texto principal (títulos, contenido importante)
  Color get primaryText => colors.onSurface;

  /// Texto secundario (subtítulos, descripciones)
  Color get secondaryText => colors.onSurface.withValues(alpha: 0.6);

  /// Texto terciario (hints, placeholders, timestamps)
  Color get tertiaryText => colors.onSurface.withValues(alpha: 0.4);

  /// Color de superficie (cards, containers)
  Color get surfaceColor => colors.surface;

  /// Color de fondo (scaffold)
  Color get backgroundColor => theme.scaffoldBackgroundColor;

  /// Color primario de marca
  Color get primaryColor => colors.primary;

  /// Color sobre el primario (texto sobre fondo brand)
  Color get onPrimaryText => colors.onPrimary;

  /// Color de error
  Color get errorColor => colors.error;

  /// Color de borde/outline
  Color get outlineColor => colors.outline;

  /// Color de borde suave
  Color get outlineVariant => colors.outlineVariant;

  // ════════════════════════════════════════════
  // COLORES SEMÁNTICOS (constantes, independientes del tema)
  // ════════════════════════════════════════════
  Color get successColor => RtColors.success;
  Color get warningColor => RtColors.warning;
  Color get infoColor => RtColors.info;

  // ════════════════════════════════════════════
  // SOMBRAS ADAPTATIVAS
  // ════════════════════════════════════════════
  List<BoxShadow> get softShadow => RtShadow.soft(isDark: isDark);
  List<BoxShadow> get mediumShadow => RtShadow.medium(isDark: isDark);
  List<BoxShadow> get strongShadow => RtShadow.strong(isDark: isDark);

  // ════════════════════════════════════════════
  // UTILIDADES
  // ════════════════════════════════════════════

  /// Tamaño de pantalla
  Size get screenSize => MediaQuery.sizeOf(this);
  double get screenWidth => screenSize.width;
  double get screenHeight => screenSize.height;
  EdgeInsets get screenPadding => MediaQuery.paddingOf(this);
}

// La extensión ThemeColors (vieja) se mantiene en
// core/extensions/theme_extensions.dart para compatibilidad
