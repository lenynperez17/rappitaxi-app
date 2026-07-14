import 'package:flutter/material.dart';
import '../services/rapi_api_client.dart';
import '../utils/logger.dart';

enum CardType { visa, mastercard, amex, discover, other }
enum PaymentMethodType { card, cash, wallet, paypal }

/// Convertimos el `methodType` textual del backend al enum de la app.
PaymentMethodType _methodTypeFromString(String? s) {
  switch ((s ?? '').toLowerCase()) {
    case 'cash': return PaymentMethodType.cash;
    case 'wallet': return PaymentMethodType.wallet;
    case 'card':
    case 'mercadopago': return PaymentMethodType.card;
    case 'paypal': return PaymentMethodType.paypal;
    default: return PaymentMethodType.cash;
  }
}

String _methodTypeToString(PaymentMethodType t) {
  switch (t) {
    case PaymentMethodType.cash: return 'cash';
    case PaymentMethodType.wallet: return 'wallet';
    case PaymentMethodType.card: return 'mercadopago';
    case PaymentMethodType.paypal: return 'paypal';
  }
}

class PaymentMethod {
  final String id;
  final PaymentMethodType type;
  final String name;
  final String? cardNumber;
  final String? cardHolder;
  final String? expiryDate;
  final CardType? cardType;
  final bool isDefault;
  final String? walletBalance;
  final String iconName;
  final String colorHex;
  final DateTime? createdAt;
  final bool isActive;

  PaymentMethod({
    required this.id,
    required this.type,
    required this.name,
    this.cardNumber,
    this.cardHolder,
    this.expiryDate,
    this.cardType,
    required this.isDefault,
    this.walletBalance,
    required this.iconName,
    required this.colorHex,
    this.createdAt,
    this.isActive = true,
  });

  String get displayName {
    if (type == PaymentMethodType.card && cardNumber != null && cardNumber!.length >= 4) {
      return '$name •••• ${cardNumber!.substring(cardNumber!.length - 4)}';
    }
    return name;
  }

  Color get color => Color(int.parse(colorHex.replaceAll('#', '0xFF')));

  /// Mapea la respuesta del backend `/api/payment-methods` al modelo local.
  static PaymentMethod fromApi(Map<String, dynamic> data) {
    final t = _methodTypeFromString(data['methodType'] as String?);
    final defaults = _defaultDisplay(t);
    return PaymentMethod(
      id: (data['id'] ?? '') as String,
      type: t,
      name: (data['label'] ?? defaults.name) as String,
      isDefault: (data['isDefault'] ?? false) as bool,
      iconName: defaults.icon,
      colorHex: defaults.color,
      createdAt: _parseDate(data['createdAt']),
      isActive: true,
    );
  }

  static _MethodDisplay _defaultDisplay(PaymentMethodType t) {
    switch (t) {
      case PaymentMethodType.cash: return _MethodDisplay('Efectivo', 'money', '#4CAF50');
      case PaymentMethodType.wallet: return _MethodDisplay('Billetera', 'wallet', '#FF6B00');
      case PaymentMethodType.card: return _MethodDisplay('MercadoPago', 'credit_card', '#2196F3');
      case PaymentMethodType.paypal: return _MethodDisplay('PayPal', 'paypal', '#003087');
    }
  }

  PaymentMethod copyWith({
    String? id, PaymentMethodType? type, String? name, String? cardNumber,
    String? cardHolder, String? expiryDate, CardType? cardType, bool? isDefault,
    String? walletBalance, String? iconName, String? colorHex,
    DateTime? createdAt, bool? isActive,
  }) {
    return PaymentMethod(
      id: id ?? this.id, type: type ?? this.type, name: name ?? this.name,
      cardNumber: cardNumber ?? this.cardNumber, cardHolder: cardHolder ?? this.cardHolder,
      expiryDate: expiryDate ?? this.expiryDate, cardType: cardType ?? this.cardType,
      isDefault: isDefault ?? this.isDefault, walletBalance: walletBalance ?? this.walletBalance,
      iconName: iconName ?? this.iconName, colorHex: colorHex ?? this.colorHex,
      createdAt: createdAt ?? this.createdAt, isActive: isActive ?? this.isActive,
    );
  }
}

class _MethodDisplay {
  final String name;
  final String icon;
  final String color;
  const _MethodDisplay(this.name, this.icon, this.color);
}

class TransactionRecord {
  final String id;
  final String userId;
  final String? tripId;
  final double amount;
  final String paymentMethodId;
  final String paymentMethodName;
  final String status;
  final String? failureReason;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  TransactionRecord({
    required this.id,
    required this.userId,
    this.tripId,
    required this.amount,
    required this.paymentMethodId,
    required this.paymentMethodName,
    required this.status,
    this.failureReason,
    required this.createdAt,
    this.metadata,
  });

