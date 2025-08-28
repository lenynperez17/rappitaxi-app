import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/auth/presentation/providers/auth_provider.dart' as auth;
import '../services/notification_service.dart';
import '../utils/logger.dart';

class NotificationHandlerWidget extends StatefulWidget {
  final Widget child;
  
  const NotificationHandlerWidget({
    super.key,
    required this.child,
  });
  
  @override
  State<NotificationHandlerWidget> createState() => _NotificationHandlerWidgetState();
}

class _NotificationHandlerWidgetState extends State<NotificationHandlerWidget> {
  final NotificationService _notificationService = NotificationService();
  
  @override
  void initState() {
    super.initState();
    _setupNotifications();
  }
  
  Future<void> _setupNotifications() async {
    try {
      await _notificationService.initialize();
      
      // Escuchar cambios de autenticación
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // TODO: Implementar AuthProvider correctamente
        // final authProvider = context.read<auth.AuthProvider>();
        // 
        // if (authProvider.isAuthenticated) {
        //   _notificationService.updateUserId(authProvider.user?.uid);
        //   
        //   // Suscribirse a topics relevantes
        //   _notificationService.subscribeToTopic('promotions');
        //   _notificationService.subscribeToTopic('updates');
        // }
        
        // Por ahora, suscribirse a topics básicos
        _notificationService.subscribeToTopic('promotions');
        _notificationService.subscribeToTopic('updates');
        
        // Configurar navegación basada en notificaciones
        _notificationService.setNavigationHandler((data) {
          _handleNotificationNavigation(data);
        });
      });
    } catch (e, stack) {
      Logger.error('Error setting up notifications', e, stack);
    }
  }
  
  void _handleNotificationNavigation(Map<String, dynamic> data) {
    // Aquí puedes manejar la navegación basada en las notificaciones
    final route = data['route'] as String?;
    if (route == null) return;
    
    switch (route) {
      case '/ride/details':
        // Navigator.of(context).pushNamed(route, arguments: data);
        break;
      case '/chat':
        // Navigator.of(context).pushNamed(route, arguments: data);
        break;
      default:
        // Navigator.of(context).pushNamed(route);
        break;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // TODO: Implementar AuthProvider correctamente
    // Escuchar cambios de autenticación
    // final authProvider = context.watch<auth.AuthProvider>();
    // 
    // // Actualizar token FCM cuando cambie el estado de autenticación
    // if (authProvider.isAuthenticated && authProvider.user != null) {
    //   _notificationService.updateUserId(authProvider.user!.uid);
    // } else {
    //   _notificationService.unsubscribeFromTopic('promotions');
    //   _notificationService.unsubscribeFromTopic('updates');
    //   _notificationService.clearAllNotifications();
    // }
    
    return widget.child;
  }
  
  @override
  void dispose() {
    super.dispose();
  }
}