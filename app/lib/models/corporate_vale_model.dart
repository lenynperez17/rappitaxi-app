/// Modelo de Vale Corporativo
class CorporateValeModel {
  // Identificación
  final String id;
  final String valeCode; // Código único (ej: VALE-2024-ABC123XYZ)
  final String batchId; // ID del lote al que pertenece

  // Empresa
  final String companyId;
  final String companyName;

  // Tipo de Vale
  final ValeType valeType;

  // Configuración según tipo
  final double? initialBalance; // Para tipo creditBalance
  final double? currentBalance; // Saldo actual
  final double? discountPercentage; // Para tipo percentDiscount (0-100)
  final int? maxUsesDiscount; // Máximo usos para descuento
  final int? currentUsesDiscount; // Usos actuales
  final double? maxRideValue; // Para tipo freeRides
  final int? maxFreeRides; // Cantidad máxima de viajes gratis
  final int? currentFreeRides; // Viajes gratis usados
  final bool? isUnlimited; // Para tipo unlimited
  final DateTime? billingPeriodEnd; // Fecha de corte para liquidación

  // Estado
  final ValeStatus status;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? expiresAt;

  // Uso y estadísticas
  final int totalTripsUsed;
  final double totalAmountUsed;
  final List<String> rideIds; // IDs de viajes donde se usó
  final String? assignedToUserId; // Usuario específico (opcional)

  // Restricciones (opcional)
  final int? maxTripsPerDay;
  final List<String>? allowedVehicleTypes;
  final TimeRestriction? timeRestriction;

  // Metadata
  final String? notes;
  final Map<String, dynamic>? metadata;

  CorporateValeModel({
    required this.id,
    required this.valeCode,
    required this.batchId,
    required this.companyId,
    required this.companyName,
    required this.valeType,
    this.initialBalance,
    this.currentBalance,
    this.discountPercentage,
    this.maxUsesDiscount,
    this.currentUsesDiscount,
    this.maxRideValue,
    this.maxFreeRides,
    this.currentFreeRides,
    this.isUnlimited,
    this.billingPeriodEnd,
    required this.status,
    this.isActive = true,
    required this.createdAt,
    this.expiresAt,
    this.totalTripsUsed = 0,
    this.totalAmountUsed = 0.0,
    this.rideIds = const [],
    this.assignedToUserId,
    this.maxTripsPerDay,
    this.allowedVehicleTypes,
    this.timeRestriction,
    this.notes,
    this.metadata,
  });

  /// Crear desde JSON
  factory CorporateValeModel.fromJson(Map<String, dynamic> json) {
    return CorporateValeModel(
      id: json['id'] ?? '',
      valeCode: json['valeCode'] ?? '',
      batchId: json['batchId'] ?? '',
      companyId: json['companyId'] ?? '',
      companyName: json['companyName'] ?? '',
      valeType: ValeType.values.firstWhere(
        (e) => e.toString() == 'ValeType.${json['valeType']}',
        orElse: () => ValeType.creditBalance,
      ),
      initialBalance: json['initialBalance']?.toDouble(),
      currentBalance: json['currentBalance']?.toDouble(),
      discountPercentage: json['discountPercentage']?.toDouble(),
      maxUsesDiscount: json['maxUsesDiscount'],
      currentUsesDiscount: json['currentUsesDiscount'] ?? 0,
      maxRideValue: json['maxRideValue']?.toDouble(),
      maxFreeRides: json['maxFreeRides'],
      currentFreeRides: json['currentFreeRides'] ?? 0,
      isUnlimited: json['isUnlimited'],
      billingPeriodEnd: json['billingPeriodEnd'] != null
          ? DateTime.parse(json['billingPeriodEnd'])
          : null,
      status: ValeStatus.values.firstWhere(
        (e) => e.toString() == 'ValeStatus.${json['status']}',
        orElse: () => ValeStatus.active,
      ),
      isActive: json['isActive'] ?? true,
      createdAt: DateTime.parse(json['createdAt']),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'])
          : null,
      totalTripsUsed: json['totalTripsUsed'] ?? 0,
      totalAmountUsed: (json['totalAmountUsed'] ?? 0.0).toDouble(),
      rideIds: List<String>.from(json['rideIds'] ?? []),
      assignedToUserId: json['assignedToUserId'],
      maxTripsPerDay: json['maxTripsPerDay'],
      allowedVehicleTypes: json['allowedVehicleTypes'] != null
          ? List<String>.from(json['allowedVehicleTypes'])
          : null,
      timeRestriction: json['timeRestriction'] != null
          ? TimeRestriction.fromJson(json['timeRestriction'])
          : null,
      notes: json['notes'],
      metadata: json['metadata'],
    );
  }

