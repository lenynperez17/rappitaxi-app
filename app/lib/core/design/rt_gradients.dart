import 'package:flutter/material.dart';
import 'rt_colors.dart';

/// Sistema de gradientes coherente para toda la app
class RtGradients {
  RtGradients._();

  // Gradiente principal de marca (headers, CTAs prominentes)
  static const LinearGradient brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [RtColors.brand, RtColors.brandDark],
  );

  // Gradiente suave de marca (backgrounds tinted)
  static const LinearGradient brandSoft = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x1AE31E24), Color(0x0DB91C1C)],
  );

  // Gradiente oscuro (modo oscuro, overlays)
  static const LinearGradient dark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [RtColors.neutral800, RtColors.neutral950],
  );

  // Gradiente de superficie (backgrounds claros)
  static const LinearGradient surface = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [RtColors.white, RtColors.neutral100],
  );

  // Gradiente de éxito (ganancias, balance, online)
  static const LinearGradient success = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [RtColors.success, RtColors.successDark],
  );

  // Gradiente de información (notificaciones, stats)
  static const LinearGradient info = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [RtColors.info, RtColors.infoDark],
  );

  // Gradiente de advertencia
  static const LinearGradient warning = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [RtColors.warning, RtColors.warningDark],
  );

  // Gradiente para overlays sobre mapa (de transparente a color)
  static LinearGradient mapOverlay({bool isDark = false}) => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: isDark
      ? [RtColors.transparent, RtColors.neutral950.withValues(alpha: 0.8)]
      : [RtColors.transparent, RtColors.white.withValues(alpha: 0.8)],
  );
}
