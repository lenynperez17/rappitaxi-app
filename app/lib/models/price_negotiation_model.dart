
// Modelo para negociación de precio estilo InDriver
class PriceNegotiation {
  final String id;
  final String passengerId;
  final String passengerName;
  final String passengerPhoto;
  final double passengerRating;
  final LocationPoint pickup;
  final LocationPoint destination;
  final double suggestedPrice;
  final double offeredPrice;
  final double distance;
  final int estimatedTime; // en minutos
  final DateTime createdAt;
  final DateTime expiresAt;
  final NegotiationStatus status;
  final List<DriverOffer> driverOffers;
  final String? selectedDriverId;
  final PaymentMethod paymentMethod;
  final String? notes;

  PriceNegotiation({
    required this.id,
    required this.passengerId,
    required this.passengerName,
    required this.passengerPhoto,
    required this.passengerRating,
    required this.pickup,
    required this.destination,
    required this.suggestedPrice,
    required this.offeredPrice,
    required this.distance,
    required this.estimatedTime,
    required this.createdAt,
    required this.expiresAt,
    required this.status,
    required this.driverOffers,
    this.selectedDriverId,
    required this.paymentMethod,
    this.notes,
  });

  // Factory para crear desde Map (Firestore)
  factory PriceNegotiation.fromMap(String id, Map<String, dynamic> map) {
    return PriceNegotiation(
      id: id,
      passengerId: map['passengerId'] ?? '',
      passengerName: map['passengerName'] ?? 'Usuario',
      passengerPhoto: map['passengerPhoto'] ?? '',
      passengerRating: (map['passengerRating'] ?? 0.0).toDouble(),
      pickup: LocationPoint.fromMap(map['pickup'] ?? {}),
      destination: LocationPoint.fromMap(map['destination'] ?? {}),
      suggestedPrice: (map['suggestedPrice'] ?? 0.0).toDouble(),
      offeredPrice: (map['offeredPrice'] ?? 0.0).toDouble(),
      distance: (map['distance'] ?? 0.0).toDouble(),
      estimatedTime: map['estimatedTime'] ?? 0,
      createdAt: _parseDateTime(map['createdAt']),
      expiresAt: _parseDateTime(map['expiresAt']),
      status: _statusFromString(map['status'] ?? 'waiting'),
      driverOffers: (map['driverOffers'] as List<dynamic>?)
              ?.map((offer) => DriverOffer.fromMap(offer))
              .toList() ??
          [],
      selectedDriverId: map['selectedDriverId'],
      paymentMethod: _paymentMethodFromString(map['paymentMethod'] ?? 'cash'),
      notes: map['notes'],
    );
  }

  // Convertir a Map para Firestore
  Map<String, dynamic> toMap() {
    return {
      'passengerId': passengerId,
      'passengerName': passengerName,
      'passengerPhoto': passengerPhoto,
      'passengerRating': passengerRating,
      'pickup': pickup.toMap(),
      'destination': destination.toMap(),
      'suggestedPrice': suggestedPrice,
      'offeredPrice': offeredPrice,
      'distance': distance,
      'estimatedTime': estimatedTime,
      'createdAt': createdAt,
      'expiresAt': expiresAt,
      'status': status.toString().split('.').last,
      'driverOffers': driverOffers.map((offer) => offer.toMap()).toList(),
      'selectedDriverId': selectedDriverId,
      'paymentMethod': paymentMethod.toString().split('.').last,
      'notes': notes,
    };
  }

  // Helper para convertir string a enum
  static NegotiationStatus _statusFromString(String status) {
    switch (status.toLowerCase()) {
      case 'waiting':
        return NegotiationStatus.waiting;
      case 'negotiating':
        return NegotiationStatus.negotiating;
      case 'accepted':
        return NegotiationStatus.accepted;
      case 'inprogress':
        return NegotiationStatus.inProgress;
      case 'completed':
        return NegotiationStatus.completed;
      case 'cancelled':
        return NegotiationStatus.cancelled;
      case 'expired':
        return NegotiationStatus.expired;
      default:
        return NegotiationStatus.waiting;
    }
  }

  static PaymentMethod _paymentMethodFromString(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return PaymentMethod.cash;
      case 'card':
        return PaymentMethod.card;
      case 'wallet':
        return PaymentMethod.wallet;
      default:
        return PaymentMethod.cash;
    }
  }

  /// ✅ Helper para parsear DateTime desde Firestore (soporta Timestamp y String ISO8601)
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    // Si es Timestamp de Firestore
    if (value is DateTime) return value;
    // Verificar si tiene método toDate() (Timestamp)
    try {
      if (value.toDate != null) {
        return value.toDate();
      }
    } catch (_) {}
    // Si es String ISO8601
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  PriceNegotiation copyWith({
    double? offeredPrice,
    NegotiationStatus? status,
    List<DriverOffer>? driverOffers,
    String? selectedDriverId,
    String? acceptedDriverId,
  }) {
    return PriceNegotiation(
      id: id,
      passengerId: passengerId,
      passengerName: passengerName,
      passengerPhoto: passengerPhoto,
      passengerRating: passengerRating,
      pickup: pickup,
      destination: destination,
      suggestedPrice: suggestedPrice,
      offeredPrice: offeredPrice ?? this.offeredPrice,
      distance: distance,
      estimatedTime: estimatedTime,
      createdAt: createdAt,
      expiresAt: expiresAt,
      status: status ?? this.status,
      driverOffers: driverOffers ?? this.driverOffers,
      selectedDriverId: acceptedDriverId ?? selectedDriverId ?? this.selectedDriverId,
      paymentMethod: paymentMethod,
      notes: notes,
    );
  }

  // Calcular tiempo restante para ofertar
  Duration get timeRemaining => expiresAt.difference(DateTime.now());
  
  // Verificar si la negociación ha expirado
  bool get isExpired => DateTime.now().isAfter(expiresAt);
  
  // Obtener la mejor oferta de los conductores
  DriverOffer? get bestOffer {
    if (driverOffers.isEmpty) return null;
    return driverOffers.reduce((a, b) => 
      a.acceptedPrice < b.acceptedPrice ? a : b
    );
  }
}

