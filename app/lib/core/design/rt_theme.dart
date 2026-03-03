import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'rt_colors.dart';
import 'rt_page_transitions.dart';
import 'rt_tokens.dart';
import 'rt_typography.dart';

/// Tema unificado de RapiTeam - Reemplaza ModernTheme y AppTheme
/// Material 3 + Google Fonts Inter + paleta corporativa rojo
class RtTheme {
  RtTheme._();

  // ════════════════════════════════════════════
  // TEMA CLARO
  // ════════════════════════════════════════════
  static ThemeData get light {
    final colorScheme = ColorScheme.light(
      primary: RtColors.brand,
      onPrimary: RtColors.white,
      primaryContainer: RtColors.brandSurface,
      onPrimaryContainer: RtColors.brandDark,
      secondary: RtColors.neutral800,
      onSecondary: RtColors.white,
      secondaryContainer: RtColors.neutral100,
      onSecondaryContainer: RtColors.neutral800,
      tertiary: RtColors.accentBlue,
      onTertiary: RtColors.white,
      surface: RtColors.white,
      onSurface: RtColors.neutral900,
      surfaceContainerHighest: RtColors.neutral100,
      error: RtColors.error,
      onError: RtColors.white,
      outline: RtColors.neutral200,
      outlineVariant: RtColors.neutral100,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: RtColors.neutral50,
      textTheme: RtTypo.textTheme(color: RtColors.neutral900),
      fontFamily: RtTypo.fontFamily,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        iconTheme: const IconThemeData(color: RtColors.neutral900, size: 24),
        titleTextStyle: RtTypo.headingSmall.copyWith(color: RtColors.neutral900),
      ),

      // Botones elevados
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: RtColors.brand,
          foregroundColor: RtColors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: RtSpacing.xl, vertical: RtSpacing.base),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: RtRadius.borderMd),
          textStyle: RtTypo.labelLarge.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      // Botones outlined
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: RtColors.brand,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: RtSpacing.xl, vertical: RtSpacing.base),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: RtRadius.borderMd),
          side: const BorderSide(color: RtColors.brand, width: 1.5),
          textStyle: RtTypo.labelLarge.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      // Botones de texto
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: RtColors.brand,
          textStyle: RtTypo.labelLarge.copyWith(fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: RtSpacing.base, vertical: RtSpacing.sm),
        ),
      ),

      // Cards
      cardTheme: CardThemeData(
        color: RtColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: RtRadius.borderMd),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),

      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: RtColors.neutral50,
        contentPadding: const EdgeInsets.symmetric(horizontal: RtSpacing.base, vertical: RtSpacing.base),
        border: OutlineInputBorder(
          borderRadius: RtRadius.borderMd,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: RtRadius.borderMd,
          borderSide: const BorderSide(color: RtColors.neutral200, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: RtRadius.borderMd,
          borderSide: const BorderSide(color: RtColors.brand, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: RtRadius.borderMd,
          borderSide: const BorderSide(color: RtColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: RtRadius.borderMd,
          borderSide: const BorderSide(color: RtColors.error, width: 2),
        ),
        hintStyle: RtTypo.bodyMedium.copyWith(color: RtColors.neutral400),
        labelStyle: RtTypo.bodyMedium.copyWith(color: RtColors.neutral500),
        errorStyle: RtTypo.bodySmall.copyWith(color: RtColors.error),
        floatingLabelStyle: RtTypo.labelMedium.copyWith(color: RtColors.brand),
      ),

      // Bottom Navigation
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: RtColors.white,
        selectedItemColor: RtColors.brand,
        unselectedItemColor: RtColors.neutral400,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: RtColors.neutral200,
        thickness: 1,
        space: 1,
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: RtColors.neutral100,
        selectedColor: RtColors.brandSurface,
        labelStyle: RtTypo.labelMedium,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: RtRadius.borderSm),
        padding: const EdgeInsets.symmetric(horizontal: RtSpacing.md, vertical: RtSpacing.xs),
      ),

      // BottomSheet
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: RtColors.white,
        shape: RoundedRectangleBorder(borderRadius: RtRadius.sheetTop),
        elevation: 0,
        dragHandleColor: RtColors.neutral300,
        dragHandleSize: const Size(40, 4),
        showDragHandle: true,
      ),

      // Dialogs
      dialogTheme: DialogThemeData(
        backgroundColor: RtColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: RtRadius.borderLg),
        titleTextStyle: RtTypo.headingSmall.copyWith(color: RtColors.neutral900),
        contentTextStyle: RtTypo.bodyMedium.copyWith(color: RtColors.neutral600),
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: RtRadius.borderMd),
        elevation: 0,
        contentTextStyle: RtTypo.bodyMedium.copyWith(color: RtColors.white),
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return RtColors.white;
          return RtColors.neutral400;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return RtColors.brand;
          return RtColors.neutral200;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      // FloatingActionButton
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: RtColors.brand,
        foregroundColor: RtColors.white,
        elevation: 2,
        shape: CircleBorder(),
      ),

      // TabBar
      tabBarTheme: TabBarThemeData(
        indicatorColor: RtColors.brand,
        labelColor: RtColors.brand,
        unselectedLabelColor: RtColors.neutral500,
        labelStyle: RtTypo.labelLarge.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: RtTypo.labelLarge,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: RtColors.neutral200,
      ),

      // ListTile
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: RtSpacing.base),
        minVerticalPadding: RtSpacing.md,
        shape: RoundedRectangleBorder(borderRadius: RtRadius.borderMd),
        titleTextStyle: RtTypo.titleLarge.copyWith(color: RtColors.neutral900),
        subtitleTextStyle: RtTypo.bodySmall.copyWith(color: RtColors.neutral500),
      ),

      // ProgressIndicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: RtColors.brand,
        linearTrackColor: RtColors.neutral200,
      ),

      // Transiciones de página
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: RtPageTransitionsBuilder(),
          TargetPlatform.iOS: RtPageTransitionsBuilder(),
        },
      ),
    );
  }

  // ════════════════════════════════════════════
  // TEMA OSCURO
  // ════════════════════════════════════════════
  static ThemeData get dark {
    final colorScheme = ColorScheme.dark(
      primary: RtColors.brand,
      onPrimary: RtColors.white,
      primaryContainer: RtColors.brandDark,
      onPrimaryContainer: RtColors.brandLight,
      secondary: RtColors.neutral200,
      onSecondary: RtColors.neutral900,
      secondaryContainer: RtColors.neutral800,
      onSecondaryContainer: RtColors.neutral200,
      tertiary: RtColors.info,
      onTertiary: RtColors.white,
      surface: RtColors.neutral800,
      onSurface: RtColors.neutral50,
      surfaceContainerHighest: RtColors.neutral700,
      error: RtColors.error,
      onError: RtColors.white,
      outline: RtColors.neutral600,
      outlineVariant: RtColors.neutral700,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: RtColors.neutral950,
      textTheme: RtTypo.textTheme(color: RtColors.neutral50),
      fontFamily: RtTypo.fontFamily,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: const IconThemeData(color: RtColors.neutral50, size: 24),
        titleTextStyle: RtTypo.headingSmall.copyWith(color: RtColors.neutral50),
      ),

      // Botones elevados
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: RtColors.brand,
          foregroundColor: RtColors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: RtSpacing.xl, vertical: RtSpacing.base),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: RtRadius.borderMd),
          textStyle: RtTypo.labelLarge.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      // Botones outlined
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: RtColors.brandLight,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: RtSpacing.xl, vertical: RtSpacing.base),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: RtRadius.borderMd),
          side: const BorderSide(color: RtColors.brandLight, width: 1.5),
          textStyle: RtTypo.labelLarge.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      // Botones de texto
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: RtColors.brandLight,
          textStyle: RtTypo.labelLarge.copyWith(fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: RtSpacing.base, vertical: RtSpacing.sm),
        ),
      ),

      // Cards
      cardTheme: CardThemeData(
        color: RtColors.neutral800,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: RtRadius.borderMd),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),

      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: RtColors.neutral900,
        contentPadding: const EdgeInsets.symmetric(horizontal: RtSpacing.base, vertical: RtSpacing.base),
        border: OutlineInputBorder(
          borderRadius: RtRadius.borderMd,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: RtRadius.borderMd,
          borderSide: const BorderSide(color: RtColors.neutral700, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: RtRadius.borderMd,
          borderSide: const BorderSide(color: RtColors.brand, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: RtRadius.borderMd,
          borderSide: const BorderSide(color: RtColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: RtRadius.borderMd,
          borderSide: const BorderSide(color: RtColors.error, width: 2),
        ),
        hintStyle: RtTypo.bodyMedium.copyWith(color: RtColors.neutral500),
        labelStyle: RtTypo.bodyMedium.copyWith(color: RtColors.neutral400),
        errorStyle: RtTypo.bodySmall.copyWith(color: RtColors.error),
        floatingLabelStyle: RtTypo.labelMedium.copyWith(color: RtColors.brand),
      ),

      // Bottom Navigation
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: RtColors.neutral900,
        selectedItemColor: RtColors.brand,
        unselectedItemColor: RtColors.neutral500,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: RtColors.neutral700,
        thickness: 1,
        space: 1,
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: RtColors.neutral800,
        selectedColor: RtColors.brandDark,
        labelStyle: RtTypo.labelMedium.copyWith(color: RtColors.neutral200),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: RtRadius.borderSm),
        padding: const EdgeInsets.symmetric(horizontal: RtSpacing.md, vertical: RtSpacing.xs),
      ),

      // BottomSheet
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: RtColors.neutral900,
        shape: RoundedRectangleBorder(borderRadius: RtRadius.sheetTop),
        elevation: 0,
        dragHandleColor: RtColors.neutral600,
        dragHandleSize: const Size(40, 4),
        showDragHandle: true,
      ),

      // Dialogs
      dialogTheme: DialogThemeData(
        backgroundColor: RtColors.neutral800,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: RtRadius.borderLg),
        titleTextStyle: RtTypo.headingSmall.copyWith(color: RtColors.neutral50),
        contentTextStyle: RtTypo.bodyMedium.copyWith(color: RtColors.neutral400),
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: RtColors.neutral800,
        shape: RoundedRectangleBorder(borderRadius: RtRadius.borderMd),
        elevation: 0,
        contentTextStyle: RtTypo.bodyMedium.copyWith(color: RtColors.neutral50),
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return RtColors.white;
          return RtColors.neutral500;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return RtColors.brand;
          return RtColors.neutral700;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      // FloatingActionButton
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: RtColors.brand,
        foregroundColor: RtColors.white,
        elevation: 2,
        shape: CircleBorder(),
      ),

      // TabBar
      tabBarTheme: TabBarThemeData(
        indicatorColor: RtColors.brand,
        labelColor: RtColors.brand,
        unselectedLabelColor: RtColors.neutral500,
        labelStyle: RtTypo.labelLarge.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: RtTypo.labelLarge,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: RtColors.neutral700,
      ),

      // ListTile
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: RtSpacing.base),
        minVerticalPadding: RtSpacing.md,
        shape: RoundedRectangleBorder(borderRadius: RtRadius.borderMd),
        titleTextStyle: RtTypo.titleLarge.copyWith(color: RtColors.neutral50),
        subtitleTextStyle: RtTypo.bodySmall.copyWith(color: RtColors.neutral400),
      ),

      // ProgressIndicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: RtColors.brand,
        linearTrackColor: RtColors.neutral700,
      ),

      // Transiciones de página
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: RtPageTransitionsBuilder(),
          TargetPlatform.iOS: RtPageTransitionsBuilder(),
        },
      ),
    );
  }
}
