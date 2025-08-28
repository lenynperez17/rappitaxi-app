import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/services/notification_service.dart';
import 'package:rappitaxi_app/shared/utils/logger.dart';

// Provider para manejar notificaciones de viajes
final rideNotificationProvider = Provider<RideNotificationHandler>((ref) {
  return RideNotificationHandler(ref);
});

class RideNotificationHandler {
  final Ref _ref;
  StreamSubscription<RemoteMessage>? _subscription;
  
  RideNotificationHandler(this._ref);
  
  // Inicializar el handler
  void initialize() {
    final notificationService = NotificationService();
    
    _subscription = notificationService.onMessageReceived.listen((message) {
      _handleRideNotification(message);
    });
  }
  
  // Manejar notificaciones de viajes
  void _handleRideNotification(RemoteMessage message) {
    final data = message.data;
    final type = data['type'];
    
    Logger.info('Handling ride notification: $type');
    
    switch (type) {
      case 'ride_accepted':
        _handleRideAccepted(data);
        break;
      case 'driver_arriving':
        _handleDriverArriving(data);
        break;
      case 'ride_started':
        _handleRideStarted(data);
        break;
      case 'ride_completed':
        _handleRideCompleted(data);
        break;
      case 'ride_cancelled':
        _handleRideCancelled(data);
        break;
      default:
        Logger.warning('Unknown ride notification type: $type');
    }
  }
  
  // Viaje aceptado por conductor
  void _handleRideAccepted(Map<String, dynamic> data) {
    final router = appRouter;
    
    // Extraer datos del conductor
    final driverData = {
      'id': data['driver_id'],
      'name': data['driver_name'],
      'photo': data['driver_photo'],
      'rating': double.parse(data['driver_rating'] ?? '5.0'),
      'vehicle_plate': data['vehicle_plate'],
      'vehicle_model': data['vehicle_model'],
      'vehicle_color': data['vehicle_color'],
    };
    
    // Navegar a la pantalla de conductor llegando
    // TODO: Implementar navegación cuando esté la pantalla
    Logger.info('Driver accepted ride', driverData);
  }
  
  // Conductor llegando
  void _handleDriverArriving(Map<String, dynamic> data) {
    final estimatedTime = data['estimated_time'] ?? '5';
    Logger.info('Driver arriving in $estimatedTime minutes');
    
    // TODO: Actualizar UI con tiempo estimado
  }
  
  // Viaje iniciado
  void _handleRideStarted(Map<String, dynamic> data) {
    final router = appRouter;
    final rideId = data['ride_id'];
    
    // Navegar a viaje en progreso
    // TODO: Implementar navegación cuando esté la pantalla
    Logger.info('Ride started: $rideId');
  }
  
  // Viaje completado
  void _handleRideCompleted(Map<String, dynamic> data) {
    final router = appRouter;
    final rideId = data['ride_id'];
    final fare = double.parse(data['fare'] ?? '0');
    
    // Navegar a pantalla de viaje completado
    router.go('/ride/completed', extra: {
      'ride_id': rideId,
      'fare': fare,
    });
  }
  
  // Viaje cancelado
  void _handleRideCancelled(Map<String, dynamic> data) {
    final reason = data['reason'] ?? 'El conductor canceló el viaje';
    final cancelledBy = data['cancelled_by'] ?? 'driver';
    
    Logger.warning('Ride cancelled by $cancelledBy: $reason');
    
    // TODO: Mostrar diálogo de cancelación
  }
  
  // Dispose
  void dispose() {
    _subscription?.cancel();
  }
}