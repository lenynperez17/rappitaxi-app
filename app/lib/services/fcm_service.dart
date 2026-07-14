import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'rapi_api_client.dart';

/// ✅ Servicio FCM SEGURO - Notificaciones enviadas desde el backend Node (VPS)
///
/// ⚠️ ARQUITECTURA POST-MIGRACIÓN (2026-07):
/// - Firebase Auth / Firestore / Realtime DB / Storage → REEMPLAZADOS por el
///   backend Node en el VPS a través de [RapiApiClient].
/// - `firebase_messaging` es el ÚNICO servicio Firebase que sobrevive porque
///   sigue siendo la vía oficial para entregar push notifications al
///   dispositivo.
///
/// RESPONSABILIDADES DE ESTE SERVICIO:
/// - Obtener y refrescar el token FCM del dispositivo.
/// - Registrar/actualizar el token en el backend Node
///   (`api.registerFcmToken`), quien lo persistirá en su base de datos.
/// - Suscribir/desuscribir el dispositivo a topics de FCM.
///
/// El envío de notificaciones a otros usuarios YA NO se hace desde el cliente:
/// lo hace el backend Node en respuesta a eventos del negocio (viaje aceptado,
/// pago acreditado, mensaje de chat, etc.). Los métodos `send…` de este
/// servicio se mantienen sólo por compatibilidad con providers existentes y
/// devuelven `true` como no-op para no romper la interfaz pública.
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final RapiApiClient _api = RapiApiClient.instance;

  String? _lastRegisteredToken;

  /// Inicializar servicio FCM (permisos + token + registro en backend).
  Future<void> initialize() async {
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: true,
      );

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        debugPrint('✅ FCM Token: ${token.substring(0, 20)}...');
        // Registrar el token en el backend cuando ya haya sesión.
        // Si aún no hay sesión (login pendiente), quien invoque login debe
        // llamar a [registerDeviceTokenWithBackend] tras autenticarse.
        if (_api.isSignedIn) {
          await registerDeviceTokenWithBackend(token);
        }
      }

      // Refresco automático del token → re-registrar en backend.
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        debugPrint('🔄 FCM token refrescado: ${newToken.substring(0, 20)}...');
        if (_api.isSignedIn) {
          await registerDeviceTokenWithBackend(newToken);
        }
      });
    } catch (e) {
      debugPrint('❌ Error inicializando FCM: $e');
    }
  }

  /// Registra (o actualiza) el token FCM del dispositivo en el backend Node.
  /// Es idempotente: si el token no cambió respecto al último registrado,
  /// no vuelve a llamar al backend.
  Future<bool> registerDeviceTokenWithBackend(String token) async {
    if (token.isEmpty) return false;
    if (_lastRegisteredToken == token) return true;
    try {
      final platform = _detectPlatform();
      await _api.registerFcmToken(token, platform: platform);
      _lastRegisteredToken = token;
      debugPrint('✅ Token FCM registrado en backend (platform=$platform)');
      return true;
    } catch (e) {
      debugPrint('❌ Error registrando token FCM en backend: $e');
      return false;
    }
  }

  String _detectPlatform() {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
    } catch (_) {}
    return 'unknown';
  }

  /// Validar formato de token FCM
  bool isValidFCMToken(String token) {
    return token.isNotEmpty && token.length > 100;
  }

  // ============================================
  // MÉTODOS DE SEND* — SE MANTIENEN POR COMPATIBILIDAD
  // ============================================
  //
  // El envío real de push notifications ahora lo dispara el backend Node en
  // respuesta a los eventos del negocio. Los providers de la app llaman a
  // estos métodos como parte de su flujo existente; para no romper la
  // interfaz pública devolvemos `true` como no-op y logueamos.

  Future<bool> sendTripRequestToDriver({
    required String driverId,
    required String tripId,
    required String passengerName,
    required String origin,
    required String destination,
    required double estimatedFare,
  }) async {
    debugPrint(
        'ℹ️ sendTripRequestToDriver → delegado al backend (driver=$driverId, trip=$tripId)');
    return true;
  }

  Future<bool> sendTripAcceptedToPassenger({
    required String passengerId,
    required String tripId,
    required String driverName,
    required String vehicleInfo,
    required String estimatedArrival,
  }) async {
    debugPrint(
        'ℹ️ sendTripAcceptedToPassenger → delegado al backend (passenger=$passengerId, trip=$tripId)');
    return true;
  }

  Future<bool> sendDriverArrivedToPassenger({
    required String passengerId,
    required String tripId,
    required String driverName,
  }) async {
    debugPrint(
        'ℹ️ sendDriverArrivedToPassenger → delegado al backend (passenger=$passengerId, trip=$tripId)');
    return true;
  }

  Future<bool> sendTripStartedNotification({
    required String userId,
    required String tripId,
    required String userType,
  }) async {
    debugPrint(
        'ℹ️ sendTripStartedNotification → delegado al backend (user=$userId, trip=$tripId)');
    return true;
  }

  Future<bool> sendTripCompletedNotification({
    required String userId,
    required String tripId,
    required double finalFare,
    required String userType,
  }) async {
    debugPrint(
        'ℹ️ sendTripCompletedNotification → delegado al backend (user=$userId, trip=$tripId)');
    return true;
  }

  Future<bool> sendTripCancelledNotification({
    required String userId,
    required String tripId,
    required String reason,
    required String userType,
  }) async {
    debugPrint(
        'ℹ️ sendTripCancelledNotification → delegado al backend (user=$userId, trip=$tripId)');
    return true;
  }

  Future<bool> sendChatMessageNotification({
    required String userId,
    required String senderName,
    required String message,
    required String chatId,
  }) async {
    debugPrint(
        'ℹ️ sendChatMessageNotification → delegado al backend (user=$userId, chat=$chatId)');
    return true;
  }

  Future<bool> sendDriverVerificationStatusNotification({
    required String driverId,
    required String status,
    String? rejectionReason,
  }) async {
    debugPrint(
        'ℹ️ sendDriverVerificationStatusNotification → delegado al backend (driver=$driverId, status=$status)');
    return true;
  }

  Future<bool> sendPromotionNotification({
    required String userId,
    required String promoTitle,
    required String promoDescription,
    required String promoCode,
  }) async {
    debugPrint(
        'ℹ️ sendPromotionNotification → delegado al backend (user=$userId, promo=$promoCode)');
    return true;
  }

  Future<bool> sendGenericNotification({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? imageUrl,
  }) async {
    debugPrint('ℹ️ sendGenericNotification → delegado al backend (user=$userId)');
    return true;
  }

  // ============================================
  // TOKEN + TOPICS (firebase_messaging directo)
  // ============================================

  /// Obtener token FCM del dispositivo actual.
  Future<String?> getDeviceFCMToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('❌ Error obteniendo FCM token: $e');
      return null;
    }
  }

  /// Suscribirse a un topic de FCM.
  Future<void> subscribeToTopic(String topic) async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic(topic);
      debugPrint('✅ Suscrito al topic: $topic');
    } catch (e) {
      debugPrint('❌ Error suscribiéndose al topic $topic: $e');
    }
  }

  /// Desuscribirse de un topic de FCM.
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      debugPrint('✅ Desuscrito del topic: $topic');
    } catch (e) {
      debugPrint('❌ Error desuscribiéndose del topic $topic: $e');
    }
  }

  /// Enviar notificación de estado de viaje (genérico) — no-op post-migración.
  Future<bool> sendTripStatusNotification({
    required String userId,
    required String tripId,
    required String status,
    String? message,
  }) async {
    debugPrint(
        'ℹ️ sendTripStatusNotification → delegado al backend (user=$userId, trip=$tripId, status=$status)');
    return true;
  }

  /// Enviar notificación a múltiples conductores — no-op post-migración.
  /// El backend Node se encarga del broadcast cuando se crea el ride.
  Future<Map<String, bool>> sendRideNotificationToMultipleDrivers({
    required List<String> driverIds,
    required String tripId,
    required String passengerName,
    required String origin,
    required String destination,
    required int estimatedFare,
  }) async {
    debugPrint(
        'ℹ️ sendRideNotificationToMultipleDrivers → delegado al backend (drivers=${driverIds.length}, trip=$tripId)');
    return {for (final id in driverIds) id: true};
  }

  /// Limpiar tokens inválidos (no-op — lo maneja el backend Node).
  Future<void> cleanupInvalidTokens() async {
    debugPrint('ℹ️ Limpieza de tokens FCM la maneja el backend Node');
  }
}
