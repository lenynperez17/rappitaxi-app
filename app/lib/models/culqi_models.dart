// Modelos para la integración con Culqi
// Pasarela de pagos peruana

// ==================== ENUMS ====================

/// Tipo de resultado del checkout
enum CulqiResultType {
  token,  // Pago con tarjeta - genera token
  order,  // Pago con Yape/PagoEfectivo - genera order
}

/// Estado de un cargo
enum CulqiChargeStatus {
  successful,
  declined,
  pending,
  refunded,
  partiallyRefunded,
  disputed,
}

/// Tipo de tarjeta
enum CulqiCardType {
  credit,
  debit,
  prepaid,
}

// ==================== RESPONSES ====================

/// Respuesta de configuración de Culqi
class CulqiConfigResponse {
  final bool success;
  final String? publicKey;
  final String? environment;
  final String? error;

  CulqiConfigResponse({
    required this.success,
    this.publicKey,
    this.environment,
    this.error,
  });

  factory CulqiConfigResponse.fromJson(Map<String, dynamic> json) {
    return CulqiConfigResponse(
      success: json['success'] ?? false,
      publicKey: json['publicKey'],
      environment: json['environment'],
      error: json['error'],
    );
  }

  bool get isProduction => environment == 'production';
  bool get isTest => environment == 'test';
}

/// Respuesta de cargo de Culqi
class CulqiChargeResponse {
  final bool success;
  final String? chargeId;
  final String? status;
  final int? amount;
  final String? error;
  final String? errorCode;

  CulqiChargeResponse({
    required this.success,
    this.chargeId,
    this.status,
    this.amount,
    this.error,
    this.errorCode,
  });

  factory CulqiChargeResponse.fromJson(Map<String, dynamic> json) {
    return CulqiChargeResponse(
      success: json['success'] ?? false,
      chargeId: json['chargeId'],
      status: json['status'],
      amount: json['amount'],
      error: json['error'],
      errorCode: json['errorCode'],
    );
  }

  bool get isSuccessful => success && status == 'successful';
}

/// Respuesta de recarga de Culqi
class CulqiRechargeResponse {
  final bool success;
  final String? chargeId;
  final String? transactionId;
  final double? newBalance;
  final String? error;

  CulqiRechargeResponse({
    required this.success,
    this.chargeId,
    this.transactionId,
    this.newBalance,
    this.error,
  });

  factory CulqiRechargeResponse.fromJson(Map<String, dynamic> json) {
    return CulqiRechargeResponse(
      success: json['success'] ?? false,
      chargeId: json['chargeId'],
      transactionId: json['transactionId'],
      newBalance: (json['newBalance'] as num?)?.toDouble(),
      error: json['error'],
    );
  }
}

/// Respuesta de reembolso de Culqi
class CulqiRefundResponse {
  final bool success;
  final String? refundId;
  final String? status;
  final int? amount;
  final String? error;

  CulqiRefundResponse({
    required this.success,
    this.refundId,
    this.status,
    this.amount,
    this.error,
  });

  factory CulqiRefundResponse.fromJson(Map<String, dynamic> json) {
    return CulqiRefundResponse(
      success: json['success'] ?? false,
      refundId: json['refundId'],
      status: json['status'],
      amount: json['amount'],
      error: json['error'],
    );
  }
}

/// Respuesta de cliente de Culqi
class CulqiCustomerResponse {
  final bool success;
  final String? customerId;
  final String? error;

  CulqiCustomerResponse({
    required this.success,
    this.customerId,
    this.error,
  });

  factory CulqiCustomerResponse.fromJson(Map<String, dynamic> json) {
    return CulqiCustomerResponse(
      success: json['success'] ?? false,
      customerId: json['customerId'],
      error: json['error'],
    );
  }
}

/// Respuesta de tarjeta de Culqi
class CulqiCardResponse {
  final bool success;
  final String? cardId;
  final String? cardBrand;
  final String? cardLast4;
  final String? error;

  CulqiCardResponse({
    required this.success,
    this.cardId,
    this.cardBrand,
    this.cardLast4,
    this.error,
  });

