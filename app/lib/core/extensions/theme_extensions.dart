import 'package:flutter/material.dart';
import '../theme/modern_theme.dart';

/// Extensión para acceder fácilmente a los colores del tema actual
/// Esta extensión permite obtener colores que se adaptan automáticamente al modo claro/oscuro
extension ThemeColors on BuildContext {
  /// Color de texto principal que se adapta al tema
  /// Modo claro: texto oscuro (#1A1A2E)
  /// Modo oscuro: texto claro (automático por Material 3)
  Color get primaryText => Theme.of(this).colorScheme.onSurface;

  /// Color de texto secundario (con opacidad) que se adapta al tema
  /// Modo claro: texto gris oscuro con 60% opacidad
  /// Modo oscuro: texto claro con 60% opacidad
  Color get secondaryText => Theme.of(this).colorScheme.onSurface.withValues(alpha: 0.6);

  /// Color de superficie (cards, containers) que se adapta al tema
  /// Modo claro: blanco (#FFFFFF)
  /// Modo oscuro: gris oscuro (#2D3748)
  Color get surfaceColor => Theme.of(this).colorScheme.surface;

  /// Color de fondo principal que se adapta al tema
  /// Modo claro: gris muy claro (#F8F9FD)
  /// Modo oscuro: azul-gris oscuro (#1E2937)
  Color get backgroundColor => Theme.of(this).scaffoldBackgroundColor;

  /// Color primario corporativo (Rappi Team Green - no cambia con el tema)
  Color get primaryColor => ModernTheme.rappiOrange;

  /// Color de error que se adapta al tema
  Color get errorColor => Theme.of(this).colorScheme.error;

  /// Color de éxito (verde corporativo)
  Color get successColor => ModernTheme.success;

  /// Color de advertencia (naranja)
  Color get warningColor => ModernTheme.warning;

  /// Color de información (azul claro)
  Color get infoColor => ModernTheme.info;

  /// Color de texto sobre el color primario
  Color get onPrimaryText => Theme.of(this).colorScheme.onPrimary;

  /// Color de texto con opacidad personalizada
  Color textWithOpacity(double opacity) =>
      Theme.of(this).colorScheme.onSurface.withValues(alpha: opacity);
}
