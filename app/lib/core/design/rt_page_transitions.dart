import 'package:flutter/material.dart';

import 'rt_tokens.dart';

/// Transiciones de navegación personalizadas de RapiTeam.
/// Usa los tokens de duracion y curvas del design system para
/// mantener consistencia en todas las animaciones de la app.

// ================================================================
// RtPageTransition - Fabrica de rutas con transiciones custom
// ================================================================

/// Clase utilitaria con métodos estaticos para crear [PageRouteBuilder]
/// con animaciones predefinidas usando los tokens del design system.
///
/// Uso:
///   Navigator.push(context, RtPageTransition.slide(MiPágina()));
///   Navigator.push(context, RtPageTransition.fadeSlide(DetallePage()));
class RtPageTransition {
  RtPageTransition._();

  /// Slide desde la derecha - Navegacion estandar entre pantallas.
  /// Duracion: normal (300ms), curva: enter (easeOutCubic).
  static PageRouteBuilder<T> slide<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: RtDuration.normal,
      reverseTransitionDuration: RtDuration.normal,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: RtCurve.enter));

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }

  /// Slide desde abajo - Para modals, bottom sheets y pantallas overlay.
  /// Duracion: normal (300ms), curva: enter (easeOutCubic).
  static PageRouteBuilder<T> slideUp<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: RtDuration.normal,
      reverseTransitionDuration: RtDuration.normal,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween<Offset>(
          begin: const Offset(0.0, 1.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: RtCurve.enter));

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }

  /// Fade simple - Para cambios de tabs o switches de contenido.
  /// Duracion: fast (150ms), curva: enter (easeOutCubic).
  static PageRouteBuilder<T> fade<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: RtDuration.fast,
      reverseTransitionDuration: RtDuration.fast,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: RtCurve.enter));

        return FadeTransition(
          opacity: animation.drive(tween),
          child: child,
        );
      },
    );
  }

  /// Fade + slide sutil desde abajo - Para pantallas de detalle.
  /// Combina opacidad con un desplazamiento vertical suave.
  /// Duracion: normal (300ms), curva: enter (easeOutCubic).
  static PageRouteBuilder<T> fadeSlide<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: RtDuration.normal,
      reverseTransitionDuration: RtDuration.normal,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final slideTween = Tween<Offset>(
          begin: const Offset(0.0, 0.05),
          end: Offset.zero,
        ).chain(CurveTween(curve: RtCurve.enter));

        final fadeTween = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: RtCurve.enter));

        return FadeTransition(
          opacity: animation.drive(fadeTween),
          child: SlideTransition(
            position: animation.drive(slideTween),
            child: child,
          ),
        );
      },
    );
  }

  /// Scale desde el centro - Para dialogos y popups.
  /// Duracion: fast (150ms), curva: emphasis (easeInOutCubic).
  static PageRouteBuilder<T> scale<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: RtDuration.fast,
      reverseTransitionDuration: RtDuration.fast,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final scaleTween = Tween<double>(
          begin: 0.85,
          end: 1.0,
        ).chain(CurveTween(curve: RtCurve.emphasis));

        final fadeTween = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: RtCurve.enter));

        return FadeTransition(
          opacity: animation.drive(fadeTween),
          child: ScaleTransition(
            scale: animation.drive(scaleTween),
            child: child,
          ),
        );
      },
    );
  }
}

// ================================================================
// _RtPageTransitionsBuilder - Builder para PageTransitionsTheme
// ================================================================

/// Builder de transiciones para integrar con [PageTransitionsTheme] en el tema.
/// Usa fade + slide sutil como transicion por defecto para toda la app.
class RtPageTransitionsBuilder extends PageTransitionsBuilder {
  const RtPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final slideTween = Tween<Offset>(
      begin: const Offset(0.0, 0.05),
      end: Offset.zero,
    ).chain(CurveTween(curve: RtCurve.enter));

    final fadeTween = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).chain(CurveTween(curve: RtCurve.enter));

    return FadeTransition(
      opacity: animation.drive(fadeTween),
      child: SlideTransition(
        position: animation.drive(slideTween),
        child: child,
      ),
    );
  }
}