  factory CulqiCardResponse.fromJson(Map<String, dynamic> json) {
    return CulqiCardResponse(
      success: json['success'] ?? false,
      cardId: json['cardId'],
      cardBrand: json['cardBrand'],
      cardLast4: json['cardLast4'],
      error: json['error'],
    );
  }
}

/// Tarjeta guardada de Culqi
class CulqiSavedCard {
  final String id;
  final String brand;
  final String last4;
  final String? type;
  final int? expMonth;
  final int? expYear;
  final bool isActive;

  CulqiSavedCard({
    required this.id,
    required this.brand,
    required this.last4,
    this.type,
    this.expMonth,
    this.expYear,
    this.isActive = true,
  });

  factory CulqiSavedCard.fromJson(Map<String, dynamic> json) {
    // Obtener last4 de forma segura
    String last4Value = '****';
    if (json['last4'] != null) {
      last4Value = json['last4'].toString();
    } else if (json['source']?['card_number'] != null) {
      final cardNumber = json['source']['card_number'].toString();
      if (cardNumber.length >= 4) {
        last4Value = cardNumber.substring(cardNumber.length - 4);
      }
    }

    return CulqiSavedCard(
      id: json['id'] ?? '',
      brand: json['brand'] ?? json['source']?['iin']?['card_brand'] ?? 'Unknown',
      last4: last4Value,
      type: json['type'] ?? json['source']?['iin']?['card_type'],
      expMonth: json['exp_month'] ?? json['source']?['expiration_month'],
      expYear: json['exp_year'] ?? json['source']?['expiration_year'],
      isActive: json['active'] ?? true,
    );
  }

  /// Icono de la marca de la tarjeta
  String get brandIcon {
    switch (brand.toLowerCase()) {
      case 'visa':
        return '💳 Visa';
      case 'mastercard':
        return '💳 Mastercard';
      case 'amex':
      case 'american express':
        return '💳 Amex';
      case 'diners':
      case 'diners club':
        return '💳 Diners';
      default:
        return '💳 $brand';
    }
  }

  /// Número enmascarado de la tarjeta
  String get maskedNumber => '**** **** **** $last4';

  /// Fecha de expiración formateada
  String get expirationDate {
    if (expMonth == null || expYear == null) return '';
    return '${expMonth.toString().padLeft(2, '0')}/${expYear.toString().substring(2)}';
  }
}

/// Respuesta de lista de tarjetas de Culqi
class CulqiCardsListResponse {
  final bool success;
  final List<CulqiSavedCard>? cards;
  final String? error;

  CulqiCardsListResponse({
    required this.success,
    this.cards,
    this.error,
  });

  factory CulqiCardsListResponse.fromJson(Map<String, dynamic> json) {
    final List<dynamic>? cardsData = json['cards'];
    return CulqiCardsListResponse(
      success: json['success'] ?? false,
      cards: cardsData?.map((c) => CulqiSavedCard.fromJson(c)).toList(),
      error: json['error'],
    );
  }
}

// ==================== CHECKOUT RESULT ====================

/// Resultado del checkout de Culqi
class CulqiCheckoutResult {
  final bool success;
  final CulqiResultType type;

  // Para tokens (tarjeta)
  final String? token;
  final String? email;
  final String? cardBrand;
  final String? cardLast4;

  // Para orders (Yape, PagoEfectivo)
  final String? orderId;
  final String? status;
  final String? paymentCode;
  final String? expirationDate;

  // Metadata adicional
  final Map<String, dynamic>? metadata;

  CulqiCheckoutResult({
    required this.success,
    required this.type,
    this.token,
    this.email,
    this.cardBrand,
    this.cardLast4,
    this.orderId,
    this.status,
    this.paymentCode,
    this.expirationDate,
    this.metadata,
  });

  /// Es un pago con tarjeta
  bool get isCardPayment => type == CulqiResultType.token;

  /// Es un pago con Yape o PagoEfectivo
  bool get isAlternativePayment => type == CulqiResultType.order;

