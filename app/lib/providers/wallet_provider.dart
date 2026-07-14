import 'dart:async'; // Para TimeoutException + StreamSubscription
import 'package:flutter/material.dart';
import '../utils/logger.dart';
import '../services/rapi_api_client.dart';
import '../services/rapi_sse_client.dart';
import '../services/payment_service.dart';
import '../widgets/mercadopago_checkout_pro_widget.dart';
import '../core/constants/credit_constants.dart';
import '../utils/error_messages.dart';

// Helper: parse ISO8601 date strings desde la respuesta del backend Node.
// Acepta tanto Strings como null (defaults a DateTime.now()).
DateTime _parseDate(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is DateTime) return value;
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }
  return DateTime.now();
}

DateTime? _parseDateOrNull(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

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
    // Compatibilidad con la respuesta del backend Node:
    // - GET /api/wallet/balance devuelve un único `balance` numérico que
    //   representa el saldo unificado (créditos de servicio y saldo son
    //   lo mismo en el backend).
    // - Los campos extendidos (pendingBalance, totalEarnings...) se rellenan
    //   con defaults 0 si el backend no los envía.
    final rawBalance = (map['balance'] ?? map['serviceCredits'] ?? 0).toDouble();
    return Wallet(
      id: id,
      userId: map['userId'] ?? id,
      balance: rawBalance,
      pendingBalance: (map['pendingBalance'] ?? 0).toDouble(),
      totalEarnings: (map['totalEarnings'] ?? 0).toDouble(),
      totalWithdrawals: (map['totalWithdrawals'] ?? 0).toDouble(),
      currency: map['currency'] ?? 'PEN',
      isActive: map['isActive'] ?? true,
      lastActivityDate: _parseDate(map['lastActivityDate']),
      bankAccount: map['bankAccount'],
      serviceCredits: (map['serviceCredits'] ?? rawBalance).toDouble(),
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
      'lastActivityDate': lastActivityDate.toIso8601String(),
      'bankAccount': bankAccount,
      'serviceCredits': serviceCredits,
      'totalCreditsRecharged': totalCreditsRecharged,
      'totalCreditsUsed': totalCreditsUsed,
      'isFirstRecharge': isFirstRecharge,
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
  final String type; // 'earning', 'withdrawal', 'commission', 'bonus', 'penalty', 'recharge', 'debit', 'refund'
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
      walletId: map['walletId'] ?? map['userId'] ?? '',
      type: map['type'] ?? 'earning',
      amount: (map['amount'] ?? 0).toDouble(),
      balanceBefore: (map['balanceBefore'] ?? 0).toDouble(),
      balanceAfter: (map['balanceAfter'] ?? 0).toDouble(),
      status: map['status'] ?? 'pending',
      tripId: map['tripId'] ?? map['rideId'],
      description: map['description'],
      metadata: map['metadata'],
      createdAt: _parseDate(map['createdAt']),
      processedAt: _parseDateOrNull(map['processedAt'] ?? map['completedAt']),
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
      'createdAt': createdAt.toIso8601String(),
      'processedAt': processedAt?.toIso8601String(),
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
      walletId: map['walletId'] ?? map['userId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      status: map['status'] ?? 'pending',
      bankAccountId: map['bankAccountId'],
      bankDetails: map['bankDetails'] ?? map['accountDetails'],
      rejectionReason: map['rejectionReason'],
      requestedAt: _parseDate(map['requestedAt'] ?? map['createdAt']),
      approvedAt: _parseDateOrNull(map['approvedAt']),
      completedAt: _parseDateOrNull(map['completedAt']),
    );
  }
}

class WalletProvider extends ChangeNotifier {
  final RapiApiClient _api = RapiApiClient.instance;
  final RapiSseClient _sse = RapiSseClient.instance;

  // Estado
  Wallet? _wallet;
  List<WalletTransaction> _transactions = [];
  final List<WithdrawalRequest> _withdrawalRequests = [];
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

  // Subscriptions SSE — para reactividad en tiempo real (reemplaza snapshots).
  StreamSubscription<Map<String, dynamic>>? _notificationsSub;
  StreamSubscription<Map<String, dynamic>>? _rideUpdatesSub;

