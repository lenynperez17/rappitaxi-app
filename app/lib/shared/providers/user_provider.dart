import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

import '../../models/user_model.dart';
import '../../utils/logger.dart';
import '../../utils/firestore_error_handler.dart';

class UserProvider extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

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
  
  // ✅ DUAL-ACCOUNT: Usar activeMode para validar rol activo
  // activeMode siempre retorna 'driver' o 'passenger', incluso para cuentas dual
  bool get isDriver => _currentUser?.activeMode == 'driver';
  bool get isPassenger => _currentUser?.activeMode == 'passenger';
  bool get isAdmin => _currentUser?.userType == 'admin';
  bool get isEmailVerified => _currentUser?.emailVerified ?? false;
  bool get isPhoneVerified => _currentUser?.phoneVerified ?? false;

  /// Inicializar usuario desde Firebase Auth
  Future<void> initializeUser() async {
    final User? firebaseUser = _auth.currentUser;
    if (firebaseUser != null) {
      await loadUserFromFirebase(firebaseUser.uid);
    }
  }

  /// Cargar usuario completo desde Firestore
  Future<void> loadUserFromFirebase(String userId) async {
    if (_isLoading) return;
    
    _setLoading(true);
    AppLogger.info('Cargando datos de usuario: $userId');

    try {
      final docSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        _currentUser = UserModel.fromFirestore(data, userId);
        _error = null;
        AppLogger.info('Usuario cargado exitosamente: ${_currentUser?.fullName}');
      } else {
        // Crear usuario base desde Firebase Auth si no existe en Firestore
        await _createUserFromAuth(userId);
      }
    } catch (e, stackTrace) {
      _error = FirestoreErrorHandler.getSpanishMessage(e);
      AppLogger.error('Error cargando usuario', e, stackTrace);
    } finally {
      _setLoading(false);
    }
  }

  /// Crear usuario en Firestore desde datos de Firebase Auth
  Future<void> _createUserFromAuth(String userId) async {
    final User? firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      throw Exception('Usuario no autenticado');
    }

    AppLogger.info('Creando usuario en Firestore: $userId');

    final userData = {
      'email': firebaseUser.email ?? '',
      'phone': firebaseUser.phoneNumber ?? '',
      'fullName': firebaseUser.displayName ?? 'Usuario',
      'userType': 'passenger', // Por defecto
      'isActive': true,
      'emailVerified': firebaseUser.emailVerified,
      'phoneVerified': firebaseUser.phoneNumber != null,
      'profilePhotoUrl': firebaseUser.photoURL,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
    };

    await _firestore.collection('users').doc(userId).set(userData);
    
    // Recargar usuario
    await loadUserFromFirebase(userId);
  }

  /// Establecer usuario manualmente (para sincronización con AuthProvider)
  void setUser(UserModel? user) {
    _currentUser = user;
    _error = null;
    notifyListeners();
    AppLogger.info('Usuario establecido: ${user?.fullName}');
  }

  /// Actualizar perfil de usuario
  Future<bool> updateProfile({
    String? fullName,
    String? phone,
    String? profilePhotoUrl,
    Map<String, dynamic>? additionalData,
  }) async {
    if (_currentUser == null) {
      _error = 'No hay usuario activo';
      return false;
    }

    _setLoading(true);
    AppLogger.info('Actualizando perfil de usuario: ${_currentUser!.id}');

    try {
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (fullName != null) updateData['fullName'] = fullName;
      if (phone != null) updateData['phone'] = phone;
      if (profilePhotoUrl != null) updateData['profilePhotoUrl'] = profilePhotoUrl;
      if (additionalData != null) updateData.addAll(additionalData);

      await _firestore
          .collection('users')
          .doc(_currentUser!.id)
          .update(updateData);

      // Actualizar usuario local
      _currentUser = _currentUser!.copyWith(
        fullName: fullName ?? _currentUser!.fullName,
        phone: phone ?? _currentUser!.phone,
        profilePhotoUrl: profilePhotoUrl ?? _currentUser!.profilePhotoUrl,
        updatedAt: DateTime.now(),
      );

      _error = null;
      notifyListeners();
      AppLogger.info('Perfil actualizado exitosamente');
      return true;

    } catch (e, stackTrace) {
      _error = FirestoreErrorHandler.getSpanishMessage(e);
      AppLogger.error('Error actualizando perfil', e, stackTrace);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Subir foto de perfil
  Future<String?> uploadProfilePhoto(File imageFile) async {
    if (_currentUser == null) {
      _error = 'No hay usuario activo';
      return null;
    }

    _setLoading(true);
    AppLogger.info('Subiendo foto de perfil');

    try {
      final fileName = 'profile_${_currentUser!.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('profile_photos').child(fileName);
      
      final uploadTask = ref.putFile(imageFile);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Actualizar URL en perfil
      await updateProfile(profilePhotoUrl: downloadUrl);

      AppLogger.info('Foto de perfil subida exitosamente');
      return downloadUrl;

    } catch (e, stackTrace) {
      _error = FirestoreErrorHandler.getSpanishMessage(e);
      AppLogger.error('Error subiendo foto de perfil', e, stackTrace);
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Cambiar tipo de usuario (solo admin)
  Future<bool> updateUserType(String newUserType) async {
    if (_currentUser == null) {
      _error = 'No hay usuario activo';
      return false;
    }

    _setLoading(true);
    AppLogger.info('Cambiando tipo de usuario a: $newUserType');

    try {
      await _firestore
          .collection('users')
          .doc(_currentUser!.id)
          .update({
            'userType': newUserType,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      _currentUser = _currentUser!.copyWith(
        userType: newUserType,
        updatedAt: DateTime.now(),
      );

      _error = null;
      notifyListeners();
      AppLogger.info('Tipo de usuario actualizado a: $newUserType');
      return true;

    } catch (e, stackTrace) {
      _error = FirestoreErrorHandler.getSpanishMessage(e);
      AppLogger.error('Error cambiando tipo de usuario', e, stackTrace);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Verificar email
  Future<bool> updateEmailVerification(bool isVerified) async {
    if (_currentUser == null) return false;

    try {
      await _firestore
          .collection('users')
          .doc(_currentUser!.id)
          .update({
            'emailVerified': isVerified,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      _currentUser = _currentUser!.copyWith(
        emailVerified: isVerified,
        updatedAt: DateTime.now(),
      );

      notifyListeners();
      AppLogger.info('Verificación de email actualizada: $isVerified');
      return true;
    } catch (e) {
      AppLogger.error('Error actualizando verificación de email', e);
      return false;
    }
  }

  /// Verificar teléfono
  Future<bool> updatePhoneVerification(bool isVerified) async {
    if (_currentUser == null) return false;

    try {
      await _firestore
          .collection('users')
          .doc(_currentUser!.id)
          .update({
            'phoneVerified': isVerified,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      _currentUser = _currentUser!.copyWith(
        phoneVerified: isVerified,
        updatedAt: DateTime.now(),
      );

      notifyListeners();
      AppLogger.info('Verificación de teléfono actualizada: $isVerified');
      return true;
    } catch (e) {
      AppLogger.error('Error actualizando verificación de teléfono', e);
      return false;
    }
  }

  /// Actualizar última conexión
  Future<void> updateLastLogin() async {
    if (_currentUser == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(_currentUser!.id)
          .update({
            'lastLoginAt': FieldValue.serverTimestamp(),
          });

      AppLogger.debug('Última conexión actualizada');
    } catch (e) {
      AppLogger.error('Error actualizando última conexión', e);
    }
  }

  /// Obtener datos adicionales del conductor
  Future<Map<String, dynamic>?> getDriverData() async {
    if (!isDriver || _currentUser == null) return null;

    try {
      final docSnapshot = await _firestore
          .collection('drivers')
          .doc(_currentUser!.id)
          .get();

      return docSnapshot.exists ? docSnapshot.data() : null;
    } catch (e) {
      AppLogger.error('Error obteniendo datos del conductor', e);
      return null;
    }
  }

  /// Obtener estadísticas del usuario
  Future<Map<String, dynamic>?> getUserStats() async {
    if (_currentUser == null) return null;

    try {
      final docSnapshot = await _firestore
          .collection('user_stats')
          .doc(_currentUser!.id)
          .get();

      return docSnapshot.exists ? docSnapshot.data() : null;
    } catch (e) {
      AppLogger.error('Error obteniendo estadísticas del usuario', e);
      return null;
    }
  }

  /// Sincronizar con AuthProvider
  Future<void> syncWithAuth() async {
    final User? firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      clearUser();
      return;
    }

    // Solo recargar si no tenemos usuario o el ID no coincide
    if (_currentUser == null || _currentUser!.id != firebaseUser.uid) {
      await loadUserFromFirebase(firebaseUser.uid);
    }

    // Actualizar estado de verificación si cambió
    if (_currentUser != null) {
      if (_currentUser!.emailVerified != firebaseUser.emailVerified) {
        await updateEmailVerification(firebaseUser.emailVerified);
      }
    }
  }

  /// Limpiar usuario (logout)
  void clearUser() {
    _currentUser = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
    AppLogger.info('Usuario limpiado del provider');
  }

  /// Recargar usuario desde Firebase
  Future<void> refreshUser() async {
    if (_currentUser != null) {
      await loadUserFromFirebase(_currentUser!.id);
    }
  }

  /// Verificar si el usuario existe en Firestore
  Future<bool> userExists(String userId) async {
    try {
      final docSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      return docSnapshot.exists;
    } catch (e) {
      AppLogger.error('Error verificando existencia del usuario', e);
      return false;
    }
  }

  // Métodos de utilidad privados
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

}