  /// Obtiene el ID del source (token u orderId)
  String? get sourceId => isCardPayment ? token : orderId;

  /// Resumen del pago para mostrar al usuario
  String get paymentSummary {
    if (isCardPayment) {
      return 'Tarjeta ${cardBrand ?? ''} terminada en ${cardLast4 ?? '****'}';
    } else {
      return 'Pago alternativo - Código: ${paymentCode ?? orderId ?? 'N/A'}';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'type': type.name,
      'token': token,
      'email': email,
      'cardBrand': cardBrand,
      'cardLast4': cardLast4,
      'orderId': orderId,
      'status': status,
      'paymentCode': paymentCode,
      'expirationDate': expirationDate,
      'metadata': metadata,
    };
  }

  factory CulqiCheckoutResult.fromJson(Map<String, dynamic> json) {
    return CulqiCheckoutResult(
      success: json['success'] ?? false,
      type: json['type'] == 'order' ? CulqiResultType.order : CulqiResultType.token,
      token: json['token'],
      email: json['email'],
      cardBrand: json['cardBrand'],
      cardLast4: json['cardLast4'],
      orderId: json['orderId'],
      status: json['status'],
      paymentCode: json['paymentCode'],
      expirationDate: json['expirationDate'],
      metadata: json['metadata'],
    );
  }
}

// ==================== ANTIFRAUD ====================

/// Detalles antifraude para Culqi
class CulqiAntifraudDetails {
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? phoneNumber;
  final String? address;
  final String? addressCity;
  final String? countryCode;
  final String? deviceFingerprint;

  CulqiAntifraudDetails({
    this.firstName,
    this.lastName,
    this.email,
    this.phoneNumber,
    this.address,
    this.addressCity,
    this.countryCode,
    this.deviceFingerprint,
  });

  Map<String, dynamic> toJson() {
    return {
      if (firstName != null) 'first_name': firstName,
      if (lastName != null) 'last_name': lastName,
      if (email != null) 'email': email,
      if (phoneNumber != null) 'phone_number': phoneNumber,
      if (address != null) 'address': address,
      if (addressCity != null) 'address_city': addressCity,
      if (countryCode != null) 'country_code': countryCode,
      if (deviceFingerprint != null) 'device_finger_print': deviceFingerprint,
    };
  }
}

// ==================== TRANSACTION ====================

/// Transacción de Culqi guardada localmente
class CulqiTransaction {
  final String id;
  final String chargeId;
  final int amount;
  final String status;
  final String type;
  final DateTime createdAt;
  final String? description;
  final Map<String, dynamic>? metadata;

  CulqiTransaction({
    required this.id,
    required this.chargeId,
    required this.amount,
    required this.status,
    required this.type,
    required this.createdAt,
    this.description,
    this.metadata,
  });

  factory CulqiTransaction.fromFirestore(Map<String, dynamic> data, String id) {
    return CulqiTransaction(
      id: id,
      chargeId: data['chargeId'] ?? '',
      amount: data['amount'] ?? 0,
      status: data['status'] ?? 'unknown',
      type: data['type'] ?? 'charge',
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      description: data['description'],
      metadata: data['metadata'],
    );
  }

  /// Monto en soles
  double get amountInSoles => amount / 100;

  /// Monto formateado
  String get formattedAmount => 'S/ ${amountInSoles.toStringAsFixed(2)}';

  /// Estado legible
  String get statusLabel {
    switch (status) {
      case 'successful':
        return 'Exitoso';
      case 'declined':
        return 'Rechazado';
      case 'pending':
        return 'Pendiente';
      case 'refunded':
        return 'Reembolsado';
      default:
        return status;
    }
  }

  /// Color del estado
  int get statusColor {
    switch (status) {
      case 'successful':
        return 0xFF4CAF50; // Verde
      case 'declined':
        return 0xFFE53935; // Rojo
      case 'pending':
        return 0xFFFFA726; // Naranja
      case 'refunded':
        return 0xFF2196F3; // Azul
      default:
        return 0xFF9E9E9E; // Gris
    }
  }
}
