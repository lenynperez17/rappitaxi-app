import 'package:flutter/material.dart';

/// AdminProvider (DEPRECATED)
///
/// El panel administrativo se movió al panel web (`admin/`) — este provider
/// existía cuando la app móvil incluía secciones de administración dentro del
/// mismo binario. Tras la migración a la API Node (RapiApiClient) y la
/// eliminación de Firebase del cliente móvil, este provider ya no realiza
/// ninguna llamada real y se conserva únicamente como stub para no romper la
/// compilación si algún import antiguo quedara colgado.
///
/// Cualquier llamada a los métodos aquí definidos lanza [UnimplementedError]
/// con un mensaje claro. No consumir desde pantallas nuevas.
@Deprecated('El panel admin ahora vive en el panel web. Este provider ya no se usa.')
class AdminProvider extends ChangeNotifier {
  // Estados de carga (mantenidos por si alguna UI residual los consulta).
  final bool _isLoading = false;
  final String? _error = null;

  // Datos de administración (siempre vacíos).
  final List<Map<String, dynamic>> _users = const [];
  final List<Map<String, dynamic>> _drivers = const [];
  final Map<String, dynamic>? _statistics = null;
  final Map<String, dynamic>? _financialData = null;
  final List<Map<String, dynamic>> _transactions = const [];
  final Map<String, dynamic>? _settings = null;

  // Getters conservados por compatibilidad de interfaz.
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get users => _users;
  List<Map<String, dynamic>> get drivers => _drivers;
  Map<String, dynamic>? get statistics => _statistics;
  Map<String, dynamic>? get financialData => _financialData;
  List<Map<String, dynamic>> get transactions => _transactions;
  Map<String, dynamic>? get settings => _settings;

  // Getters de configuración de créditos (devuelven defaults inofensivos).
  double get serviceFee => 1.0;
  double get minServiceCredits => 10.0;
  List<Map<String, dynamic>> get creditPackages => const [];

  static Never _notSupported(String method) {
    throw UnimplementedError(
      'AdminProvider.$method no está disponible: el panel admin ahora está en el web.',
    );
  }

  Future<void> loadUsers() async => _notSupported('loadUsers');
  Future<void> loadDrivers() async => _notSupported('loadDrivers');
  Future<void> loadStatistics() async => _notSupported('loadStatistics');
  Future<void> loadFinancialData() async => _notSupported('loadFinancialData');
  Future<void> loadTransactions() async => _notSupported('loadTransactions');

  Future<bool> verifyDriver(String driverId) async => _notSupported('verifyDriver');
  Future<bool> suspendUser(String userId, String reason) async =>
      _notSupported('suspendUser');
  Future<bool> reactivateUser(String userId) async => _notSupported('reactivateUser');
  Future<bool> updateDriverStatus(String driverId, String status) async =>
      _notSupported('updateDriverStatus');
  Future<bool> deleteDriver(String driverId) async => _notSupported('deleteDriver');
  Future<bool> updateUserStatus(String userId, bool isActive) async =>
      _notSupported('updateUserStatus');
  Future<bool> deleteUser(String userId) async => _notSupported('deleteUser');

  Future<bool> updateSettings(Map<String, dynamic> settings) async =>
      _notSupported('updateSettings');
  Future<void> loadSettings() async => _notSupported('loadSettings');

  // Ronda 96: no-op reales (mismo patrón que clearError). Antes: _notSupported
  // es Never (throws UnimplementedError) → el throw sync se propaga al caller
  // reventando el frame de Flutter cuando la UI residual invoca estos stubs
  // esperando comportamiento silencioso como decía el docstring del header.
  void searchUsers(String query) {
    // No-op: la búsqueda ya se hace directamente en el panel admin (React).
  }
  void searchDrivers(String query) {
    // No-op: idem searchUsers.
  }

  void clearError() {
    // No-op: el provider ya no mantiene estado de error real.
  }

  // ============ CONFIGURACIÓN DE CRÉDITOS PARA CONDUCTORES ============
  Future<bool> updateServiceFee(double fee) async => _notSupported('updateServiceFee');
  Future<bool> updateMinServiceCredits(double minCredits) async =>
      _notSupported('updateMinServiceCredits');
  Future<bool> updateCreditPackages(List<Map<String, dynamic>> packages) async =>
      _notSupported('updateCreditPackages');
  Future<bool> addCreditsToDriver(String driverId, double amount, String reason) async =>
      _notSupported('addCreditsToDriver');
  Future<List<Map<String, dynamic>>> getDriversWithLowCredits() async =>
      _notSupported('getDriversWithLowCredits');
  Future<List<Map<String, dynamic>>> getCreditTransactionsHistory({int limit = 50}) async =>
      _notSupported('getCreditTransactionsHistory');
  Future<Map<String, dynamic>> getCreditStatistics() async =>
      _notSupported('getCreditStatistics');
}
