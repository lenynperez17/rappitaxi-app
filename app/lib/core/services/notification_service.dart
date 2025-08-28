import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../utils/logger.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static NotificationService get instance => _instance;
  
  factory NotificationService() => _instance;
  
  NotificationService._internal();
  
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  String? _userId;
  Function(Map<String, dynamic>)? _navigationHandler;
  
  Future<void> initialize() async {
    // Request permissions
    await _messaging.requestPermission();
    
    // Get token
    final token = await _messaging.getToken();
    if (kDebugMode) {
      Logger().info('FCM Token obtenido', additionalData: {'token': token});
    }
    
    // Handle messages
    FirebaseMessaging.onMessage.listen(_handleMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
  }
  
  void _handleMessage(RemoteMessage message) {
    if (kDebugMode) {
      Logger().info('Mensaje FCM recibido', additionalData: {
        'title': message.notification?.title,
        'body': message.notification?.body,
        'data': message.data,
      });
    }
  }
  
  void _handleMessageOpenedApp(RemoteMessage message) {
    if (_navigationHandler != null && message.data.isNotEmpty) {
      _navigationHandler!(message.data);
    }
  }
  
  // Getter para obtener el stream de mensajes
  Stream<RemoteMessage> get onMessageReceived => FirebaseMessaging.onMessage;
  
  void updateUserId(String? userId) {
    _userId = userId;
  }
  
  void setNavigationHandler(Function(Map<String, dynamic>) handler) {
    _navigationHandler = handler;
  }
  
  Future<String?> getToken() async {
    return await _messaging.getToken();
  }
  
  // Métodos adicionales necesarios
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
  }
  
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }
  
  void clearAllNotifications() {
    // Implementación para limpiar notificaciones locales
    // Por ahora es un placeholder
  }
}