  // Getters
  Wallet? get wallet => _wallet;
  List<WalletTransaction> get transactions => _transactions;
  List<WithdrawalRequest> get withdrawalRequests => _withdrawalRequests;
  Map<String, double> get earnings => _earnings;
  bool get isLoading => _isLoading;
  String? get error => _error;
  // Unified balance: serviceCredits is the single source of truth
  double get availableBalance => (_wallet?.serviceCredits ?? 0.0) - (_wallet?.pendingBalance ?? 0.0);

  double get serviceCredits => _wallet?.serviceCredits ?? 0.0;
  double get totalCreditsRecharged => _wallet?.totalCreditsRecharged ?? 0.0;
  double get totalCreditsUsed => _wallet?.totalCreditsUsed ?? 0.0;
  bool get isFirstRecharge => _wallet?.isFirstRecharge ?? true;

  WalletProvider() {
    _initializeWallet();
  }

  // Inicializar billetera — carga inicial HTTP + suscripción SSE.
  Future<void> _initializeWallet() async {
    if (!_api.isSignedIn) return;

    // 1) Estado inicial via HTTP
    await _refreshBalance();

    // 2) Reactividad en tiempo real via SSE:
    //    - notifications: el backend emite notificaciones para eventos
    //      wallet.recharge_approved, wallet.debit, wallet.refund, etc.
    //    - ride_update: al completar/aceptar un viaje se recalcula saldo.
    _notificationsSub = _sse.notifications.listen((event) {
      final type = (event['type'] ?? '').toString();
      if (type.startsWith('wallet') ||
          type == 'recharge_approved' ||
          type == 'credit_added' ||
          type == 'credit_used') {
        // Refrescar balance ante eventos de billetera
        _refreshBalance();
      }
    });

    _rideUpdatesSub = _sse.rideUpdates.listen((event) {
      final status = (event['status'] ?? '').toString();
      // Cambios de viaje que afectan saldo/créditos del conductor
      if (status == 'accepted' || status == 'completed' || status == 'cancelled') {
        _refreshBalance();
      }
    });
  }

  /// Refresca balance + transacciones recientes desde el backend.
  Future<void> _refreshBalance() async {
    try {
      if (!_api.isSignedIn) return;

      final data = await _api.walletBalance();

      // Construir Wallet a partir de la respuesta del backend Node.
      // El backend expone un solo balance unificado; lo mapeamos a
      // serviceCredits + balance en el modelo cliente.
      final balance = (data['balance'] ?? 0).toDouble();
      final currency = (data['currency'] ?? 'PEN').toString();

      _wallet = Wallet(
        id: _wallet?.id ?? 'me',
        userId: _wallet?.userId ?? 'me',
        balance: balance,
        pendingBalance: 0,
        totalEarnings: _wallet?.totalEarnings ?? 0,
        totalWithdrawals: _wallet?.totalWithdrawals ?? 0,
        currency: currency,
        isActive: true,
        lastActivityDate: DateTime.now(),
        bankAccount: _wallet?.bankAccount,
        serviceCredits: balance,
        totalCreditsRecharged: _wallet?.totalCreditsRecharged ?? 0,
        totalCreditsUsed: _wallet?.totalCreditsUsed ?? 0,
        isFirstRecharge: _wallet?.isFirstRecharge ?? (balance == 0),
      );

      // Parsear transacciones incluidas en la respuesta.
      final txList = (data['transactions'] as List?) ?? const [];
      _transactions = txList
          .whereType<Map<String, dynamic>>()
          .map((m) => WalletTransaction.fromMap(m, (m['id'] ?? '').toString()))
          .toList();

      await _calculateEarnings();
      notifyListeners();
    } catch (e) {
      AppLogger.error('Error refrescando balance de wallet', e);
    }
  }

