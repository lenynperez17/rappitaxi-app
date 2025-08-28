// RappiTaxi - Punto de entrada optimizado para producción
// Este archivo está específicamente configurado para builds de producción

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

import 'core/config/production_config.dart';
import 'package:rappitaxi_app/shared/utils/logger.dart';
import 'core/services/crash_reporting_service.dart';
import 'core/services/performance_monitoring_service.dart';
import 'core/services/analytics_service.dart';
import 'firebase_options.dart';
import 'app.dart';

void main() async {
  // Configuración inicial para producción
  await _initializeProductionApp();
  
  // Ejecutar app con manejo de errores robusto
  runZonedGuarded<Future<void>>(
    () async {
      runApp(
        ProviderScope(
          child: RappiTaxiApp(),
        ),
      );
    },
    (error, stack) {
      // Capturar errores no manejados en producción
      _handleUncaughtError(error, stack);
    },
  );
}

/// Inicialización completa para ambiente de producción
Future<void> _initializeProductionApp() async {
  // Asegurar que los widgets estén inicializados
  WidgetsFlutterBinding.ensureInitialized();
  
  // Validar configuración de producción
  if (!kReleaseMode) {
    Logger.warning('Ejecutando en modo no-release con configuración de producción');
  }
  
  try {
    // Validar configuración antes de continuar
    ProductionConfig.validateProductionConfig();
    Logger.info('Configuración de producción validada correctamente');
  } catch (e) {
    Logger.error('Error en configuración de producción: $e');
    // En producción, podríamos mostrar un mensaje de error al usuario
    // y posiblemente terminar la app o usar configuración de fallback
    if (kReleaseMode) {
      exit(1); // Terminar app si configuración es inválida
    }
  }
  
  // Configurar orientación (solo vertical en producción)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Configurar UI del sistema para producción
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  
  // Habilitar edge-to-edge en Android
  if (Platform.isAndroid) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
  
  // Inicializar Firebase con configuración de producción
  await _initializeFirebase();
  
  // Configurar servicios de monitoreo y reportes
  await _initializeMonitoringServices();
  
  // Configurar manejo de errores Flutter
  _setupFlutterErrorHandling();
  
  // Optimizaciones de rendimiento para producción
  _applyPerformanceOptimizations();
  
  Logger.info('App inicializada correctamente para producción');
}

/// Inicializar Firebase con todas las configuraciones de producción
Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Configurar Crashlytics solo en producción
    if (kReleaseMode && ProductionConfig.enableErrorReporting) {
      // Habilitar recolección automática de crashs
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
      
      // Configurar información de usuario para debugging
      await FirebaseCrashlytics.instance.setUserIdentifier('production_user');
      
      // Configurar custom keys para mejor debugging
      await FirebaseCrashlytics.instance.setCustomKey('environment', 'production');
      await FirebaseCrashlytics.instance.setCustomKey('app_version', ProductionConfig.minimumAppVersion);
    }
    
    // Configurar Performance Monitoring
    if (ProductionConfig.enablePerformanceMonitoring) {
      await FirebasePerformance.instance.setPerformanceCollectionEnabled(true);
    }
    
    // Configurar Analytics
    if (ProductionConfig.enableAnalytics) {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
    }
    
    Logger.info('Firebase inicializado correctamente para producción');
  } catch (e, stack) {
    Logger.error('Error inicializando Firebase: $e');
    Logger.error('Stack trace: $stack');
    
    // En producción, continuar sin Firebase si hay error crítico
    // pero registrar el problema
    if (kReleaseMode) {
      Logger.warning('Continuando sin Firebase debido a error de inicialización');
    } else {
      rethrow; // Re-throw en desarrollo para debugging
    }
  }
}

/// Inicializar servicios de monitoreo y reportes
Future<void> _initializeMonitoringServices() async {
  try {
    // Inicializar servicio de reportes de crash
    await CrashReportingService.instance.initialize();
    
    // Inicializar monitoreo de rendimiento
    await PerformanceMonitoringService.instance.initialize();
    
    // Inicializar analytics
    await AnalyticsService.instance.initialize();
    
    // Configurar métricas personalizadas
    PerformanceMonitoringService.instance.startAppLaunchTrace();
    
    // Registrar información de dispositivo para debugging
    final deviceInfo = await _getDeviceInfo();
    AnalyticsService.instance.setUserProperties(deviceInfo);
    
    Logger.info('Servicios de monitoreo inicializados correctamente');
  } catch (e) {
    Logger.error('Error inicializando servicios de monitoreo: $e');
    // Continuar sin servicios de monitoreo si hay error
  }
}

