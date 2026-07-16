// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter, unused_import
import 'dart:async'; // ✅ FIX: runZonedGuarded para capturar errores asíncronos
import 'dart:ui' show PlatformDispatcher; // ✅ iOS FIX: Para capturar errores de plataforma
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 🔐 NUEVO: Cargar variables de entorno desde .env
import 'generated/l10n/app_localizations.dart'; // ✅ NUEVO: Localizaciones generadas
// Firebase — SOLO FCM para notificaciones push (todo lo demás migró al backend Node)
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'firebase_messaging_handler.dart';

// Core
import 'core/theme/modern_theme.dart';
import 'core/widgets/notification_handler_widget.dart';

// Services — Backend propio (VPS)
import 'services/rapi_api_client.dart';
import 'services/rapi_sse_client.dart';
import 'services/notification_service.dart';

// Dev-only: tour orchestrator (import indirecto)
import 'dev_tour_orchestrator.dart';

// Utils
import 'utils/logger.dart';
import 'utils/navigation_helper.dart';

// Providers
import 'providers/auth_provider.dart';
import 'providers/location_provider.dart';
import 'providers/ride_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/price_negotiation_provider.dart';
import 'providers/locale_provider.dart'; // ✅ NUEVO: Provider para cambio de idioma
import 'providers/preferences_provider.dart'; // ✅ NUEVO: Provider para Dark Mode y preferencias
import 'providers/wallet_provider.dart'; // ✅ FIX: Provider para créditos de servicio
import 'providers/document_provider.dart'; // ✅ FIX: Provider para documentos de conductor
import 'models/trip_model.dart';