  // Calcular ganancias por período — usa las transacciones locales cargadas.
  Future<void> _calculateEarnings() async {
    if (_wallet == null) return;

    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final monthStart = DateTime(now.year, now.month, 1);

      double sumEarningsBetween(DateTime start, DateTime end) {
        double sum = 0;
        for (final t in _transactions) {
          final isEarning = (t.type == 'earning' || t.type == 'recharge') && t.status == 'completed';
          if (!isEarning) continue;
          if (t.createdAt.isBefore(start) || t.createdAt.isAfter(end)) continue;
          sum += t.amount;
        }
        return sum;
      }

      _earnings = {
        'today': sumEarningsBetween(todayStart, now),
        'week': sumEarningsBetween(weekStart, now),
        'month': sumEarningsBetween(monthStart, now),
        'total': _wallet!.totalEarnings,
      };

      notifyListeners();
    } catch (e) {
      AppLogger.error('Error calculando ganancias', e);
    }
  }

  /// Refresh público — para pantallas que quieran forzar recarga manual.
  Future<void> refresh() async {
    await _refreshBalance();
  }

  // Agregar ganancia por viaje — el backend Node ya registra ganancias
  // server-side cuando se completa un viaje (endpoint completeRide).
  // Este método legacy simplemente refresca el balance para actualizar UI.
  Future<bool> addTripEarning({
    required String tripId,
    required double amount,
    required double commission,
    String? description,
  }) async {
    _setLoading(true);
    try {
      // El accounting real ocurre en /api/rides/:id/complete. Aquí solo refrescamos.
      await _refreshBalance();
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(userFriendlyError(e, fallback: 'Error al agregar ganancia'));
      _setLoading(false);
      return false;
    }
  }

  /// Solicitar retiro contra una cuenta bancaria registrada del conductor.
  /// [bankDetails] debe contener `bankAccountId` (uuid de la cuenta creada
  /// previamente via addBankAccount). Si no viene, se toma la default.
  Future<bool> requestWithdrawal({
    required double amount,
    required Map<String, dynamic> bankDetails,
  }) async {
    _setLoading(true);
    try {
      if (amount > availableBalance) {
        throw Exception('Monto excede el balance disponible');
      }
      if (amount < 20) {
        throw Exception('El monto mínimo de retiro es S/ 20.00');
      }
      String? bankAccountId = bankDetails['bankAccountId'] as String?;
      // Si no vino explícito, buscar la default cargando la lista.
      if (bankAccountId == null || bankAccountId.isEmpty) {
        final accountsResp = await _api.listBankAccounts();
        final accounts = (accountsResp['accounts'] as List?) ?? const [];
        final def = accounts
            .whereType<Map<String, dynamic>>()
            .firstWhere((a) => a['isDefault'] == true,
                orElse: () => accounts.isNotEmpty
                    ? Map<String, dynamic>.from(accounts.first as Map)
                    : <String, dynamic>{});
        bankAccountId = def['id'] as String?;
      }
      if (bankAccountId == null || bankAccountId.isEmpty) {
        throw Exception('Primero debes agregar una cuenta bancaria');
      }

      final resp = await _api.requestWithdrawal(
        bankAccountId: bankAccountId,
        amount: amount,
      );
      final w = resp['withdrawal'] as Map<String, dynamic>?;
      if (w != null) {
        _pendingWithdrawals += amount;
        _withdrawalHistory.insert(0, w);
      }
      await _refreshBalance();
      _setLoading(false);
      return true;
    } on RapiApiException catch (e) {
      _setError('Error al solicitar retiro: ${e.message ?? e.code}');
      _setLoading(false);
      return false;
    } catch (e) {
      _setError(userFriendlyError(e, fallback: 'Error al solicitar retiro'));
      _setLoading(false);
      return false;
    }
  }

  /// Cancelar retiro pendiente.
  Future<bool> cancelWithdrawal(String withdrawalId) async {
    _setLoading(true);
    try {
      await _api.cancelWithdrawal(withdrawalId);
      _withdrawalHistory.removeWhere((w) => w['id'] == withdrawalId);
      await _refreshBalance();
      _setLoading(false);
      return true;
    } on RapiApiException catch (e) {
      _setError('Error al cancelar retiro: ${e.message ?? e.code}');
      _setLoading(false);
      return false;
    } catch (e) {
      _setError(userFriendlyError(e, fallback: 'Error al cancelar retiro'));
      _setLoading(false);
      return false;
    }
  }

  /// Agregar cuenta bancaria del conductor para poder recibir retiros.
  Future<bool> addBankAccount(Map<String, dynamic> bankAccount) async {
    _setLoading(true);
    try {
      final bankName = (bankAccount['bankName'] ?? bankAccount['bank']) as String?;
      final accountType = (bankAccount['accountType'] ?? 'savings') as String;
      final accountNumber = (bankAccount['accountNumber'] ?? bankAccount['number']) as String?;
      final holderName = (bankAccount['holderName'] ?? bankAccount['holder']) as String?;
      final holderDocument = (bankAccount['holderDocument'] ?? bankAccount['dni']) as String?;
      final cci = bankAccount['cci'] as String?;
      final isDefault = (bankAccount['isDefault'] ?? true) as bool;

      if (bankName == null || accountNumber == null || holderName == null || holderDocument == null) {
        throw Exception('Faltan datos de la cuenta bancaria');
      }

      await _api.addBankAccount(
        bankName: bankName,
        accountType: accountType,
        accountNumber: accountNumber,
        holderName: holderName,
        holderDocument: holderDocument,
        cci: cci,
        isDefault: isDefault,
      );
      _setLoading(false);
      return true;
    } on RapiApiException catch (e) {
      _setError('Error al agregar cuenta bancaria: ${e.message ?? e.code}');
      _setLoading(false);
      return false;
    } catch (e) {
      _setError(userFriendlyError(e, fallback: 'Error al agregar cuenta bancaria'));
      _setLoading(false);
      return false;
    }
  }

  // Obtener estadísticas — se calcula sobre transacciones locales cargadas.
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      // Cargar historial extendido si es necesario
      final txResp = await _api.listWalletTransactions(page: 1, pageSize: 200);
      final txList = (txResp['transactions'] as List?) ?? const [];

      final now = DateTime.now();
      final lastMonth = now.subtract(const Duration(days: 30));

      int totalTrips = 0;
      double totalEarnings = 0;
      double totalCommissions = 0;
      double totalWithdrawals = 0;

      for (final raw in txList) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        final createdAt = _parseDate(map['createdAt']);
        if (createdAt.isBefore(lastMonth)) continue;

        final type = map['type'];
        final amount = (map['amount'] ?? 0).toDouble();

        if (type == 'earning' || type == 'recharge') {
          totalTrips++;
          totalEarnings += amount.abs();
          final md = map['metadata'];
          if (md is Map) {
            totalCommissions += (md['commission'] ?? 0).toDouble();
          }
        } else if (type == 'withdrawal' && map['status'] == 'completed') {
          totalWithdrawals += amount.abs();
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

  /// Cargar historial de retiros — usa listWalletTransactions(type: 'withdrawal').
  Future<void> loadWithdrawalHistory(String userId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final resp = await _api.listWalletTransactions(
        type: 'withdrawal',
        page: 1,
        pageSize: 50,
      );

      final list = (resp['transactions'] as List?) ?? const [];
      _withdrawalHistory = list
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } catch (e) {
      AppLogger.error('Error cargando historial de retiros', e);
      _error = 'Error al cargar historial';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Procesar retiro — atajo que:
  ///   1) asegura que exista una cuenta bancaria (crea una nueva con
  ///      `accountDetails` si el driver aún no tiene ninguna),
  ///   2) solicita el retiro contra esa cuenta.
  Future<bool> processWithdrawal({
    required String userId,
    required double amount,
    required String method,
    required Map<String, dynamic> accountDetails,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();
      if (amount > availableBalance) {
        throw Exception('Saldo insuficiente');
      }

      // Asegurar cuenta bancaria
      final accountsResp = await _api.listBankAccounts();
      final accounts = (accountsResp['accounts'] as List?) ?? const [];
      String? bankAccountId;
      if (accounts.isEmpty) {
        final added = await addBankAccount({...accountDetails, 'isDefault': true});
        if (!added) throw Exception('No se pudo registrar la cuenta bancaria');
        final refresh = await _api.listBankAccounts();
        final list = (refresh['accounts'] as List?) ?? const [];
        bankAccountId = list.isNotEmpty
            ? (list.first as Map<String, dynamic>)['id'] as String?
            : null;
      } else {
        final def = accounts.whereType<Map<String, dynamic>>().firstWhere(
          (a) => a['isDefault'] == true,
          orElse: () => Map<String, dynamic>.from(accounts.first as Map),
        );
        bankAccountId = def['id'] as String?;
      }
      if (bankAccountId == null) throw Exception('No hay cuenta bancaria registrada');

      return await requestWithdrawal(
        amount: amount,
        bankDetails: {'bankAccountId': bankAccountId},
      );
    } catch (e) {
      AppLogger.error('Error procesando retiro', e);
      _error = userFriendlyError(e, fallback: 'Error al procesar retiro');
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

  /// Verificar si el conductor tiene créditos suficientes para aceptar un servicio.
  /// Consulta el backend para el balance más reciente.
  Future<bool> hasEnoughCreditsForService() async {
    try {
      final config = await getCreditConfig();
      final serviceFee = (config['serviceFee'] as num).toDouble();
      final minCredits = (config['minServiceCredits'] as num).toDouble();

      // Si wallet aún no cargó, refrescar directamente del backend.
      double credits = serviceCredits;
      if (credits <= 0) {
        try {
          final data = await _api.walletBalance()
              .timeout(const Duration(seconds: 10));
          credits = (data['balance'] ?? 0).toDouble();
        } catch (walletError) {
          AppLogger.warning(userFriendlyError(walletError, fallback: 'No se pudo leer wallet del backend'));
        }
      }

      final hasEnough = credits >= serviceFee && credits >= minCredits;
      if (!hasEnough) {
        AppLogger.warning(
          'Créditos insuficientes: S/ $credits (necesita >= S/ $serviceFee y >= S/ $minCredits)',
        );
      }
      return hasEnough;
    } catch (e) {
      AppLogger.error(userFriendlyError(e, fallback: 'Error verificando créditos'));
      // En caso de error, permitir y dejar que el backend valide en accept.
      return true;
    }
  }

  /// Obtener configuración de créditos.
  /// El backend Node aún no expone /api/settings/credits — devolvemos defaults.
  Future<Map<String, dynamic>> getCreditConfig() async {
    // Sin endpoint público todavía. Retornamos configuración por defecto
    // (mismos valores que la config previa en Firestore settings/admin).
    return {
      'serviceFee': 1.0,
      'minServiceCredits': CreditConstants.minServiceCredits,
      'creditPackages': const [],
    };
  }

  /// Consumir créditos al aceptar un servicio.
  /// En el backend Node, el débito ocurre server-side al llamar acceptRide().
  /// Este método mantiene la interfaz pública y refresca el balance local.
  Future<bool> consumeCreditsForService({
    required String tripId,
    String? negotiationId,
  }) async {
    _setLoading(true);
    try {
      // El backend descuenta atómicamente al aceptar el viaje.
      // Aquí solo refrescamos para reflejar el nuevo saldo en UI.
      await _refreshBalance();
      AppLogger.info('Créditos consumidos server-side para viaje $tripId');
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(userFriendlyError(e, fallback: 'Error al consumir créditos'));
      AppLogger.error('Error refrescando saldo tras consumo de créditos', e);
      _setLoading(false);
      return false;
    }
  }

  /// Recargar créditos de servicio — legacy, ahora los pagos aprobados por
  /// MercadoPago llegan por webhook al backend y se acreditan server-side.
  /// Este método solo refresca el balance tras un pago exitoso.
  Future<bool> rechargeServiceCredits({
    required double amount,
    required String paymentMethod,
    String? paymentId,
  }) async {
    _setLoading(true);
    try {
      // La acreditación ocurre en el webhook del backend
      // (/api/payments/mercadopago/webhook). Aquí solo refrescamos.
      await _refreshBalance();
      AppLogger.info(
        'Recarga procesada (paymentId=$paymentId): saldo actual ${_wallet?.serviceCredits}',
      );
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(userFriendlyError(e, fallback: 'Error al refrescar créditos tras recarga'));
      _setLoading(false);
      return false;
    }
  }

  /// Procesar recarga con MercadoPago Checkout Pro.
  /// Ahora llama al backend Node para crear la preferencia (ya no a Cloud Functions).
  Future<Map<String, dynamic>> processRechargeWithMercadoPago({
    required double amount,
    required BuildContext context,
  }) async {
    try {
      if (!_api.isSignedIn) {
        return {'success': false, 'message': 'Usuario no autenticado'};
      }

      debugPrint(
        '💳 WalletProvider: Iniciando recarga con MercadoPago Checkout Pro - S/ ${amount.toStringAsFixed(2)}',
      );

      // 1) Crear preferencia via backend Node.
      Map<String, dynamic> preference;
      try {
        preference = await _api.createRechargeCheckout(amount);
      } on RapiApiException catch (e) {
        return {
          'success': false,
          'message': e.message ?? 'No se pudo crear la preferencia de pago',
        };
      }

      final initPoint = preference['initPoint'] as String?;
      final rechargeId = (preference['externalReference'] ?? '').toString();
      if (initPoint == null || initPoint.isEmpty) {
        return {'success': false, 'message': 'Backend no devolvió URL de pago'};
      }

      // 2) Inicializar PaymentService para tracking (compat con analytics/logs).
      try {
        final paymentService = PaymentService();
        await paymentService.initialize(isProduction: true);
      } catch (_) {
        // Falla no bloqueante — el checkout puede seguir sin él.
      }

      if (!context.mounted) {
        return {'success': false, 'message': 'Contexto no disponible'};
      }

      debugPrint('💳 Abriendo MercadoPago Checkout Pro...');

      // 3) Abrir el widget de checkout con la initPoint devuelta.
      String? resultStatus;
      final completer = Completer<String?>();

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => MercadoPagoCheckoutProWidget(
            initPoint: initPoint,
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

      if (!completer.isCompleted) completer.complete(resultStatus);
      final finalStatus = await completer.future;

      if (finalStatus == 'approved') {
        // 4) Pago aprobado: refrescar balance (el webhook ya acreditó server-side).
        debugPrint('💳 Pago aprobado, refrescando balance...');
        final credited = await rechargeServiceCredits(
          amount: amount,
          paymentMethod: 'mercadopago',
          paymentId: rechargeId,
        );

        if (credited) {
          debugPrint('✅ Balance actualizado');
          return {'success': true, 'message': 'Créditos agregados exitosamente'};
        } else {
          return {'success': false, 'message': 'Error refrescando balance tras el pago'};
        }
      } else if (finalStatus == 'pending') {
        return {
          'success': false,
          'message': 'Pago en proceso. Tu saldo se actualizará cuando sea confirmado.',
        };
      } else {
        return {'success': false, 'message': 'Pago cancelado o no completado'};
      }
    } catch (e) {
      AppLogger.error('Error en processRechargeWithMercadoPago', e);
      debugPrint('❌ Error procesando pago: $e');
      return {'success': false, 'message': userFriendlyError(e, fallback: 'Error procesando pago')};
    }
  }

  /// Obtener historial de transacciones de créditos.
  Future<List<Map<String, dynamic>>> getCreditTransactionsHistory({int limit = 50}) async {
    try {
      final resp = await _api.listWalletTransactions(page: 1, pageSize: limit);
      final list = (resp['transactions'] as List?) ?? const [];
      return list
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } catch (e) {
      AppLogger.error('Error cargando historial de créditos', e);
      return [];
    }
  }

  @override
  void dispose() {
    _notificationsSub?.cancel();
    _rideUpdatesSub?.cancel();
    super.dispose();
  }

  /// Verificar estado de créditos y devolver información detallada.
  /// Consulta directamente al backend para tener el saldo más fresco.
  Future<Map<String, dynamic>> checkCreditStatus() async {
    try {
      if (!_api.isSignedIn) {
        return {
          'currentCredits': 0.0,
          'hasEnoughCredits': false,
          'needsRecharge': true,
        };
      }

      final data = await _api.walletBalance().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Timeout verificando estado de créditos');
        },
      );

      final currentCredits = (data['balance'] ?? 0).toDouble();

      // Sincronizar estado local con lo que devolvió el backend.
      if (_wallet != null || currentCredits > 0) {
        _wallet = Wallet(
          id: _wallet?.id ?? 'me',
          userId: _wallet?.userId ?? 'me',
          balance: currentCredits,
          pendingBalance: _wallet?.pendingBalance ?? 0,
          totalEarnings: _wallet?.totalEarnings ?? 0,
          totalWithdrawals: _wallet?.totalWithdrawals ?? 0,
          currency: (data['currency'] ?? 'PEN').toString(),
          isActive: true,
          lastActivityDate: DateTime.now(),
          bankAccount: _wallet?.bankAccount,
          serviceCredits: currentCredits,
          totalCreditsRecharged: _wallet?.totalCreditsRecharged ?? 0,
          totalCreditsUsed: _wallet?.totalCreditsUsed ?? 0,
          isFirstRecharge: _wallet?.isFirstRecharge ?? (currentCredits == 0),
        );
        notifyListeners();
      }

      final config = await getCreditConfig();
      final serviceFee = (config['serviceFee'] as num).toDouble();
      final minCredits = (config['minServiceCredits'] as num).toDouble();

      final hasEnough = serviceFee <= 0
          ? true
          : (currentCredits >= serviceFee && currentCredits >= minCredits);
      final servicesAvailable = (serviceFee <= 0)
          ? 999
          : (hasEnough ? (currentCredits / serviceFee).floor() : 0);

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
        'hasEnoughCredits': true,
        'needsRecharge': false,
        'error': 'timeout',
      };
    } catch (e) {
      AppLogger.error('Error verificando estado de créditos', e);
      return {
        'currentCredits': 0.0,
        'hasEnoughCredits': true,
        'needsRecharge': false,
      };
    }
  }
}