/// Configurar manejo de errores de Flutter para producción
void _setupFlutterErrorHandling() {
  // Configurar manejo de errores de Flutter
  FlutterError.onError = (FlutterErrorDetails details) {
    // Log del error para debugging
    Logger.error('Flutter Error: ${details.exception}');
    Logger.error('Stack trace: ${details.stack}');
    
    // Reportar a Crashlytics en producción
    if (kReleaseMode && ProductionConfig.enableErrorReporting) {
      FirebaseCrashlytics.instance.recordFlutterError(details);
    }
    
    // Reportar a servicio personalizado de crash reporting
    CrashReportingService.instance.recordFlutterError(details);
    
    // En desarrollo, usar el handler por defecto
    if (!kReleaseMode) {
      FlutterError.presentError(details);
    }
  };
  
  // Configurar manejo de errores de plataforma
  PlatformDispatcher.instance.onError = (error, stack) {
    Logger.error('Platform Error: $error');
    Logger.error('Stack trace: $stack');
    
    // Reportar error de plataforma
    if (kReleaseMode && ProductionConfig.enableErrorReporting) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: false);
    }
    
    CrashReportingService.instance.recordError(error, stack);
    
    return true; // Handled
  };
}

/// Aplicar optimizaciones de rendimiento específicas para producción
void _applyPerformanceOptimizations() {
  // Configurar parámetros de rendering optimizados
  if (kReleaseMode) {
    // Habilitar skippable frames para mejor rendimiento
    WidgetsBinding.instance.platformDispatcher.onReportTimings = (List<FrameTiming> timings) {
      // Monitorear frame timings en producción
      for (final timing in timings) {
        final frameDuration = timing.totalSpan;
        if (frameDuration > const Duration(milliseconds: 16)) {
          // Frame lento detectado (>16ms = <60fps)
          PerformanceMonitoringService.instance.recordSlowFrame(frameDuration);
        }
      }
    };
  }
  
  // Configurar memory management optimizado
  WidgetsBinding.instance.addObserver(_AppLifecycleObserver());
  
  // Configurar image cache optimizado para producción
  PaintingBinding.instance.imageCache.maximumSize = 100; // Limitar cache de imágenes
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 << 20; // 50MB max
  
  Logger.info('Optimizaciones de rendimiento aplicadas');
}

/// Manejar errores no capturados en producción
void _handleUncaughtError(Object error, StackTrace stack) {
  Logger.error('Uncaught Error: $error');
  Logger.error('Stack trace: $stack');
  
  // Reportar a Crashlytics
  if (kReleaseMode && ProductionConfig.enableErrorReporting) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  }
  
  // Reportar a servicio personalizado
  CrashReportingService.instance.recordError(error, stack);
  
  // En producción, podríamos mostrar un diálogo de error amigable al usuario
  // y opcionalmente reiniciar la app
  if (kReleaseMode) {
    // TODO: Implementar manejo graceful de errores fatales
    // Por ejemplo, mostrar pantalla de error y opción de reiniciar
  }
}

/// Obtener información del dispositivo para analytics y debugging
Future<Map<String, String>> _getDeviceInfo() async {
  try {
    return {
      'platform': Platform.operatingSystem,
      'platform_version': Platform.operatingSystemVersion,
      'locale': Platform.localeName,
      'environment': 'production',
      'flutter_version': kReleaseMode ? 'release' : 'debug',
    };
  } catch (e) {
    Logger.error('Error obteniendo información del dispositivo: $e');
    return {'error': 'unable_to_get_device_info'};
  }
}

/// Observer del ciclo de vida de la app para optimizaciones
class _AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        Logger.info('App resumed');
        AnalyticsService.instance.trackEvent('app_resumed');
        // Reiniciar servicios críticos si es necesario
        break;
        
      case AppLifecycleState.paused:
        Logger.info('App paused');
        AnalyticsService.instance.trackEvent('app_paused');
        // Pausar servicios no críticos para conservar batería
        _optimizeForBackground();
        break;
        
      case AppLifecycleState.inactive:
        Logger.info('App inactive');
        break;
        
      case AppLifecycleState.detached:
        Logger.info('App detached');
        // Cleanup final si es necesario
        _cleanup();
        break;
        
      case AppLifecycleState.hidden:
        Logger.info('App hidden');
        break;
    }
  }
  
  void _optimizeForBackground() {
    // Reducir frecuencia de actualizaciones en background
    // Pausar animaciones no críticas
    // Limpiar caché temporal
  }
  
  void _cleanup() {
    // Cerrar conexiones abiertas
    // Guardar estado crítico
    // Limpiar recursos temporales
  }
}

/// Configuración adicional específica para producción
class ProductionAppConfig {
  static void configure() {
    // Deshabilitar debug banners en producción
    if (kReleaseMode) {
      debugPaintSizeEnabled = false;
    }
    
    // Configurar timeouts de red optimizados
    HttpOverrides.global = _ProductionHttpOverrides();
  }
}

/// HTTP Overrides optimizados para producción
class _ProductionHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    
    // Configurar timeouts optimizados para producción
    client.connectionTimeout = ProductionConfig.apiTimeout;
    client.idleTimeout = const Duration(seconds: 15);
    
    // Habilitar SSL pinning en producción
    if (ProductionConfig.enableSSLPinning) {
      client.badCertificateCallback = (cert, host, port) => false;
    }
    
    return client;
  }
}