// ignore_for_file: deprecated_member_use, unused_field, unused_element, avoid_print, unreachable_switch_default, avoid_web_libraries_in_flutter
// ignore_for_file: library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/notification_service.dart';
import '../../providers/auth_provider.dart';
import 'dart:async';
import '../../utils/error_messages.dart';

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
  StreamSubscription? _notificationStreamSubscription;

  @override
  void initState() {
    super.initState();
    
    // Inicializar servicio de notificaciones
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeNotifications();
    });
  }
  
  /// Inicializar servicio de notificaciones con listeners reales
  Future<void> _initializeNotifications() async {
    await _notificationService.initialize();
    
    // Configurar listener para notificaciones seleccionadas
    _notificationStreamSubscription = _notificationService.onNotificationSelected?.listen((payload) {
      if (payload.isNotEmpty) {
        _handleNotificationTap(payload);
      }
    });
  }
  
  /// Manejar tap en notificación con navegación real
  void _handleNotificationTap(String payload) {
    // Verificar si el widget sigue montado antes de usar context
    if (!mounted) return;
    
    // Manejar la navegación según el payload
    if (payload.startsWith('ride:')) {
      final rideId = payload.substring(5);
      // Ambos roles usan la ruta shared para ver detalle del viaje.
      Navigator.pushNamed(
        context,
        '/shared/trip-details',
        arguments: {'rideId': rideId},
      );
      
      debugPrint(userFriendlyError(rideId, fallback: 'Navegando al viaje'));
    } else if (payload == 'ride_request') {
      // Nueva solicitud de viaje para conductores
      _navigateToDriverHome();
    } else if (payload == 'driver_found') {
      // Conductor encontrado para pasajeros
      _navigateToPassengerHome();
    } else if (payload == 'driver_arrived') {
      // Conductor llegó
      _showDriverArrivedDialog();
    } else if (payload == 'trip_completed') {
      // Viaje completado
      _navigateToTripHistory();
    } else if (payload == 'payment_received') {
      // Pago recibido para conductores
      _navigateToDriverEarnings();
    } else if (payload == 'emergency' || payload.startsWith('emergency:')) {
      // Notificación de emergencia — payload puede ser 'emergency' (sin id)
      // o 'emergency:<uuid>' con id de la emergencia específica.
      final emergencyId = payload.startsWith('emergency:')
        ? payload.substring('emergency:'.length)
        : null;
      _handleEmergencyNotification(emergencyId);
    } else if (payload == 'price_negotiation') {
      // Nueva negociación de precio
      _handlePriceNegotiation();
    } else if (payload.startsWith('chat:')) {
      // Notif de chat: payload 'chat:<rideId>'. El backend envía rideId ya
      // que la conversación se identifica por el ride.
      final rideId = payload.substring('chat:'.length);
      if (rideId.isNotEmpty) {
        Navigator.pushNamed(
          context,
          '/shared/chat',
          arguments: {'rideId': rideId},
        );
      }
    } else if (payload.startsWith('promo:')) {
      // Notif de promo/vale: por ahora navegar al home del passenger para
      // que vea el mensaje. En el futuro, ruta dedicada a promos.
      _navigateToPassengerHome();
    }
  }
  
  /// Obtener tipo de usuario real desde AuthProvider (backend Node/Postgres)
  String _getUserType() {
    try {
      // Verificar si el widget sigue montado antes de acceder al context
      if (!mounted) return 'passenger';

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;
      if (user == null) return 'guest';

      // ✅ DUAL-ACCOUNT: Usar activeMode en lugar de userType
      // activeMode retorna el modo actual ('driver' o 'passenger') incluso para cuentas dual
      return user.activeMode;
    } catch (e) {
      debugPrint(userFriendlyError(e, fallback: 'Error obteniendo tipo de usuario'));
      return 'passenger';
    }
  }
  
  void _showDriverArrivedDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.local_taxi, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Text('¡Tu conductor llegó!'),
          ],
        ),
        content: Text(
          'Tu conductor está esperándote en el punto de recogida. Por favor dirígete al vehículo.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/passenger/home');
            },
            child: Text('Ver detalles'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
  
  /// Navegaciones específicas por tipo de notificación
  void _navigateToDriverHome() {
    if (!mounted) return;
    
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/driver/home',
      (route) => route.isFirst,
    );
  }
  
  void _navigateToPassengerHome() {
    if (!mounted) return;
    
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/passenger/home',
      (route) => route.isFirst,
    );
  }
  
  void _navigateToTripHistory() {
    if (!mounted) return;

    final userType = _getUserType();
    final routeName = userType == 'driver'
      ? '/driver/order-history'
      : '/passenger/trip-history';
    Navigator.pushNamed(context, routeName);
  }

  void _navigateToDriverEarnings() {
    if (!mounted) return;
    Navigator.pushNamed(context, '/driver/earnings-details');
  }
  
  void _handleEmergencyNotification([String? emergencyId]) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 32),
            SizedBox(width: 12),
            Text('🚨 EMERGENCIA'),
          ],
        ),
        content: Text(
          'Se ha detectado una situación de emergencia. Por favor, revisa los detalles inmediatamente.',
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              // Solo navegar si tenemos un ID concreto — sin él la pantalla
              // de detalle no puede cargar nada.
              if (emergencyId != null && emergencyId.isNotEmpty) {
                Navigator.pushNamed(context, '/shared/emergency-details',
                  arguments: emergencyId);
              }
            },
            child: Text(
              'Ver Emergencia',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onError,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _handlePriceNegotiation() {
    if (!mounted) return;
    
    final userType = _getUserType();
    if (userType == 'driver') {
      Navigator.pushNamed(context, '/driver/negotiations');
    } else {
      Navigator.pushNamed(context, '/passenger/negotiations');
    }
  }
  
  @override
  void dispose() {
    _notificationStreamSubscription?.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}