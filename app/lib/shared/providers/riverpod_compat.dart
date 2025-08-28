// Archivo de compatibilidad completamente implementado con servicios reales

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/crash_reporting_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/token_service.dart';
import '../../core/services/location_service.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/payment/data/services/mercadopago_service.dart';
import '../models/user_model.dart';


// ===== SERVICIOS CORE =====
final tokenServiceProvider = Provider<TokenService>((ref) {
  return TokenService();
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService.instance;
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

final mercadoPagoServiceProvider = Provider<MercadoPagoService>((ref) {
  return MercadoPagoService();
});

// Los providers de analytics y crash reporting ya están en sus archivos respectivos

// ===== REPOSITORIOS =====
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref);
});

// ===== PROVIDERS DE ESTADO =====
final authStateProvider = StreamProvider<UserModel?>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return authRepository.authStateChanges;
});

final currentUserProvider = Provider<UserModel?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.whenOrNull(data: (user) => user);
});

// ===== PROVIDERS DE UBICACIÓN =====
final currentLocationProvider = StreamProvider<Position?>((ref) {
  return ref.watch(locationServiceProvider).getLocationStream();
});

// El locationProvider es redundante con currentLocationProvider, así que lo removemos
// Si necesitamos una referencia alternativa, podemos usar currentLocationProvider directamente

// ===== PROVIDERS DE NOTIFICACIONES =====
final rideNotificationProvider = StreamProvider<RemoteMessage>((ref) {
  final notificationService = ref.watch(notificationServiceProvider);
  return notificationService.onMessageReceived;
});

final fcmTokenProvider = FutureProvider<String?>((ref) {
  final notificationService = ref.watch(notificationServiceProvider);
  return notificationService.getToken();
});

// ===== PROVIDERS ADICIONALES PARA COMPLETITUD =====
final isUserLoggedInProvider = Provider<bool>((ref) {
  final currentUser = ref.watch(currentUserProvider);
  return currentUser != null;
});

final userRoleProvider = Provider<String?>((ref) {
  final currentUser = ref.watch(currentUserProvider);
  return currentUser?.role;
});

final isDriverProvider = Provider<bool>((ref) {
  final userRole = ref.watch(userRoleProvider);
  return userRole == 'driver';
});

final isPassengerProvider = Provider<bool>((ref) {
  final userRole = ref.watch(userRoleProvider);
  return userRole == 'passenger';
});

final isAdminProvider = Provider<bool>((ref) {
  final userRole = ref.watch(userRoleProvider);
  return userRole == 'admin';
});

// ===== PROVIDERS DE CONFIGURACIÓN =====
final appInitializationProvider = FutureProvider<bool>((ref) async {
  try {
    // Inicializar servicios
    final crashReporting = ref.read(crashReportingServiceProvider);
    final notification = ref.read(notificationServiceProvider);
    
    await crashReporting.initialize();
    await notification.initialize();
    
    return true;
  } catch (e) {
    return false;
  }
});