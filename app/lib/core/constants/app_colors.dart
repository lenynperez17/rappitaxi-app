import 'package:flutter/material.dart';

class AppColors {
  // ============================================================================
  // COLORES PRINCIPALES RAPPI TEAM
  // ============================================================================

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

  // ============================================================================
  // COLORES ESTILO INDRIVE (para UI minimalista de pasajero)
  // ============================================================================

  /// Green inDrive - Main color for CTA buttons and active elements
  static const Color inDriveGreen = Color(0xFF10B981);

  /// Dark green inDrive - For hover states and variations
  static const Color inDriveGreenDark = Color(0xFF059669);

  /// Light green inDrive - For backgrounds and soft selected states
  static const Color inDriveGreenLight = Color(0xFFD1FAE5);

  /// Yellow inDrive - For alternative CTA buttons
  static const Color inDriveYellow = Color(0xFFFBBF24);

  /// Dark yellow inDrive - For hover states
  static const Color inDriveYellowDark = Color(0xFFF59E0B);

  /// Light grey inDrive - For field backgrounds and cards
  static const Color inDriveGrey = Color(0xFFF3F4F6);

  /// Lime green CTA inDrive - Main "Find offers" button
  static const Color ctaGreen = Color(0xFFBEF264);

  /// Searching orange - Driver search progress bar
  static const Color searchingOrange = Color(0xFFFB923C);

  /// Cancel pill - "Cancel request" button background
  static const Color cancelPill = Color(0xFFFDA4AF);

  /// Price black - Large price text
  static const Color priceBlack = Color(0xFF111827);

  /// InDrive green gradient
  static const LinearGradient inDriveGradient = LinearGradient(
    colors: [inDriveGreen, inDriveGreenDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Accept offer gradient - Yellow to Green ("Accept" button)
  static const LinearGradient acceptGradient = LinearGradient(
    colors: [Color(0xFFFBBF24), Color(0xFF4ADE80)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// CTA lime green gradient
  static const LinearGradient ctaGreenGradient = LinearGradient(
    colors: [Color(0xFFBEF264), Color(0xFF84CC16)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ============================================================================
  // COLORES DE ESTADO
  // ============================================================================

  static const Color success = Color(0xFF00A000);
  static const Color error = Color(0xFFDC2626);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  /// State color variations
  static const Color successLight = Color(0xFFB9F6CA);
  static const Color warningLight = Color(0xFFFFE57F);
  static const Color errorLight = Color(0xFFFFCDD2);
  static const Color infoLight = Color(0xFFB3E5FC);

  // ============================================================================
  // ESCALA DE GRISES (Material Design inspired)
  // ============================================================================

  static const Color grey50 = Color(0xFFFAFAFA);
  static const Color grey100 = Color(0xFFF5F5F5);
  static const Color grey200 = Color(0xFFEEEEEE);
  static const Color grey300 = Color(0xFFE0E0E0);
  static const Color grey400 = Color(0xFFBDBDBD);
  static const Color grey500 = Color(0xFF9E9E9E);
  static const Color grey600 = Color(0xFF757575);
  static const Color grey700 = Color(0xFF616161);
  static const Color grey800 = Color(0xFF424242);
  static const Color grey900 = Color(0xFF212121);

  // Aliases for compatibility
  static const Color grey = Color(0xFF6B7280);
  static const Color greyLight = Color(0xFFD1D5DB);
  static const Color greyMedium = Color(0xFF9CA3AF);
  static const Color greyDark = Color(0xFF374151);
  static const Color greyExtraDark = Color(0xFF1F2937);

  // ============================================================================
  // COLORES DE FONDO
  // ============================================================================

  static const Color backgroundLight = Color(0xFFF9FAFB);
  static const Color backgroundMedium = Color(0xFFF3F4F6);
  static const Color backgroundDark = Color(0xFF111827);
  static const Color scaffoldBackground = white;

  // ============================================================================
  // COLORES DE TEXTO
  // ============================================================================

  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = grey500;
  static const Color textOnDark = Colors.white;
  static const Color textOnPrimary = Colors.white;
  static const Color textOnOrange = Colors.white;
  static const Color textHint = grey400;

  // ============================================================================
  // OVERLAYS Y SOMBRAS
  // ============================================================================

  static const Color overlay = Color(0x80000000);
  static const Color overlayLight = Color(0x40000000);
  static const Color cardShadow = Color(0x1A000000);
  static const Color elevation = Color(0x1F000000);

  // ============================================================================
  // COLORES PARA MAPAS Y NAVEGACION
  // ============================================================================

  static const Color routeColor = rappiOrange;
  static const Color routeColorActive = rappiOrangeDark;
  static const Color pickupMarker = textPrimary;
  static const Color dropoffMarker = rappiOrange;
  static const Color driverMarker = rappiOrangeDark;
  static const Color currentLocationMarker = info;

  // ============================================================================
  // COLORES PARA ESTADOS DE VIAJE
  // ============================================================================

  static const Color tripRequested = warning;
  static const Color tripAccepted = info;
  static const Color tripActive = rappiOrange;
  static const Color tripArriving = rappiOrangeDark;
  static const Color tripInProgress = textPrimary;
  static const Color tripCompleted = success;
  static const Color tripCancelled = grey500;
  static const Color tripPending = warning;

  // ============================================================================
  // GRADIENTES PREDEFINIDOS
  // ============================================================================

  /// Main gradient (for buttons, headers)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [rappiOrange, rappiOrangeDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Horizontal gradient
  static const LinearGradient primaryGradientHorizontal = LinearGradient(
    colors: [rappiOrange, rappiOrangeDark],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Dark gradient (for backgrounds, appbars)
  static const LinearGradient darkGradient = LinearGradient(
    colors: [backgroundDark, Color(0xFF0D1A23)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Success gradient
  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF00C853), Color(0xFF00A844)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Soft background gradient
  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [white, grey50],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ============================================================================
  // COLORES PARA ROLES DE USUARIO
  // ============================================================================

  static const Color passengerColor = rappiOrange;
  static const Color driverColor = textPrimary;
  static const Color adminColor = rappiOrangeDark;

  // ============================================================================
  // METODOS UTILITARIOS
  // ============================================================================

  /// Get color with custom opacity
  static Color withOpacity(Color color, double opacity) {
    return color.withValues(alpha: opacity);
  }

  /// Convert hex string to Color
  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  /// Get automatic contrast color for text over a background
  static Color getContrastColor(Color backgroundColor) {
    final double luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? textPrimary : white;
  }

  /// Get custom shadow for cards and elevations
  static List<BoxShadow> getCardShadow({double elevation = 2}) {
    return [
      BoxShadow(
        color: cardShadow,
        blurRadius: elevation * 4,
        offset: Offset(0, elevation),
      ),
    ];
  }

  /// Get gradient with custom colors
  static LinearGradient customGradient({
    required Color startColor,
    required Color endColor,
    AlignmentGeometry beginAlignment = Alignment.topLeft,
    AlignmentGeometry endAlignment = Alignment.bottomRight,
  }) {
    return LinearGradient(
      colors: [startColor, endColor],
      begin: beginAlignment,
      end: endAlignment,
    );
  }

  // ============================================================================
  // COLORES DINAMICOS PARA MODO OSCURO
  // ============================================================================

  /// Get background color based on current theme
  static Color getBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? backgroundDark
        : white;
  }

  /// Get surface/card color based on current theme
  static Color getSurface(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1E293B)
        : white;
  }

  /// Get primary text color based on current theme
  static Color getTextPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? white
        : textPrimary;
  }

  /// Get secondary text color based on current theme
  static Color getTextSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? grey400
        : grey700;
  }

  /// Get border color based on current theme
  static Color getBorder(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF334155)
        : grey300;
  }

  /// Get input fill color based on current theme
  static Color getInputFill(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF334155)
        : grey50;
  }

  /// Get icon color based on current theme
  static Color getIcon(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? grey300
        : grey600;
  }

  /// Get divider color based on current theme
  static Color getDivider(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF334155)
        : grey200;
  }

  /// Get background gradient based on theme
  static LinearGradient getBackgroundGradient(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const LinearGradient(
            colors: [backgroundDark, Color(0xFF0D1A23)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          )
        : backgroundGradient;
  }

  /// Check if current theme is dark
  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }
}

/// Extension for accessing dynamic colors from context
extension AppColorsExtension on BuildContext {
  /// Dynamic colors that adapt to the current theme
  DynamicColors get colors => DynamicColors(this);
}

/// Helper class for dynamic theme-aware colors
class DynamicColors {
  final BuildContext _context;

