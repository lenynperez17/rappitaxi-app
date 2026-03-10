import 'package:flutter/material.dart';

class AppColors {
  // Color principal de Rappi Team - Rojo corporativo
  static const Color rappiRed = Color(0xFFE31E24);
  static const Color rappiRedDark = Color(0xFFB91C1C);
  static const Color rappiRedLight = Color(0xFFFCA5A5);

  // Aliases principales
  static const Color primary = rappiRed;
  // Backward compatibility aliases
  static const Color rappiOrange = rappiRed;
  static const Color rappiOrangeDark = rappiRedDark;
  static const Color rappiOrangeLight = rappiRedLight;
  static const Color rappiBlack = Color(0xFF000000);
  static const Color rappiWhite = Color(0xFFFFFFFF);
  static const Color white = rappiWhite;

  // Aliases para compatibilidad
  static const Color rappiTurquoise = rappiRed;
  static const Color rappiTurquoiseDark = rappiRedDark;
  static const Color rappiTurquoiseLight = rappiRedLight;

  // Colores base con mejor contraste
  static const Color black = Color(0xFF1A1A1A);
  static const Color offWhite = Color(0xFFFAFAFA);

  // Colores de estado
  static const Color success = Color(0xFF00A000);
  static const Color error = Color(0xFFDC2626);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // Grises
  static const Color grey = Color(0xFF6B7280);
  static const Color greyLight = Color(0xFFD1D5DB); // Darkened for better contrast
  static const Color greyMedium = Color(0xFF9CA3AF);
  static const Color greyDark = Color(0xFF374151);
  static const Color greyExtraDark = Color(0xFF1F2937);

  // Colores de fondo
  static const Color backgroundLight = Color(0xFFF9FAFB);
  static const Color backgroundMedium = Color(0xFFF3F4F6);
  static const Color backgroundDark = Color(0xFF111827);

  // Colores de texto
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textOnDark = Colors.white;
  static const Color textOnPrimary = Colors.white;
  static const Color textOnOrange = Colors.white;
}