// Screens
import 'screens/auth/modern_splash_screen.dart';
import 'screens/auth/rapi_login_screen.dart';
import 'screens/auth/email_verification_screen.dart';
import 'screens/auth/phone_verification_screen.dart';
import 'screens/auth/complete_profile_screen.dart'; // ✅ NUEVO: Pantalla obligatoria para login social
import 'screens/passenger/modern_passenger_home.dart';
import 'screens/passenger/trip_history_screen.dart';
import 'screens/passenger/ratings_history_screen.dart';
import 'screens/passenger/payment_methods_screen.dart';
import 'screens/passenger/favorites_screen.dart';
import 'screens/passenger/promotions_screen.dart';
import 'screens/passenger/profile_screen.dart';
import 'screens/passenger/profile_edit_screen.dart';
import 'screens/passenger/passenger_negotiations_screen.dart';
// Screens with complex constructors temporarily disabled
import 'screens/driver/modern_driver_home.dart';
import 'screens/driver/wallet_screen.dart';
import 'screens/driver/navigation_screen.dart';
import 'screens/driver/communication_screen.dart';
import 'screens/driver/metrics_screen.dart';
import 'screens/driver/vehicle_management_screen.dart';
import 'screens/driver/transactions_history_screen.dart';
import 'screens/driver/earnings_details_screen.dart';
import 'screens/driver/earnings_withdrawal_screen.dart';
import 'providers/vale_provider.dart';
import 'screens/driver/documents_screen.dart';
import 'screens/driver/driver_profile_screen.dart';
import 'screens/driver/driver_negotiations_screen.dart';
import 'screens/driver/recharge_credits_screen.dart';
import 'screens/driver/driver_settings_screen.dart';
import 'screens/driver/driver_security_screen.dart';
import 'screens/driver/driver_ride_config_screen.dart';
import 'screens/driver/driver_notifications_screen.dart';
import 'screens/driver/driver_registration_type_screen.dart';
import 'screens/driver/driver_registration_personal_screen.dart';
import 'screens/driver/driver_registration_vehicle_screen.dart';
import 'screens/driver/driver_registration_documents_screen.dart';
import 'screens/driver/driver_registration_pending_screen.dart';
import 'screens/driver/driver_performance_screen.dart';
import 'screens/driver/driver_achievements_screen.dart';
import 'screens/driver/driver_order_history_screen.dart';
import 'screens/driver/driver_intercity_screen.dart';
import 'screens/driver/driver_freight_screen.dart';
import 'screens/driver/driver_benefits_screen.dart';
import 'screens/driver/driver_benefit_detail_screen.dart';
import 'screens/driver/driver_comfort_rules_screen.dart';
import 'screens/driver/driver_wallet_simple_screen.dart';
import 'screens/driver/driver_recharge_screen.dart';
import 'screens/driver/driver_earnings_detail_screen.dart';
import 'screens/passenger/vale_input_screen.dart';
import 'screens/admin/admin_login_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/users_management_screen.dart';
import 'screens/admin/drivers_management_screen.dart';
import 'screens/admin/financial_screen.dart';
import 'screens/admin/analytics_screen.dart';
import 'screens/admin/settings_admin_screen.dart';
import 'screens/shared/help_center_screen.dart';
import 'screens/shared/settings_screen.dart';
import 'screens/shared/about_screen.dart';
import 'screens/shared/support_screen.dart';
import 'screens/shared/notifications_screen.dart';
// import 'screens/shared/live_tracking_map_screen.dart'; // No usado - ruta comentada
import 'screens/shared/emergency_details_screen.dart';
// Verification screens removed - no longer used
// import 'screens/passenger/trip_verification_code_screen.dart';
// import 'screens/driver/driver_verification_screen.dart';
import 'screens/shared/trip_details_screen.dart';
import 'screens/shared/trip_tracking_screen.dart';
import 'screens/shared/chat_screen.dart';
import 'screens/shared/map_picker_screen.dart';
import 'screens/shared/upgrade_to_driver_screen.dart';
import 'screens/shared/change_phone_number_screen.dart';
import 'screens/driver/active_trip_screen.dart'; // Pantalla de viaje activo para conductor
import 'screens/passenger/trip_completed_screen.dart'; // Pantalla de viaje completado para pasajero
import 'screens/shared/maintenance_screen.dart'; // ✅ NUEVO: Pantalla de mantenimiento del sistema

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Capturar errores del framework Flutter (Crashlytics removido: se migró a logging propio)
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      AppLogger.error('FlutterError capturado', details.exception, details.stack);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      AppLogger.error('PlatformError capturado', error, stack);
      return true;
    };

    AppLogger.separator('INICIANDO RAPPI TEAM APP');
    AppLogger.info('Iniciando aplicación Rappi Team...');

    try {
      // Load .env (may fail on iOS, not critical)
      try {
        await dotenv.load(fileName: '.env');
        AppLogger.info('Variables de entorno cargadas');
      } catch (e) {
        AppLogger.warning('No se pudo cargar .env (normal en iOS): $e');
      }

      // Set orientation (may fail on iPad, not critical)
      try {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      } catch (e) {
        AppLogger.warning('No se pudo configurar orientación (normal en iPad): $e');
      }

    // Configurar barra de estado
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    // Firebase Core — SOLO para que firebase_messaging (FCM push) funcione.
    // Todo lo demás (Auth, Firestore, Storage, Analytics, Crashlytics, App Check)
    // fue migrado al backend Node en el VPS.
    AppLogger.info('Inicializando Firebase Core (solo para FCM)...');
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
    AppLogger.info('Firebase Core listo');

    // Restaurar sesión del backend Node si hay tokens guardados
    await RapiApiClient.instance.restore();
    if (RapiApiClient.instance.isSignedIn) {
      AppLogger.info('Sesión restaurada — iniciando stream SSE');
      RapiSseClient.instance.start();
    }

    // FCM: registrar handler de background messages
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    AppLogger.info('Firebase Messaging (FCM) OK');

    await NotificationService().initialize();
    AppLogger.info('NotificationService OK');

    // Preferencias de usuario
    final preferencesProvider = PreferencesProvider();
    await preferencesProvider.init();
    AppLogger.info('PreferencesProvider OK');

    AppLogger.separator('APP LISTA PARA PRODUCCIÓN');

    runApp(RappiTeamApp(preferencesProvider: preferencesProvider));

  } catch (error, stackTrace) {
    AppLogger.error('Error crítico al inicializar', error, stackTrace);
    try {
      final fallbackProvider = PreferencesProvider();
      await fallbackProvider.init();
      runApp(RappiTeamApp(preferencesProvider: fallbackProvider));
    } catch (fallbackErr, fallbackStack) {
      // Ronda 98: no descartar silenciosamente el segundo error. Antes: el
      // catch (_) mudo dejaba un provider sin init pasado a la app → prefs
      // devolvían valores por defecto silenciosamente (tema, biometría, idioma).
      AppLogger.error('Fallback también falló', fallbackErr, fallbackStack);
      runApp(RappiTeamApp(preferencesProvider: PreferencesProvider()));
    }
  }
  }, (error, stack) {
    AppLogger.error('Zone error no capturado', error, stack);
  });
}

