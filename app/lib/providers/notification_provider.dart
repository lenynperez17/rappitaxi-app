import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/utils/payment_utils.dart';
import '../models/notification_types.dart';
import '../services/fcm_service.dart';
import '../services/notification_service.dart';
import '../services/rapi_api_client.dart';
import '../services/rapi_sse_client.dart';
import '../utils/error_messages.dart';

/// Provider de Notificaciones — usa el backend Node (RapiApiClient) para el
/// listado in-app y suscribe SSE (RapiSseClient) para nuevas notifs en tiempo
/// real. `firebase_messaging` se mantiene sólo para push del sistema (topics
/// + delivery), pero los datos in-app (bell icon, historial) viven ya en el
/// backend Node.
class NotificationProvider extends ChangeNotifier {
  final NotificationService _notificationService = NotificationService();
  final FCMService _fcmService = FCMService();
  final RapiApiClient _api = RapiApiClient.instance;

  final List<NotificationData> _notifications = [];
  bool _notificationsEnabled = true;
  bool _isLoading = false;
  final Map<String, bool> _subscribedTopics = {
    'all_users': true,
    'app_updates': true,
    'passengers': true,
    'drivers': false,
    'admins': false,
    'passenger_promotions': true,
    'system_alerts': true,
  };

  StreamSubscription<Map<String, dynamic>>? _sseSub;

  // Getters (interfaz pública — NO cambiar nombres/tipos)
  List<NotificationData> get notifications => List.unmodifiable(_notifications);
  List<NotificationData> get unreadNotifications =>
      _notifications.where((n) => !n.isRead).toList();
  int get unreadCount => unreadNotifications.length;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get isLoading => _isLoading;
  Map<String, bool> get subscribedTopics => Map.unmodifiable(_subscribedTopics);
  Map<String, bool> get topicSubscriptions => subscribedTopics;

  /// Token FCM real del dispositivo (NO el UID del usuario).
  String? _cachedFcmToken;
  String? get fcmToken => _cachedFcmToken;

  /// Indica si el provider ya tiene sesión válida en el backend Node.
  bool get isInitialized => _api.isSignedIn;

  NotificationProvider() {
    _initializeNotifications();
  }

  /// Inicializar notificaciones locales + escucha SSE + primer fetch.
  Future<void> _initializeNotifications() async {
    await _notificationService.initialize();

    // Cachear token FCM del dispositivo (útil para la UI de settings).
    _cachedFcmToken = await _fcmService.getDeviceFCMToken();
    if (_cachedFcmToken != null) {
      debugPrint('✅ Token FCM obtenido: ${_cachedFcmToken!.substring(0, 20)}...');
    }

    // Suscribirse al stream SSE del backend para push en tiempo real dentro
    // de la app (bell icon).
    _sseSub ??= RapiSseClient.instance.notifications.listen(_onSseNotification);

    await _loadNotificationsFromBackend();
  }

