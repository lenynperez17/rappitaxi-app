import 'dart:async'; // Para TimeoutException
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/logger.dart';
import '../services/firebase_service.dart';
import '../services/payment_service.dart';
import '../widgets/mercadopago_checkout_pro_widget.dart';
import '../core/constants/credit_constants.dart';

// Modelo para billetera
class Wallet {
  final String id;
  final String userId;
  final double balance;
  final double pendingBalance;
  final double totalEarnings;
  final double totalWithdrawals;
  final String currency;
  final bool isActive;
  final DateTime lastActivityDate;
  final Map<String, dynamic>? bankAccount;
  // Créditos de servicio para conductores
  final double serviceCredits;
  final double totalCreditsRecharged;
  final double totalCreditsUsed;
  final bool isFirstRecharge;

  Wallet({
    required this.id,
    required this.userId,
    required this.balance,
    required this.pendingBalance,
    required this.totalEarnings,
    required this.totalWithdrawals,
    required this.currency,
    required this.isActive,
    required this.lastActivityDate,
    this.bankAccount,
    this.serviceCredits = 0,
    this.totalCreditsRecharged = 0,
    this.totalCreditsUsed = 0,
    this.isFirstRecharge = true,
  });

  factory Wallet.fromMap(Map<String, dynamic> map, String id) {
    return Wallet(
      id: id,
      userId: map['userId'] ?? '',
      balance: (map['balance'] ?? 0).toDouble(),
      pendingBalance: (map['pendingBalance'] ?? 0).toDouble(),
      totalEarnings: (map['totalEarnings'] ?? 0).toDouble(),
      totalWithdrawals: (map['totalWithdrawals'] ?? 0).toDouble(),
      currency: map['currency'] ?? 'PEN',
      isActive: map['isActive'] ?? true,
      lastActivityDate: (map['lastActivityDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      bankAccount: map['bankAccount'],
      serviceCredits: (map['serviceCredits'] ?? 0).toDouble(),
      totalCreditsRecharged: (map['totalCreditsRecharged'] ?? 0).toDouble(),
      totalCreditsUsed: (map['totalCreditsUsed'] ?? 0).toDouble(),
      isFirstRecharge: map['isFirstRecharge'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'balance': balance,
      'pendingBalance': pendingBalance,
      'totalEarnings': totalEarnings,
      'totalWithdrawals': totalWithdrawals,
      'currency': currency,
      'isActive': isActive,
      'lastActivityDate': Timestamp.fromDate(lastActivityDate),
      'bankAccount': bankAccount,
      'serviceCredits': serviceCredits,
      'totalCreditsRecharged': totalCreditsRecharged,
      'totalCreditsUsed': totalCreditsUsed,
      'isFirstRecharge': isFirstRecharge,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // Verificar si tiene créditos suficientes para aceptar un servicio
  bool hasEnoughCredits(double serviceFee, double minRequired) {
    return serviceCredits >= serviceFee && serviceCredits >= minRequired;
  }
}

// Modelo para transacción de billetera
class WalletTransaction {
  final String id;
  final String walletId;
  final String type; // 'earning', 'withdrawal', 'commission', 'bonus', 'penalty'
  final double amount;
  final double balanceBefore;
  final double balanceAfter;
  final String status; // 'pending', 'processing', 'completed', 'failed', 'cancelled'
  final String? tripId;
  final String? description;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime? processedAt;

  WalletTransaction({
    required this.id,
    required this.walletId,
    required this.type,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.status,
    this.tripId,
    this.description,
    this.metadata,
    required this.createdAt,
    this.processedAt,
  });

  factory WalletTransaction.fromMap(Map<String, dynamic> map, String id) {
    return WalletTransaction(
      id: id,
      walletId: map['walletId'] ?? '',
      type: map['type'] ?? 'earning',
      amount: (map['amount'] ?? 0).toDouble(),
      balanceBefore: (map['balanceBefore'] ?? 0).toDouble(),
      balanceAfter: (map['balanceAfter'] ?? 0).toDouble(),
      status: map['status'] ?? 'pending',
      tripId: map['tripId'],
      description: map['description'],
      metadata: map['metadata'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      processedAt: (map['processedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'walletId': walletId,
      'type': type,
      'amount': amount,
      'balanceBefore': balanceBefore,
      'balanceAfter': balanceAfter,
      'status': status,
      'tripId': tripId,
      'description': description,
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
      'processedAt': processedAt != null ? Timestamp.fromDate(processedAt!) : null,
    };
  }
}

// Modelo para solicitud de retiro
class WithdrawalRequest {
  final String id;
  final String walletId;
  final double amount;
  final String status; // 'pending', 'approved', 'processing', 'completed', 'rejected'
  final String? bankAccountId;
  final Map<String, dynamic>? bankDetails;
  final String? rejectionReason;
  final DateTime requestedAt;
  final DateTime? approvedAt;
  final DateTime? completedAt;

  WithdrawalRequest({
    required this.id,
    required this.walletId,
    required this.amount,
    required this.status,
    this.bankAccountId,
    this.bankDetails,
    this.rejectionReason,
    required this.requestedAt,
    this.approvedAt,
    this.completedAt,
  });

  factory WithdrawalRequest.fromMap(Map<String, dynamic> map, String id) {
    return WithdrawalRequest(
      id: id,
      walletId: map['walletId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      status: map['status'] ?? 'pending',
      bankAccountId: map['bankAccountId'],
      bankDetails: map['bankDetails'],
      rejectionReason: map['rejectionReason'],
      requestedAt: (map['requestedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      approvedAt: (map['approvedAt'] as Timestamp?)?.toDate(),
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
    );
  }
}

class WalletProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseService().firestore;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Estado
  Wallet? _wallet;
  List<WalletTransaction> _transactions = [];
  List<WithdrawalRequest> _withdrawalRequests = [];
  Map<String, double> _earnings = {
    'today': 0,
    'week': 0,
    'month': 0,
    'total': 0,
  };
  bool _isLoading = false;
  String? _error;
  
  // Campos adicionales para retiros
  List<Map<String, dynamic>> _withdrawalHistory = [];
  final double _totalWithdrawn = 0.0;
  double _pendingWithdrawals = 0.0;
  
  // Streams
  Stream<DocumentSnapshot>? _walletStream;
  Stream<QuerySnapshot>? _transactionsStream;
  Stream<QuerySnapshot>? _withdrawalsStream;

  // Subscriptions para evitar memory leaks
  StreamSubscription<DocumentSnapshot>? _walletSubscription;
  StreamSubscription<QuerySnapshot>? _transactionsSubscription;
  StreamSubscription<QuerySnapshot>? _withdrawalsSubscription;

  // Getters
  Wallet? get wallet => _wallet;
  List<WalletTransaction> get transactions => _transactions;
  List<WithdrawalRequest> get withdrawalRequests => _withdrawalRequests;
  Map<String, double> get earnings => _earnings;
  bool get isLoading => _isLoading;
  String? get error => _error;
  double get availableBalance => (_wallet?.balance ?? 0.0) - (_wallet?.pendingBalance ?? 0.0);

  // Getters de créditos de servicio
  double get serviceCredits => _wallet?.serviceCredits ?? 0.0;
  double get totalCreditsRecharged => _wallet?.totalCreditsRecharged ?? 0.0;
  double get totalCreditsUsed => _wallet?.totalCreditsUsed ?? 0.0;
  bool get isFirstRecharge => _wallet?.isFirstRecharge ?? true;

  WalletProvider() {
    _initializeWallet();
  }

  // Inicializar billetera
  Future<void> _initializeWallet() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Stream de billetera
    _walletStream = _firestore
        .collection('wallets')
        .doc(user.uid)
        .snapshots();

    _walletSubscription = _walletStream?.handleError((error) {
      // Error en stream de wallet
    }).listen((snapshot) async {
      if (snapshot.exists) {
        _wallet = Wallet.fromMap(snapshot.data() as Map<String, dynamic>? ?? {}, snapshot.id);
      } else {
        // Crear billetera si no existe
        await _createWallet();
      }

      await _calculateEarnings();
      notifyListeners();
    });

    // Stream de transacciones
    _transactionsStream = _firestore
        .collection('walletTransactions')
        .where('walletId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .handleError((error) {
          // Error en stream de walletTransactions (ej: índice creándose)
        });

    _transactionsSubscription = _transactionsStream?.listen((snapshot) {
      _transactions = snapshot.docs
          .map((doc) => WalletTransaction.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      notifyListeners();
    });

    // Stream de solicitudes de retiro
    _withdrawalsStream = _firestore
        .collection('withdrawalRequests')
        .where('walletId', isEqualTo: user.uid)
        .orderBy('requestedAt', descending: true)
        .limit(20)
        .snapshots()
        .handleError((error) {
          // Error en stream de withdrawalRequests
        });

    _withdrawalsSubscription = _withdrawalsStream?.listen((snapshot) {
      _withdrawalRequests = snapshot.docs
          .map((doc) => WithdrawalRequest.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      notifyListeners();
    });
  }

  // Crear billetera nueva
  Future<void> _createWallet() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final wallet = Wallet(
        id: user.uid,
        userId: user.uid,
        balance: 0,
        pendingBalance: 0,
        totalEarnings: 0,
        totalWithdrawals: 0,
        currency: 'PEN',
        isActive: true,
        lastActivityDate: DateTime.now(),
      );

      await _firestore
          .collection('wallets')
          .doc(user.uid)
          .set({
        ...wallet.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      _wallet = wallet;
    } catch (e) {
      AppLogger.error('Error creando billetera', e);
    }
  }

  // Calcular ganancias por período
  Future<void> _calculateEarnings() async {
    if (_wallet == null) return;

    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final monthStart = DateTime(now.year, now.month, 1);

      // Ganancias de hoy
      final todayEarnings = await _getEarningsByPeriod(todayStart, now);
      
      // Ganancias de la semana
      final weekEarnings = await _getEarningsByPeriod(weekStart, now);
      
      // Ganancias del mes
      final monthEarnings = await _getEarningsByPeriod(monthStart, now);

      _earnings = {
        'today': todayEarnings,
        'week': weekEarnings,
        'month': monthEarnings,
        'total': _wallet!.totalEarnings,
      };

      notifyListeners();
    } catch (e) {
      AppLogger.error('Error calculando ganancias', e);
    }
  }

  // Obtener ganancias por período
  Future<double> _getEarningsByPeriod(DateTime start, DateTime end) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 0;

      final query = await _firestore
          .collection('walletTransactions')
          .where('walletId', isEqualTo: user.uid)
          .where('type', isEqualTo: 'earning')
          .where('status', isEqualTo: 'completed')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      double total = 0;
      for (var doc in query.docs) {
        total += (doc.data()['amount'] ?? 0).toDouble();
      }

      return total;
    } catch (e) {
      AppLogger.error('Error obteniendo ganancias por período', e);
      return 0;
    }
  }

  // Agregar ganancia por viaje
  Future<bool> addTripEarning({
    required String tripId,
    required double amount,
    required double commission,
    String? description,
  }) async {
    _setLoading(true);
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      if (_wallet == null) {
        await _createWallet();
      }

      final netEarning = amount - commission;
      final balanceBefore = _wallet!.balance;
      final balanceAfter = balanceBefore + netEarning;

      // Crear transacción
      final transaction = WalletTransaction(
        id: '',
        walletId: user.uid,
        type: 'earning',
        amount: netEarning,
        balanceBefore: balanceBefore,
        balanceAfter: balanceAfter,
        status: 'completed',
        tripId: tripId,
        description: description ?? 'Ganancia por viaje',
        metadata: {
          'grossAmount': amount,
          'commission': commission,
          'commissionRate': (commission / amount * 100).toStringAsFixed(2),
        },
        createdAt: DateTime.now(),
        processedAt: DateTime.now(),
      );

      // Guardar transacción
      await _firestore
          .collection('walletTransactions')
          .add(transaction.toMap());

      // Actualizar billetera
      await _firestore
          .collection('wallets')
          .doc(user.uid)
          .update({
        'balance': FieldValue.increment(netEarning),
        'totalEarnings': FieldValue.increment(netEarning),
        'lastActivityDate': FieldValue.serverTimestamp(),
      });

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Error al agregar ganancia: $e');
      _setLoading(false);
      return false;
    }
  }

  // Solicitar retiro
  Future<bool> requestWithdrawal({
    required double amount,
    required Map<String, dynamic> bankDetails,
  }) async {
    _setLoading(true);
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      if (_wallet == null) throw Exception('Billetera no encontrada');

      // Validar monto
      if (amount > availableBalance) {
        throw Exception('Monto excede el balance disponible');
      }

      if (amount < 50) {
        throw Exception('El monto mínimo de retiro es S/. 50.00');
      }

      // Crear solicitud de retiro
      final withdrawal = {
        'walletId': user.uid,
        'amount': amount,
        'status': 'pending',
        'bankDetails': bankDetails,
        'requestedAt': FieldValue.serverTimestamp(),
        'metadata': {
          'balanceAtRequest': _wallet!.balance,
          'currency': 'PEN',
        },
      };

      final docRef = await _firestore
          .collection('withdrawalRequests')
          .add(withdrawal);

      // Actualizar balance pendiente
      await _firestore
          .collection('wallets')
          .doc(user.uid)
          .update({
        'pendingBalance': FieldValue.increment(amount),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Crear transacción pendiente
      final transaction = WalletTransaction(
        id: '',
        walletId: user.uid,
        type: 'withdrawal',
        amount: amount,
        balanceBefore: _wallet!.balance,
        balanceAfter: _wallet!.balance,
        status: 'pending',
        description: 'Solicitud de retiro',
        metadata: {
          'withdrawalRequestId': docRef.id,
          'bankDetails': bankDetails,
        },
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('walletTransactions')
          .add(transaction.toMap());

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Error al solicitar retiro: $e');
      _setLoading(false);
      return false;
    }
  }

  // Cancelar solicitud de retiro
  Future<bool> cancelWithdrawal(String withdrawalId) async {
    _setLoading(true);
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      // Obtener solicitud
      final withdrawalDoc = await _firestore
          .collection('withdrawalRequests')
          .doc(withdrawalId)
          .get();

      if (!withdrawalDoc.exists) {
        throw Exception('Solicitud no encontrada');
      }

      final withdrawal = WithdrawalRequest.fromMap(withdrawalDoc.data()!, withdrawalId);

      if (withdrawal.status != 'pending') {
        throw Exception('Solo se pueden cancelar solicitudes pendientes');
      }

      // Actualizar solicitud
      await _firestore
          .collection('withdrawalRequests')
          .doc(withdrawalId)
          .update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      // Liberar balance pendiente
      await _firestore
          .collection('wallets')
          .doc(user.uid)
          .update({
        'pendingBalance': FieldValue.increment(-withdrawal.amount),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Error al cancelar retiro: $e');
      _setLoading(false);
      return false;
    }
  }

  // Agregar cuenta bancaria
  Future<bool> addBankAccount(Map<String, dynamic> bankAccount) async {
    _setLoading(true);
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      await _firestore
          .collection('wallets')
          .doc(user.uid)
          .update({
        'bankAccount': bankAccount,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Error al agregar cuenta bancaria: $e');
      _setLoading(false);
      return false;
    }
  }

  // Obtener estadísticas
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {};

      final now = DateTime.now();
      final lastMonth = now.subtract(const Duration(days: 30));

      // Obtener todas las transacciones del último mes
      final query = await _firestore
          .collection('walletTransactions')
          .where('walletId', isEqualTo: user.uid)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(lastMonth))
          .get();

      int totalTrips = 0;
      double totalEarnings = 0;
      double totalCommissions = 0;
      double totalWithdrawals = 0;

      for (var doc in query.docs) {
        final data = doc.data();
        final type = data['type'];
        final amount = (data['amount'] ?? 0).toDouble();

        if (type == 'earning') {
          totalTrips++;
          totalEarnings += amount;
          totalCommissions += (data['metadata']?['commission'] ?? 0).toDouble();
        } else if (type == 'withdrawal' && data['status'] == 'completed') {
          totalWithdrawals += amount;
        }
      }

      return {
        'totalTrips': totalTrips,
        'totalEarnings': totalEarnings,
        'totalCommissions': totalCommissions,
        'totalWithdrawals': totalWithdrawals,
        'averagePerTrip': totalTrips > 0 ? totalEarnings / totalTrips : 0,
      };
    } catch (e) {
      AppLogger.error('Error obteniendo estadísticas', e);
      return {};
    }
  }

  // Helpers
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    if (error != null) {
      AppLogger.error(error, null);
    }
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Cargar historial de retiros
  Future<void> loadWithdrawalHistory(String userId) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      final snapshot = await FirebaseFirestore.instance
          .collection('withdrawals')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();
      
      _withdrawalHistory = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
      
    } catch (e) {
      AppLogger.error('Error cargando historial de retiros', e);
      _error = 'Error al cargar historial';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Procesar retiro
  Future<bool> processWithdrawal({
    required String userId,
    required double amount,
    required String method,
    required Map<String, dynamic> accountDetails,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      // Verificar saldo disponible
      if (amount > availableBalance) {
        throw Exception('Saldo insuficiente');
      }
      
      // Crear documento de retiro
      await FirebaseFirestore.instance.collection('withdrawals').add({
        'userId': userId,
        'amount': amount,
        'method': method,
        'accountDetails': accountDetails,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Actualizar saldo pendiente de retiro
      _pendingWithdrawals += amount;
      
      // Actualizar en Firestore
      await FirebaseFirestore.instance
          .collection('wallets')
          .doc(userId)
          .update({
        'pendingBalance': FieldValue.increment(amount),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      return true;
    } catch (e) {
      AppLogger.error('Error procesando retiro', e);
      _error = 'Error al procesar retiro: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Getters adicionales
  List<Map<String, dynamic>> get withdrawalHistory => _withdrawalHistory;
  double get totalWithdrawn => _totalWithdrawn;
  double get pendingWithdrawals => _pendingWithdrawals;

  // ============ SISTEMA DE CRÉDITOS PARA CONDUCTORES ============

  /// Verificar si el conductor tiene créditos suficientes para aceptar un servicio
  Future<bool> hasEnoughCreditsForService() async {
    try {
      // Reutilizar getCreditConfig() que ya tiene timeout y fallback a defaults
      final config = await getCreditConfig();
      final serviceFee = (config['serviceFee'] as num).toDouble();
      final minCredits = (config['minServiceCredits'] as num).toDouble();

      // Si wallet aún no cargó del stream, leer directamente de Firestore
      double credits = serviceCredits;
      if (credits <= 0) {
        final user = _auth.currentUser;
        if (user != null) {
          try {
            final walletDoc = await _firestore
                .collection('wallets').doc(user.uid).get()
                .timeout(const Duration(seconds: 10));
            if (walletDoc.exists) {
              credits = (walletDoc.data()?['serviceCredits'] ?? 0.0).toDouble();
            }
          } catch (walletError) {
            AppLogger.warning('No se pudo leer wallet directamente: $walletError');
          }
        }
      }

      final hasEnough = credits >= serviceFee && credits >= minCredits;
      if (!hasEnough) {
        AppLogger.warning('Créditos insuficientes: S/. $credits (necesita >= S/. $serviceFee y >= S/. $minCredits)');
      }
      return hasEnough;
    } catch (e) {
      AppLogger.error('Error verificando créditos: $e');
      // En caso de error, permitir y dejar que consumeCreditsForService() valide
      return true;
    }
  }

  /// Obtener configuración de créditos desde Firestore
  Future<Map<String, dynamic>> getCreditConfig() async {
    try {
      // ✅ FIX: Agregar timeout para evitar congelamiento
      final settingsDoc = await _firestore
          .collection('settings')
          .doc('admin')
          .get()
          .timeout(const Duration(seconds: 15), onTimeout: () {
            throw TimeoutException('Timeout obteniendo config de créditos');
          });

      return {
        'serviceFee': (settingsDoc.data()?['serviceFee'] ?? 1.0).toDouble(),
        'minServiceCredits': (settingsDoc.data()?['minServiceCredits'] ?? CreditConstants.minServiceCredits).toDouble(),
        'bonusCreditsOnFirstRecharge': (settingsDoc.data()?['bonusCreditsOnFirstRecharge'] ?? 5.0).toDouble(),
        'creditPackages': settingsDoc.data()?['creditPackages'] ?? [],
      };
    } on TimeoutException {
      AppLogger.warning('⏱️ Timeout obteniendo config, usando valores por defecto');
      return {
        'serviceFee': 1.0,
        'minServiceCredits': CreditConstants.minServiceCredits,
        'bonusCreditsOnFirstRecharge': 5.0,
        'creditPackages': [],
      };
    } catch (e) {
      AppLogger.error('Error obteniendo config de créditos', e);
      return {
        'serviceFee': 1.0,
        'minServiceCredits': CreditConstants.minServiceCredits,
        'bonusCreditsOnFirstRecharge': 5.0,
        'creditPackages': [],
      };
    }
  }

  /// Consumir créditos al aceptar un servicio
  /// ✅ CORREGIDO: Ahora usa Firestore Transaction para operación ATÓMICA
  /// Si falla cualquier parte, la operación completa se revierte automáticamente
  Future<bool> consumeCreditsForService({
    required String tripId,
    String? negotiationId,
  }) async {
    _setLoading(true);
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      // Obtener costo del servicio
      final config = await getCreditConfig();
      final serviceFee = (config['serviceFee'] as num).toDouble();
      // ignore: unused_local_variable - se usa en código comentado para validación opcional
      final minCredits = CreditConstants.minServiceCredits;

      // ✅ TRANSACTION ATÓMICA: Verificar, descontar y registrar en una sola operación
      await _firestore.runTransaction((transaction) async {
        // 1. Leer wallet actual DENTRO de la transacción
        final walletRef = _firestore.collection('wallets').doc(user.uid);
        final walletDoc = await transaction.get(walletRef);

        if (!walletDoc.exists) {
          throw Exception('Billetera no encontrada');
        }

        final currentCredits = (walletDoc.data()?['serviceCredits'] ?? 0.0).toDouble();

        // 2. Verificar saldo suficiente (dentro de transacción para evitar race condition)
        if (currentCredits < serviceFee) {
          throw Exception('Créditos insuficientes. Tienes S/. ${currentCredits.toStringAsFixed(2)}, necesitas S/. ${serviceFee.toStringAsFixed(2)}');
        }

        // 3. Verificar que después de descontar no quede bajo el mínimo requerido
        // (opcional - comentar si se permite operar con saldo bajo)
        // final newBalance = currentCredits - serviceFee;
        // if (newBalance < minCredits) {
        //   AppLogger.warning('⚠️ Después de este servicio, saldo será menor al mínimo');
        // }

        // 4. Actualizar wallet (ATÓMICO)
        transaction.update(walletRef, {
          'serviceCredits': FieldValue.increment(-serviceFee),
          'totalCreditsUsed': FieldValue.increment(serviceFee),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // 5. Crear registro de transacción (ATÓMICO)
        final txRef = _firestore.collection('creditTransactions').doc();
        transaction.set(txRef, {
          'userId': user.uid,
          'amount': -serviceFee,
          'type': 'service_fee',
          'tripId': tripId,
          'negotiationId': negotiationId,
          'balanceBefore': currentCredits,
          'balanceAfter': currentCredits - serviceFee,
          'description': 'Cobro por servicio aceptado',
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      AppLogger.info('✅ Créditos consumidos atómicamente: S/. $serviceFee para viaje $tripId');
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Error al consumir créditos: $e');
      AppLogger.error('❌ Error en consumo atómico de créditos', e);
      _setLoading(false);
      return false;
    }
  }

  /// Recargar créditos de servicio
  Future<bool> rechargeServiceCredits({
    required double amount,
    required String paymentMethod,
    String? paymentId,
    double bonus = 0,
  }) async {
    _setLoading(true);
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      // Verificar si es primera recarga para bonificación
      double actualBonus = bonus;
      if (isFirstRecharge) {
        final config = await getCreditConfig();
        actualBonus += (config['bonusCreditsOnFirstRecharge'] as num).toDouble();
      }

      final totalCredits = amount + actualBonus;

      // Actualizar wallet
      final Map<String, Object> updateData = {
        'serviceCredits': FieldValue.increment(totalCredits),
        'totalCreditsRecharged': FieldValue.increment(amount),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Si es primera recarga, marcar como ya no primera
      if (isFirstRecharge) {
        updateData['isFirstRecharge'] = false;
      }

      await _firestore
          .collection('wallets')
          .doc(user.uid)
          .update(updateData);

      // Registrar transacción de crédito
      await _firestore.collection('creditTransactions').add({
        'userId': user.uid,
        'amount': totalCredits,
        'paidAmount': amount,
        'bonus': actualBonus,
        'type': 'recharge',
        'paymentMethod': paymentMethod,
        'paymentId': paymentId,
        'balanceBefore': serviceCredits,
        'balanceAfter': serviceCredits + totalCredits,
        'isFirstRecharge': isFirstRecharge,
        'description': isFirstRecharge
            ? 'Primera recarga de créditos (+ S/. ${actualBonus.toStringAsFixed(2)} de bonificación)'
            : 'Recarga de créditos',
        'createdAt': FieldValue.serverTimestamp(),
      });

      AppLogger.info('✅ Créditos recargados: S/. $amount + S/. $actualBonus bonificación');
      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Error al recargar créditos: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Procesar recarga con MercadoPago Checkout Pro (hosted page with Yape, Plin, cards, etc.)
  Future<Map<String, dynamic>> processRechargeWithMercadoPago({
    required double amount,
    required double bonus,
    required BuildContext context,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'Usuario no autenticado'};
      }

      debugPrint('💳 WalletProvider: Iniciando recarga con MercadoPago Checkout Pro - S/. ${amount.toStringAsFixed(2)}');

      // Get user data for MercadoPago preference
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      final userName = userData['name'] ?? userData['displayName'] ?? userData['fullName'] ?? 'Usuario';
      final userEmail = user.email ?? userData['email'] ?? 'usuario@rapiteam.app';

      final rechargeId = 'recharge_${user.uid}_${DateTime.now().millisecondsSinceEpoch}';

      // Create MercadoPago preference via Cloud Functions
      final paymentService = PaymentService();
      await paymentService.initialize(isProduction: true);

      final preferenceResult = await paymentService.createMercadoPagoPreference(
        rideId: rechargeId,
        amount: amount,
        payerEmail: userEmail,
        payerName: userName,
        description: 'Recarga de créditos Rappi Team - S/. ${amount.toStringAsFixed(2)}',
      );

      if (!preferenceResult.success || preferenceResult.initPoint == null) {
        return {'success': false, 'message': preferenceResult.error ?? 'No se pudo crear la preferencia de pago'};
      }

      if (!context.mounted) return {'success': false, 'message': 'Contexto no disponible'};

      debugPrint('💳 Abriendo MercadoPago Checkout Pro...');

      // Track payment result from the checkout
      String? resultStatus;
      final completer = Completer<String?>();

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => MercadoPagoCheckoutProWidget(
            initPoint: preferenceResult.initPoint!,
            transactionId: rechargeId,
            amount: amount,
            onPaymentComplete: (status, transactionId) {
              debugPrint('💳 Pago completado: status=$status, txId=$transactionId');
              resultStatus = status;
              Navigator.pop(ctx);
              if (!completer.isCompleted) completer.complete(status);
            },
            onCancel: () {
              debugPrint('💳 Pago cancelado por el usuario');
              Navigator.pop(ctx);
              if (!completer.isCompleted) completer.complete(null);
            },
          ),
        ),
      );

      // If Navigator.push returned without callback (back button), treat as cancel
      if (!completer.isCompleted) completer.complete(resultStatus);
      final finalStatus = await completer.future;

      if (finalStatus == 'approved') {
        // Payment approved - add credits
        debugPrint('💳 Pago aprobado, agregando créditos...');
        final credited = await rechargeServiceCredits(
          amount: amount,
          paymentMethod: 'mercadopago',
          paymentId: rechargeId,
          bonus: bonus,
        );

        if (credited) {
          debugPrint('✅ Créditos agregados exitosamente');
          return {'success': true, 'message': 'Créditos agregados exitosamente'};
        } else {
          return {'success': false, 'message': 'Error agregando créditos después del pago'};
        }
      } else if (finalStatus == 'pending') {
        return {'success': false, 'message': 'Pago en proceso. Tu saldo se actualizará cuando sea confirmado.'};
      } else {
        return {'success': false, 'message': 'Pago cancelado o no completado'};
      }
    } catch (e) {
      AppLogger.error('Error en processRechargeWithMercadoPago', e);
      debugPrint('❌ Error procesando pago: $e');
      return {'success': false, 'message': 'Error procesando pago: $e'};
    }
  }

  /// Obtener historial de transacciones de créditos
  Future<List<Map<String, dynamic>>> getCreditTransactionsHistory({int limit = 50}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final snapshot = await _firestore
          .collection('creditTransactions')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      AppLogger.error('Error cargando historial de créditos', e);
      return [];
    }
  }

  @override
  void dispose() {
    _walletSubscription?.cancel();
    _transactionsSubscription?.cancel();
    _withdrawalsSubscription?.cancel();
    super.dispose();
  }

  /// Verificar estado de créditos y devolver información detallada
  /// ✅ CORREGIDO: Lee directamente de Firestore para garantizar data fresca
  Future<Map<String, dynamic>> checkCreditStatus() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {
          'currentCredits': 0.0,
          'hasEnoughCredits': false,
          'needsRecharge': true,
        };
      }

      // ✅ FIX: Agregar timeout para evitar congelamiento
      final walletDoc = await _firestore.collection('wallets').doc(user.uid).get()
          .timeout(const Duration(seconds: 15), onTimeout: () {
            throw TimeoutException('Timeout verificando estado de créditos');
          });
      double currentCredits = 0;
      if (walletDoc.exists) {
        currentCredits = (walletDoc.data()?['serviceCredits'] ?? 0).toDouble();
      }

      final config = await getCreditConfig();
      final serviceFee = (config['serviceFee'] as num).toDouble();
      final minCredits = (config['minServiceCredits'] as num).toDouble();

      final hasEnough = currentCredits >= serviceFee && currentCredits >= minCredits;
      final servicesAvailable = hasEnough ? (currentCredits / serviceFee).floor() : 0;

      return {
        'currentCredits': currentCredits,
        'serviceFee': serviceFee,
        'minCredits': minCredits,
        'hasEnoughCredits': hasEnough,
        'servicesAvailable': servicesAvailable,
        'needsRecharge': !hasEnough,
        'amountNeeded': hasEnough ? 0 : (minCredits - currentCredits).clamp(0, double.infinity),
      };
    } on TimeoutException {
      AppLogger.warning('⏱️ Timeout verificando créditos');
      return {
        'currentCredits': 0.0,
        'hasEnoughCredits': false,
        'needsRecharge': true,
        'error': 'timeout',
      };
    } catch (e) {
      AppLogger.error('Error verificando estado de créditos', e);
      return {
        'currentCredits': 0.0,
        'hasEnoughCredits': false,
        'needsRecharge': true,
      };
    }
  }
}