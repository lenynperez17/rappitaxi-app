import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/design/design_system.dart';
import '../../generated/l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../utils/logger.dart';

/// Splash screen minimalista de RapiTeam
///
/// Fondo blanco limpio con logo animado (scale-in elasticOut),
/// nombre de la app, tagline y un indicador de carga sutil.
/// Mantiene toda la logica de navegación según estado de autenticación.
class ModernSplashScreen extends StatefulWidget {
  const ModernSplashScreen({super.key});

  @override
  State<ModernSplashScreen> createState() => _ModernSplashScreenState();
}

class _ModernSplashScreenState extends State<ModernSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    AppLogger.lifecycle('ModernSplashScreen', 'initState');

    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    _startSequence();
  }

  Future<void> _startSequence() async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    _controller.forward();

    AppLogger.info('Esperando a que AuthProvider se inicialice...');

    final authProvider = context.read<AuthProvider>();
    final startTime = DateTime.now();
    const maxWaitTime = Duration(seconds: 10);

    while (authProvider.isInitializing &&
        DateTime.now().difference(startTime) < maxWaitTime) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Mostrar splash al menos 2 segundos
    final elapsed = DateTime.now().difference(startTime);
    if (elapsed < const Duration(seconds: 2)) {
      await Future.delayed(const Duration(seconds: 2) - elapsed);
    }

    AppLogger.info('AuthProvider listo. Navegando...', {
      'tiempoEspera': DateTime.now().difference(startTime).inMilliseconds,
      'isAuthenticated': authProvider.isAuthenticated,
      'hasUser': authProvider.currentUser != null,
    });

    _navigateToHome();
  }

  /// Navega según estado de autenticación y modo del usuario
  ///
  /// - Sin perfil completo -> /auth/complete-profile
  /// - Admin -> /admin/dashboard
  /// - Conductor aprobado -> /driver/home
  /// - Conductor esperando aprobación -> /passenger/home
  /// - Conductor nuevo -> /upgrade-to-driver
  /// - Pasajero -> /passenger/home
  /// - Sin autenticación -> /login
  Future<void> _navigateToHome() async {
    if (!mounted) return;

    try {
      final authProvider = context.read<AuthProvider>();

      if (!authProvider.isAuthenticated || authProvider.currentUser == null) {
        AppLogger.navigation('ModernSplashScreen', '/login', {
          'reason': 'Sin autenticación',
        });
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      final user = authProvider.currentUser!;
      AppLogger.info('Usuario autenticado detectado', {
        'userId': user.id,
        'userType': user.userType,
        'currentMode': user.currentMode,
        'isDualAccount': user.isDualAccount,
      });

      // Verificar si necesita completar perfil
      if (authProvider.needsProfileCompletion()) {
        final loginMethod = _detectLoginMethod();
        AppLogger.navigation('ModernSplashScreen', '/auth/complete-profile', {
          'reason': 'Perfil incompleto',
          'loginMethod': loginMethod,
        });
        Navigator.pushReplacementNamed(
          context,
          '/auth/complete-profile',
          arguments: {'loginMethod': loginMethod},
        );
        return;
      }

      final route = await _resolveRoute(user, authProvider);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, route);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error en navegación desde splash - redirigiendo a login',
        e,
        stackTrace,
      );
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  /// Detecta el método de login basado en los proveedores de Firebase Auth
  String _detectLoginMethod() {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return 'email';

    for (final provider in firebaseUser.providerData) {
      switch (provider.providerId) {
        case 'google.com':
          return 'google';
      }
    }
    return 'email';
  }

  /// Determina la ruta de navegación según el tipo y modo del usuario
  Future<String> _resolveRoute(dynamic user, AuthProvider authProvider) async {
    if (user.isAdmin) {
      AppLogger.navigation('ModernSplashScreen', '/admin/dashboard', {
        'reason': 'Usuario admin',
      });
      return '/admin/dashboard';
    }

    final mode = user.activeMode;

    if (mode != 'driver') {
      AppLogger.navigation('ModernSplashScreen', '/passenger/home', {
        'reason': 'Usuario en modo pasajero',
        'isDual': user.isDualAccount,
      });
      return '/passenger/home';
    }

    // Modo conductor
    if (user.documentVerified) {
      AppLogger.navigation('ModernSplashScreen', '/driver/home', {
        'reason': 'Conductor aprobado',
        'isDual': user.isDualAccount,
      });
      return '/driver/home';
    }

    // Conductor sin documentos aprobados: sincronizar currentMode
    if (user.currentMode == 'driver') {
      AppLogger.info('Sincronizando currentMode a passenger (documentos no verificados)');
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.id)
            .update({'currentMode': 'passenger'})
            .timeout(const Duration(seconds: 5));
        await authProvider.refreshUserData();
      } catch (e) {
        AppLogger.warning('Error sincronizando currentMode: $e');
      }
      if (!mounted) return '/login';
    }

    final driverStatus = user.driverStatus ?? 'pending_documents';
    if (driverStatus == 'pending_approval') {
      AppLogger.navigation('ModernSplashScreen', '/passenger/home', {
        'reason': 'Conductor esperando aprobación',
        'driverStatus': driverStatus,
      });
      return '/passenger/home';
    }

    AppLogger.navigation('ModernSplashScreen', '/upgrade-to-driver', {
      'reason': 'Conductor nuevo - debe subir documentos',
      'driverStatus': driverStatus,
    });
    return '/upgrade-to-driver';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: RtColors.neutral50,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 3),

            // Logo con animacion scale-in y Hero transition al login
            ScaleTransition(
              scale: _scaleAnimation,
              child: Hero(
                tag: 'app-logo',
                child: Material(
                  type: MaterialType.transparency,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: RtColors.white,
                      borderRadius: RtRadius.borderXl,
                      boxShadow: RtShadow.medium(),
                    ),
                    padding: const EdgeInsets.all(RtSpacing.base),
                    child: Image.asset(
                      'assets/images/logo_rapiteam.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.local_taxi,
                        size: 64,
                        color: RtColors.brand,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: RtSpacing.xl),

            // Nombre de la app
            FadeTransition(
              opacity: _fadeAnimation,
              child: Text(
                'RAPITEAM',
                style: RtTypo.displayLarge.copyWith(
                  color: RtColors.neutral900,
                  letterSpacing: 2,
                ),
              ),
            ),

            const SizedBox(height: RtSpacing.sm),

            // Tagline
            FadeTransition(
              opacity: _fadeAnimation,
              child: Text(
                l10n.tagline,
                style: RtTypo.bodyMedium.copyWith(
                  color: RtColors.neutral500,
                ),
              ),
            ),

            const Spacer(flex: 2),

            // Indicador de carga sutil
            FadeTransition(
              opacity: _fadeAnimation,
              child: const _LoadingDots(),
            ),

            const SizedBox(height: RtSpacing.xxl),

            // Version
            FadeTransition(
              opacity: _fadeAnimation,
              child: Text(
                l10n.appVersion,
                style: RtTypo.bodySmall.copyWith(
                  color: RtColors.neutral400,
                ),
              ),
            ),

            const SizedBox(height: RtSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

/// Tres puntos animados como indicador de carga sutil
class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final value = (_controller.value - delay).clamp(0.0, 1.0);
            // Pulso suave: sube y baja
            final opacity = 0.3 + 0.7 * (1.0 - (2.0 * value - 1.0).abs());

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: RtColors.brand,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