class RappiTeamApp extends StatelessWidget {
  final PreferencesProvider preferencesProvider;

  const RappiTeamApp({super.key, required this.preferencesProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()), // ✅ NUEVO: Provider de idioma
        ChangeNotifierProvider.value(value: preferencesProvider), // ✅ MODIFICADO: Usar provider ya inicializado
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => RideProvider()),
        ChangeNotifierProvider(create: (_) => PriceNegotiationProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => WalletProvider()), // ✅ FIX: Provider para créditos de servicio
        ChangeNotifierProvider(create: (_) => DocumentProvider()), // ✅ FIX: Provider para documentos de conductor
        ChangeNotifierProvider(create: (_) => ValeProvider()),
      ],
      // ✅ HANDLER DE NOTIFICACIONES - Procesa clicks en notificaciones
      child: NotificationHandlerWidget(
        // ✅ DISMISS GLOBAL DEL TECLADO - Funciona en TODA la aplicación
        child: Builder(
          builder: (context) => GestureDetector(
            onTap: () {
              // Cerrar teclado al hacer tap en cualquier parte de la app
              FocusManager.instance.primaryFocus?.unfocus();
              // Force hide on Android where unfocus() alone may not dismiss the native keyboard
              SystemChannels.textInput.invokeMethod('TextInput.hide');
            },
            behavior: HitTestBehavior.translucent, // No bloquear otros gestos
            // ✅ CORREGIDO: Usar MaterialApp directo con animación de tema
            child: _ThemedMaterialApp(),
          ),
        ),
      ),
    );
  }
}

// ✅ SOLUCIÓN DEFINITIVA: Usar Consumer para garantizar rebuild cuando cambia darkMode
class _ThemedMaterialApp extends StatelessWidget {
  const _ThemedMaterialApp();