  /// Cargar historial de notificaciones desde el backend Node.
  Future<void> _loadNotificationsFromBackend() async {
    if (!_api.isSignedIn) return;

    _isLoading = true;
    notifyListeners();

    try {
      final result = await _api.listNotifications(limit: 50);
      final items = (result['notifications'] as List?) ?? const [];

      _notifications.clear();
      for (final raw in items) {
        if (raw is! Map) continue;
        final data = Map<String, dynamic>.from(raw);
        _notifications.add(_notificationFromBackend(data));
      }
    } catch (e) {
      debugPrint(userFriendlyError(e, fallback: 'Error cargando notificaciones'));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Handler de eventos SSE: al llegar una notificación nueva la insertamos
  /// arriba y refrescamos la UI.
  void _onSseNotification(Map<String, dynamic> event) {
    try {
      // El backend puede enviar el payload envuelto en `notification`.
      final payload = event['notification'] is Map
          ? Map<String, dynamic>.from(event['notification'] as Map)
          : event;
      final notification = _notificationFromBackend(payload);

      // Evitar duplicados si el mismo id ya estaba (ej. refetch + SSE).
      final existingIdx = _notifications.indexWhere((n) => n.id == notification.id);
      if (existingIdx != -1) {
        _notifications[existingIdx] = notification;
      } else {
        _notifications.insert(0, notification);
      }
      notifyListeners();
    } catch (e) {
      debugPrint(userFriendlyError(e, fallback: 'Error procesando notificación SSE'));
    }
  }

  /// Convierte un mapa del backend Node en un [NotificationData].
  /// Timestamps llegan como ISO-8601 (columna TIMESTAMP en Postgres).
  NotificationData _notificationFromBackend(Map<String, dynamic> data) {
    final rawTs = data['timestamp'] ?? data['createdAt'] ?? data['created_at'];
    DateTime ts;
    if (rawTs is String) {
      ts = DateTime.tryParse(rawTs) ?? DateTime.now();
    } else {
      ts = DateTime.now();
    }
    final rawInner = data['data'];
    final Map<String, dynamic>? inner = rawInner is Map
        ? Map<String, dynamic>.from(rawInner)
        : null;

    return NotificationData(
      id: (data['id'] ?? '').toString(),
      title: (data['title'] ?? '') as String,
      body: (data['body'] ?? '') as String,
      timestamp: ts,
      type: _getNotificationTypeFromString(
          (data['type'] ?? 'system').toString()),
      // Ronda 247: el backend manda `readAt`, no un bool. Sin esto el contador
      // de la campana marcaba TODAS como no leídas para siempre.
      isRead: (data['isRead'] ?? data['is_read']) == true ||
          data['readAt'] != null ||
          data['read_at'] != null,
      data: inner,
      channel: NotificationChannel.general,
    );
  }

  NotificationType _getNotificationTypeFromString(String type) {
    switch (type) {
      case 'general':
        return NotificationType.general;
      case 'tripRequest':
        return NotificationType.tripRequest;
      case 'tripAccepted':
        return NotificationType.tripAccepted;
      case 'tripStarted':
        return NotificationType.tripStarted;
      case 'tripCancelled':
        return NotificationType.tripCancelled;
      case 'tripCompleted':
        return NotificationType.tripCompleted;
      case 'driverArrived':
        return NotificationType.driverArrived;
      case 'payment':
        return NotificationType.payment;
      case 'promotion':
        return NotificationType.promotion;
      case 'support':
        return NotificationType.support;
      default:
        return NotificationType.system;
    }
  }

  void setNotificationsEnabled(bool enabled) {
    _notificationsEnabled = enabled;
    notifyListeners();
  }

  /// Agregar una notificación local (ej. eventos generados en cliente).
  /// El backend Node es la fuente de verdad para las notifs remotas — las
  /// generadas localmente sólo viven en memoria hasta que el backend las
  /// emita de vuelta por SSE.
  Future<void> addNotification(NotificationData notification) async {
    _notifications.insert(0, notification);
    notifyListeners();
  }

  void markAsRead(String notificationId) {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index == -1) return;

    _notifications[index] = _notifications[index].copyWith(isRead: true);
    notifyListeners();

    // Propagar el read al backend Node.
    unawaited(_markReadInBackend(notificationId));
  }

  Future<void> _markReadInBackend(String notificationId) async {
    if (!_api.isSignedIn) return;
    try {
      await _api.markNotificationRead(notificationId);
    } catch (e) {
      debugPrint(userFriendlyError(e, fallback: 'Error marcando notificación leída'));
    }
  }

  void markAllAsRead() {
    for (int i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
      }
    }
    notifyListeners();

    unawaited(_markAllReadInBackend());
  }

  Future<void> _markAllReadInBackend() async {
    if (!_api.isSignedIn) return;
    try {
      await _api.markAllNotificationsRead();
    } catch (e) {
      debugPrint(userFriendlyError(e, fallback: 'Error marcando todas notificaciones leídas'));
    }
  }

  void clearAll() {
    _notifications.clear();
    notifyListeners();
  }

  void clearAllNotifications() {
    clearAll();
  }

  void deleteNotification(String notificationId) {
    _notifications.removeWhere((n) => n.id == notificationId);
    notifyListeners();
    // El backend Node no expone (aún) endpoint de delete individual.
    // El delete local basta para la UX; el registro histórico vive en Postgres.
  }

