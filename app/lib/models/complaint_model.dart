// Modelo para el Libro de Reclamaciones
// Cumple con Ley N° 29571 - Código de Protección y Defensa del Consumidor (Perú)

import 'package:cloud_firestore/cloud_firestore.dart';

// Tipo de registro: Reclamo o Queja
enum ComplaintType {
  reclamo, // Disconformidad con el servicio - respuesta obligatoria en 30 días
  queja,   // Malestar por la atención - no requiere respuesta formal
}

// Estado del reclamo
enum ComplaintStatus {
  pending,    // Pendiente de revisión
  inReview,   // En revisión por el proveedor
  resolved,   // Resuelto
  closed,     // Cerrado
}

// Datos del proveedor (empresa)
class ProviderInfo {
  static const String name = 'RAPI SOLUCIONES GENERALES S.A.C.';
  static const String ruc = '20612945790';
  static const String address = 'CALLE LOS LAURELES MZ. Z LT. 6, COOP. CESAR VALLEJO, SAN MARTIN DE PORRES, LIMA';
}

// Modelo principal del reclamo
class ComplaintRecord {
  final String id;
  final String complaintNumber; // Formato: "REC-2026-00001"
  final DateTime createdAt;
  final ComplaintType type;

  // Datos del consumidor
  final String consumerId;
  final String consumerName;
  final String consumerDni;
  final String consumerAddress;
  final String consumerPhone;
  final String consumerEmail;

  // Datos del reclamo
  final String? tripId; // Viaje relacionado (opcional)
  final double? claimedAmount; // Monto reclamado
  final String serviceDescription; // Descripción del servicio
  final String complaintDetail; // Detalle del reclamo (mín 50 caracteres)
  final String consumerRequest; // Pedido del consumidor

  // Estado y respuesta
  final ComplaintStatus status;
  final String? adminResponse; // Respuesta del proveedor
  final DateTime? responseDate;
  final DateTime? resolvedDate;

  // Datos del proveedor
  final String providerName;
  final String providerRuc;
  final String providerAddress;

  ComplaintRecord({
    required this.id,
    required this.complaintNumber,
    required this.createdAt,
    required this.type,
    required this.consumerId,
    required this.consumerName,
    required this.consumerDni,
    required this.consumerAddress,
    required this.consumerPhone,
    required this.consumerEmail,
    this.tripId,
    this.claimedAmount,
    required this.serviceDescription,
    required this.complaintDetail,
    required this.consumerRequest,
    required this.status,
    this.adminResponse,
    this.responseDate,
    this.resolvedDate,
    this.providerName = ProviderInfo.name,
    this.providerRuc = ProviderInfo.ruc,
    this.providerAddress = ProviderInfo.address,
  });