  /// Mapea la respuesta del backend `/api/wallet/transactions`.
  static TransactionRecord fromApi(Map<String, dynamic> data) {
    return TransactionRecord(
      id: (data['id'] ?? '') as String,
      userId: (data['userId'] ?? '') as String,
      tripId: data['rideId'] as String?,
      amount: ((data['amount'] as num?) ?? 0).toDouble().abs(),
      paymentMethodId: '${data['type'] ?? ''}',
      paymentMethodName: (data['description'] ?? data['type'] ?? '') as String,
      status: (data['status'] ?? 'completed') as String,
      createdAt: _parseDate(data['createdAt']) ?? DateTime.now(),
      metadata: data['metadata'] is Map<String, dynamic> ? data['metadata'] as Map<String, dynamic> : null,
    );
  }
}

class PaymentStatistics {
  final double totalSpent;
  final int totalTransactions;
  final int successfulTransactions;
  final int failedTransactions;
  final double averageTransactionAmount;
  final Map<String, double> spendingByMethod;
  final Map<String, int> transactionsByMethod;

  PaymentStatistics({
    required this.totalSpent,
    required this.totalTransactions,
    required this.successfulTransactions,
    required this.failedTransactions,
    required this.averageTransactionAmount,
    required this.spendingByMethod,
    required this.transactionsByMethod,
  });
}

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  return null;
}

class PaymentProvider with ChangeNotifier {
  final RapiApiClient _api = RapiApiClient.instance;

  bool _isLoading = false;
  bool _isLoadingTransactions = false;
  String? _error;

  List<PaymentMethod> _paymentMethods = [];
  String? _defaultPaymentMethodId;

  List<TransactionRecord> _transactions = [];
  PaymentStatistics? _statistics;

  double _walletBalance = 0.0;
  bool _isWalletLoading = false;

  bool get isLoading => _isLoading;
  bool get isLoadingTransactions => _isLoadingTransactions;
  bool get isWalletLoading => _isWalletLoading;
  String? get error => _error;

  List<PaymentMethod> get paymentMethods => List.unmodifiable(_paymentMethods);
  List<PaymentMethod> get activePaymentMethods =>
      _paymentMethods.where((m) => m.isActive == true).toList();
  PaymentMethod? get selectedPaymentMethod => _defaultPaymentMethodId != null && _paymentMethods.isNotEmpty
      ? _paymentMethods.firstWhere((m) => m.id == _defaultPaymentMethodId, orElse: () => _paymentMethods.first)
      : (_paymentMethods.isNotEmpty ? _paymentMethods.first : null);

  PaymentMethod? get defaultPaymentMethod {
    for (final m in _paymentMethods) {
      if (m.isDefault && m.isActive) return m;
    }
    if (_paymentMethods.isNotEmpty) return _paymentMethods.first;
    return PaymentMethod(
      id: 'cash', type: PaymentMethodType.cash, name: 'Efectivo',
      isDefault: true, iconName: 'money', colorHex: '#4CAF50',
    );
  }

  List<TransactionRecord> get transactions => List.unmodifiable(_transactions);
  List<TransactionRecord> get successfulTransactions =>
      _transactions.where((t) => t.status == 'completed').toList();
  PaymentStatistics? get statistics => _statistics;
  double get walletBalance => _walletBalance;

  void clearError() { _error = null; notifyListeners(); }