// Oferta de conductor
class DriverOffer {
  final String driverId;
  final String driverName;
  final String driverPhoto;
  final double driverRating;
  final String vehicleModel;
  final String vehiclePlate;
  final String vehicleColor;
  final double acceptedPrice;
  final int estimatedArrival; // en minutos
  final DateTime offeredAt;
  final OfferStatus status;
  final int completedTrips;
  final double acceptanceRate;

  DriverOffer({
    required this.driverId,
    required this.driverName,
    required this.driverPhoto,
    required this.driverRating,
    required this.vehicleModel,
    required this.vehiclePlate,
    required this.vehicleColor,
    required this.acceptedPrice,
    required this.estimatedArrival,
    required this.offeredAt,
    required this.status,
    required this.completedTrips,
    required this.acceptanceRate,
  });

  // Factory para crear desde Map
  factory DriverOffer.fromMap(Map<String, dynamic> map) {
    return DriverOffer(
      driverId: map['driverId'] ?? '',
      driverName: map['driverName'] ?? 'Conductor',
      driverPhoto: map['driverPhoto'] ?? '',
      driverRating: (map['driverRating'] ?? 0.0).toDouble(),
      vehicleModel: map['vehicleModel'] ?? '',
      vehiclePlate: map['vehiclePlate'] ?? '',
      vehicleColor: map['vehicleColor'] ?? '',
      acceptedPrice: (map['acceptedPrice'] ?? 0.0).toDouble(),
      estimatedArrival: map['estimatedArrival'] ?? 0,
      offeredAt: (map['offeredAt'] as dynamic)?.toDate() ?? DateTime.now(),
      status: _offerStatusFromString(map['status'] ?? 'pending'),
      completedTrips: map['completedTrips'] ?? 0,
      acceptanceRate: (map['acceptanceRate'] ?? 0.0).toDouble(),
    );
  }

  // Convertir a Map
  Map<String, dynamic> toMap() {
    return {
      'driverId': driverId,
      'driverName': driverName,
      'driverPhoto': driverPhoto,
      'driverRating': driverRating,
      'vehicleModel': vehicleModel,
      'vehiclePlate': vehiclePlate,
      'vehicleColor': vehicleColor,
      'acceptedPrice': acceptedPrice,
      'estimatedArrival': estimatedArrival,
      'offeredAt': offeredAt,
      'status': status.toString().split('.').last,
      'completedTrips': completedTrips,
      'acceptanceRate': acceptanceRate,
    };
  }

  static OfferStatus _offerStatusFromString(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return OfferStatus.pending;
      case 'accepted':
        return OfferStatus.accepted;
      case 'rejected':
        return OfferStatus.rejected;
      case 'withdrawn':
        return OfferStatus.withdrawn;
      default:
        return OfferStatus.pending;
    }
  }

  DriverOffer copyWith({
    OfferStatus? status,
  }) {
    return DriverOffer(
      driverId: driverId,
      driverName: driverName,
      driverPhoto: driverPhoto,
      driverRating: driverRating,
      vehicleModel: vehicleModel,
      vehiclePlate: vehiclePlate,
      vehicleColor: vehicleColor,
      acceptedPrice: acceptedPrice,
      estimatedArrival: estimatedArrival,
      offeredAt: offeredAt,
      status: status ?? this.status,
      completedTrips: completedTrips,
      acceptanceRate: acceptanceRate,
    );
  }
}

// Punto de ubicación
class LocationPoint {
  final double latitude;
  final double longitude;
  final String address;
  final String? reference;

  LocationPoint({
    required this.latitude,
    required this.longitude,
    required this.address,
    this.reference,
  });

  // Factory para crear desde Map
  factory LocationPoint.fromMap(Map<String, dynamic> map) {
    return LocationPoint(
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      address: map['address'] ?? 'Dirección no disponible',
      reference: map['reference'],
    );
  }

  // Convertir a Map
  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'reference': reference,
    };
  }
}

// Estados de negociación
enum NegotiationStatus {
  waiting, // Esperando ofertas de conductores
  negotiating, // Conductores han hecho ofertas
  accepted, // Pasajero aceptó una oferta
  inProgress, // Viaje en curso
  completed, // Viaje completado
  cancelled, // Cancelado
  expired, // Expirado sin respuesta
}

// Estados de oferta del conductor
enum OfferStatus {
  pending, // Esperando respuesta del pasajero
  accepted, // Aceptada por el pasajero
  rejected, // Rechazada por el pasajero
  withdrawn, // Retirada por el conductor
}

// Métodos de pago
enum PaymentMethod {
  cash,
  card,
  wallet,
}

// Alias para compatibilidad
typedef PaymentMethodType = PaymentMethod;