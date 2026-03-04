import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../utils/logger.dart';

enum CardType { visa, mastercard, amex, discover, other }
enum PaymentMethodType { card, cash, wallet, paypal }

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

  // Getter para displayName
  String get displayName {
    if (type == PaymentMethodType.card ) {
      return '$name •••• ${cardNumber!.substring(cardNumber!.length - 4)}';
    }
    return name;
  }
  
  // Getter para color
  Color get color => Color(int.parse(colorHex.replaceAll('#', '0xFF')));

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'type': type.toString(),
      'name': name,
      'cardNumber': cardNumber,
      'cardHolder': cardHolder,
      'expiryDate': expiryDate,
      'cardType': cardType?.toString(),
      'isDefault': isDefault,
      'walletBalance': walletBalance,
      'iconName': iconName,
      'colorHex': colorHex,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'isActive': isActive,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
  }

  static PaymentMethod fromFirestore(Map<String, dynamic> data) {
    return PaymentMethod(
      id: data['id'] ?? '',
      type: PaymentMethodType.values.firstWhere(
        (e) => e.toString() == data['type'],
        orElse: () => PaymentMethodType.cash,
      ),
      name: data['name'] ?? '',
      cardNumber: data['cardNumber'],
      cardHolder: data['cardHolder'],
      expiryDate: data['expiryDate'],
      cardType: data['cardType'] != null
          ? CardType.values.firstWhere(
              (e) => e.toString() == data['cardType'],
              orElse: () => CardType.other,
            )
          : null,
      isDefault: data['isDefault'] ?? false,
      walletBalance: data['walletBalance']?.toString(),
      iconName: data['iconName'] ?? 'credit_card',
      colorHex: data['colorHex'] ?? '#2196F3',
      createdAt: data['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['createdAt'])
          : null,
      isActive: data['isActive'] ?? true,
    );
  }

  PaymentMethod copyWith({
    String? id,
    PaymentMethodType? type,
    String? name,
    String? cardNumber,
    String? cardHolder,
    String? expiryDate,
    CardType? cardType,
    bool? isDefault,
    String? walletBalance,
    String? iconName,
    String? colorHex,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return PaymentMethod(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      cardNumber: cardNumber ?? this.cardNumber,
      cardHolder: cardHolder ?? this.cardHolder,
      expiryDate: expiryDate ?? this.expiryDate,
      cardType: cardType ?? this.cardType,
      isDefault: isDefault ?? this.isDefault,
      walletBalance: walletBalance ?? this.walletBalance,
      iconName: iconName ?? this.iconName,
      colorHex: colorHex ?? this.colorHex,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }
}

class TransactionRecord {
  final String id;
  final String userId;
  final String? tripId;
  final double amount;
  final String paymentMethodId;
  final String paymentMethodName;
  final String status; // 'completed', 'failed', 'pending', 'refunded'
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

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'userId': userId,
      'tripId': tripId,
      'amount': amount,
      'paymentMethodId': paymentMethodId,
      'paymentMethodName': paymentMethodName,
      'status': status,
      'failureReason': failureReason,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'metadata': metadata,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
  }

  static TransactionRecord fromFirestore(Map<String, dynamic> data) {
    return TransactionRecord(
      id: data['id'] ?? '',
      userId: data['userId'] ?? '',
      tripId: data['tripId'],
      amount: (data['amount'] ?? 0.0).toDouble(),
      paymentMethodId: data['paymentMethodId'] ?? '',
      paymentMethodName: data['paymentMethodName'] ?? '',
      status: data['status'] ?? 'pending',
      failureReason: data['failureReason'],
      createdAt: data['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['createdAt'])
          : DateTime.now(),
      metadata: data['metadata'] != null 
          ? Map<String, dynamic>.from(data['metadata'])
          : null,
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

class PaymentProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  
  // Estado de carga
  bool _isLoading = false;
  bool _isLoadingTransactions = false;
  String? _error;

  // Métodos de pago
  List<PaymentMethod> _paymentMethods = [];
  String? _defaultPaymentMethodId;

  // Transacciones
  List<TransactionRecord> _transactions = [];
  PaymentStatistics? _statistics;

  // Billetera
  double _walletBalance = 0.0;
  bool _isWalletLoading = false;

  // Getters
  bool get isLoading => _isLoading;
  bool get isLoadingTransactions => _isLoadingTransactions;
  bool get isWalletLoading => _isWalletLoading;
  String? get error => _error;
  
  List<PaymentMethod> get paymentMethods => List.unmodifiable(_paymentMethods);
  List<PaymentMethod> get activePaymentMethods => 
      _paymentMethods.where((method) => method.isActive == true).toList();
  PaymentMethod? get selectedPaymentMethod => _defaultPaymentMethodId != null
      ? _paymentMethods.firstWhere((m) => m.id == _defaultPaymentMethodId, orElse: () => _paymentMethods.first)
      : _paymentMethods.isNotEmpty ? _paymentMethods.first : null;
  
  PaymentMethod? get defaultPaymentMethod => _paymentMethods.firstWhere(
    (method) => method.isDefault == true && method.isActive == true,
    orElse: () => _paymentMethods.isNotEmpty ? _paymentMethods.first : 
        PaymentMethod(
          id: 'cash',
          type: PaymentMethodType.cash,
          name: 'Efectivo',
          isDefault: true,
          iconName: 'money',
          colorHex: '#4CAF50',
        ),
  );
  
  List<TransactionRecord> get transactions => List.unmodifiable(_transactions);
  List<TransactionRecord> get successfulTransactions =>
      _transactions.where((t) => t.status == 'completed').toList();
  
  PaymentStatistics? get statistics => _statistics;
  double get walletBalance => _walletBalance;

  // Limpiar error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Cargar métodos de pago
  Future<void> loadPaymentMethods(String userId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      AppLogger.info('Cargando métodos de pago para usuario: $userId');

      final snapshot = await _firebaseService.firestore
          .collection('users')
          .doc(userId)
          .collection('paymentMethods')
          .where('isActive', isEqualTo: true)
          .orderBy('isDefault', descending: true)
          .orderBy('createdAt', descending: false)
          .get();

      _paymentMethods = snapshot.docs
          .map((doc) => PaymentMethod.fromFirestore(doc.data()))
          .toList();

      // Asegurar método por defecto (efectivo)
      if (_paymentMethods.isEmpty || !_paymentMethods.any((m) => m.isDefault)) {
        await _addDefaultCashMethod(userId);
      }

      AppLogger.info('Métodos de pago cargados: ${_paymentMethods.length}');

    } catch (e) {
      _error = 'Error al cargar métodos de pago: $e';
      AppLogger.error('Error cargando métodos de pago', e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Agregar método por defecto (efectivo)
  Future<void> _addDefaultCashMethod(String userId) async {
    final cashMethod = PaymentMethod(
      id: 'cash_${DateTime.now().millisecondsSinceEpoch}',
      type: PaymentMethodType.cash,
      name: 'Efectivo',
      isDefault: true,
      iconName: 'money',
      colorHex: '#4CAF50',
      createdAt: DateTime.now(),
    );

    await _firebaseService.firestore
        .collection('users')
        .doc(userId)
        .collection('paymentMethods')
        .doc(cashMethod.id)
        .set(cashMethod.toFirestore());

    _paymentMethods.add(cashMethod);
    _defaultPaymentMethodId = cashMethod.id;
  }

  // Agregar método de pago
  Future<bool> addPaymentMethod({
    required String userId,
    required PaymentMethod paymentMethod,
    bool setAsDefault = false,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      AppLogger.info('Agregando método de pago: ${paymentMethod.name}');

      // Si es el primer método o se marca como predeterminado
      if (setAsDefault || _paymentMethods.isEmpty) {
        // Desmarcar método actual como predeterminado
        if (_defaultPaymentMethodId != null) {
          await _updateDefaultStatus(userId, _defaultPaymentMethodId!, false);
        }
        _defaultPaymentMethodId = paymentMethod.id;
      }

      final methodToAdd = paymentMethod.copyWith(
        isDefault: setAsDefault || _paymentMethods.isEmpty,
        createdAt: DateTime.now(),
      );

      await _firebaseService.firestore
          .collection('users')
          .doc(userId)
          .collection('paymentMethods')
          .doc(methodToAdd.id)
          .set(methodToAdd.toFirestore());

      _paymentMethods.add(methodToAdd);
      
      AppLogger.info('Método de pago agregado exitosamente');
      return true;

    } catch (e) {
      _error = 'Error al agregar método de pago: $e';
      AppLogger.error('Error agregando método de pago', e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Establecer método predeterminado
  Future<bool> setDefaultPaymentMethod({
    required String userId,
    required String paymentMethodId,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      AppLogger.info('Estableciendo método predeterminado: $paymentMethodId');

      // Desmarcar método actual
      if ( _defaultPaymentMethodId != paymentMethodId) {
        await _updateDefaultStatus(userId, _defaultPaymentMethodId!, false);
        
        // Actualizar en lista local
        final oldIndex = _paymentMethods.indexWhere((m) => m.id == _defaultPaymentMethodId);
        if (oldIndex != -1) {
          _paymentMethods[oldIndex] = _paymentMethods[oldIndex].copyWith(isDefault: false);
        }
      }

      // Marcar nuevo método como predeterminado
      await _updateDefaultStatus(userId, paymentMethodId, true);
      
      // Actualizar en lista local
      final newIndex = _paymentMethods.indexWhere((m) => m.id == paymentMethodId);
      if (newIndex != -1) {
        _paymentMethods[newIndex] = _paymentMethods[newIndex].copyWith(isDefault: true);
      }

      _defaultPaymentMethodId = paymentMethodId;
      
      AppLogger.info('Método predeterminado actualizado');
      return true;

    } catch (e) {
      _error = 'Error al establecer método predeterminado: $e';
      AppLogger.error('Error estableciendo método predeterminado', e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Actualizar estado predeterminado en Firebase
  Future<void> _updateDefaultStatus(String userId, String paymentMethodId, bool isDefault) async {
    await _firebaseService.firestore
        .collection('users')
        .doc(userId)
        .collection('paymentMethods')
        .doc(paymentMethodId)
        .update({
          'isDefault': isDefault,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });
  }

  // Eliminar método de pago
  Future<bool> deletePaymentMethod({
    required String userId,
    required String paymentMethodId,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      AppLogger.info('Eliminando método de pago: $paymentMethodId');

      // No permitir eliminar si es el único método
      if (_paymentMethods.length <= 1) {
        _error = 'Debes tener al menos un método de pago';
        return false;
      }

      // Marcar como inactivo en lugar de eliminar
      await _firebaseService.firestore
          .collection('users')
          .doc(userId)
          .collection('paymentMethods')
          .doc(paymentMethodId)
          .update({
            'isActive': false,
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          });

      // Remover de lista local
      final wasDefault = _paymentMethods.any((m) => m.id == paymentMethodId && m.isDefault);
      _paymentMethods.removeWhere((m) => m.id == paymentMethodId);

      // Si era el predeterminado, establecer otro
      if (wasDefault && _paymentMethods.isNotEmpty) {
        await setDefaultPaymentMethod(userId: userId, paymentMethodId: _paymentMethods.first.id);
      }

      AppLogger.info('Método de pago eliminado');
      return true;

    } catch (e) {
      _error = 'Error al eliminar método de pago: $e';
      AppLogger.error('Error eliminando método de pago', e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Cargar historial de transacciones
  Future<void> loadTransactionHistory(String userId, {int limit = 50}) async {
    try {
      _isLoadingTransactions = true;
      _error = null;
      notifyListeners();

      AppLogger.info('Cargando historial de transacciones para usuario: $userId');

      final snapshot = await _firebaseService.firestore
          .collection('transactions')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      _transactions = snapshot.docs
          .map((doc) => TransactionRecord.fromFirestore(doc.data()))
          .toList();

      // Calcular estadísticas
      _calculateStatistics();

      AppLogger.info('Transacciones cargadas: ${_transactions.length}');

    } catch (e) {
      _error = 'Error al cargar historial: $e';
      AppLogger.error('Error cargando transacciones', e);
    } finally {
      _isLoadingTransactions = false;
      notifyListeners();
    }
  }

  // Calcular estadísticas
  void _calculateStatistics() {
    if (_transactions.isEmpty) {
      _statistics = PaymentStatistics(
        totalSpent: 0,
        totalTransactions: 0,
        successfulTransactions: 0,
        failedTransactions: 0,
        averageTransactionAmount: 0,
        spendingByMethod: {},
        transactionsByMethod: {},
      );
      return;
    }

    final successful = _transactions.where((t) => t.status == 'completed').toList();
    final failed = _transactions.where((t) => t.status == 'failed').toList();
    
    final totalSpent = successful.fold<double>(0, (sum, t) => sum + t.amount);
    final spendingByMethod = <String, double>{};
    final transactionsByMethod = <String, int>{};

    for (final transaction in successful) {
      spendingByMethod[transaction.paymentMethodName] = 
          (spendingByMethod[transaction.paymentMethodName] ?? 0) + transaction.amount;
      transactionsByMethod[transaction.paymentMethodName] = 
          (transactionsByMethod[transaction.paymentMethodName] ?? 0) + 1;
    }

    _statistics = PaymentStatistics(
      totalSpent: totalSpent,
      totalTransactions: _transactions.length,
      successfulTransactions: successful.length,
      failedTransactions: failed.length,
      averageTransactionAmount: successful.isNotEmpty 
          ? totalSpent / successful.length 
          : 0,
      spendingByMethod: spendingByMethod,
      transactionsByMethod: transactionsByMethod,
    );
  }

  // Cargar balance de billetera
  Future<void> loadWalletBalance(String userId) async {
    try {
      _isWalletLoading = true;
      notifyListeners();

      AppLogger.info('Cargando balance de billetera para usuario: $userId');

      final doc = await _firebaseService.firestore
          .collection('users')
          .doc(userId)
          .collection('wallet')
          .doc('balance')
          .get();

      if (doc.exists) {
        _walletBalance = (doc.data()?['amount'] ?? 0.0).toDouble();
      }

      // Actualizar método de billetera si existe
      final walletIndex = _paymentMethods.indexWhere((m) => m.type == PaymentMethodType.wallet);
      if (walletIndex != -1) {
        _paymentMethods[walletIndex] = _paymentMethods[walletIndex].copyWith(
          walletBalance: _walletBalance.toStringAsFixed(2),
        );
      }

      AppLogger.info('Balance de billetera cargado: $_walletBalance');

    } catch (e) {
      AppLogger.error('Error cargando balance de billetera', e);
    } finally {
      _isWalletLoading = false;
      notifyListeners();
    }
  }

  // Recargar billetera
  Future<bool> rechargeWallet({
    required String userId,
    required double amount,
    required String paymentMethodId,
  }) async {
    try {
      _isWalletLoading = true;
      _error = null;
      notifyListeners();

      AppLogger.info('Recargando billetera: $amount para usuario: $userId');

      // Crear transacción de recarga
      final transactionId = 'recharge_${DateTime.now().millisecondsSinceEpoch}';
      final rechargeTransaction = TransactionRecord(
        id: transactionId,
        userId: userId,
        amount: amount,
        paymentMethodId: paymentMethodId,
        paymentMethodName: 'Recarga de Billetera',
        status: 'completed', // En un caso real, esto dependería del procesamiento
        createdAt: DateTime.now(),
        metadata: {'type': 'wallet_recharge'},
      );

      // Guardar transacción
      await _firebaseService.firestore
          .collection('transactions')
          .doc(transactionId)
          .set(rechargeTransaction.toFirestore());

      // Actualizar balance
      _walletBalance += amount;
      
      await _firebaseService.firestore
          .collection('users')
          .doc(userId)
          .collection('wallet')
          .doc('balance')
          .set({
            'amount': _walletBalance,
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          });

      // Actualizar método de billetera local
      final walletIndex = _paymentMethods.indexWhere((m) => m.type == PaymentMethodType.wallet);
      if (walletIndex != -1) {
        _paymentMethods[walletIndex] = _paymentMethods[walletIndex].copyWith(
          walletBalance: _walletBalance.toStringAsFixed(2),
        );
      }

      // Agregar a lista de transacciones
      _transactions.insert(0, rechargeTransaction);
      _calculateStatistics();

      AppLogger.info('Billetera recargada exitosamente');
      return true;

    } catch (e) {
      _error = 'Error al recargar billetera: $e';
      AppLogger.error('Error recargando billetera', e);
      return false;
    } finally {
      _isWalletLoading = false;
      notifyListeners();
    }
  }

  // Procesar pago
  Future<bool> processPayment({
    required String userId,
    required String paymentMethodId,
    required double amount,
    required String concept,
    String? tripId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      AppLogger.info('Procesando pago: $amount para usuario: $userId');

      final paymentMethod = _paymentMethods.firstWhere(
        (m) => m.id == paymentMethodId,
        orElse: () => throw Exception('Método de pago no encontrado'),
      );

      // Verificar balance para billetera
      if (paymentMethod.type == PaymentMethodType.wallet) {
        if (_walletBalance < amount) {
          _error = 'Saldo insuficiente en billetera';
          return false;
        }
      }

      // Crear transacción
      final transactionId = 'payment_${DateTime.now().millisecondsSinceEpoch}';
      final transaction = TransactionRecord(
        id: transactionId,
        userId: userId,
        tripId: tripId,
        amount: amount,
        paymentMethodId: paymentMethodId,
        paymentMethodName: paymentMethod.name,
        status: 'completed', // En producción esto dependería del procesamiento real
        createdAt: DateTime.now(),
        metadata: {
          'concept': concept,
          ...?metadata,
        },
      );

      // Guardar transacción
      await _firebaseService.firestore
          .collection('transactions')
          .doc(transactionId)
          .set(transaction.toFirestore());

      // Si es pago con billetera, descontar balance
      if (paymentMethod.type == PaymentMethodType.wallet) {
        _walletBalance -= amount;
        
        await _firebaseService.firestore
            .collection('users')
            .doc(userId)
            .collection('wallet')
            .doc('balance')
            .set({
              'amount': _walletBalance,
              'updatedAt': DateTime.now().millisecondsSinceEpoch,
            });

        // Actualizar método de billetera local
        final walletIndex = _paymentMethods.indexWhere((m) => m.type == PaymentMethodType.wallet);
        if (walletIndex != -1) {
          _paymentMethods[walletIndex] = _paymentMethods[walletIndex].copyWith(
            walletBalance: _walletBalance.toStringAsFixed(2),
          );
        }
      }

      // Agregar a lista de transacciones
      _transactions.insert(0, transaction);
      _calculateStatistics();

      AppLogger.info('Pago procesado exitosamente');
      return true;

    } catch (e) {
      _error = 'Error al procesar pago: $e';
      AppLogger.error('Error procesando pago', e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Seleccionar método de pago
  void selectPaymentMethod(PaymentMethod method) {
    _defaultPaymentMethodId = method.id;
    notifyListeners();
  }

  // Limpiar datos
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

  // Métodos adicionales para promociones y lealtad
  List<Map<String, dynamic>> _promotions = [];
  Map<String, dynamic>? _loyaltyProgram;
  
  List<Map<String, dynamic>> get promotions => _promotions;
  Map<String, dynamic>? get loyaltyProgram => _loyaltyProgram;
  
  Future<void> loadPromotions() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      // Simulación de carga de promociones
      _promotions = [
        {
          'id': '1',
          'code': 'WELCOME20',
          'description': '20% de descuento en tu primer viaje',
          'discount': 0.20,
          'expiresAt': DateTime.now().add(Duration(days: 30)),
        },
        {
          'id': '2',
          'code': 'FRIEND10',
          'description': '10% de descuento',
          'discount': 0.10,
          'expiresAt': DateTime.now().add(Duration(days: 15)),
        },
      ];
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> loadLoyaltyProgram() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      // Simulación de programa de lealtad
      _loyaltyProgram = {
        'points': 250,
        'level': 'Gold',
        'nextLevelPoints': 500,
        'benefits': [
          'Descuentos exclusivos',
          'Prioridad en solicitudes',
          'Soporte 24/7',
        ],
      };
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<bool> applyPromotionCode(String code) async {
    try {
      // Buscar promoción por código
      final promo = _promotions.firstWhere(
        (p) => p['code'] == code,
        orElse: () => {},
      );
      
      if (promo.isNotEmpty) {
        // Aplicar promoción
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }
  
  Future<bool> usePromotion(String promotionId) async {
    try {
      // Usar promoción
      _promotions.removeWhere((p) => p['id'] == promotionId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }
}