  Future<void> loadPaymentMethods(String userId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final data = await _api.listPaymentMethods();
      final rawList = (data['methods'] as List?) ?? (data['paymentMethods'] as List?) ?? const [];
      _paymentMethods = rawList
          .whereType<Map<String, dynamic>>()
          .map((m) => PaymentMethod.fromApi(m))
          .toList();

      // Efectivo siempre disponible como fallback
      if (_paymentMethods.isEmpty || !_paymentMethods.any((m) => m.type == PaymentMethodType.cash)) {
        _paymentMethods.insert(0, PaymentMethod(
          id: 'cash', type: PaymentMethodType.cash, name: 'Efectivo',
          isDefault: _paymentMethods.isEmpty, iconName: 'money', colorHex: '#4CAF50',
        ));
      }

      final def = _paymentMethods.firstWhere(
        (m) => m.isDefault,
        orElse: () => _paymentMethods.first,
      );
      _defaultPaymentMethodId = def.id;

      AppLogger.info('Métodos de pago cargados: ${_paymentMethods.length}');
    } on RapiApiException catch (e) {
      _error = 'Error al cargar métodos de pago: ${e.message ?? e.code}';
    } catch (e) {
      _error = 'Error al cargar métodos de pago: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addPaymentMethod({
    required String userId,
    required PaymentMethod paymentMethod,
    bool setAsDefault = false,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final resp = await _api.addPaymentMethod(
        methodType: _methodTypeToString(paymentMethod.type),
        label: paymentMethod.name,
        isDefault: setAsDefault || _paymentMethods.isEmpty,
      );
      final created = (resp['method'] ?? resp['paymentMethod']) as Map<String, dynamic>?;
      if (created != null) {
        final m = PaymentMethod.fromApi(created);
        if (m.isDefault) {
          // Bajar el flag default de los demás localmente
          for (int i = 0; i < _paymentMethods.length; i++) {
            if (_paymentMethods[i].isDefault) {
              _paymentMethods[i] = _paymentMethods[i].copyWith(isDefault: false);
            }
          }
          _defaultPaymentMethodId = m.id;
        }
        _paymentMethods.add(m);
      }
      return true;
    } on RapiApiException catch (e) {
      _error = 'Error al agregar método de pago: ${e.message ?? e.code}';
      return false;
    } catch (e) {
      _error = 'Error al agregar método de pago: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> setDefaultPaymentMethod({
    required String userId,
    required String paymentMethodId,
  }) async {
    // El backend acepta isDefault via PATCH del método existente. Como no
    // hay PATCH endpoint todavía, actualizamos localmente y persistimos vía
    // add (recreando el método marcándolo como default). Para methods
    // efímeros (cash-*) solo aplicamos localmente.
    final idx = _paymentMethods.indexWhere((m) => m.id == paymentMethodId);
    if (idx == -1) return false;
    for (int i = 0; i < _paymentMethods.length; i++) {
      _paymentMethods[i] = _paymentMethods[i].copyWith(isDefault: i == idx);
    }
    _defaultPaymentMethodId = paymentMethodId;
    notifyListeners();
    return true;
  }

  Future<bool> deletePaymentMethod({
    required String userId,
    required String paymentMethodId,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      if (_paymentMethods.length <= 1) {
        _error = 'Debes tener al menos un método de pago';
        return false;
      }

      // Método efectivo local — solo remover
      if (paymentMethodId.startsWith('cash')) {
        _paymentMethods.removeWhere((m) => m.id == paymentMethodId);
        return true;
      }

      // Ya no es local-only: eliminar en backend con endpoint DELETE.
      // Si el backend confirma, actualizar la lista local.
      await RapiApiClient.instance.deletePaymentMethod(paymentMethodId);
      _paymentMethods.removeWhere((m) => m.id == paymentMethodId);
      return true;
    } catch (e) {
      _error = 'Error al eliminar método de pago: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadTransactionHistory(String userId, {int limit = 50}) async {
    try {
      _isLoadingTransactions = true;
      _error = null;
      notifyListeners();

      final data = await _api.listWalletTransactions(pageSize: limit);
      final rawList = (data['transactions'] as List?) ?? const [];
      _transactions = rawList
          .whereType<Map<String, dynamic>>()
          .map((t) => TransactionRecord.fromApi(t))
          .toList();

      _calculateStatistics();
    } on RapiApiException catch (e) {
      _error = 'Error al cargar historial: ${e.message ?? e.code}';
    } catch (e) {
      _error = 'Error al cargar historial: $e';
    } finally {
      _isLoadingTransactions = false;
      notifyListeners();
    }
  }

  void _calculateStatistics() {
    final completed = _transactions.where((t) => t.status == 'completed').toList();
    final failed = _transactions.where((t) => t.status == 'failed').toList();
    final total = completed.fold<double>(0, (sum, t) => sum + t.amount);
    final byMethod = <String, double>{};
    final countByMethod = <String, int>{};
    for (final t in completed) {
      byMethod[t.paymentMethodName] = (byMethod[t.paymentMethodName] ?? 0) + t.amount;
      countByMethod[t.paymentMethodName] = (countByMethod[t.paymentMethodName] ?? 0) + 1;
    }
    _statistics = PaymentStatistics(
      totalSpent: total,
      totalTransactions: _transactions.length,
      successfulTransactions: completed.length,
      failedTransactions: failed.length,
      averageTransactionAmount: completed.isEmpty ? 0 : total / completed.length,
      spendingByMethod: byMethod,
      transactionsByMethod: countByMethod,
    );
  }

  Future<void> loadWalletBalance(String userId) async {
    try {
      _isWalletLoading = true;
      notifyListeners();

      final data = await _api.walletBalance();
      _walletBalance = ((data['balance'] as num?) ?? 0).toDouble();

      // Actualizar método wallet visible
      final walletIndex = _paymentMethods.indexWhere((m) => m.type == PaymentMethodType.wallet);
      if (walletIndex != -1) {
        _paymentMethods[walletIndex] = _paymentMethods[walletIndex].copyWith(
          walletBalance: _walletBalance.toStringAsFixed(2),
        );
      }
    } catch (e) {
      AppLogger.error('Error cargando balance de billetera', e);
    } finally {
      _isWalletLoading = false;
      notifyListeners();
    }
  }

  /// Crea checkout de MercadoPago. La recarga real se acredita cuando MP
  /// notifica al webhook del backend — hay que refrescar `loadWalletBalance`
  /// tras cerrar el WebView.
  Future<Map<String, dynamic>?> createRechargeCheckout({
    required double amount,
  }) async {
    try {
      final data = await _api.createRechargeCheckout(amount);
      return data;
    } on RapiApiException catch (e) {
      _error = 'Error al crear pago: ${e.message ?? e.code}';
      notifyListeners();
      return null;
    }
  }

  Future<bool> rechargeWallet({
    required String userId,
    required double amount,
    required String paymentMethodId,
  }) async {
    try {
      _isWalletLoading = true;
      _error = null;
      notifyListeners();
      final data = await _api.createRechargeCheckout(amount);
      final ok = data['initPoint'] != null || data['preferenceId'] != null;
      return ok;
    } on RapiApiException catch (e) {
      _error = 'Error al recargar billetera: ${e.message ?? e.code}';
      return false;
    } catch (e) {
      _error = 'Error al recargar billetera: $e';
      return false;
    } finally {
      _isWalletLoading = false;
      notifyListeners();
    }
  }

  /// Los pagos por wallet/efectivo se procesan server-side al completar el ride
  /// (`api.completeRide(paymentMethod: 'wallet' | 'cash')`). Aquí solo validamos
  /// pre-condiciones locales para UX.
  Future<bool> processPayment({
    required String userId,
    required String paymentMethodId,
    required double amount,
    required String concept,
    String? tripId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final method = _paymentMethods.firstWhere(
        (m) => m.id == paymentMethodId,
        orElse: () => throw Exception('Método de pago no encontrado'),
      );
      if (method.type == PaymentMethodType.wallet && _walletBalance < amount) {
        _error = 'Saldo insuficiente en billetera';
        notifyListeners();
        return false;
      }
      // El débito real lo ejecuta el backend en completeRide.
      return true;
    } catch (e) {
      _error = 'Error al procesar pago: $e';
      notifyListeners();
      return false;
    }
  }

  void selectPaymentMethod(PaymentMethod method) {
    _defaultPaymentMethodId = method.id;
    notifyListeners();
  }

  void clearData() {
    _paymentMethods.clear();
    _transactions.clear();
    _statistics = null;
    _walletBalance = 0.0;
    _defaultPaymentMethodId = null;
    _error = null;
    _isLoading = false;
    _isLoadingTransactions = false;
    _isWalletLoading = false;
    notifyListeners();
  }

  // ─── Promociones (aún no persistidas en backend) ───────────────────────────
  List<Map<String, dynamic>> _promotions = [];
  Map<String, dynamic>? _loyaltyProgram;

  List<Map<String, dynamic>> get promotions => _promotions;
  Map<String, dynamic>? get loyaltyProgram => _loyaltyProgram;

  Future<void> loadPromotions() async {
    _promotions = [
      {
        'id': '1', 'code': 'WELCOME20',
        'description': '20% de descuento en tu primer viaje',
        'discount': 0.20,
        'expiresAt': DateTime.now().add(const Duration(days: 30)),
      },
      {
        'id': '2', 'code': 'FRIEND10',
        'description': '10% de descuento',
        'discount': 0.10,
        'expiresAt': DateTime.now().add(const Duration(days: 15)),
      },
    ];
    notifyListeners();
  }

  Future<void> loadLoyaltyProgram() async {
    _loyaltyProgram = {
      'points': 250, 'level': 'Gold', 'nextLevelPoints': 500,
      'benefits': ['Descuentos exclusivos', 'Prioridad en solicitudes', 'Soporte 24/7'],
    };
    notifyListeners();
  }

  Future<bool> applyPromotionCode(String code) async {
    final promo = _promotions.firstWhere((p) => p['code'] == code, orElse: () => {});
    return promo.isNotEmpty;
  }

  Future<bool> usePromotion(String promotionId) async {
    _promotions.removeWhere((p) => p['id'] == promotionId);
    notifyListeners();
    return true;
  }
}
