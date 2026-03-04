import '../../core/utils/currency_formatter.dart';

/// Tipos de notificaciones del sistema RappiTeam
enum NotificationType {
  // Notificaciones generales
  general,
  system,
  maintenance,
  
  // Notificaciones de viaje
  tripRequest,        // Nueva solicitud de viaje
  tripAccepted,       // Viaje aceptado por conductor
  tripStarted,        // Viaje iniciado
  tripCompleted,      // Viaje completado
  tripCancelled,      // Viaje cancelado
  driverArrived,      // Conductor llegó al punto de recogida
  driverAssigned,     // Conductor asignado
  
  // Alias y notificaciones adicionales de viaje
  rideUpdate,         // Actualización general del viaje
  rideAccepted,       // Alias para tripAccepted (compatibilidad)
  rideCancelled,      // Alias para tripCancelled (compatibilidad)
  
  // Notificaciones de pago
  payment,            // Pago general
  paymentSuccess,     // Pago exitoso
  paymentFailed,      // Fallo en pago
  paymentRefund,      // Reembolso procesado
  
  // Notificaciones de emergencia
  emergency,          // Botón SOS activado
  securityAlert,      // Alerta de seguridad
  
  // Notificaciones de chat
  chatMessage,        // Nuevo mensaje en chat
  chatDriverMessage,  // Mensaje del conductor
  chatPassengerMessage, // Mensaje del pasajero
  
  // Notificaciones promocionales
  promotion,          // Promoción general
  discount,           // Descuento disponible
  specialOffer,       // Oferta especial
  
  // Soporte y sistema
  support,            // Mensaje de soporte
  appUpdate,          // Actualización de app disponible
}

/// Prioridades de notificación
enum NotificationPriority {
  low,      // Promociones, ofertas
  normal,   // Mensajes generales
  high,     // Viajes, pagos
  critical, // Emergencias, seguridad
}

/// Canales de notificación Android
enum NotificationChannel {
  general('rappi_general', 'General', 'Notificaciones generales'),
  rides('rappi_rides', 'Viajes', 'Notificaciones de viajes'),
  payments('rappi_payments', 'Pagos', 'Notificaciones de pago'),
  emergency('rappi_emergency', 'Emergencias', 'Alertas de seguridad'),
  chat('rappi_chat', 'Chat', 'Mensajes de chat'),
  promotions('rappi_promotions', 'Promociones', 'Ofertas y descuentos');
  
  const NotificationChannel(this.id, this.name, this.description);
  final String id;
  final String name;
  final String description;
}

/// Modelo de datos para notificaciones
class NotificationData {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final NotificationPriority priority;
  final NotificationChannel channel;
  final DateTime timestamp;
  final DateTime? scheduledTime;
  final DateTime? expiresAt;
  final bool isRead;
  final bool isDelivered;
  final String? userId;
  final String? tripId;
  final String? imageUrl;
  final Map<String, dynamic>? data;
  final Map<String, String>? actions; // Para action buttons

  NotificationData({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.priority = NotificationPriority.normal,
    required this.channel,
    required this.timestamp,
    this.scheduledTime,
    this.expiresAt,
    this.isRead = false,
    this.isDelivered = false,
    this.userId,
    this.tripId,
    this.imageUrl,
    this.data,
    this.actions,
  });

  /// Crear desde Map (Firestore)
  factory NotificationData.fromMap(Map<String, dynamic> map) {
    return NotificationData(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => NotificationType.general,
      ),
      priority: NotificationPriority.values.firstWhere(
        (e) => e.name == map['priority'],
        orElse: () => NotificationPriority.normal,
      ),
      channel: NotificationChannel.values.firstWhere(
        (e) => e.id == map['channel'],
        orElse: () => NotificationChannel.general,
      ),
      timestamp: DateTime.parse(map['timestamp']),
      scheduledTime: map['scheduledTime'] != null 
        ? DateTime.parse(map['scheduledTime']) 
        : null,
      expiresAt: map['expiresAt'] != null 
        ? DateTime.parse(map['expiresAt']) 
        : null,
      isRead: map['isRead'] ?? false,
      isDelivered: map['isDelivered'] ?? false,
      userId: map['userId'],
      tripId: map['tripId'],
      imageUrl: map['imageUrl'],
      data: map['data'] != null ? Map<String, dynamic>.from(map['data']) : {},
      actions: map['actions'] != null ? Map<String, String>.from(map['actions']) : {},
    );
  }

  /// Convertir a Map (Firestore)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type.name,
      'priority': priority.name,
      'channel': channel.id,
      'timestamp': timestamp.toIso8601String(),
      'scheduledTime': scheduledTime?.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'isRead': isRead,
      'isDelivered': isDelivered,
      'userId': userId,
      'tripId': tripId,
      'imageUrl': imageUrl,
      'data': data,
      'actions': actions,
    };
  }

  NotificationData copyWith({
    String? id,
    String? title,
    String? body,
    NotificationType? type,
    NotificationPriority? priority,
    NotificationChannel? channel,
    DateTime? timestamp,
    DateTime? scheduledTime,
    DateTime? expiresAt,
    bool? isRead,
    bool? isDelivered,
    String? userId,
    String? tripId,
    String? imageUrl,
    Map<String, dynamic>? data,
    Map<String, String>? actions,
  }) {
    return NotificationData(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      channel: channel ?? this.channel,
      timestamp: timestamp ?? this.timestamp,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      expiresAt: expiresAt ?? this.expiresAt,
      isRead: isRead ?? this.isRead,
      isDelivered: isDelivered ?? this.isDelivered,
      userId: userId ?? this.userId,
      tripId: tripId ?? this.tripId,
      imageUrl: imageUrl ?? this.imageUrl,
      data: data ?? this.data,
      actions: actions ?? this.actions,
    );
  }

  /// Verificar si la notificación ha expirado
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Obtener color por tipo de notificación
  int get colorCode {
    switch (type) {
      case NotificationType.emergency:
      case NotificationType.securityAlert:
        return 0xFFD32F2F; // Rojo para emergencias
      case NotificationType.tripRequest:
      case NotificationType.driverAssigned:
      case NotificationType.driverArrived:
        return 0xFF4CAF50; // Verde para viajes
      case NotificationType.paymentSuccess:
        return 0xFF2196F3; // Azul para pagos
      case NotificationType.paymentFailed:
        return 0xFFFF9800; // Naranja para errores de pago
      case NotificationType.chatMessage:
      case NotificationType.chatDriverMessage:
      case NotificationType.chatPassengerMessage:
        return 0xFF9C27B0; // Púrpura para chat
      case NotificationType.promotion:
      case NotificationType.discount:
      case NotificationType.specialOffer:
        return 0xFFFFC107; // Amarillo para promociones
      default:
        return 0xFF757575; // Gris para general
    }
  }
}

