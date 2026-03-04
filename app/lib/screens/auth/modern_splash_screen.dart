// ignore_for_file: use_build_context_synchronously, unused_import, unused_field
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider; // ✅ Para verificar proveedores
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ NUEVO: Para sincronizar currentMode
import 'dart:math' as math;
import '../../generated/l10n/app_localizations.dart';
import '../../core/theme/modern_theme.dart';
import '../../utils/logger.dart';
import '../../utils/map_marker_utils.dart';
import '../../providers/auth_provider.dart';

/// Pantalla de splash con animaciones modernas
///
/// Muestra el logo de Rappi Team con animaciones mientras
/// se inicializa el AuthProvider y determina la ruta inicial
class ModernSplashScreen extends StatefulWidget {
  const ModernSplashScreen({super.key});

  @override
  State<ModernSplashScreen> createState() => _ModernSplashScreenState();
}

class _ModernSplashScreenState extends State<ModernSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _rippleController;
  late AnimationController _carController;
  
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoRotateAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<double> _textSlideAnimation;
  late Animation<double> _rippleAnimation;
  late Animation<double> _carAnimation;

  @override
  void initState() {
    super.initState();
    AppLogger.lifecycle('ModernSplashScreen', 'initState');
    
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _textController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _rippleController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _carController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    _logoScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    ));
    
    _logoRotateAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeInOut,
    ));
    
    _textFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeIn,
    ));
    
    _textSlideAnimation = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOut,
    ));
    
    _rippleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rippleController,
      curve: Curves.easeOut,
    ));
    
    _carAnimation = Tween<double>(
      begin: -1.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _carController,
      curve: Curves.easeInOut,
    ));
    
    _startAnimations();
  }
  
  Future<void> _startAnimations() async {
    AppLogger.info('Iniciando animaciones del Splash Screen');
    await Future.delayed(const Duration(milliseconds: 300));
    _logoController.forward();

    await Future.delayed(const Duration(milliseconds: 800));
    _textController.forward();
    _rippleController.repeat();
    _carController.repeat();

    // Pre-cargar marcadores del mapa para que estén listos al abrir el mapa
    MapMarkerUtils.preloadAllIcons();

    AppLogger.info('Esperando a que AuthProvider se inicialice...');

    // Esperar a que AuthProvider termine de inicializar (máximo 10 segundos)
    if (!mounted) return;
    final authProvider = context.read<AuthProvider>();
    final startTime = DateTime.now();
    const maxWaitTime = Duration(seconds: 10);

    // Esperar a que isInitializing sea false
    while (authProvider.isInitializing &&
           DateTime.now().difference(startTime) < maxWaitTime) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Esperar al menos 2 segundos totales para mostrar el splash
    final elapsedTime = DateTime.now().difference(startTime);
    if (elapsedTime < const Duration(seconds: 2)) {
      await Future.delayed(const Duration(seconds: 2) - elapsedTime);
    }

    AppLogger.info('AuthProvider listo. Navegando...', {
      'tiempoEspera': DateTime.now().difference(startTime).inMilliseconds,
      'isAuthenticated': authProvider.isAuthenticated,
      'hasUser': authProvider.currentUser != null,
    });

    _navigateToHome();
  }

  /// Navegar a pantalla correspondiente según estado de autenticación y modo
  ///
  /// ✅ iOS FIX: Todo envuelto en try-catch para evitar crashes silenciosos
  /// ✅ NUEVO: Verifica modo mantenimiento y allowNewRegistrations desde Firebase
  /// Implementa navegación inteligente estilo InDriver:
  /// - Sistema en mantenimiento (no admin) → /maintenance
  /// - Usuario sin perfil completo → /auth/complete-profile
  /// - Usuario dual con currentMode='passenger' → /passenger/home
  /// - Usuario dual con currentMode='driver' → /driver/home
  /// - Usuario passenger (puro) → /passenger/home
  /// - Usuario driver (puro) → /driver/home
  /// - Usuario admin → /admin/dashboard
  /// - Sin autenticación → /login
  Future<void> _navigateToHome() async {
    if (!mounted) return;

    // ✅ iOS FIX: Try-catch global para TODA la navegación
    try {
      final authProvider = context.read<AuthProvider>();

      // ✅ NUEVO: Verificar modo mantenimiento desde Firebase
      bool isMaintenanceMode = false;
      try {
        final configDoc = await FirebaseFirestore.instance
            .collection('settings')
            .doc('app_config')
            .get()
            .timeout(const Duration(seconds: 5));

        if (configDoc.exists) {
          isMaintenanceMode = configDoc.data()?['maintenanceMode'] ?? false;
        }
      } catch (e) {
        AppLogger.warning('Error verificando modo mantenimiento: $e');
      }

      // Verificar si hay usuario autenticado
      if (authProvider.isAuthenticated && authProvider.currentUser != null) {
        final user = authProvider.currentUser!;

        // ✅ NUEVO: Si está en mantenimiento y NO es admin, mostrar pantalla de mantenimiento
        if (isMaintenanceMode && !user.isAdmin) {
          AppLogger.navigation('ModernSplashScreen', '/maintenance', {
            'reason': 'Sistema en modo mantenimiento',
            'userId': user.id,
          });
          Navigator.pushReplacementNamed(context, '/maintenance');
          return;
        }

        AppLogger.info('Usuario autenticado detectado', {
          'userId': user.id,
          'userType': user.userType,
          'currentMode': user.currentMode,
          'isDualAccount': user.isDualAccount,
        });

        // ✅ NUEVO: Verificar si necesita completar perfil ANTES de navegar a home
        if (authProvider.needsProfileCompletion()) {
          // Determinar método de login basado en proveedores vinculados
          String loginMethod = 'email';
          final firebaseUser = FirebaseAuth.instance.currentUser;
          if (firebaseUser != null) {
            for (final provider in firebaseUser.providerData) {
              if (provider.providerId == 'google.com') {
                loginMethod = 'google';
                break;
              } else if (provider.providerId == 'facebook.com') {
                loginMethod = 'facebook';
                break;
              } else if (provider.providerId == 'apple.com') {
                loginMethod = 'apple';
                break;
              }
            }
          }

          AppLogger.navigation('ModernSplashScreen', '/auth/complete-profile', {
            'reason': 'Perfil incompleto - falta teléfono o contraseña',
            'loginMethod': loginMethod,
          });
          Navigator.pushReplacementNamed(
            context,
            '/auth/complete-profile',
            arguments: {'loginMethod': loginMethod},
          );
          return;
        }

        // Determinar ruta según tipo y modo
        String route;

        if (user.isAdmin) {
          // Admin siempre va al dashboard
          route = '/admin/dashboard';
          AppLogger.navigation('ModernSplashScreen', route, {'reason': 'Usuario admin'});
        } else {
          // Usuario dual o single: usar currentMode o activeMode
          final mode = user.activeMode; // Usa currentMode si existe, sino userType

          if (mode == 'driver') {
            // Verificar si el conductor tiene documentos aprobados
            if (user.documentVerified) {
              route = '/driver/home';
              AppLogger.navigation('ModernSplashScreen', route, {
                'reason': 'Conductor aprobado',
                'isDual': user.isDualAccount,
              });
            } else {
              // Conductor sin documentos aprobados
              // Verificar si ya envió documentos (pending_approval) o es nuevo
              final driverStatus = user.driverStatus ?? 'pending_documents';

              // ✅ FIX BUG ROL: Sincronizar currentMode con la pantalla real
              // Si el usuario está en modo 'driver' pero NO tiene documentos verificados,
              // actualizar currentMode a 'passenger' para evitar inconsistencia visual
              if (user.currentMode == 'driver') {
                AppLogger.info('🔄 Sincronizando currentMode a passenger (documentos no verificados)');
                // ✅ iOS FIX: Try-catch específico para Firestore con timeout
                try {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.id)
                      .update({'currentMode': 'passenger'})
                      .timeout(const Duration(seconds: 5));
                  // Refrescar datos del usuario en memoria
                  await authProvider.refreshUserData();
                } catch (e) {
                  // ✅ iOS FIX: No crashear si falla - solo log warning
                  AppLogger.warning('Error sincronizando currentMode: $e');
                }
                // ✅ FIX: Verificar mounted después de operaciones async
                if (!mounted) return;
              }

              if (driverStatus == 'pending_approval') {
                // Ya envió documentos, puede usar como pasajero mientras espera
                route = '/passenger/home';
                AppLogger.navigation('ModernSplashScreen', route, {
                  'reason': 'Conductor esperando aprobación - usando como pasajero',
                  'driverStatus': driverStatus,
                });
              } else {
                // Conductor nuevo, debe subir documentos
                route = '/upgrade-to-driver';
                AppLogger.navigation('ModernSplashScreen', route, {
                  'reason': 'Conductor nuevo - debe subir documentos',
                  'driverStatus': driverStatus,
                });
              }
            }
          } else {
            // Default: modo pasajero (passenger o cualquier otro)
            route = '/passenger/home';
            AppLogger.navigation('ModernSplashScreen', route, {
              'reason': 'Usuario en modo pasajero',
              'isDual': user.isDualAccount,
            });
          }
        }

        Navigator.pushReplacementNamed(context, route);
      } else {
        // Sin autenticación
        // ✅ NUEVO: Si está en mantenimiento, mostrar pantalla de mantenimiento (incluso sin login)
        if (isMaintenanceMode) {
          AppLogger.navigation('ModernSplashScreen', '/maintenance', {
            'reason': 'Sistema en modo mantenimiento (usuario no autenticado)',
          });
          Navigator.pushReplacementNamed(context, '/maintenance');
          return;
        }

        AppLogger.navigation('ModernSplashScreen', '/login', {'reason': 'Sin autenticación'});
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e, stackTrace) {
      // ✅ iOS FIX: FALLBACK - Si hay CUALQUIER error, ir a login en vez de crashear
      AppLogger.error('Error en navegación desde splash - redirigiendo a login', e, stackTrace);
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _rippleController.dispose();
    _carController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // Gradiente radial naranja desde el centro hacia blanco
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [
              const Color(0xFFFF6B00),
              const Color(0xFFFF8C00),
              Colors.white,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Contenido principal centrado
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo animado: solo scale + pulse, sin rotacion
                  AnimatedBuilder(
                    animation: _logoScaleAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _logoScaleAnimation.value,
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF6B00).withValues(alpha: 0.35),
                                blurRadius: 40,
                                spreadRadius: 8,
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(24),
                          child: Image.asset(
                            'assets/images/logo_rappi_taxi.png',
                            width: 132,
                            height: 132,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.local_taxi,
                                size: 90,
                                color: Color(0xFFFF6B00),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 36),

                  // Texto animado
                  AnimatedBuilder(
                    animation: Listenable.merge([_textFadeAnimation, _textSlideAnimation]),
                    builder: (context, child) {
                      return Opacity(
                        opacity: _textFadeAnimation.value,
                        child: Transform.translate(
                          offset: Offset(0, _textSlideAnimation.value),
                          child: Column(
                            children: [
                              // Nombre de la app
                              Text(
                                AppLocalizations.of(context)!.rappiTeam,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                  shadows: [
                                    Shadow(
                                      color: const Color(0xFFFF6B00).withValues(alpha: 0.6),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Tagline
                              Text(
                                AppLocalizations.of(context)!.tagline,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.5,
                                  shadows: [
                                    Shadow(
                                      color: const Color(0xFFFF6B00).withValues(alpha: 0.5),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 40),
                              // LinearProgressIndicator de 200px
                              SizedBox(
                                width: 200,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                    minHeight: 4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Version en la parte inferior
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _textFadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _textFadeAnimation.value,
                    child: Text(
                      AppLocalizations.of(context)!.appVersion,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}