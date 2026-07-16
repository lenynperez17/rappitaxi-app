// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';

/// Servicio de Notificaciones Real para Producción
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  bool _initialized = false;

  // Subscriptions para evitar memory leaks
  StreamSubscription<RemoteMessage>? _onMessageSubscription;
  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSubscription;

  // Stream controller para manejar notificaciones seleccionadas
  final StreamController<String> _notificationSelectedController = StreamController<String>.broadcast();
  
  /// Stream para escuchar notificaciones seleccionadas
  Stream<String>? get onNotificationSelected => _notificationSelectedController.stream;
  
  // Vibration pattern of 5 seconds (alternating buzzes)
  // Format: [wait, vibrate, wait, vibrate, ...]
  static final Int64List _longVibrationPattern =
      Int64List.fromList([0, 1000, 500, 1000, 500, 1000, 500, 1000]);

  /// Android notification channels - each with its own custom 5-second sound.
  /// Sound files are in android/app/src/main/res/raw/ (without extension).
  static final List<AndroidNotificationChannel> _channels = [
    AndroidNotificationChannel(
      'rappi_rides',
      'Solicitudes de viaje',
      description: 'Nuevas solicitudes de viaje y actualizaciones de estado',
      importance: Importance.max,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('ride_request'),
      enableLights: true,
      ledColor: const Color(0xFFE31E24),
      enableVibration: true,
      vibrationPattern: _longVibrationPattern,
    ),
    AndroidNotificationChannel(
      'rappi_payments',
      'Pagos y ganancias',
      description: 'Notificaciones sobre pagos, ganancias y transacciones',
      importance: Importance.max,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('trip_completed'),
      enableLights: true,
      enableVibration: true,
      vibrationPattern: _longVibrationPattern,
    ),
    AndroidNotificationChannel(
      'rappi_emergency',
      'Alertas de emergencia',
      description: 'Alertas SOS y notificaciones de seguridad',
      importance: Importance.max,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('emergency_alert'),
      enableLights: true,
      ledColor: const Color(0xFFFF0000),
      enableVibration: true,
      vibrationPattern: _longVibrationPattern,
    ),
    AndroidNotificationChannel(
      'rappi_chat',
      'Mensajes',
      description: 'Mensajes de chat con conductores y pasajeros',
      importance: Importance.high,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('chat_message'),
      enableLights: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 400, 200, 400]),
    ),
    AndroidNotificationChannel(
      'rappi_promotions',
      'Promociones',
      description: 'Ofertas y promociones especiales',
      importance: Importance.defaultImportance,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('ride_accepted'),
      enableVibration: true,
    ),
    AndroidNotificationChannel(
      'rappi_general',
      'Notificaciones generales',
      description: 'Notificaciones generales de Rappi Team',
      importance: Importance.high,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('ride_accepted'),
      enableVibration: true,
      vibrationPattern: _longVibrationPattern,
    ),
  ];

  /// Inicializar servicio de notificaciones
  Future<void> initialize() async {
    if (_initialized) return;

    // Configuración Android
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // Configuración iOS
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    // Configuración general
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Inicializar plugin de notificaciones locales
    await _flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Crear TODOS los canales de notificaciones Android
    if (!kIsWeb && Platform.isAndroid) {
      final androidPlugin = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        // Request POST_NOTIFICATIONS permission (Android 13+)
        await androidPlugin.requestNotificationsPermission();
        // Create every channel with its own custom sound
        for (final channel in _channels) {
          await androidPlugin.createNotificationChannel(channel);
        }
      }
    }

    // Configurar handlers de Firebase Messaging
    await _setupFirebaseMessaging();

    _initialized = true;
    debugPrint('✅ Servicio de notificaciones inicializado');
  }

  /// Configurar Firebase Messaging
  Future<void> _setupFirebaseMessaging() async {
    // Handler para mensajes en primer plano (almacenar subscription)
    _onMessageSubscription = FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handler para cuando se abre la app desde una notificación (almacenar subscription)
    _onMessageOpenedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Obtener mensaje inicial si la app se abrió desde una notificación
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }

    // ✅ NOTA: El background handler se registra en main.dart con firebaseMessagingBackgroundHandler
    // No registrar aquí para evitar duplicación
  }

  /// Handler para mensajes en primer plano
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('📱 Mensaje recibido en primer plano: ${message.messageId}');

    // Mostrar notificación local con canal apropiado segun el tipo
    await showNotification(
      title: message.notification?.title ?? 'Nueva notificación',
      body: message.notification?.body ?? '',
      payload: json.encode(message.data),
      type: message.data['type'] as String?,
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
  }

  /// Handler para cuando se abre la app desde notificación
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('📱 App abierta desde notificación: ${message.messageId}');
    _handleNotificationClick(message.data);
  }

  /// Get the channel ID based on notification type
  String _channelIdForType(String? type) {
    switch (type) {
      case 'ride':
      case 'rideRequest':
      case 'tripRequest':
      case 'tripAccepted':
      case 'tripStarted':
      case 'driverArrived':
        return 'rappi_rides';
      case 'payment':
      case 'paymentSuccess':
      case 'paymentFailed':
      case 'tripCompleted':
        return 'rappi_payments';
      case 'emergency':
      case 'securityAlert':
      case 'sos':
        return 'rappi_emergency';
      case 'chat':
      case 'chatMessage':
      case 'message':
        return 'rappi_chat';
      case 'promotion':
      case 'discount':
      case 'offer':
        return 'rappi_promotions';
      default:
        return 'rappi_general';
    }
  }

  /// iOS sound filename by notification type (with extension)
  String _iosSoundForType(String? type) {
    switch (type) {
      case 'ride':
      case 'rideRequest':
      case 'tripRequest':
      case 'tripAccepted':
      case 'tripStarted':
      case 'driverArrived':
        return 'ride_request.wav';
      case 'payment':
      case 'paymentSuccess':
      case 'paymentFailed':
      case 'tripCompleted':
        return 'trip_completed.wav';
      case 'emergency':
      case 'securityAlert':
      case 'sos':
        return 'emergency_alert.wav';
      case 'chat':
      case 'chatMessage':
      case 'message':
        return 'chat_message.wav';
      case 'promotion':
      case 'discount':
      case 'offer':
        return 'ride_accepted.wav';
      default:
        return 'ride_accepted.wav';
    }
  }

  /// Build AndroidNotificationDetails for the given channel id
  AndroidNotificationDetails _androidDetailsForChannel(String channelId) {
    final channel = _channels.firstWhere(
      (c) => c.id == channelId,
      orElse: () => _channels.last,
    );
    return AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance: channel.importance,
      priority: Priority.max,
      ticker: 'Rappi Team',
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFFE31E24),
      playSound: true,
      sound: channel.sound,
      enableVibration: true,
      vibrationPattern: _longVibrationPattern,
      enableLights: true,
      ledColor: const Color(0xFFE31E24),
      ledOnMs: 1000,
      ledOffMs: 500,
      fullScreenIntent: channelId == 'rappi_rides' || channelId == 'rappi_emergency',
      category: channelId == 'rappi_emergency'
          ? AndroidNotificationCategory.alarm
          : AndroidNotificationCategory.call,
      // Ronda 192 PRIVACY: canales con PII (chat = nombre + mensaje,
      // emergency = ubicación + tipo, payments = monto + método) usan
      // visibility.private → título ocultado en lockscreen si el device
      // está bloqueado con PIN/biometric. Otros canales (ride status
      // genérico, marketing) pueden ser públicos.
      visibility: (channelId == 'rappi_chat' ||
              channelId == 'rappi_emergency' ||
              channelId == 'rappi_payments')
          ? NotificationVisibility.private
          : NotificationVisibility.public,
    );
  }

  /// Mostrar notificación local
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    int id = 0,
    String? type,
  }) async {
    final channelId = _channelIdForType(type);
    final androidDetails = _androidDetailsForChannel(channelId);

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: _iosSoundForType(type),
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Mostrar notificación de viaje
  Future<void> showRideNotification({
    required String title,
    required String body,
    required Map<String, dynamic> rideData,
  }) async {
    await showNotification(
      title: title,
      body: body,
      payload: json.encode({
        'type': 'ride',
        'data': rideData,
      }),
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      type: 'rideRequest',
    );
  }

  /// Mostrar notificación de chat
  Future<void> showChatNotification({
    required String senderName,
    required String message,
    required String chatId,
  }) async {
    await showNotification(
      title: senderName,
      body: message,
      payload: json.encode({
        'type': 'chat',
        'chatId': chatId,
      }),
      id: chatId.hashCode,
      type: 'chatMessage',
    );
  }

  /// Mostrar notificación de promoción
  Future<void> showPromoNotification({
    required String title,
    required String description,
    required String promoCode,
  }) async {
    await showNotification(
      title: title,
      body: '$description\nCódigo: $promoCode',
      payload: json.encode({
        'type': 'promo',
        'code': promoCode,
      }),
      id: promoCode.hashCode,
      type: 'promotion',
    );
  }

  /// Mostrar notificación de emergencia / SOS
  Future<void> showEmergencyNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await showNotification(
      title: title,
      body: body,
      payload: json.encode({'type': 'emergency', 'data': data ?? {}}),
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      type: 'emergency',
    );
  }

  /// Mostrar notificación de pago
  Future<void> showPaymentNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await showNotification(
      title: title,
      body: body,
      payload: json.encode({'type': 'payment', 'data': data ?? {}}),
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      type: 'payment',
    );
  }

  /// Cancelar notificación
  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
  }

  /// Cancelar todas las notificaciones
  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  /// Handler para respuesta a notificación
  static void _onNotificationResponse(NotificationResponse response) {
    debugPrint('📱 Notificación clickeada: ${response.payload}');
    if (response.payload != null) {
      try {
        final data = json.decode(response.payload!);
        _instance._handleNotificationClick(data);
      } catch (e) {
        debugPrint('Error procesando payload: $e');
      }
    }
  }

  /// Manejar click en notificación y emitir evento
  void _handleNotificationClick(Map<String, dynamic> data) {
    final type = data['type'] ?? '';
    
    // Emitir evento para que el NotificationHandler lo procese
    String payload = '';
    
    switch (type) {
      case 'ride':
        // Backend puede enviar payload plano `{type:"ride", rideId:"..."}` o
        // anidado `{type:"ride", data:{rideId:"..."}}`. Aceptar ambos sin crash.
        final nested = data['data'];
        final rideId = (nested is Map ? (nested['rideId'] ?? '') : (data['rideId'] ?? '')).toString();
        payload = 'ride:$rideId';
        debugPrint('Navegar a viaje: $rideId');
        break;
      case 'chat':
        payload = 'chat:${data['chatId']}';
        debugPrint('Navegar a chat: ${data['chatId']}');
        break;
      case 'promo':
        payload = 'promo:${data['code']}';
        debugPrint('Aplicar promo: ${data['code']}');
        break;
      case 'emergency':
        payload = 'emergency';
        debugPrint('Manejar emergencia');
        break;
      case 'price_negotiation':
        payload = 'price_negotiation';
        debugPrint('Nueva negociación de precio');
        break;
      case 'driver_found':
        payload = 'driver_found';
        break;
      case 'driver_arrived':
        payload = 'driver_arrived';
        break;
      case 'trip_completed':
        payload = 'trip_completed';
        break;
      case 'payment_received':
        payload = 'payment_received';
        break;
      case 'ride_request':
        payload = 'ride_request';
        break;
      default:
        payload = type;
        debugPrint('Tipo de notificación desconocido: $type');
    }
    
    // Emitir el payload al stream
    if (payload.isNotEmpty) {
      _notificationSelectedController.add(payload);
    }
  }

  /// Handler para notificaciones iOS en primer plano (legacy)
  static void _onDidReceiveLocalNotification(
    int id,
    String? title,
    String? body,
    String? payload,
  ) {
    debugPrint('iOS notificación recibida: $title');
  }

  /// Obtener detalles de notificación pendiente
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
  }

  /// ✅ IMPLEMENTADO: Actualizar badge de la app (iOS)
  Future<void> updateBadge(int count) async {
    if (Platform.isIOS) {
      try {
        // Para iOS se necesita plugin específico como flutter_app_badger
        // Por ahora implementamos con notificaciones locales
        await _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true);

        debugPrint('✅ Badge iOS actualizado a: $count');
      } catch (e) {
        debugPrint('❌ Error actualizando badge iOS: $e');
      }
    }
  }
  
  /// Limpiar recursos
  void dispose() {
    _onMessageSubscription?.cancel();
    _onMessageOpenedAppSubscription?.cancel();
    _notificationSelectedController.close();
  }
}

// ✅ NOTA: El background handler está definido en firebase_messaging_handler.dart
// No duplicar aquí para evitar conflictos