  DynamicColors(this._context);

  bool get isDark => Theme.of(_context).brightness == Brightness.dark;

  // Background colors
  Color get background => isDark ? AppColors.backgroundDark : AppColors.white;
  Color get surface => isDark ? const Color(0xFF1E293B) : AppColors.white;
  Color get surfaceVariant => isDark ? const Color(0xFF334155) : AppColors.grey50;
  Color get card => isDark ? const Color(0xFF1E293B) : AppColors.white;

  // Text colors
  Color get textPrimary => isDark ? AppColors.white : AppColors.textPrimary;
  Color get textSecondary => isDark ? AppColors.grey400 : AppColors.grey700;
  Color get textTertiary => isDark ? AppColors.grey500 : AppColors.grey500;
  Color get textHint => isDark ? AppColors.grey600 : AppColors.grey400;

  // Border and divider colors
  Color get border => isDark ? const Color(0xFF334155) : AppColors.grey300;
  Color get divider => isDark ? const Color(0xFF334155) : AppColors.grey200;

  // Input colors
  Color get inputFill => isDark ? const Color(0xFF334155) : AppColors.grey50;
  Color get inputBorder => isDark ? const Color(0xFF334155) : AppColors.grey300;

  // Icon colors
  Color get icon => isDark ? AppColors.grey300 : AppColors.grey600;
  Color get iconSecondary => isDark ? AppColors.grey500 : AppColors.grey400;

  // Shadow colors
  Color get shadow => isDark ? Colors.black54 : AppColors.cardShadow;

  // Gradients
  LinearGradient get backgroundGradient => isDark
      ? const LinearGradient(
          colors: [AppColors.backgroundDark, Color(0xFF0D1A23)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        )
      : AppColors.backgroundGradient;
}