  void removeNotification(String notificationId) {
    deleteNotification(notificationId);
  }

  void updateTopicSubscription(String topic, bool subscribed) {
    _subscribedTopics[topic] = subscribed;
    notifyListeners();
  }

  Future<void> subscribeToTopic(String topic) async {
    _subscribedTopics[topic] = true;
    notifyListeners();

    try {
      await _fcmService.subscribeToTopic(topic);
      debugPrint('✅ Suscrito al topic: $topic');
    } catch (e) {
      _subscribedTopics[topic] = false;
      notifyListeners();
      debugPrint('❌ Error suscribiendo a topic: $topic');
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    _subscribedTopics[topic] = false;
    notifyListeners();

    try {
      await _fcmService.unsubscribeFromTopic(topic);
      debugPrint('✅ Desuscrito del topic: $topic');
    } catch (e) {
      _subscribedTopics[topic] = true;
      notifyListeners();
      debugPrint('❌ Error desuscribiendo de topic: $topic');
    }
  }

  void sendTestNotification() {
    addNotification(NotificationData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Notificación de prueba',
      body: 'Esta es una notificación de prueba del sistema',
      timestamp: DateTime.now(),
      type: NotificationType.system,
      isRead: false,
      channel: NotificationChannel.general,
    ));
  }

  /// Agregar notificación de viaje específica (local + mostrar en bandeja).
  Future<void> addTripNotification({
    required String tripId,
    required NotificationType type,
    required String title,
    required String body,
    Map<String, dynamic>? tripData,
  }) async {
    final notification = NotificationData(
      id: '${type.toString().split('.').last}_$tripId',
      title: title,
      body: body,
      timestamp: DateTime.now(),
      type: type,
      isRead: false,
      data: {
        'tripId': tripId,
        ...?tripData,
      },
      channel: NotificationChannel.general,
    );

    await addNotification(notification);

    await _notificationService.showRideNotification(
      title: title,
      body: body,
      rideData: {
        'tripId': tripId,
        'type': type.toString(),
        ...?tripData,
      },
    );
  }

  Future<void> notifyRideRequestReceived({
    required String tripId,
    required String pickupAddress,
    required String destinationAddress,
    required double fare,
    required String passengerName,
  }) async {
    await addTripNotification(
      tripId: tripId,
      type: NotificationType.tripRequest,
      title: '¡Nueva solicitud de viaje!',
      body: '$passengerName solicita un viaje desde $pickupAddress',
      tripData: {
        'pickupAddress': pickupAddress,
        'destinationAddress': destinationAddress,
        'fare': fare,
        'passengerName': passengerName,
      },
    );
  }

  Future<void> notifyRideAccepted({
    required String tripId,
    required String driverName,
    required String vehicleInfo,
    required String estimatedArrival,
  }) async {
    await addTripNotification(
      tripId: tripId,
      type: NotificationType.tripAccepted,
      title: '¡Viaje aceptado!',
      body: '$driverName va hacia ti. Llegada estimada: $estimatedArrival',
      tripData: {
        'driverName': driverName,
        'vehicleInfo': vehicleInfo,
        'estimatedArrival': estimatedArrival,
      },
    );
  }

  Future<void> notifyDriverArrived({
    required String tripId,
    required String driverName,
    required String verificationCode,
  }) async {
    await addTripNotification(
      tripId: tripId,
      type: NotificationType.driverArrived,
      title: '¡Tu conductor ha llegado!',
      body: '$driverName está esperándote. Código: $verificationCode',
      tripData: {
        'driverName': driverName,
        'verificationCode': verificationCode,
      },
    );
  }

  Future<void> notifyTripStarted({
    required String tripId,
    required String destinationAddress,
  }) async {
    await addTripNotification(
      tripId: tripId,
      type: NotificationType.tripStarted,
      title: '¡Viaje iniciado!',
      body: 'En camino a $destinationAddress',
      tripData: {
        'destinationAddress': destinationAddress,
      },
    );
  }

