import 'package:flutter/material.dart';

class ModernTheme {
  // Colores corporativos de Rappi Team
  static const Color rappiOrange = Color(0xFFE31E24);
  static const Color rappiBlack = Color(0xFF2C2C2C); // Cambiado de negro puro a gris oscuro
  static const Color rappiWhite = Color(0xFFFFFFFF);
  static const Color accentGray = Color(0xFF6B6B6B); // Gris más claro para mejor contraste
  static const Color lightGray = Color(0xFFF8F8F8);
  
  // Aliases para compatibilidad con el código existing
  static const Color primaryOrange = rappiOrange; 
  static const Color primaryBlue = Color(0xFF2196F3);
  static const Color darkBlue = Color(0xFF1976D2);
  static const Color accentYellow = Color(0xFFFFC107);
  static const Color cardDark = Color(0xFF1A1D35);
  
  // Colores de fondo
  static const Color background = Color(0xFFF8F9FD);
  static const Color backgroundLight = Color(0xFFF0F1F5); // Slightly darker for better contrast
  static const Color backgroundDark = Color(0xFF1E2937);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color cardBackgroundDark = Color(0xFF2D3748);
  
  // Colores de texto
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textLight = Color(0xFFFFFFFF);
  
  // Colores de estado
  static const Color success = Color(0xFF00C896);
  static const Color warning = Color(0xFFFFB547);
  static const Color error = Color(0xFFFF4757);
  static const Color info = Color(0xFF00B8D4);
  
  // Getter para borderColor
  static Color get borderColor => Color(0xFFE0E0E0);
  
  // Gradientes modernos con colores corporativos
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [rappiOrange, Color(0xFF00A000)],
  );
  
  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF4A5568), Color(0xFF2D3748)],
  );
  
  static const LinearGradient lightGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [rappiWhite, lightGray],
  );
  
  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [rappiOrange, Color(0xFFFF8533)],
  );
  
  // Sombras modernas adaptativas al tema
  static List<BoxShadow> getCardShadow(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: isDark
          ? Color(0xFF000000).withValues(alpha: 0.3)
          : Color(0xFF000000).withValues(alpha: 0.08),
        blurRadius: 20,
        offset: Offset(0, 10),
        spreadRadius: 0,
      ),
    ];
  }

  static List<BoxShadow> getButtonShadow(BuildContext context) {
    return [
      BoxShadow(
        color: rappiOrange.withValues(alpha: 0.3),
        blurRadius: 15,
        offset: Offset(0, 8),
        spreadRadius: 0,
      ),
    ];
  }

  static List<BoxShadow> getFloatingShadow(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: isDark
          ? Color(0xFF000000).withValues(alpha: 0.4)
          : Color(0xFF000000).withValues(alpha: 0.15),
        blurRadius: 30,
        offset: Offset(0, 15),
        spreadRadius: 0,
      ),
    ];
  }

  // DEPRECATED: Use getCardShadow(context) instead
  @Deprecated('Use getCardShadow(context) for theme-aware shadows')
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0xFF000000).withValues(alpha: 0.08),
      blurRadius: 20,
      offset: Offset(0, 10),
      spreadRadius: 0,
    ),
  ];

  // DEPRECATED: Use getButtonShadow(context) instead
  @Deprecated('Use getButtonShadow(context) for theme-aware shadows')
  static List<BoxShadow> buttonShadow = [
    BoxShadow(
      color: rappiOrange.withValues(alpha: 0.3),
      blurRadius: 15,
      offset: Offset(0, 8),
      spreadRadius: 0,
    ),
  ];

  // DEPRECATED: Use getFloatingShadow(context) instead
  @Deprecated('Use getFloatingShadow(context) for theme-aware shadows')
  static List<BoxShadow> floatingShadow = [
    BoxShadow(
      color: Color(0xFF000000).withValues(alpha: 0.15),
      blurRadius: 30,
      offset: Offset(0, 15),
      spreadRadius: 0,
    ),
  ];
  
  // Temas
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: rappiOrange,
    scaffoldBackgroundColor: backgroundLight,
    colorScheme: ColorScheme.light(
      primary: rappiOrange,
      secondary: rappiBlack,
      surface: cardBackground,
      error: error,
    ),
    fontFamily: 'SF Pro Display',
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: textPrimary),
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: rappiOrange,
        foregroundColor: rappiWhite,
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: cardBackground,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFFF3F4F6), // grey.shade100 equivalent - visible against white
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Color(0xFFBDBDBD), width: 1), // grey.shade400
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Color(0xFFBDBDBD), width: 1), // grey.shade400 - visible border
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: rappiOrange, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: error, width: 1.5),
      ),
      hintStyle: TextStyle(
        color: Color(0xFF78909C), // blueGrey[400] - darker hint for readability
        fontSize: 14,
      ),
      labelStyle: TextStyle(
        color: Color(0xFF546E7A), // blueGrey[600] - darker label for readability
        fontSize: 14,
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: cardBackground,
      selectedItemColor: rappiOrange,
      unselectedItemColor: textSecondary,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    dividerTheme: DividerThemeData(
      color: Color(0xFFD1D5DB), // grey.shade300 - visible divider
      thickness: 1,
      space: 1,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: rappiOrange,
    scaffoldBackgroundColor: backgroundDark,
    colorScheme: ColorScheme.dark(
      primary: rappiOrange,
      secondary: rappiBlack,
      surface: cardBackgroundDark,
      error: error,
    ),
    fontFamily: 'SF Pro Display',
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: textLight),
      titleTextStyle: TextStyle(
        color: textLight,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: rappiOrange,
        foregroundColor: rappiWhite,
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: cardBackgroundDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFF374151), // Gris oscuro para campos de texto
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Color(0xFF4B5563), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: rappiOrange, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: error, width: 1),
      ),
      hintStyle: TextStyle(
        color: Color(0xFF9CA3AF), // Gris claro para hints
        fontSize: 14,
      ),
      labelStyle: TextStyle(
        color: Color(0xFF9CA3AF), // Gris claro para labels
        fontSize: 14,
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: cardBackgroundDark,
      selectedItemColor: rappiOrange,
      unselectedItemColor: textSecondary,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    dividerTheme: DividerThemeData(
      color: Color(0xFF374151), // Gris oscuro para divisores
      thickness: 1,
      space: 1,
    ),
    textTheme: TextTheme(
      displayLarge: TextStyle(color: textLight),
      displayMedium: TextStyle(color: textLight),
      displaySmall: TextStyle(color: textLight),
      headlineLarge: TextStyle(color: textLight),
      headlineMedium: TextStyle(color: textLight),
      headlineSmall: TextStyle(color: textLight),
      titleLarge: TextStyle(color: textLight),
      titleMedium: TextStyle(color: textLight),
      titleSmall: TextStyle(color: textLight),
      bodyLarge: TextStyle(color: textLight),
      bodyMedium: TextStyle(color: textLight),
      bodySmall: TextStyle(color: Color(0xFF9CA3AF)),
      labelLarge: TextStyle(color: textLight),
      labelMedium: TextStyle(color: textLight),
      labelSmall: TextStyle(color: Color(0xFF9CA3AF)),
    ),
  );
}