  @override
  Widget build(BuildContext context) {
    // ✅ Usar Consumer para garantizar que el widget se reconstruya cuando cambie darkMode
    return Consumer<PreferencesProvider>(
      builder: (context, prefsProvider, child) {
        final locale = context.select<LocaleProvider, Locale>((provider) => provider.locale);
        final darkMode = prefsProvider.darkMode;
        final themeMode = darkMode ? ThemeMode.dark : ThemeMode.light;

        return MaterialApp(
      title: 'Rappi Team',
      debugShowCheckedModeBanner: false,
      // navigatorKey global usado por NavigationHelper para navegar desde
      // callbacks externos al widget tree (notificaciones locales, etc.).
      navigatorKey: NavigationHelper.navigatorKey,

      // Configurar localizaciones
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'),
        Locale('en', 'US'),
      ],
      locale: locale,

      // Tema moderno con gradientes y animaciones
      theme: ModernTheme.lightTheme,
      darkTheme: ModernTheme.darkTheme,
      themeMode: themeMode,

      // Ruta inicial
      initialRoute: '/',

      // Rutas
      routes: {
        '/': (context) => ModernSplashScreen(),
        '/login': (context) => const RapiLoginScreen(),
        // '/login-legacy' y '/forgot-password' eliminadas: el backend Node solo
        // soporta login por SMS/OAuth, no email+password (no hay password reset).
        '/email-verification': (context) => EmailVerificationScreen(
          email: (ModalRoute.of(context)!.settings.arguments as String?) ?? '',
        ),
        '/phone-verification': (context) => PhoneVerificationScreen(
          phoneNumber: (ModalRoute.of(context)!.settings.arguments as String?) ?? '',
        ),
        '/auth/complete-profile': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          return CompleteProfileScreen(
            loginMethod: args?['loginMethod'] as String? ?? 'google',
          );
        },

        // Rutas de Pasajero
        '/passenger/home': (context) => ModernPassengerHomeScreen(),
        '/passenger/trip-history': (context) => TripHistoryScreen(),
        '/passenger/ratings-history': (context) => RatingsHistoryScreen(),
        '/passenger/payment-methods': (context) => PaymentMethodsScreen(),
        '/passenger/negotiations': (context) => PassengerNegotiationsScreen(),
        '/passenger/favorites': (context) => FavoritesScreen(),
        '/passenger/promotions': (context) => PromotionsScreen(),
        '/passenger/profile': (context) => ProfileScreen(),
        '/passenger/profile-edit': (context) => ProfileEditScreen(),
        '/passenger/trip-details': (context) => TripDetailsScreen(
          tripId: (ModalRoute.of(context)!.settings.arguments as String?) ?? '',
        ),
        '/passenger/tracking': (context) => TripTrackingScreen(
          rideId: (ModalRoute.of(context)!.settings.arguments as String?) ?? '',
        ),
        // Verification code screen removed - no longer needed

        // Rutas de Conductor
        '/driver/home': (context) => ModernDriverHomeScreen(),
        '/driver/wallet': (context) => WalletScreen(),
        '/driver/navigation': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          return NavigationScreen(
            tripData: args is Map<String, dynamic> ? args : null,
          );
        },
        '/driver/communication': (context) => CommunicationScreen(),
        '/driver/metrics': (context) => MetricsScreen(),
        '/driver/vehicle-management': (context) => VehicleManagementScreen(),
        '/driver/transactions-history': (context) => TransactionsHistoryScreen(),
        '/driver/earnings-details': (context) => EarningsDetailsScreen(),
        '/driver/earnings-withdrawal': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return EarningsWithdrawalScreen(driverId: args?['driverId'] ?? '');
        },
        '/driver/negotiations': (context) => DriverNegotiationsScreen(),
        '/driver/documents': (context) => DocumentsScreen(),
        '/driver/profile': (context) => DriverProfileScreen(),
        '/driver/recharge-credits': (context) => RechargeCreditsScreen(),
        '/driver/settings': (context) => DriverSettingsScreen(),
        '/driver/security': (context) => DriverSecurityScreen(),
        '/driver/ride-config': (context) => DriverRideConfigScreen(),
        '/driver/notifications': (context) => DriverNotificationsScreen(),
        '/driver/registration-type': (context) => DriverRegistrationTypeScreen(),
        '/driver/registration-personal': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return DriverRegistrationPersonalScreen(workType: args?['workType'] ?? 'full_time');
        },
        '/driver/registration-vehicle': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return DriverRegistrationVehicleScreen(registrationData: args?['registrationData'] ?? {});
        },
        '/driver/registration-documents': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return DriverRegistrationDocumentsScreen(registrationData: args?['registrationData'] ?? {});
        },
        '/driver/registration-pending': (context) => DriverRegistrationPendingScreen(),
        '/driver/performance': (context) => DriverPerformanceScreen(),
        '/driver/achievements': (context) => DriverAchievementsScreen(),
        '/driver/order-history': (context) => DriverOrderHistoryScreen(),
        '/driver/intercity': (context) => DriverIntercityScreen(),
        '/driver/freight': (context) => DriverFreightScreen(),
        '/driver/benefits': (context) => DriverBenefitsScreen(),
        '/driver/comfort-rules': (context) => DriverComfortRulesScreen(),
        '/driver/wallet-simple': (context) => DriverWalletSimpleScreen(),
        '/driver/recharge': (context) => DriverRechargeScreen(),
        '/driver/earnings-detail': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return DriverEarningsDetailScreen(
            todayEarnings: (args?['todayEarnings'] as num?)?.toDouble() ?? 0.0,
            targetEarnings: (args?['targetEarnings'] as num?)?.toDouble() ?? 100.0,
          );
        },
        // '/shared/change-password' eliminada: no aplica con SMS/OAuth.
        '/passenger/vale-input': (context) => ValeInputScreen(),
        // Driver verification screen removed - no longer needed
        '/driver/active-trip': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final tripId = args?['tripId'] as String? ?? '';
          if (tripId.isEmpty) {
            return const Scaffold(
              body: Center(child: Text('Error: No se encontró el ID del viaje')),
            );
          }
          return ActiveTripScreen(tripId: tripId);
        },

        // Rutas de Admin
        '/admin/login': (context) => AdminLoginScreen(),
        '/admin/dashboard': (context) => AdminDashboardScreen(),
        '/admin/users-management': (context) => UsersManagementScreen(),
        '/admin/drivers-management': (context) => DriversManagementScreen(),
        '/admin/financial': (context) => FinancialScreen(),
        '/admin/analytics': (context) => AnalyticsScreen(),
        '/admin/settings': (context) => SettingsAdminScreen(),

        // Rutas Compartidas — algunas rutas reciben Map, otras String plano.
        // Los helpers _readArg / _readMap abajo normalizan ambos casos.
        '/shared/chat': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final rideId = _readRideOrTripId(args);
          String? otherUserName;
          String? otherUserRole;
          String? otherUserId;
          if (args is Map) {
            otherUserName = args['otherUserName'] as String?;
            otherUserRole = args['otherUserRole'] as String?;
            otherUserId = args['otherUserId'] as String?;
          }
          return ChatScreen(
            rideId: rideId,
            otherUserName: otherUserName ?? 'Usuario',
            otherUserRole: otherUserRole ?? 'user',
            otherUserId: otherUserId,
          );
        },
        '/shared/trip-details': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          return TripDetailsScreen(tripId: _readRideOrTripId(args));
        },
        '/shared/trip-tracking': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          return TripTrackingScreen(rideId: _readRideOrTripId(args));
        },
        '/shared/help-center': (context) => HelpCenterScreen(),
        '/shared/settings': (context) => SettingsScreen(),
        '/shared/about': (context) => AboutScreen(),
        '/shared/support': (context) => SupportScreen(),
        '/shared/notifications': (context) => NotificationsScreen(),
        '/shared/emergency-details': (context) => EmergencyDetailsScreen(
          emergencyId: (ModalRoute.of(context)!.settings.arguments as String?) ?? '',
        ),
        '/shared/upgrade-to-driver': (context) => UpgradeToDriverScreen(),
        '/upgrade-to-driver': (context) => UpgradeToDriverScreen(),
        '/driver/register': (context) => DriverRegistrationTypeScreen(),
        '/driver/register/pending': (context) => DriverRegistrationPendingScreen(),
        '/driver/register/personal': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return DriverRegistrationPersonalScreen(workType: args?['workType'] ?? 'full_time');
        },
        '/driver/register/vehicle': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return DriverRegistrationVehicleScreen(registrationData: args ?? {});
        },
        '/driver/register/documents': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return DriverRegistrationDocumentsScreen(registrationData: args ?? {});
        },
        '/maintenance': (context) => MaintenanceScreen(), // ✅ NUEVO: Pantalla de mantenimiento
        '/map-picker': (context) => MapPickerScreen(),
        '/change-phone-number': (context) => ChangePhoneNumberScreen(
          currentPhoneNumber: (ModalRoute.of(context)!.settings.arguments as String?) ?? '',
        ),
        '/trip-tracking': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          return TripTrackingScreen(
            rideId: args?['rideId'] as String? ?? '',
          );
        },
        '/trip-completed': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          return TripCompletedScreen(
            tripId: args?['tripId'] as String? ?? '',
          );
        },
      },
    );
      },  // Cierra builder del Consumer
    );    // Cierra Consumer
  }
}

/// Lee un `rideId`/`tripId` desde el `arguments` de una ruta.
/// Acepta:
///   - `String` plano ("abc-123")
///   - `Map<String, dynamic>` con `rideId`, `tripId` o `id`
///   - cualquier otra cosa → ''
String _readRideOrTripId(Object? args) {
  if (args is String) return args;
  if (args is Map) {
    final v = args['rideId'] ?? args['tripId'] ?? args['id'];
    if (v is String) return v;
    if (v != null) return v.toString();
  }
  return '';
}