  Future<void> notifyTripCompleted({
    required String tripId,
    required double totalFare,
    required String paymentMethod,
  }) async {
    await addTripNotification(
      tripId: tripId,
      type: NotificationType.tripCompleted,
      title: '¡Viaje completado!',
      body:
          'Total: S/ ${totalFare.toStringAsFixed(2)} - ${formatPaymentMethodLabel(paymentMethod)}',
      tripData: {
        'totalFare': totalFare,
        'paymentMethod': paymentMethod,
      },
    );
  }

  Future<void> notifyTripCancelled({
    required String tripId,
    required String reason,
    required String cancelledBy,
  }) async {
    await addTripNotification(
      tripId: tripId,
      type: NotificationType.tripCancelled,
      title: 'Viaje cancelado',
      body: userFriendlyError(reason, fallback: 'Cancelado por $cancelledBy. Motivo'),
      tripData: {
        'reason': reason,
        'cancelledBy': cancelledBy,
      },
    );
  }

  /// Actualizar token FCM del usuario actual — lo persiste el backend Node.
  Future<void> updateUserFCMToken() async {
    try {
      final token = await _fcmService.getDeviceFCMToken();
      if (token != null && _api.isSignedIn) {
        final ok = await _fcmService.registerDeviceTokenWithBackend(token);
        _cachedFcmToken = token;
        if (ok) {
          debugPrint('✅ Token FCM actualizado en backend Node');
        } else {
          debugPrint('⚠️  Token FCM NO se pudo registrar en backend');
        }
      }
    } catch (e) {
      debugPrint('❌ Error actualizando token FCM: $e');
    }
  }

  /// Suscribirse a tópicos según tipo de usuario.
  Future<void> subscribeToUserTypeTopics(String userType) async {
    try {
      await _fcmService.subscribeToTopic('all_users');
      await _fcmService.subscribeToTopic('app_updates');

      switch (userType) {
        case 'passenger':
          await _fcmService.subscribeToTopic('passengers');
          await _fcmService.subscribeToTopic('passenger_promotions');
          await _fcmService.unsubscribeFromTopic('drivers');
          break;
        case 'driver':
          await _fcmService.subscribeToTopic('drivers');
          await _fcmService.subscribeToTopic('driver_updates');
          await _fcmService.unsubscribeFromTopic('passengers');
          await _fcmService.unsubscribeFromTopic('passenger_promotions');
          break;
        case 'admin':
          await _fcmService.subscribeToTopic('admins');
          await _fcmService.subscribeToTopic('system_alerts');
          break;
      }

      debugPrint('✅ Suscrito a tópicos para tipo de usuario: $userType');
    } catch (e) {
      debugPrint('❌ Error suscribiendo a tópicos: $e');
    }
  }

  Map<String, int> getNotificationStats() {
    return {
      'total': _notifications.length,
      'unread': unreadCount,
      'tripRequests':
          _notifications.where((n) => n.type == NotificationType.tripRequest).length,
      'tripUpdates': _notifications
          .where((n) =>
              n.type == NotificationType.tripAccepted ||
              n.type == NotificationType.tripStarted ||
              n.type == NotificationType.driverArrived ||
              n.type == NotificationType.tripCompleted)
          .length,
      'promotions':
          _notifications.where((n) => n.type == NotificationType.promotion).length,
    };
  }

  /// Limpiar notificaciones antiguas (más de 30 días) — sólo estado local;
  /// el backend Node mantiene su propio TTL/purge server-side.
  Future<void> cleanupOldNotifications() async {
    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
      final oldNotifications =
          _notifications.where((n) => n.timestamp.isBefore(cutoffDate)).toList();

      for (final notification in oldNotifications) {
        _notifications.remove(notification);
      }

      if (oldNotifications.isNotEmpty) {
        debugPrint('🧹 Limpiadas ${oldNotifications.length} notificaciones antiguas');
        notifyListeners();
      }
    } catch (e) {
      debugPrint(userFriendlyError(e, fallback: 'Error limpiando notificaciones antiguas'));
    }
  }

  @override
  void dispose() {
    _sseSub?.cancel();
    _sseSub = null;
    super.dispose();
  }
}
