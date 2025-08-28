import 'package:flutter/material.dart';

class AppColors {
  // Color principal de Rappi Taxi
  static const Color rappiOrange = Color(0xFFFF6B00);
  static const Color rappiOrangeDark = Color(0xFFE55100); // Naranja más oscuro para mejor contraste
  static const Color rappiOrangeLight = Color(0xFFFF9A4D); // Naranja más claro
  
  // Mantener los nombres antiguos para compatibilidad
  static const Color oasisGreen = rappiOrange;
  static const Color oasisGreenDark = rappiOrangeDark;
  static const Color oasisGreenLight = rappiOrangeLight;
  
  // Colores base con mejor contraste
  static const Color black = Color(0xFF1A1A1A); // Negro más suave
  static const Color white = Colors.white;
  static const Color offWhite = Color(0xFFFAFAFA); // Blanco más suave
  
  // Colores de estado con mejor contraste
  static const Color success = Color(0xFF00A000); // Verde más oscuro
  static const Color error = Color(0xFFDC2626); // Rojo con mejor contraste
  static const Color warning = Color(0xFFF59E0B); // Naranja con mejor contraste
  static const Color info = Color(0xFF3B82F6); // Azul con mejor contraste
  
  // Grises con mejor contraste
  static const Color grey = Color(0xFF6B7280);
  static const Color greyLight = Color(0xFFE5E7EB);
  static const Color greyMedium = Color(0xFF9CA3AF);
  static const Color greyDark = Color(0xFF374151);
  static const Color greyExtraDark = Color(0xFF1F2937);
  
  // Colores de fondo con mejor contraste
  static const Color backgroundLight = Color(0xFFF9FAFB);
  static const Color backgroundMedium = Color(0xFFF3F4F6);
  static const Color backgroundDark = Color(0xFF111827);
  
  // Colores de texto con mejor contraste
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textOnDark = Colors.white;
  static const Color textOnGreen = Colors.white;
}