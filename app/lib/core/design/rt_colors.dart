import 'package:flutter/material.dart';

/// Paleta de colores unificada de RapiTeam
/// Fuente única de verdad para TODOS los colores de la app
class RtColors {
  RtColors._();

  // ════════════════════════════════════════════
  // BRAND - Identidad corporativa
  // ════════════════════════════════════════════
  static const Color brand = Color(0xFFE31E24);
  static const Color brandDark = Color(0xFFB91C1C);
  static const Color brandLight = Color(0xFFFCA5A5);
  static const Color brandSurface = Color(0xFFFEF2F2);

  // ════════════════════════════════════════════
  // NEUTRALS - Escala de grises (10 niveles)
  // ════════════════════════════════════════════
  static const Color neutral50 = Color(0xFFFAFAFA);
  static const Color neutral100 = Color(0xFFF5F5F5);
  static const Color neutral200 = Color(0xFFE5E5E5);
  static const Color neutral300 = Color(0xFFD4D4D4);
  static const Color neutral400 = Color(0xFFA3A3A3);
  static const Color neutral500 = Color(0xFF737373);
  static const Color neutral600 = Color(0xFF525252);
  static const Color neutral700 = Color(0xFF404040);
  static const Color neutral800 = Color(0xFF262626);
  static const Color neutral900 = Color(0xFF171717);
  static const Color neutral950 = Color(0xFF0A0A0A);

  // ════════════════════════════════════════════
  // SEMÁNTICOS - Estados y feedback
  // ════════════════════════════════════════════
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color successDark = Color(0xFF059669);

  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color warningDark = Color(0xFFD97706);

  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color errorDark = Color(0xFFDC2626);

  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);
  static const Color infoDark = Color(0xFF2563EB);

  // ════════════════════════════════════════════
  // ACCENT - Colores complementarios
  // ════════════════════════════════════════════
  static const Color accentBlue = Color(0xFF1E40AF);
  static const Color accentAmber = Color(0xFFD97706);
  static const Color accentEmerald = Color(0xFF059669);
  static const Color accentPurple = Color(0xFF7C3AED);

  // ════════════════════════════════════════════
  // UTILIDAD
  // ════════════════════════════════════════════
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color transparent = Color(0x00000000);

  // ════════════════════════════════════════════
  // COMPATIBILIDAD - Alias para migración gradual
  // Estos alias permiten cambiar las referencias de
  // ModernTheme.* y AppColors.* al nuevo sistema
  // ════════════════════════════════════════════

  // ModernTheme aliases
  static const Color rapiteamRed = brand;
  static const Color rapiteamRedDark = brandDark;
  static const Color rapiteamRedLight = brandLight;
  static const Color rapiteamBlack = neutral950;
  static const Color rapiteamWhite = white;
  static const Color rapiteamGreen = brand; // Alias confuso original, apunta a brand
  static const Color primaryOrange = brand;
  static const Color primaryBlue = info;
  static const Color primary = brand;
}
