import 'package:flutter/material.dart';

/// Design Tokens estandarizados de RapiTeam
/// Define spacing, radii, sombras, duraciones y curvas de animación

// ════════════════════════════════════════════
// SPACING - Sistema basado en grid de 4px
// ════════════════════════════════════════════
class RtSpacing {
  RtSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double base = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;

  // EdgeInsets pre-construidos para uso rápido
  static const EdgeInsets paddingXs = EdgeInsets.all(xs);
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingBase = EdgeInsets.all(base);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);

  // Padding horizontal estándar de pantalla
  static const EdgeInsets screenH = EdgeInsets.symmetric(horizontal: xl);
  static const EdgeInsets screenAll = EdgeInsets.symmetric(horizontal: xl, vertical: base);
}

// ════════════════════════════════════════════
// BORDER RADIUS - Solo 5 niveles
// ════════════════════════════════════════════
class RtRadius {
  RtRadius._();

  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double full = 999.0;

  // BorderRadius pre-construidos
  static final BorderRadius borderSm = BorderRadius.circular(sm);
  static final BorderRadius borderMd = BorderRadius.circular(md);
  static final BorderRadius borderLg = BorderRadius.circular(lg);
  static final BorderRadius borderXl = BorderRadius.circular(xl);
  static final BorderRadius borderFull = BorderRadius.circular(full);

  // Para bottom sheets (solo esquinas superiores)
  static final BorderRadius sheetTop = BorderRadius.vertical(top: Radius.circular(xl));
}

// ════════════════════════════════════════════
// SHADOWS - 3 niveles de elevación
// ════════════════════════════════════════════
class RtShadow {
  RtShadow._();

  static List<BoxShadow> soft({bool isDark = false}) => [
    BoxShadow(
      color: Color(0xFF000000).withValues(alpha: isDark ? 0.15 : 0.05),
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> medium({bool isDark = false}) => [
    BoxShadow(
      color: Color(0xFF000000).withValues(alpha: isDark ? 0.25 : 0.08),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> strong({bool isDark = false}) => [
    BoxShadow(
      color: Color(0xFF000000).withValues(alpha: isDark ? 0.35 : 0.12),
      blurRadius: 30,
      offset: const Offset(0, 8),
    ),
  ];

  // Sombra con color brand (para botones principales)
  static List<BoxShadow> brand() => [
    BoxShadow(
      color: const Color(0xFFE31E24).withValues(alpha: 0.25),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];
}

// ════════════════════════════════════════════
// DURACIONES DE ANIMACIÓN
// ════════════════════════════════════════════
class RtDuration {
  RtDuration._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration emphasis = Duration(milliseconds: 800);
}

// ════════════════════════════════════════════
// CURVAS DE ANIMACIÓN
// ════════════════════════════════════════════
class RtCurve {
  RtCurve._();

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve emphasis = Curves.easeInOutCubic;
  static const Curve bounce = Curves.elasticOut;
  static const Curve spring = Curves.easeOutBack;
}

// ════════════════════════════════════════════
// TAMAÑOS DE ICONOS
// ════════════════════════════════════════════
class RtIconSize {
  RtIconSize._();

  static const double xs = 16.0;
  static const double sm = 20.0;
  static const double md = 24.0;
  static const double lg = 28.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}
