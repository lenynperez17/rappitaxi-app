import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'config/api_config.dart';
import 'firebase_options.dart';
import 'core/services/crash_reporting_service.dart';
import 'core/services/notification_service.dart';
import 'package:rappitaxi_app/shared/utils/logger.dart';
import 'shared/providers/riverpod_compat.dart';
import 'core/router/role_based_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Cargar variables de entorno
    await dotenv.load(fileName: ".env");
    Logger.info('✅ Variables de entorno cargadas');
    Logger.info('🌐 Entorno: ${ApiConfig.environment}');
    Logger.info('🔗 API Base URL: ${ApiConfig.apiBaseUrl}');
  } catch (e) {
    Logger.warning('⚠️  Warning: No se pudo cargar archivo .env: $e');
  }
  
  // Inicializar Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  Logger.info('🔥 Firebase inicializado correctamente');
  
  // Configurar manejo de errores
  FlutterError.onError = (errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };
  
  // Capturar errores asíncronos
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  
  runApp(
    ProviderScope(
      child: RappiTaxiApp(),
    ),
  );
}

class RappiTaxiApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Verificar inicialización de la app
    final appInitialization = ref.watch(appInitializationProvider);
    
    return appInitialization.when(
      data: (initialized) => _buildApp(context, initialized),
      loading: () => MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Inicializando RappiTaxi...'),
              ],
            ),
          ),
        ),
      ),
      error: (error, stack) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Colors.red),
                SizedBox(height: 16),
                Text('Error al inicializar la aplicación'),
                Text(error.toString()),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildApp(BuildContext context, bool initialized) {
    return MaterialApp.router(
      title: 'RappiTaxi - Aplicación Completa de Transporte',
      routerConfig: roleBasedRouter,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.light,
        ),
        fontFamily: 'Inter',
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

