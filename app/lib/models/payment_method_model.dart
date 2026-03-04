/// Modelo para métodos de retiro del conductor
class PaymentMethodModel {
  final String id;
  final String userId; // ID del conductor
  final String type; // 'bank', 'card', 'cash'
  final String status; // 'active', 'inactive', 'pending_verification'
  final DateTime createdAt;
  final DateTime updatedAt;

  // Datos específicos de cuenta bancaria
  final String? bankName;
  final String? accountType; // 'savings', 'checking'
  final String? accountNumber;
  final String? cci; // Código de Cuenta Interbancaria (Perú)
  final String? accountHolderName;
  final String? accountHolderDni;

  // Datos específicos de tarjeta de débito
  final String? cardNumber; // Últimos 4 dígitos
  final String? cardHolderName;
  final String? cardBank;

  // Configuración
  final bool isDefault; // Método por defecto para retiros

  PaymentMethodModel({
    required this.id,
    required this.userId,
    required this.type,
    this.status = 'pending_verification',
    required this.createdAt,
    required this.updatedAt,
    this.bankName,
    this.accountType,
    this.accountNumber,
    this.cci,
    this.accountHolderName,
    this.accountHolderDni,
    this.cardNumber,
    this.cardHolderName,
    this.cardBank,
    this.isDefault = false,
  });

  /// Crear desde JSON
  factory PaymentMethodModel.fromJson(Map<String, dynamic> json) {
    return PaymentMethodModel(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      type: json['type'] ?? 'bank',
      status: json['status'] ?? 'pending_verification',
      createdAt: json['createdAt'] is DateTime
          ? json['createdAt']
          : DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: json['updatedAt'] is DateTime
          ? json['updatedAt']
          : DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
      bankName: json['bankName'],
      accountType: json['accountType'],
      accountNumber: json['accountNumber'],
      cci: json['cci'],
      accountHolderName: json['accountHolderName'],
      accountHolderDni: json['accountHolderDni'],
      cardNumber: json['cardNumber'],
      cardHolderName: json['cardHolderName'],
      cardBank: json['cardBank'],
      isDefault: json['isDefault'] ?? false,
    );
  }

  /// Crear desde Firestore
  factory PaymentMethodModel.fromFirestore(Map<String, dynamic> data, String documentId) {
    return PaymentMethodModel(
      id: documentId,
      userId: data['userId'] ?? '',
      type: data['type'] ?? 'bank',
      status: data['status'] ?? 'pending_verification',
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
      updatedAt: data['updatedAt']?.toDate() ?? DateTime.now(),
      bankName: data['bankName'],
      accountType: data['accountType'],
      accountNumber: data['accountNumber'],
      cci: data['cci'],
      accountHolderName: data['accountHolderName'],
      accountHolderDni: data['accountHolderDni'],
      cardNumber: data['cardNumber'],
      cardHolderName: data['cardHolderName'],
      cardBank: data['cardBank'],
      isDefault: data['isDefault'] ?? false,
    );
  }

  /// Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'bankName': bankName,
      'accountType': accountType,
      'accountNumber': accountNumber,
      'cci': cci,
      'accountHolderName': accountHolderName,
      'accountHolderDni': accountHolderDni,
      'cardNumber': cardNumber,
      'cardHolderName': cardHolderName,
      'cardBank': cardBank,
      'isDefault': isDefault,
    };
  }

  /// Convertir a Firestore (sin ID)
  Map<String, dynamic> toFirestore() {
    final data = toJson();
    data.remove('id');
    return data;
  }

  /// Copiar con cambios
  PaymentMethodModel copyWith({
    String? id,
    String? userId,
    String? type,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? bankName,
    String? accountType,
    String? accountNumber,
    String? cci,
    String? accountHolderName,
    String? accountHolderDni,
    String? cardNumber,
    String? cardHolderName,
    String? cardBank,
    bool? isDefault,
  }) {
    return PaymentMethodModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      bankName: bankName ?? this.bankName,
      accountType: accountType ?? this.accountType,
      accountNumber: accountNumber ?? this.accountNumber,
      cci: cci ?? this.cci,
      accountHolderName: accountHolderName ?? this.accountHolderName,
      accountHolderDni: accountHolderDni ?? this.accountHolderDni,
      cardNumber: cardNumber ?? this.cardNumber,
      cardHolderName: cardHolderName ?? this.cardHolderName,
      cardBank: cardBank ?? this.cardBank,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  /// Obtener descripción legible del método
  String get displayName {
    switch (type) {
      case 'bank':
        return bankName ?? 'Cuenta Bancaria';
      case 'card':
        return cardBank != null
            ? '$cardBank - ${cardNumber ?? "****"}'
            : 'Tarjeta de Débito';
      case 'cash':
        return 'Efectivo en Oficina';
      default:
        return 'Método de Pago';
    }
  }

  /// Obtener número de cuenta oculto (para mostrar en UI)
  String? get maskedAccountNumber {
    if (accountNumber == null || accountNumber!.length < 4) return null;
    final last4 = accountNumber!.substring(accountNumber!.length - 4);
    return '****$last4';
  }

  @override
  String toString() {
    return 'PaymentMethodModel(id: $id, type: $type, displayName: $displayName)';
  }
}