/// Helper para crear notificaciones específicas de taxi
class TaxiNotificationBuilder {
  static NotificationData rideRequest({
    required String tripId,
    required String passengerName,
    required String pickupAddress,
    required String destinationAddress,
    required double estimatedFare,
  }) {
    return NotificationData(
      id: 'ride_request_$tripId',
      title: '¡Nueva solicitud de viaje!',
      body: 'Pasajero: $passengerName\nDesde: $pickupAddress\nTarifa: ${estimatedFare.toCurrency()}',
      type: NotificationType.tripRequest,
      priority: NotificationPriority.high,
      channel: NotificationChannel.rides,
      timestamp: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(minutes: 2)),
      tripId: tripId,
      data: {
        'passenger_name': passengerName,
        'pickup_address': pickupAddress,
        'destination_address': destinationAddress,
        'estimated_fare': estimatedFare,
      },
      actions: {
        'accept': 'Aceptar',
        'reject': 'Rechazar',
      },
    );
  }

  static NotificationData driverArrived({
    required String tripId,
    required String driverName,
    required String licensePlate,
  }) {
    return NotificationData(
      id: 'driver_arrived_$tripId',
      title: 'Tu conductor ha llegado',
      body: '$driverName está esperando\nPlaca: $licensePlate',
      type: NotificationType.driverArrived,
      priority: NotificationPriority.high,
      channel: NotificationChannel.rides,
      timestamp: DateTime.now(),
      tripId: tripId,
      data: {
        'driver_name': driverName,
        'license_plate': licensePlate,
      },
    );
  }

  static NotificationData paymentSuccess({
    required String tripId,
    required double amount,
    required String paymentMethod,
  }) {
    return NotificationData(
      id: 'payment_success_$tripId',
      title: 'Pago procesado exitosamente',
      body: '${amount.toCurrency()} pagado con $paymentMethod',
      type: NotificationType.paymentSuccess,
      priority: NotificationPriority.normal,
      channel: NotificationChannel.payments,
      timestamp: DateTime.now(),
      tripId: tripId,
      data: {
        'amount': amount,
        'payment_method': paymentMethod,
      },
    );
  }

  static NotificationData emergencyAlert({
    required String tripId,
    required String location,
  }) {
    return NotificationData(
      id: 'emergency_${DateTime.now().millisecondsSinceEpoch}',
      title: '🚨 ALERTA DE EMERGENCIA',
      body: 'Botón SOS activado\nUbicación: $location',
      type: NotificationType.emergency,
      priority: NotificationPriority.critical,
      channel: NotificationChannel.emergency,
      timestamp: DateTime.now(),
      tripId: tripId,
      data: {
        'location': location,
        'emergency_type': 'sos_button',
      },
    );
  }

  static NotificationData chatMessage({
    required String tripId,
    required String senderName,
    required String message,
    required bool isFromDriver,
  }) {
    return NotificationData(
      id: 'chat_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Nuevo mensaje de ${isFromDriver ? 'conductor' : 'pasajero'}',
      body: '$senderName: $message',
      type: isFromDriver 
        ? NotificationType.chatDriverMessage 
        : NotificationType.chatPassengerMessage,
      priority: NotificationPriority.normal,
      channel: NotificationChannel.chat,
      timestamp: DateTime.now(),
      tripId: tripId,
      data: {
        'sender_name': senderName,
        'message': message,
        'is_from_driver': isFromDriver,
      },
    );
  }
}