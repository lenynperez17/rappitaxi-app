// ignore_for_file: avoid_print
//
// user_provider.dart (LEGACY - DEPRECATED)
// ─────────────────────────────────────────
// Este provider era el puente Firebase Auth + Firestore para el usuario actual.
// Fue reemplazado por `AuthProvider` (lib/providers/auth_provider.dart), que ahora
// habla con el backend Node/Postgres a través de `RapiApiClient`.
//
// Se conserva este archivo únicamente como stub de compatibilidad con imports
// legacy que aún puedan quedar en el árbol. Toda la lógica Firebase fue
// eliminada; los métodos delegan/estubean y NO tocan Firestore ni Storage.
//
// TODO(node-migration): eliminar este archivo cuando ninguna pantalla lo importe
// y todos los llamadores pasen a `Provider.of<AuthProvider>()`.
//
// Firebase permitido en el proyecto: solo firebase_messaging, firebase_analytics,
// firebase_app_check, firebase_crashlytics. cloud_firestore / firebase_auth /
// firebase_storage están prohibidos.

import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../models/user_model.dart';
import '../../services/rapi_api_client.dart';
import '../../utils/logger.dart';

@Deprecated('Usa AuthProvider (lib/providers/auth_provider.dart) en su lugar.')
class UserProvider extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;

  final RapiApiClient _api = RapiApiClient.instance;

  // Getters
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;

  String? get userId => _currentUser?.id;
  String? get userType => _currentUser?.userType;
  String? get userName => _currentUser?.fullName;
  String? get userEmail => _currentUser?.email;
  String? get userPhone => _currentUser?.phone;
  String? get userPhoto => _currentUser?.profilePhotoUrl;

  // ✅ DUAL-ACCOUNT: activeMode retorna 'driver' o 'passenger' aunque el userType
  // sea 'dual'.
  bool get isDriver => _currentUser?.activeMode == 'driver';
  bool get isPassenger => _currentUser?.activeMode == 'passenger';
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get isEmailVerified => _currentUser?.emailVerified ?? false;
  bool get isPhoneVerified => _currentUser?.phoneVerified ?? false;

  /// Inicializar usuario desde el backend (equivalente al viejo Firebase Auth).
  Future<void> initializeUser() async {
    await _refreshFromApi();
  }

  /// Cargar usuario desde el backend Node (`GET /auth/me`).
  ///
  /// El parámetro [userId] se ignora: el backend siempre devuelve el usuario
  /// autenticado por el access token. Se mantiene la firma para no romper
  /// llamadores legacy.
  Future<void> loadUserFromFirebase(String userId) async {
    await _refreshFromApi();
  }

  Future<void> _refreshFromApi() async {
    if (_isLoading) return;
    _setLoading(true);
    try {
      final json = await _api.me();
      if (json != null) {
        _currentUser = UserModel.fromJson(json);
        _error = null;
        AppLogger.info('UserProvider (legacy) refrescado: ${_currentUser?.fullName}');
      } else {
        _currentUser = null;
      }
    } catch (e, st) {
      _error = 'Error al cargar usuario: $e';
      AppLogger.error('UserProvider (legacy) refresh falló', e, st);
    } finally {
      _setLoading(false);
    }
  }

  /// Establecer usuario manualmente (para sincronización con AuthProvider).
  void setUser(UserModel? user) {
    _currentUser = user;
    _error = null;
    notifyListeners();
  }

  /// Actualizar perfil de usuario.
  Future<bool> updateProfile({
    String? fullName,
    String? phone,
    String? profilePhotoUrl,
    Map<String, dynamic>? additionalData,
  }) async {
    // TODO(node-migration): reemplazar con endpoint PATCH /users/me cuando exista.
    // Por ahora es un stub que solo actualiza el estado local — sin persistencia.
    if (_currentUser == null) {
      _error = 'No hay usuario activo';
      return false;
    }
    _currentUser = _currentUser!.copyWith(
      fullName: fullName ?? _currentUser!.fullName,
      phone: phone ?? _currentUser!.phone,
      profilePhotoUrl: profilePhotoUrl ?? _currentUser!.profilePhotoUrl,
      updatedAt: DateTime.now(),
    );
    _error = null;
    notifyListeners();
    return true;
  }

  /// Subir foto de perfil.
  Future<String?> uploadProfilePhoto(File imageFile) async {
    // TODO(node-migration): reemplazar por RapiApiClient.instance.uploadFile(...)
    // + PATCH /users/me con la URL resultante cuando el endpoint exista.
    AppLogger.info('uploadProfilePhoto stub — pendiente de endpoint backend');
    return null;
  }

  /// Cambiar tipo de usuario (solo admin).
  Future<bool> updateUserType(String newUserType) async {
    // TODO(node-migration): reemplazar por endpoint admin de cambio de rol.
    if (_currentUser == null) return false;
    _currentUser = _currentUser!.copyWith(
      userType: newUserType,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    return true;
  }

  /// Marcar email como verificado.
  Future<bool> updateEmailVerification(bool isVerified) async {
    // TODO(node-migration): endpoint pendiente.
    if (_currentUser == null) return false;
    _currentUser = _currentUser!.copyWith(
      emailVerified: isVerified,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    return true;
  }

  /// Marcar teléfono como verificado.
  Future<bool> updatePhoneVerification(bool isVerified) async {
    // TODO(node-migration): endpoint pendiente.
    if (_currentUser == null) return false;
    _currentUser = _currentUser!.copyWith(
      phoneVerified: isVerified,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    return true;
  }

  /// Actualizar última conexión.
  Future<void> updateLastLogin() async {
    // TODO(node-migration): el backend actualiza lastLoginAt automáticamente en
    // login/refresh; ya no es necesario del cliente.
  }

  /// Obtener datos adicionales del conductor.
  Future<Map<String, dynamic>?> getDriverData() async {
    if (!isDriver || _currentUser == null) return null;
    try {
      return await _api.myDriverProfile();
    } catch (e) {
      AppLogger.error('Error obteniendo datos del conductor', e);
      return null;
    }
  }

  /// Obtener estadísticas del usuario.
  Future<Map<String, dynamic>?> getUserStats() async {
    // TODO(node-migration): reemplazar por endpoint GET /users/me/stats cuando exista.
    return null;
  }

  /// Sincronizar con AuthProvider.
  Future<void> syncWithAuth() async {
    await _refreshFromApi();
  }

  /// Limpiar usuario (logout).
  void clearUser() {
    _currentUser = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Recargar usuario desde backend.
  Future<void> refreshUser() async {
    await _refreshFromApi();
  }

  /// Verificar si el usuario existe (por id).
  Future<bool> userExists(String userId) async {
    // TODO(node-migration): endpoint pendiente. Devolvemos true si coincide con
    // el usuario actualmente autenticado, false si no hay match.
    return _currentUser?.id == userId;
  }

  // Métodos de utilidad privados
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
