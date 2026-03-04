import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';

class AdminProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseService().firestore;

  // Estados de carga
  bool _isLoading = false;
  String? _error;

  // Datos de administración
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _drivers = [];
  Map<String, dynamic>? _statistics;
  Map<String, dynamic>? _financialData;
  List<Map<String, dynamic>> _transactions = [];
  Map<String, dynamic>? _settings;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get users => _users;
  List<Map<String, dynamic>> get drivers => _drivers;
  Map<String, dynamic>? get statistics => _statistics;
  Map<String, dynamic>? get financialData => _financialData;
  List<Map<String, dynamic>> get transactions => _transactions;
  Map<String, dynamic>? get settings => _settings;

  // Getters de configuración de créditos para conductores
  double get serviceFee => (_settings?['serviceFee'] ?? 1.0).toDouble();
  double get minServiceCredits => (_settings?['minServiceCredits'] ?? 10.0).toDouble(); // ✅ Unificado con mínimo de MercadoPago
  double get bonusCreditsOnFirstRecharge => (_settings?['bonusCreditsOnFirstRecharge'] ?? 5.0).toDouble();
  List<Map<String, dynamic>> get creditPackages =>
      (_settings?['creditPackages'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

  // Cargar usuarios
  Future<void> loadUsers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await _firestore.collection('users').get();
      _users = snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      _error = 'Error al cargar usuarios: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  // Cargar conductores
  Future<void> loadDrivers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'driver')
          .get();
      
      _drivers = snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      _error = 'Error al cargar conductores: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  // Cargar estadísticas
  Future<void> loadStatistics() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Cargar estadísticas generales
      final usersSnapshot = await _firestore.collection('users').get();
      final tripsSnapshot = await _firestore.collection('rides').get();
      
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      
      final monthlyTrips = await _firestore
          .collection('rides')
          .where('createdAt', isGreaterThanOrEqualTo: startOfMonth)
          .get();

      _statistics = {
        'totalUsers': usersSnapshot.docs.where((doc) => 
            doc.data()['role'] == 'passenger').length,
        'totalDrivers': usersSnapshot.docs.where((doc) => 
            doc.data()['role'] == 'driver').length,
        'activeDrivers': usersSnapshot.docs.where((doc) => 
            doc.data()['role'] == 'driver' && 
            doc.data()['isOnline'] == true).length,
        'totalTrips': tripsSnapshot.docs.length,
        'monthlyTrips': monthlyTrips.docs.length,
        'completedTrips': tripsSnapshot.docs.where((doc) => 
            doc.data()['status'] == 'completed').length,
      };
    } catch (e) {
      _error = 'Error al cargar estadísticas: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  // Cargar datos financieros
  Future<void> loadFinancialData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final tripsSnapshot = await _firestore
          .collection('rides')
          .where('status', isEqualTo: 'completed')
          .get();

      double totalRevenue = 0;
      double totalCommission = 0;
      double totalDriverEarnings = 0;

      for (var doc in tripsSnapshot.docs) {
        final data = doc.data();
        final fare = (data['fare'] ?? 0).toDouble();
        final commission = fare * 0.20; // 20% de comisión
        
        totalRevenue += fare;
        totalCommission += commission;
        totalDriverEarnings += (fare - commission);
      }

      _financialData = {
        'totalRevenue': totalRevenue,
        'totalCommission': totalCommission,
        'totalDriverEarnings': totalDriverEarnings,
        'averageTripValue': tripsSnapshot.docs.isNotEmpty 
            ? totalRevenue / tripsSnapshot.docs.length 
            : 0,
      };
    } catch (e) {
      _error = 'Error al cargar datos financieros: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  // Cargar transacciones
  Future<void> loadTransactions() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('transactions')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();

      _transactions = snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      _error = 'Error al cargar transacciones: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  // Verificar conductor
  Future<bool> verifyDriver(String driverId) async {
    try {
      await _firestore.collection('users').doc(driverId).update({
        'isVerified': true,
        'verifiedAt': FieldValue.serverTimestamp(),
      });
      
      await loadDrivers();
      return true;
    } catch (e) {
      _error = 'Error al verificar conductor: $e';
      notifyListeners();
      return false;
    }
  }

  // Suspender usuario
  Future<bool> suspendUser(String userId, String reason) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isSuspended': true,
        'suspendedAt': FieldValue.serverTimestamp(),
        'suspensionReason': reason,
      });
      
      await loadUsers();
      return true;
    } catch (e) {
      _error = 'Error al suspender usuario: $e';
      notifyListeners();
      return false;
    }
  }

  // Reactivar usuario
  Future<bool> reactivateUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isSuspended': false,
        'suspendedAt': null,
        'suspensionReason': null,
      });
      
      await loadUsers();
      return true;
    } catch (e) {
      _error = 'Error al reactivar usuario: $e';
      notifyListeners();
      return false;
    }
  }

  // Actualizar estado del conductor
  Future<bool> updateDriverStatus(String driverId, String status) async {
    try {
      await _firestore.collection('users').doc(driverId).update({
        'isActive': status == 'active',
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      await loadDrivers();
      return true;
    } catch (e) {
      _error = 'Error al actualizar estado del conductor: $e';
      notifyListeners();
      return false;
    }
  }

  // Eliminar conductor
  Future<bool> deleteDriver(String driverId) async {
    try {
      await _firestore.collection('users').doc(driverId).delete();
      await loadDrivers();
      return true;
    } catch (e) {
      _error = 'Error al eliminar conductor: $e';
      notifyListeners();
      return false;
    }
  }

  // Actualizar estado del usuario
  Future<bool> updateUserStatus(String userId, bool isActive) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      await loadUsers();
      return true;
    } catch (e) {
      _error = 'Error al actualizar estado del usuario: $e';
      notifyListeners();
      return false;
    }
  }

  // Eliminar usuario
  Future<bool> deleteUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).delete();
      await loadUsers();
      return true;
    } catch (e) {
      _error = 'Error al eliminar usuario: $e';
      notifyListeners();
      return false;
    }
  }

  // Actualizar configuración
  // ✅ CORREGIDO: Unificado para usar 'app_config' (mismo documento que settings_admin_screen)
  Future<bool> updateSettings(Map<String, dynamic> settings) async {
    try {
      await _firestore
          .collection('settings')
          .doc('app_config')
          .set(settings, SetOptions(merge: true));

      _settings = settings;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al actualizar configuración: $e';
      notifyListeners();
      return false;
    }
  }

  // Cargar configuración
  // ✅ CORREGIDO: Unificado para usar 'app_config' (mismo documento que settings_admin_screen)
  // ✅ CORREGIDO: Orden de merge - primero defaults, luego datos de Firestore (para que Firestore sobrescriba)
  Future<void> loadSettings() async {
    try {
      final doc = await _firestore
          .collection('settings')
          .doc('app_config')
          .get();

      // Valores por defecto
      final defaultSettings = {
        'commissionRate': 0.20,
        'minFare': 5.0,
        'maxRadius': 10000,
        'surgeMultiplier': 1.0,
        'maintenanceMode': false,
        // Configuración de créditos para conductores
        'serviceFee': 1.0, // Costo por servicio aceptado (S/.)
        'minServiceCredits': 10.0, // Créditos mínimos para operar (S/.)
        'bonusCreditsOnFirstRecharge': 5.0, // Bonificación primera recarga
        'creditPackages': [
          {'amount': 10.0, 'bonus': 0.0, 'label': 'Básico'},
          {'amount': 20.0, 'bonus': 2.0, 'label': 'Popular'},
          {'amount': 50.0, 'bonus': 10.0, 'label': 'Pro'},
          {'amount': 100.0, 'bonus': 25.0, 'label': 'Premium'},
        ],
      };

      if (doc.exists) {
        // ✅ CORREGIDO: Primero defaults, luego datos de Firestore
        // Esto asegura que los valores de Firestore sobrescriban los defaults
        _settings = {
          ...defaultSettings,
          ...doc.data()!,
        };
      } else {
        // Configuración por defecto
        _settings = defaultSettings;
        // Guardar configuración por defecto en Firestore
        await _firestore
            .collection('settings')
            .doc('app_config')
            .set(_settings!);
      }
      notifyListeners();
    } catch (e) {
      _error = 'Error al cargar configuración: $e';
      notifyListeners();
    }
  }

  // Buscar usuarios
  void searchUsers(String query) {
    if (query.isEmpty) {
      loadUsers();
      return;
    }

    final lowerQuery = query.toLowerCase();
    _users = _users.where((user) {
      final name = (user['name'] ?? '').toString().toLowerCase();
      final email = (user['email'] ?? '').toString().toLowerCase();
      final phone = (user['phone'] ?? '').toString().toLowerCase();
      
      return name.contains(lowerQuery) ||
             email.contains(lowerQuery) ||
             phone.contains(lowerQuery);
    }).toList();
    
    notifyListeners();
  }

  // Buscar conductores
  void searchDrivers(String query) {
    if (query.isEmpty) {
      loadDrivers();
      return;
    }

    final lowerQuery = query.toLowerCase();
    _drivers = _drivers.where((driver) {
      final name = (driver['name'] ?? '').toString().toLowerCase();
      final email = (driver['email'] ?? '').toString().toLowerCase();
      final phone = (driver['phone'] ?? '').toString().toLowerCase();
      final vehicle = (driver['vehiclePlate'] ?? '').toString().toLowerCase();
      
      return name.contains(lowerQuery) ||
             email.contains(lowerQuery) ||
             phone.contains(lowerQuery) ||
             vehicle.contains(lowerQuery);
    }).toList();
    
    notifyListeners();
  }

  // Limpiar error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ============ CONFIGURACIÓN DE CRÉDITOS PARA CONDUCTORES ============

  // Actualizar costo por servicio
  Future<bool> updateServiceFee(double fee) async {
    try {
      await _firestore
          .collection('settings')
          .doc('admin')
          .update({'serviceFee': fee});

      _settings?['serviceFee'] = fee;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al actualizar costo por servicio: $e';
      notifyListeners();
      return false;
    }
  }

  // Actualizar créditos mínimos requeridos
  Future<bool> updateMinServiceCredits(double minCredits) async {
    try {
      await _firestore
          .collection('settings')
          .doc('admin')
          .update({'minServiceCredits': minCredits});

      _settings?['minServiceCredits'] = minCredits;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al actualizar créditos mínimos: $e';
      notifyListeners();
      return false;
    }
  }

  // Actualizar bonificación primera recarga
  Future<bool> updateBonusCreditsOnFirstRecharge(double bonus) async {
    try {
      await _firestore
          .collection('settings')
          .doc('admin')
          .update({'bonusCreditsOnFirstRecharge': bonus});

      _settings?['bonusCreditsOnFirstRecharge'] = bonus;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al actualizar bonificación: $e';
      notifyListeners();
      return false;
    }
  }

  // Actualizar paquetes de créditos
  Future<bool> updateCreditPackages(List<Map<String, dynamic>> packages) async {
    try {
      await _firestore
          .collection('settings')
          .doc('admin')
          .update({'creditPackages': packages});

      _settings?['creditPackages'] = packages;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al actualizar paquetes de créditos: $e';
      notifyListeners();
      return false;
    }
  }

  // Agregar créditos a un conductor (desde admin)
  Future<bool> addCreditsToDriver(String driverId, double amount, String reason) async {
    try {
      // Actualizar wallet del conductor
      await _firestore
          .collection('wallets')
          .doc(driverId)
          .update({
        'serviceCredits': FieldValue.increment(amount),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Registrar transacción
      await _firestore.collection('creditTransactions').add({
        'userId': driverId,
        'amount': amount,
        'type': 'admin_credit',
        'reason': reason,
        'adminId': 'admin',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      _error = 'Error al agregar créditos: $e';
      notifyListeners();
      return false;
    }
  }

  // Obtener conductores con bajo saldo
  Future<List<Map<String, dynamic>>> getDriversWithLowCredits() async {
    try {
      final minCredits = minServiceCredits;
      final snapshot = await _firestore
          .collection('wallets')
          .where('serviceCredits', isLessThan: minCredits)
          .get();

      List<Map<String, dynamic>> result = [];
      for (var doc in snapshot.docs) {
        final userData = await _firestore
            .collection('users')
            .doc(doc.id)
            .get();

        if (userData.exists && userData.data()?['role'] == 'driver') {
          result.add({
            'id': doc.id,
            'credits': doc.data()['serviceCredits'] ?? 0,
            ...userData.data()!,
          });
        }
      }
      return result;
    } catch (e) {
      _error = 'Error al obtener conductores con bajo saldo: $e';
      return [];
    }
  }

  // Obtener historial de recargas de créditos
  Future<List<Map<String, dynamic>>> getCreditTransactionsHistory({int limit = 50}) async {
    try {
      final snapshot = await _firestore
          .collection('creditTransactions')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      _error = 'Error al cargar historial de créditos: $e';
      return [];
    }
  }

  // Obtener estadísticas de créditos
  Future<Map<String, dynamic>> getCreditStatistics() async {
    try {
      // Total de créditos en circulación
      final walletsSnapshot = await _firestore.collection('wallets').get();
      double totalCreditsInCirculation = 0;
      int driversWithCredits = 0;
      int driversWithoutCredits = 0;

      for (var doc in walletsSnapshot.docs) {
        final credits = (doc.data()['serviceCredits'] ?? 0).toDouble();
        totalCreditsInCirculation += credits;
        if (credits >= minServiceCredits) {
          driversWithCredits++;
        } else {
          driversWithoutCredits++;
        }
      }

      // Total recaudado por créditos (últimos 30 días)
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final rechargesSnapshot = await _firestore
          .collection('creditTransactions')
          .where('type', isEqualTo: 'recharge')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();

      double totalRechargesLast30Days = 0;
      for (var doc in rechargesSnapshot.docs) {
        totalRechargesLast30Days += (doc.data()['amount'] ?? 0).toDouble();
      }

      return {
        'totalCreditsInCirculation': totalCreditsInCirculation,
        'driversWithCredits': driversWithCredits,
        'driversWithoutCredits': driversWithoutCredits,
        'totalRechargesLast30Days': totalRechargesLast30Days,
        'averageCreditsPerDriver': walletsSnapshot.docs.isNotEmpty
            ? totalCreditsInCirculation / walletsSnapshot.docs.length
            : 0,
      };
    } catch (e) {
      _error = 'Error al obtener estadísticas de créditos: $e';
      return {};
    }
  }
}