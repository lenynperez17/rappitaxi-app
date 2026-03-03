import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../utils/logger.dart';
import '../utils/navigation_helper.dart';

class LocalNotificationService {
  static final LocalNotificationService _instance = LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  // Inicializar notificaciones
  Future<void> initialize() async {
    // Inicializar timezone data y configurar Lima, Perú como zona horaria
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Lima')); // ✅ Zona horaria de Lima, Perú
    // Configuración para Android
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // Configuración para iOS
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Configuración general
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Inicializar
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Solicitar permisos en Android 13+
    await _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
  }

  // Callback cuando se toca una notificación
  void _onNotificationTapped(NotificationResponse response) {
    AppLogger.info('Notificación tocada: ${response.payload}');
    
    // Navegar a pantalla específica según el payload
    final payload = response.payload;
    if (payload != null) {
      _handleNotificationNavigation(payload);
    }
  }

  // Manejar navegación basada en el payload de la notificación
  void _handleNotificationNavigation(String payload) {
    switch (payload) {
      case 'ride_request':
        NavigationHelper.navigateToRideRequest();
        break;
      case 'driver_found':
        NavigationHelper.navigateToTripTracking();
        break;
      case 'driver_arrived':
        NavigationHelper.navigateToTripTracking();
        break;
      case 'trip_completed':
        NavigationHelper.navigateToTripHistory();
        break;
      case 'payment_received':
        NavigationHelper.navigateToEarnings();
        break;
      default:
        AppLogger.warning('Payload de notificación no reconocido: $payload');
        NavigationHelper.navigateToHome();
    }
  }

  // Mostrar notificación simple con sonido personalizado
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    String? customSound, // ✅ Sonido personalizado opcional
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'rapiteam_channel',
      'RapiTeam',
      channelDescription: 'Notificaciones de RapiTeam',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      sound: customSound != null
          ? RawResourceAndroidNotificationSound(customSound)
          : const RawResourceAndroidNotificationSound('notification'), // ✅ Sonido por defecto
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: customSound != null ? '$customSound.mp3' : 'notification.mp3', // ✅ Sonido iOS
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  // Notificación de nueva solicitud de viaje (para conductores)
  // ✅ MEJORADO: Usa canal con máxima prioridad, sonido largo y vibración fuerte
  Future<void> showRideRequestNotification({
    required String passengerName,
    required String pickupAddress,
    required String price,
  }) async {
    // ✅ Canal especial para solicitudes de viaje con sonido largo y repetitivo
    // ✅ CORREGIDO: No usar const porque Int64List.fromList no es const
    final androidDetails = AndroidNotificationDetails(
      'rapiteam_ride_request',
      'Solicitudes de Viaje',
      channelDescription: 'Notificaciones de nuevas solicitudes de viaje',
      importance: Importance.max, // ✅ Máxima importancia
      priority: Priority.max, // ✅ Máxima prioridad
      showWhen: true,
      enableVibration: true,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('ride_request'), // ✅ Sonido personalizado
      enableLights: true,
      ledColor: const Color.fromARGB(255, 0, 255, 0),
      ledOnMs: 1000,
      ledOffMs: 500,
      fullScreenIntent: true, // ✅ Mostrar en pantalla completa si está bloqueado
      category: AndroidNotificationCategory.alarm, // ✅ Categoría de alarma
      visibility: NotificationVisibility.public,
      ticker: 'Nueva solicitud de viaje',
      // ✅ Vibración larga y repetitiva para llamar la atención
      vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500, 200, 500]),
      audioAttributesUsage: AudioAttributesUsage.alarm, // ✅ Usar altavoz de alarma
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'ride_request.mp3', // ✅ Sonido personalizado iOS
      interruptionLevel: InterruptionLevel.timeSensitive, // ✅ Alta prioridad
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '🚗 ¡NUEVA SOLICITUD!',
      '$passengerName necesita viaje - $pickupAddress - S/. $price',
      details,
      payload: 'ride_request',
    );
  }

  // Notificación de conductor encontrado (para pasajeros)
  Future<void> showDriverFoundNotification({
    required String driverName,
    required String vehicleInfo,
    required String estimatedTime,
  }) async {
    await showNotification(
      title: '✅ ¡Conductor encontrado!',
      body: '$driverName está en camino - $vehicleInfo - Llegará en $estimatedTime',
      payload: 'driver_found',
      customSound: 'success', // ✅ Sonido de éxito
    );
  }

  // Notificación de conductor llegó
  Future<void> showDriverArrivedNotification() async {
    await showNotification(
      title: '🚗 Tu conductor ha llegado',
      body: 'Tu conductor está esperándote en el punto de recogida',
      payload: 'driver_arrived',
      customSound: 'notification', // ✅ Sonido de alerta
    );
  }

  // Notificación de viaje completado
  Future<void> showTripCompletedNotification({
    required String price,
  }) async {
    await showNotification(
      title: '✅ Viaje completado',
      body: 'El viaje ha finalizado. Total: S/. $price',
      payload: 'trip_completed',
      customSound: 'success', // ✅ Sonido de éxito
    );
  }

  // Notificación de pago recibido (para conductores)
  Future<void> showPaymentReceivedNotification({
    required String amount,
  }) async {
    await showNotification(
      title: '💰 Pago recibido',
      body: 'Has recibido S/. $amount por el viaje completado',
      payload: 'payment_received',
      customSound: 'success', // ✅ Sonido de éxito (dinero)
    );
  }

  // ✅ NUEVO: Notificación de mensaje de chat
  Future<void> showMessageNotification({
    required String senderName,
    required String message,
    String? tripId,
  }) async {
    await showNotification(
      title: '💬 Mensaje de $senderName',
      body: message,
      payload: 'message_$tripId',
      customSound: 'message', // ✅ Sonido de mensaje
    );
  }

  // ✅ NUEVO: Notificación de oferta de conductor (para pasajeros)
  Future<void> showDriverOfferNotification({
    required String driverName,
    required String price,
  }) async {
    await showNotification(
      title: '🚕 Nueva oferta de $driverName',
      body: 'Te ofrece el viaje por S/. $price',
      payload: 'driver_offer',
      customSound: 'notification', // ✅ Sonido de alerta
    );
  }

  // Notificación con acciones
  Future<void> showNotificationWithActions({
    required String title,
    required String body,
    required List<AndroidNotificationAction> actions,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'rapiteam_actions',
      'RapiTeam Acciones',
      channelDescription: 'Notificaciones con acciones',
      importance: Importance.high,
      priority: Priority.high,
      actions: actions,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }

  // Cancelar notificación
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  // Cancelar todas las notificaciones
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  // Programar notificación
  Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'rapiteam_scheduled',
      'RapiTeam Programadas',
      channelDescription: 'Notificaciones programadas',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);
      await _notifications.zonedSchedule(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        tzScheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
      AppLogger.info('Notificación programada para: $scheduledDate');
    } catch (e) {
      AppLogger.error('Error programando notificación', e);
      // Fallback: mostrar notificación inmediata
      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        details,
        payload: payload,
      );
    }
  }
}