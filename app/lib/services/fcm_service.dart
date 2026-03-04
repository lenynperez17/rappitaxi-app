import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'firebase_service.dart';

/// ✅ Servicio FCM SEGURO - Notificaciones enviadas desde Cloud Functions
///
/// ⚠️ CAMBIO DE ARQUITECTURA DE SEGURIDAD:
/// ANTES: La app Flutter tenía service-account.json y enviaba notificaciones directamente (INSEGURO)
/// AHORA: Las notificaciones se envían desde Cloud Functions en el servidor (SEGURO)
///
/// VENTAJAS:
/// - ✅ Service Account NO está en el APK (no puede ser extraído)
/// - ✅ Mayor seguridad: permisos de admin solo en servidor
/// - ✅ Mejor escalabilidad: Cloud Functions escala automáticamente
/// - ✅ Logs centralizados en Firebase Console
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Inicializar servicio FCM
  Future<void> initialize() async {
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      final token = await FirebaseMessaging.instance.getToken();
      debugPrint('✅ FCM Token: ${token?.substring(0, 20)}...');
    } catch (e) {
      debugPrint('❌ Error inicializando FCM: $e');
      await _firebaseService.recordError(e, StackTrace.current);
    }
  }

  /// ✅ Enviar notificación usando Cloud Function (SEGURO)
  ///
  /// Esta función llama a la Cloud Function `sendPushNotification` que:
  /// 1. Valida permisos en el servidor
  /// 2. Obtiene el token FCM del usuario desde Firestore
  /// 3. Envía la notificación usando Firebase Admin SDK (con service-account del servidor)
  Future<bool> _sendNotificationViaCloudFunction({
    required String userId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
    String? imageUrl,
  }) async {
    try {
      debugPrint('📲 Enviando notificación vía Cloud Function...');
      debugPrint('   Usuario: $userId');
      debugPrint('   Título: $title');

      final result = await _functions.httpsCallable('sendPushNotification').call({
        'userId': userId,
        'title': title,
        'body': body,
        'data': data,
        if (imageUrl != null) 'imageUrl': imageUrl,
      });

      final success = result.data['success'] == true;

      if (success) {
        debugPrint('✅ Notificación enviada exitosamente');
        debugPrint('   Message ID: ${result.data['messageId']}');
      } else {
        debugPrint('❌ Error en respuesta de Cloud Function');
      }

      return success;
    } catch (e) {
      debugPrint('❌ Error llamando a Cloud Function: $e');
      await _firebaseService.recordError(e, StackTrace.current);
      return false;
    }
  }

  /// Validar formato de token FCM
  bool isValidFCMToken(String token) {
    return token.isNotEmpty && token.length > 100;
  }

  /// Enviar notificación de nuevo viaje a conductor
  Future<bool> sendTripRequestToDriver({
    required String driverId,
    required String tripId,
    required String passengerName,
    required String origin,
    required String destination,
    required double estimatedFare,
  }) async {
    return await _sendNotificationViaCloudFunction(
      userId: driverId,
      title: 'Nuevo viaje disponible',
      body: '$passengerName solicita un viaje de $origin a $destination',
      data: {
        'type': 'trip_request',
        'tripId': tripId,
        'passengerId': passengerName,
        'origin': origin,
        'destination': destination,
        'estimatedFare': estimatedFare.toString(),
        'action': 'open_trip_details',
      },
    );
  }

  /// Notificar al pasajero que el conductor aceptó
  Future<bool> sendTripAcceptedToPassenger({
    required String passengerId,
    required String tripId,
    required String driverName,
    required String vehicleInfo,
    required String estimatedArrival,
  }) async {
    return await _sendNotificationViaCloudFunction(
      userId: passengerId,
      title: '¡Conductor encontrado!',
      body: '$driverName ($vehicleInfo) está en camino. Llegada estimada: $estimatedArrival',
      data: {
        'type': 'trip_accepted',
        'tripId': tripId,
        'driverName': driverName,
        'vehicleInfo': vehicleInfo,
        'action': 'open_tracking',
      },
    );
  }

  /// Notificar que el conductor llegó al punto de recogida
  Future<bool> sendDriverArrivedToPassenger({
    required String passengerId,
    required String tripId,
    required String driverName,
  }) async {
    return await _sendNotificationViaCloudFunction(
      userId: passengerId,
      title: 'Tu conductor ha llegado',
      body: '$driverName está esperándote en el punto de recogida',
      data: {
        'type': 'driver_arrived',
        'tripId': tripId,
        'action': 'open_tracking',
      },
    );
  }

  /// Notificar inicio del viaje
  Future<bool> sendTripStartedNotification({
    required String userId,
    required String tripId,
    required String userType,
  }) async {
    final title = userType == 'passenger'
        ? 'Viaje iniciado'
        : 'Viaje en curso';
    final body = userType == 'passenger'
        ? 'Tu viaje ha comenzado. ¡Disfruta el trayecto!'
        : 'El pasajero ha abordado. Viaje en curso.';

    return await _sendNotificationViaCloudFunction(
      userId: userId,
      title: title,
      body: body,
      data: {
        'type': 'trip_started',
        'tripId': tripId,
        'action': 'open_tracking',
      },
    );
  }

  /// Notificar finalización del viaje
  Future<bool> sendTripCompletedNotification({
    required String userId,
    required String tripId,
    required double finalFare,
    required String userType,
  }) async {
    final title = 'Viaje completado';
    final body = userType == 'passenger'
        ? 'Tu viaje ha finalizado. Total: S/. ${finalFare.toStringAsFixed(2)}'
        : 'Viaje completado exitosamente. Ganancia: S/. ${finalFare.toStringAsFixed(2)}';

    return await _sendNotificationViaCloudFunction(
      userId: userId,
      title: title,
      body: body,
      data: {
        'type': 'trip_completed',
        'tripId': tripId,
        'finalFare': finalFare.toString(),
        'action': 'open_rating',
      },
    );
  }

  /// Notificar cancelación de viaje
  Future<bool> sendTripCancelledNotification({
    required String userId,
    required String tripId,
    required String reason,
    required String userType,
  }) async {
    final title = 'Viaje cancelado';
    final body = userType == 'passenger'
        ? 'Tu viaje ha sido cancelado. Motivo: $reason'
        : 'El pasajero canceló el viaje. Motivo: $reason';

    return await _sendNotificationViaCloudFunction(
      userId: userId,
      title: title,
      body: body,
      data: {
        'type': 'trip_cancelled',
        'tripId': tripId,
        'reason': reason,
        'action': 'close_trip',
      },
    );
  }

  /// Notificar nuevo mensaje en el chat
  Future<bool> sendChatMessageNotification({
    required String userId,
    required String senderName,
    required String message,
    required String chatId,
  }) async {
    return await _sendNotificationViaCloudFunction(
      userId: userId,
      title: 'Nuevo mensaje de $senderName',
      body: message,
      data: {
        'type': 'chat_message',
        'chatId': chatId,
        'senderName': senderName,
        'action': 'open_chat',
      },
    );
  }

  /// Notificar cambio en el estado de verificación del conductor
  Future<bool> sendDriverVerificationStatusNotification({
    required String driverId,
    required String status,
    String? rejectionReason,
  }) async {
    final title = status == 'approved'
        ? '¡Verificación aprobada!'
        : 'Verificación pendiente';
    final body = status == 'approved'
        ? 'Tu cuenta de conductor ha sido aprobada. ¡Puedes comenzar a aceptar viajes!'
        : rejectionReason ?? 'Tu verificación está siendo revisada.';

    return await _sendNotificationViaCloudFunction(
      userId: driverId,
      title: title,
      body: body,
      data: {
        'type': 'verification_status',
        'status': status,
        if (rejectionReason != null) 'reason': rejectionReason,
        'action': 'open_profile',
      },
    );
  }

  /// Notificación de promoción disponible
  Future<bool> sendPromotionNotification({
    required String userId,
    required String promoTitle,
    required String promoDescription,
    required String promoCode,
  }) async {
    return await _sendNotificationViaCloudFunction(
      userId: userId,
      title: '🎉 $promoTitle',
      body: promoDescription,
      data: {
        'type': 'promotion',
        'promoCode': promoCode,
        'action': 'open_promotions',
      },
    );
  }

  /// Notificación genérica
  Future<bool> sendGenericNotification({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? imageUrl,
  }) async {
    return await _sendNotificationViaCloudFunction(
      userId: userId,
      title: title,
      body: body,
      data: data ?? {},
      imageUrl: imageUrl,
    );
  }

  // ============================================
  // MÉTODOS ADICIONALES (compatibilidad)
  // ============================================

  /// Obtener token FCM del dispositivo actual
  Future<String?> getDeviceFCMToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('❌ Error obteniendo FCM token: $e');
      return null;
    }
  }

  /// Suscribirse a un topic de FCM
  Future<void> subscribeToTopic(String topic) async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic(topic);
      debugPrint('✅ Suscrito al topic: $topic');
    } catch (e) {
      debugPrint('❌ Error suscribiéndose al topic $topic: $e');
    }
  }

  /// Desuscribirse de un topic de FCM
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      debugPrint('✅ Desuscrito del topic: $topic');
    } catch (e) {
      debugPrint('❌ Error desuscribiéndose del topic $topic: $e');
    }
  }

  /// Enviar notificación de estado de viaje (genérico)
  Future<bool> sendTripStatusNotification({
    required String userId,
    required String tripId,
    required String status,
    String? message,
  }) async {
    return await _sendNotificationViaCloudFunction(
      userId: userId,
      title: 'Actualización de viaje',
      body: message ?? 'El estado del viaje ha cambiado a: $status',
      data: {
        'type': 'trip_status',
        'tripId': tripId,
        'status': status,
        'action': 'open_tracking',
      },
    );
  }

  /// Enviar notificación a múltiples conductores
  Future<Map<String, bool>> sendRideNotificationToMultipleDrivers({
    required List<String> driverIds,
    required String tripId,
    required String passengerName,
    required String origin,
    required String destination,
    required int estimatedFare,
  }) async {
    final results = <String, bool>{};

    for (final driverId in driverIds) {
      final success = await sendTripRequestToDriver(
        driverId: driverId,
        tripId: tripId,
        passengerName: passengerName,
        origin: origin,
        destination: destination,
        estimatedFare: estimatedFare.toDouble(),
      );
      results[driverId] = success;
    }

    return results;
  }

  /// Limpiar tokens inválidos (stub - manejado por Cloud Functions)
  Future<void> cleanupInvalidTokens() async {
    debugPrint('ℹ️ Limpieza de tokens manejada por Cloud Functions');
    // No-op: La limpieza de tokens se hace en el servidor
  }
}