  /// Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'valeCode': valeCode,
      'batchId': batchId,
      'companyId': companyId,
      'companyName': companyName,
      'valeType': valeType.toString().split('.').last,
      'initialBalance': initialBalance,
      'currentBalance': currentBalance,
      'discountPercentage': discountPercentage,
      'maxUsesDiscount': maxUsesDiscount,
      'currentUsesDiscount': currentUsesDiscount,
      'maxRideValue': maxRideValue,
      'maxFreeRides': maxFreeRides,
      'currentFreeRides': currentFreeRides,
      'isUnlimited': isUnlimited,
      'billingPeriodEnd': billingPeriodEnd?.toIso8601String(),
      'status': status.toString().split('.').last,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'totalTripsUsed': totalTripsUsed,
      'totalAmountUsed': totalAmountUsed,
      'rideIds': rideIds,
      'assignedToUserId': assignedToUserId,
      'maxTripsPerDay': maxTripsPerDay,
      'allowedVehicleTypes': allowedVehicleTypes,
      'timeRestriction': timeRestriction?.toJson(),
      'notes': notes,
      'metadata': metadata,
    };
  }

  /// Verificar si el vale está disponible para usar
  bool get canBeUsed {
    if (!isActive || status != ValeStatus.active) return false;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt!)) return false;

    switch (valeType) {
      case ValeType.creditBalance:
        return (currentBalance ?? 0) > 0;
      case ValeType.percentDiscount:
        return (currentUsesDiscount ?? 0) < (maxUsesDiscount ?? 0);
      case ValeType.freeRides:
        return (currentFreeRides ?? 0) < (maxFreeRides ?? 0);
      case ValeType.unlimited:
        return isUnlimited ?? false;
    }
  }

  /// Calcular monto a aplicar para un viaje
  double calculateApplicableAmount(double rideFare) {
    if (!canBeUsed) return 0.0;

    switch (valeType) {
      case ValeType.creditBalance:
        final balance = currentBalance ?? 0;
        return rideFare <= balance ? rideFare : balance;

      case ValeType.percentDiscount:
        final discount = (discountPercentage ?? 0) / 100;
        return rideFare * discount;

      case ValeType.freeRides:
        final maxValue = maxRideValue ?? double.infinity;
        return rideFare <= maxValue ? rideFare : 0;

      case ValeType.unlimited:
        return rideFare; // Cubre todo
    }
  }

  /// Copiar con cambios
  CorporateValeModel copyWith({
    String? id,
    String? valeCode,
    String? batchId,
    String? companyId,
    String? companyName,
    ValeType? valeType,
    double? initialBalance,
    double? currentBalance,
    double? discountPercentage,
    int? maxUsesDiscount,
    int? currentUsesDiscount,
    double? maxRideValue,
    int? maxFreeRides,
    int? currentFreeRides,
    bool? isUnlimited,
    DateTime? billingPeriodEnd,
    ValeStatus? status,
    bool? isActive,
    DateTime? createdAt,
    DateTime? expiresAt,
    int? totalTripsUsed,
    double? totalAmountUsed,
    List<String>? rideIds,
    String? assignedToUserId,
    int? maxTripsPerDay,
    List<String>? allowedVehicleTypes,
    TimeRestriction? timeRestriction,
    String? notes,
    Map<String, dynamic>? metadata,
  }) {
    return CorporateValeModel(
      id: id ?? this.id,
      valeCode: valeCode ?? this.valeCode,
      batchId: batchId ?? this.batchId,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      valeType: valeType ?? this.valeType,
      initialBalance: initialBalance ?? this.initialBalance,
      currentBalance: currentBalance ?? this.currentBalance,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      maxUsesDiscount: maxUsesDiscount ?? this.maxUsesDiscount,
      currentUsesDiscount: currentUsesDiscount ?? this.currentUsesDiscount,
      maxRideValue: maxRideValue ?? this.maxRideValue,
      maxFreeRides: maxFreeRides ?? this.maxFreeRides,
      currentFreeRides: currentFreeRides ?? this.currentFreeRides,
      isUnlimited: isUnlimited ?? this.isUnlimited,
      billingPeriodEnd: billingPeriodEnd ?? this.billingPeriodEnd,
      status: status ?? this.status,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      totalTripsUsed: totalTripsUsed ?? this.totalTripsUsed,
      totalAmountUsed: totalAmountUsed ?? this.totalAmountUsed,
      rideIds: rideIds ?? this.rideIds,
      assignedToUserId: assignedToUserId ?? this.assignedToUserId,
      maxTripsPerDay: maxTripsPerDay ?? this.maxTripsPerDay,
      allowedVehicleTypes: allowedVehicleTypes ?? this.allowedVehicleTypes,
      timeRestriction: timeRestriction ?? this.timeRestriction,
      notes: notes ?? this.notes,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Tipo de Vale
enum ValeType {
  creditBalance, // Saldo prepagado reutilizable
  percentDiscount, // Descuento porcentual por viaje
  freeRides, // Viajes gratis hasta límite
  unlimited, // Ilimitado con liquidación mensual
}

/// Estado del Vale
enum ValeStatus {
  active, // Activo y con saldo/usos disponibles
  depleted, // Agotado (saldo = 0 o usos máximos)
  expired, // Fecha de expiración pasada
  cancelled, // Cancelado por admin
  suspended, // Suspendido temporalmente
}

/// Restricción de horario
class TimeRestriction {
  final List<int> allowedDays; // 1=Lunes, 7=Domingo
  final String startTime; // HH:mm
  final String endTime; // HH:mm

  TimeRestriction({
    required this.allowedDays,
    required this.startTime,
    required this.endTime,
  });

  factory TimeRestriction.fromJson(Map<String, dynamic> json) {
    return TimeRestriction(
      allowedDays: List<int>.from(json['allowedDays'] ?? []),
      startTime: json['startTime'] ?? '00:00',
      endTime: json['endTime'] ?? '23:59',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'allowedDays': allowedDays,
      'startTime': startTime,
      'endTime': endTime,
    };
  }

  /// Verificar si el horario actual está permitido
  bool isCurrentTimeAllowed() {
    final now = DateTime.now();
    if (!allowedDays.contains(now.weekday)) return false;

    final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return currentTime.compareTo(startTime) >= 0 &&
        currentTime.compareTo(endTime) <= 0;
  }
}