  // Crear desde Firestore
  factory ComplaintRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ComplaintRecord(
      id: doc.id,
      complaintNumber: data['complaintNumber'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: ComplaintType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => ComplaintType.reclamo,
      ),
      consumerId: data['consumerId'] ?? '',
      consumerName: data['consumerName'] ?? '',
      consumerDni: data['consumerDni'] ?? '',
      consumerAddress: data['consumerAddress'] ?? '',
      consumerPhone: data['consumerPhone'] ?? '',
      consumerEmail: data['consumerEmail'] ?? '',
      tripId: data['tripId'],
      claimedAmount: data['claimedAmount']?.toDouble(),
      serviceDescription: data['serviceDescription'] ?? '',
      complaintDetail: data['complaintDetail'] ?? '',
      consumerRequest: data['consumerRequest'] ?? '',
      status: ComplaintStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => ComplaintStatus.pending,
      ),
      adminResponse: data['adminResponse'],
      responseDate: (data['responseDate'] as Timestamp?)?.toDate(),
      resolvedDate: (data['resolvedDate'] as Timestamp?)?.toDate(),
      providerName: data['providerName'] ?? ProviderInfo.name,
      providerRuc: data['providerRuc'] ?? ProviderInfo.ruc,
      providerAddress: data['providerAddress'] ?? ProviderInfo.address,
    );
  }

  // Convertir a Map para Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'complaintNumber': complaintNumber,
      'createdAt': Timestamp.fromDate(createdAt),
      'type': type.name,
      'consumerId': consumerId,
      'consumerName': consumerName,
      'consumerDni': consumerDni,
      'consumerAddress': consumerAddress,
      'consumerPhone': consumerPhone,
      'consumerEmail': consumerEmail,
      'tripId': tripId,
      'claimedAmount': claimedAmount,
      'serviceDescription': serviceDescription,
      'complaintDetail': complaintDetail,
      'consumerRequest': consumerRequest,
      'status': status.name,
      'adminResponse': adminResponse,
      'responseDate': responseDate != null ? Timestamp.fromDate(responseDate!) : null,
      'resolvedDate': resolvedDate != null ? Timestamp.fromDate(resolvedDate!) : null,
      'providerName': providerName,
      'providerRuc': providerRuc,
      'providerAddress': providerAddress,
    };
  }

  // Copiar con cambios
  ComplaintRecord copyWith({
    String? id,
    String? complaintNumber,
    DateTime? createdAt,
    ComplaintType? type,
    String? consumerId,
    String? consumerName,
    String? consumerDni,
    String? consumerAddress,
    String? consumerPhone,
    String? consumerEmail,
    String? tripId,
    double? claimedAmount,
    String? serviceDescription,
    String? complaintDetail,
    String? consumerRequest,
    ComplaintStatus? status,
    String? adminResponse,
    DateTime? responseDate,
    DateTime? resolvedDate,
  }) {
    return ComplaintRecord(
      id: id ?? this.id,
      complaintNumber: complaintNumber ?? this.complaintNumber,
      createdAt: createdAt ?? this.createdAt,
      type: type ?? this.type,
      consumerId: consumerId ?? this.consumerId,
      consumerName: consumerName ?? this.consumerName,
      consumerDni: consumerDni ?? this.consumerDni,
      consumerAddress: consumerAddress ?? this.consumerAddress,
      consumerPhone: consumerPhone ?? this.consumerPhone,
      consumerEmail: consumerEmail ?? this.consumerEmail,
      tripId: tripId ?? this.tripId,
      claimedAmount: claimedAmount ?? this.claimedAmount,
      serviceDescription: serviceDescription ?? this.serviceDescription,
      complaintDetail: complaintDetail ?? this.complaintDetail,
      consumerRequest: consumerRequest ?? this.consumerRequest,
      status: status ?? this.status,
      adminResponse: adminResponse ?? this.adminResponse,
      responseDate: responseDate ?? this.responseDate,
      resolvedDate: resolvedDate ?? this.resolvedDate,
    );
  }

  // Helpers para UI
  String get typeDisplayName {
    switch (type) {
      case ComplaintType.reclamo:
        return 'Reclamo';
      case ComplaintType.queja:
        return 'Queja';
    }
  }

  String get statusDisplayName {
    switch (status) {
      case ComplaintStatus.pending:
        return 'Pendiente';
      case ComplaintStatus.inReview:
        return 'En Revisión';
      case ComplaintStatus.resolved:
        return 'Resuelto';
      case ComplaintStatus.closed:
        return 'Cerrado';
    }
  }

  String get statusEmoji {
    switch (status) {
      case ComplaintStatus.pending:
        return '🟡';
      case ComplaintStatus.inReview:
        return '🔵';
      case ComplaintStatus.resolved:
        return '🟢';
      case ComplaintStatus.closed:
        return '⚫';
    }
  }

  // Verificar si requiere respuesta (solo reclamos, no quejas)
  bool get requiresResponse => type == ComplaintType.reclamo;

  // Días restantes para responder (30 días según ley)
  int get daysToRespond {
    if (!requiresResponse || status == ComplaintStatus.resolved || status == ComplaintStatus.closed) {
      return 0;
    }
    final deadline = createdAt.add(const Duration(days: 30));
    final remaining = deadline.difference(DateTime.now()).inDays;
    return remaining > 0 ? remaining : 0;
  }

  // Verificar si está vencido
  bool get isOverdue {
    if (!requiresResponse || status == ComplaintStatus.resolved || status == ComplaintStatus.closed) {
      return false;
    }
    return daysToRespond == 0;
  }
}
