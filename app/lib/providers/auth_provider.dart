// ⚡⚡⚡ VERSIÓN CON PERSISTENCIA - COMPILACIÓN: 2025-11-17 05:35:00 UTC ⚡⚡⚡
// ⚡ FORZAR RECOMPILACIÓN DEL ARCHIVO - NO REMOVER ESTE COMENTARIO ⚡
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
// import 'package:email_validator/email_validator.dart'; // Eliminado: ya no se usa _validateEmail()
// import 'package:crypto/crypto.dart'; // Eliminado: ya no se usa _hashPhone()
import 'dart:convert';
import 'dart:io';
import 'dart:async'; // ✅ Agregado para StreamSubscription
import 'dart:math' as math;
import '../services/firebase_service.dart';
import '../services/fcm_service.dart';
import '../services/security_service.dart'; // ✅ NUEVO: Para limpiar bloqueos
import '../models/user_model.dart';
import '../utils/logger.dart';
import '../config/oauth_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/firestore_error_handler.dart'; // ✅ Handler para errores amigables

/// Provider de Autenticación Profesional Enterprise con Firebase
/// Incluye validación completa, seguridad avanzada y autenticación multifactor
class AuthProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  // final SecurityLogger _securityLogger = SecurityLogger(); // Removido: archivo no existe
  
  UserModel? _currentUser;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  bool _isInitializing = true; // ✅ NUEVO: Indica si está inicializando
  String? _errorMessage;

  // ✅ CORRECCIÓN MEMORY LEAK: Guardar referencia al listener para cancelarlo
  StreamSubscription<User?>? _authSubscription;

  // Nota: Variables de rate limiting eliminadas (login con email/password eliminado)

  // ✅ Control de cambio de rol para evitar listeners prematuros
  bool _isRoleSwitchInProgress = false;
  
  // Verificación de email, teléfono y documento
  bool _emailVerified = false;
  bool _phoneVerified = false;
  bool _documentVerified = false;
  String? _verificationId; // Para OTP de teléfono
  String? _pendingPhoneNumber;

  // Configuracion de seguridad simplificada (solo Google + Telefono)

  // Getters
  UserModel? get currentUser => _currentUser;
  // ✅ CORRECCIÓN PERSISTENCIA: Permitir sesión sin verificar email (como Uber/InDriver)
  // El email verificado se puede requerir solo para funciones específicas
  bool get isAuthenticated => _isAuthenticated;
  bool get isFullyVerified => _isAuthenticated && _emailVerified; // Para funciones que requieran verificación
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing; // ✅ NUEVO
  String? get errorMessage => _errorMessage;
  bool get isRoleSwitchInProgress => _isRoleSwitchInProgress;
  bool get emailVerified => _emailVerified;
  bool get phoneVerified => _phoneVerified;
  bool get documentVerified => _documentVerified;
  String? get verificationId => _verificationId;
  
  AuthProvider() {
    print('🔥🔥🔥 VERSIÓN NUEVA DE AUTHPROVIDER - TIMESTAMP: ${DateTime.now()} 🔥🔥🔥');
    AppLogger.state('AuthProvider', '🔥 CONSTRUCTOR INICIADO - NUEVA VERSIÓN CON PERSISTENCIA');
    _initializeAuth();
  }

  /// Inicializar autenticación con verificación completa
  Future<void> _initializeAuth() async {
    print('🔥🔥🔥 INICIANDO AUTH CON PERSISTENCIA - authStateChanges().first 🔥🔥🔥');
    AppLogger.state('AuthProvider', '🔥 INICIALIZANDO AUTENTICACIÓN PROFESIONAL CON PERSISTENCIA');

    try {
      print('🔥 [1/5] Cargando estado de seguridad...');
      await _loadSecurityState();
      print('🔥 [1/5] ✅ Estado de seguridad cargado');

      // ✅ CRÍTICO: Esperar el PRIMER evento de authStateChanges
      // Firebase Auth persiste automáticamente, solo necesitamos esperar a que se restaure
      print('🔥 [2/5] Esperando primer evento de authStateChanges...');
      AppLogger.info('Esperando primer evento de authStateChanges...');

      User? firstUser;
      try {
        firstUser = await FirebaseAuth.instance.authStateChanges().first
            .timeout(Duration(seconds: 3), onTimeout: () {
          print('🔥 [2/5] ⚠️ TIMEOUT - No se recibió evento en 3 segundos');
          return null;
        });
      } catch (e) {
        print('🔥 [2/5] ❌ ERROR en authStateChanges: $e');
        firstUser = null;
      }

      print('🔥 [2/5] ✅ Primer evento recibido - hasUser: ${firstUser != null}');
      AppLogger.info('Primer evento de authStateChanges recibido', {
        'hasUser': firstUser != null,
        'userId': firstUser?.uid,
      });

      // Procesar el primer usuario
      print('🔥 [3/5] Procesando usuario...');
      if (firstUser != null) {
        print('🔥 [3/5] Usuario encontrado - UID: ${firstUser.uid}, Email verificado: ${firstUser.emailVerified}');
        _emailVerified = firstUser.emailVerified;

        if (!_emailVerified) {
          AppLogger.warning('Email no verificado', {'email': firstUser.email});
          _errorMessage = 'Por favor verifica tu email antes de continuar';
        }

        print('🔥 [3/5] Cargando datos de usuario desde Firestore...');
        await _loadUserData(firstUser.uid);
        print('🔥 [3/5] Persistiendo estado de autenticación...');
        await _persistAuthState();
        print('🔥 [3/5] ✅ Usuario procesado correctamente');
      } else {
        print('🔥 [3/5] Sin usuario autenticado - reseteando estado');
        AppLogger.state('AuthProvider', 'Sin usuario autenticado');
        _resetAuthState();
        await _clearPersistedAuthState();
        print('🔥 [3/5] ✅ Estado reseteado');
      }

      // ✅ CORRECCIÓN MEMORY LEAK: Cancelar listener anterior si existe
      print('🔥 [4/5] Configurando listener de cambios futuros...');
      _authSubscription?.cancel();

      // ✅ Ahora sí, escuchar cambios futuros
      _authSubscription = FirebaseAuth.instance.authStateChanges().skip(1).listen((User? user) async {
        if (user != null) {
          AppLogger.state('AuthProvider', 'Usuario detectado en cambio', {
            'uid': user.uid,
            'email': user.email,
            'emailVerified': user.emailVerified
          });

          _emailVerified = user.emailVerified;

          if (!_emailVerified) {
            AppLogger.warning('Email no verificado', {'email': user.email});
            _errorMessage = 'Por favor verifica tu email antes de continuar';
          }

          await _loadUserData(user.uid);
          await _persistAuthState();
        } else {
          AppLogger.state('AuthProvider', 'Sin usuario autenticado');
          _resetAuthState();
          await _clearPersistedAuthState();
        }
      });
      print('🔥 [4/5] ✅ Listener configurado');
    } finally {
      // ✅ CRÍTICO: Marcar inicialización como completa DESPUÉS del primer evento
      print('🔥 [5/5] Finalizando inicialización...');
      _isInitializing = false;
      notifyListeners();
      print('🔥 [5/5] ✅ INICIALIZACIÓN COMPLETADA - isAuthenticated: $_isAuthenticated, hasUser: ${_currentUser != null}');
      AppLogger.state('AuthProvider', 'Inicialización completada', {
        'isAuthenticated': _isAuthenticated,
        'hasUser': _currentUser != null,
      });
    }
  }
  
  /// Resetear estado de autenticación
  void _resetAuthState() {
    _currentUser = null;
    _isAuthenticated = false;
    _emailVerified = false;
    _phoneVerified = false;
    _verificationId = null;
    notifyListeners();
  }

  /// Cargar datos del usuario desde Firestore
  /// ✅ iOS FIX: Timeout y mejor manejo de errores para evitar crashes silenciosos
  Future<void> _loadUserData(String uid) async {
    AppLogger.state('AuthProvider', 'Cargando datos del usuario', {'uid': uid});
    try {
      // ✅ iOS FIX: Agregar timeout para evitar que la app se cuelgue
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 10));

      if (doc.exists && doc.data() != null) {
        AppLogger.state('AuthProvider', 'Documento de usuario encontrado');
        _currentUser = UserModel.fromFirestore(doc.data()!, uid);
        _isAuthenticated = true;

        // ✅ CORREGIDO: Cargar estado de verificación desde Firestore
        final data = doc.data()!;
        _phoneVerified = data['phoneVerified'] == true;
        _emailVerified = data['emailVerified'] == true;
        _documentVerified = data['documentVerified'] == true;

        // ✅ Logging extendido para debugging
        AppLogger.state('AuthProvider', 'Usuario autenticado correctamente', {
          'userType': _currentUser?.userType,
          'email': _currentUser?.email,
          'phoneVerified': _phoneVerified,
          'emailVerified': _emailVerified,
          'currentMode': _currentUser?.currentMode,
          'activeMode': _currentUser?.activeMode,
          'isDualAccount': _currentUser?.isDualAccount,
          'availableRoles': _currentUser?.availableRoles,
        });
      } else {
        // ✅ iOS FIX: Usuario en Auth pero no en Firestore - NO crashear
        AppLogger.warning('Documento de usuario no existe en Firestore', {'uid': uid});
        _isAuthenticated = false; // Marcar como no autenticado para redirigir a login
      }
    } on TimeoutException {
      // ✅ iOS FIX: Manejar timeout específicamente
      AppLogger.error('Timeout cargando datos de usuario - verificar conexión');
      _errorMessage = 'Tiempo de espera agotado. Verifica tu conexión.';
      _isAuthenticated = false;
    } catch (e) {
      // ✅ iOS FIX: Cualquier error NO debe crashear la app
      AppLogger.error('Error cargando datos del usuario', e);
      _errorMessage = 'Error al cargar datos del usuario';
      _isAuthenticated = false; // Marcar como no autenticado para evitar crash
    }
    notifyListeners();
  }

  /// ✅ NUEVO: Método público para refrescar datos del usuario
  /// Útil después de verificar email, teléfono, etc.
  Future<void> refreshUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _loadUserData(user.uid);
    }
  }

  // Metodo login(email, password) ELIMINADO - Flujo simplificado: solo Google + Telefono

  /// ✅ NUEVO: Verificar si un email ya está registrado (para flujo inteligente)
  /// Retorna: { 'exists': bool, 'userType': String?, 'canUpgrade': bool }
  Future<Map<String, dynamic>> checkEmailExists(String email) async {
    try {
      AppLogger.info('Verificando si email existe', {'email': email});

      // Buscar en Firestore si el email ya está registrado
      final existingUser = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (existingUser.docs.isEmpty) {
        // Email NO existe - puede registrarse
        return {
          'exists': false,
          'userType': null,
          'canUpgrade': false,
          'message': 'Email disponible para registro',
        };
      }

      // Email SÍ existe - analizar si puede upgrade
      final userData = existingUser.docs.first.data();
      final userType = userData['userType'] ?? 'passenger';

      return {
        'exists': true,
        'userType': userType,
        'canUpgrade': userType != 'dual', // Solo puede upgrade si no es dual
        'message': userType == 'dual'
            ? 'Ya tienes cuenta con acceso completo'
            : 'Email ya registrado',
      };
    } catch (e) {
      AppLogger.error('Error verificando email', {'error': e.toString()});
      return {
        'exists': false,
        'userType': null,
        'canUpgrade': false,
        'message': 'Error al verificar email',
        'error': e.toString(),
      };
    }
  }

  /// ✅ NUEVO: Verificar si un teléfono ya está registrado
  /// Retorna: { 'exists': bool, 'email': String?, 'userType': String? }
  Future<Map<String, dynamic>> checkPhoneExists(String phone) async {
    try {
      AppLogger.info('Verificando si teléfono existe', {'phone': phone});

      // Buscar en Firestore si el teléfono ya está registrado
      final existingUser = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();

      if (existingUser.docs.isEmpty) {
        // Teléfono NO existe - puede registrarse
        return {
          'exists': false,
          'email': null,
          'userType': null,
          'message': 'Teléfono disponible para registro',
        };
      }

      // Teléfono SÍ existe
      final userData = existingUser.docs.first.data();
      final userType = userData['userType'] ?? 'passenger';
      final email = userData['email'] ?? '';

      return {
        'exists': true,
        'email': email,
        'userType': userType,
        'message': 'Teléfono ya registrado',
      };
    } catch (e) {
      AppLogger.error('Error verificando teléfono', {'error': e.toString()});
      return {
        'exists': false,
        'email': null,
        'userType': null,
        'message': 'Error al verificar teléfono',
        'error': e.toString(),
      };
    }
  }

  // Metodo register() ELIMINADO - Flujo simplificado: sin registro con email/password

  /// Cerrar sesión
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await FirebaseAuth.instance.signOut();
      _currentUser = null;
      _isAuthenticated = false;

      // Resetear todos los flags de estado al cerrar sesion
      _isRoleSwitchInProgress = false;
      _emailVerified = false;
      _phoneVerified = false;
      _documentVerified = false;
      _verificationId = null;
      _pendingPhoneNumber = null;
      _errorMessage = null;

      await _firebaseService.logEvent('logout', null);
      AppLogger.info('Sesión cerrada y estados limpiados correctamente');
    } catch (e) {
      debugPrint('Error al cerrar sesión: $e');
      await _firebaseService.recordError(e, null);
    }

    _isLoading = false;
    notifyListeners();
  }

  // Metodo resetPassword() ELIMINADO - Flujo simplificado: sin contrasena

  /// Actualizar perfil del usuario
  Future<bool> updateProfile(Map<String, dynamic> updates) async {
    if (_currentUser == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      // Actualizar en Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.id)
          .update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Actualizar localmente
      _currentUser = UserModel.fromJson({
        ..._currentUser!.toJson(),
        ...updates,
      });

      await _firebaseService.logEvent('profile_update', updates);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      // ✅ Usar handler para mensaje amigable en español
      _errorMessage = FirestoreErrorHandler.getSpanishMessage(e);
      await _firebaseService.recordError(e, null);
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Cambiar contraseña
  Future<bool> changePassword(String currentPassword, String newPassword) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        throw Exception('Usuario no autenticado');
      }

      // Re-autenticar
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // Cambiar contraseña
      await user.updatePassword(newPassword);
      
      await _firebaseService.logEvent('password_change', null);

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
    } catch (e) {
      // ✅ Usar handler para mensaje amigable en español
      _errorMessage = FirestoreErrorHandler.getSpanishMessage(e);
      await _firebaseService.recordError(e, null);
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Verificar email
  /// Enviar email de verificación
  Future<bool> verifyEmail() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        return true;
      }
    } catch (e) {
      debugPrint('Error verificando email: $e');
      await _firebaseService.recordError(e, null);
    }
    return false;
  }

  /// Verificar y sincronizar estado de email verificado desde Firebase Auth a Firestore
  Future<bool> checkAndSyncEmailVerification() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Refrescar estado de Firebase Auth
      await user.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser;

      if (refreshedUser != null && refreshedUser.emailVerified) {
        // Si Firebase Auth dice que el email está verificado, actualizar Firestore
        if (!_emailVerified) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(refreshedUser.uid)
              .update({
            'emailVerified': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          _emailVerified = true;
          notifyListeners();
          AppLogger.info('✅ Email verificado sincronizado con Firestore');
        }
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.error('Error sincronizando verificación de email', e);
      return false;
    }
  }

  /// Manejar errores de autenticación con mensajes detallados
  void _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        _errorMessage = 'No existe una cuenta con este email';
        break;
      case 'wrong-password':
        _errorMessage = 'Contrasena incorrecta';
        break;
      case 'email-already-in-use':
        _errorMessage = 'Este email ya está registrado. ¿Olvidaste tu contraseña?';
        break;
      case 'invalid-email':
        _errorMessage = 'El formato del email no es válido';
        break;
      case 'weak-password':
        _errorMessage = 'La contraseña no cumple con los requisitos de seguridad';
        break;
      case 'network-request-failed':
        _errorMessage = 'Error de conexión. Verifica tu internet';
        break;
      case 'too-many-requests':
        _errorMessage = 'Demasiados intentos. Por favor espera unos minutos';
        break;
      case 'user-disabled':
        _errorMessage = 'Esta cuenta ha sido deshabilitada. Contacta soporte';
        break;
      case 'operation-not-allowed':
        _errorMessage = 'Esta operación no está permitida';
        break;
      default:
        _errorMessage = 'Error de autenticación: ${e.message}';
    }
  }

  /// Iniciar sesión con Google
  Future<bool> signInWithGoogle() async {
    print('🔵 AuthProvider - signInWithGoogle() iniciado');
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      print('🔵 AuthProvider - Llamando a _firebaseService.signInWithGoogle()');
      final user = await _firebaseService.signInWithGoogle();
      print('🔵 AuthProvider - Respuesta recibida, usuario: ${user?.email ?? 'null'}');

      if (user != null) {
        print('🔵 AuthProvider - Cargando datos del usuario');
        await _loadUserData(user.uid);
        _isAuthenticated = true;

        await _firebaseService.logEvent('google_login_success', {
          'user_id': user.uid,
          'method': 'google',
        });

        _isLoading = false;
        notifyListeners();
        print('✅ AuthProvider - Login con Google EXITOSO');
        return true;
      } else {
        print('⚠️ AuthProvider - Usuario es null después del sign-in');
      }
    } catch (e) {
      print('❌ AuthProvider - ERROR CAPTURADO:');
      print('   Tipo: ${e.runtimeType}');
      print('   Mensaje: $e');

      // Manejar errores específicos de Google Sign-In
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('12501') || errorStr.contains('sign_in_canceled') || errorStr.contains('cancelled')) {
        _errorMessage = 'Inicio de sesión cancelado. Intenta nuevamente.';
      } else if (errorStr.contains('12500') || errorStr.contains('sign_in_failed')) {
        _errorMessage = 'Error de configuración de Google. Contacta soporte.';
      } else if (errorStr.contains('network') || errorStr.contains('connection')) {
        _errorMessage = 'Sin conexión a internet. Verifica tu red.';
      } else {
        _errorMessage = 'Error al iniciar sesión con Google. Intenta nuevamente.';
      }

      await _firebaseService.recordError(e, null);
    }

    _isLoading = false;
    notifyListeners();
    print('❌ AuthProvider - Login con Google FALLÓ');
    return false;
  }


  /// Limpiar mensajes de error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
  
  // ==================== METODOS DE VALIDACION ====================
  // Metodos eliminados: _validateEmail(), _validatePassword(),
  // _validatePasswordStrength(), _validateFullName()
  // Solo queda _validatePhoneNumber() que se usa en startPhoneVerification()
  
  /// Validar número de teléfono peruano - VALIDACIÓN ESTRICTA OBLIGATORIA
  bool _validatePhoneNumber(String phone) {
    // CRÍTICO: Usar validación centralizada de ValidationPatterns
    // NO permitir bypass bajo NINGUNA circunstancia
    return ValidationPatterns.isValidPeruMobile(phone);
  }
  
  // Metodo _validateFullName() ELIMINADO - Solo se usaba en register()
  
  // Metodos de rate limiting ELIMINADOS (_checkAccountLock, _incrementLoginAttempts,
  // _getRemainingLockTime, resetAccountLock) - Ya no hay login con email/password

  /// Cargar estado de seguridad (simplificado: solo limpiar datos obsoletos)
  Future<void> _loadSecurityState() async {
    final prefs = await SharedPreferences.getInstance();

    // Limpiar datos de seguridad del SecurityService al iniciar
    try {
      await SecurityService().clearAllSecurityData();
      AppLogger.info('SecurityService: Datos de seguridad limpiados al iniciar');
    } catch (e) {
      AppLogger.warning('Error limpiando SecurityService: $e');
    }

    // Limpiar claves obsoletas de rate limiting
    await prefs.remove('login_attempts');
    await prefs.remove('account_locked');
    await prefs.remove('locked_until');

    AppLogger.info('AuthProvider: Estado de seguridad cargado');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PERSISTENCIA DE SESIÓN
  // ═══════════════════════════════════════════════════════════════════════════

  /// Persistir estado de autenticación en SharedPreferences
  Future<void> _persistAuthState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_authenticated', _isAuthenticated);
      await prefs.setBool('email_verified', _emailVerified);
      await prefs.setBool('phone_verified', _phoneVerified);

      if (_currentUser != null) {
        await prefs.setString('user_id', _currentUser!.id);
        await prefs.setString('user_type', _currentUser!.userType);
        await prefs.setString('user_email', _currentUser!.email);
        if (_currentUser!.currentMode != null) {
          await prefs.setString('current_mode', _currentUser!.currentMode!);
        }
      }

      AppLogger.debug('Estado de autenticación persistido exitosamente');
    } catch (e) {
      AppLogger.error('Error persistiendo estado de autenticación: $e');
    }
  }

  /// Limpiar estado de autenticación persistido
  Future<void> _clearPersistedAuthState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('is_authenticated');
      await prefs.remove('email_verified');
      await prefs.remove('phone_verified');
      await prefs.remove('user_id');
      await prefs.remove('user_type');
      await prefs.remove('user_email');
      await prefs.remove('current_mode');

      AppLogger.debug('Estado de autenticación limpiado exitosamente');
    } catch (e) {
      AppLogger.error('Error limpiando estado de autenticación: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════

  /// Obtener ID del dispositivo
  Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('device_id');
    
    if (deviceId == null) {
      // Generar nuevo ID de dispositivo
      final random = math.Random.secure();
      final values = List<int>.generate(32, (i) => random.nextInt(256));
      deviceId = base64Url.encode(values);
      await prefs.setString('device_id', deviceId);
    }
    
    return deviceId;
  }
  
  // Metodo _hashPhone() ELIMINADO - Solo se usaba en register()
  
  /// Registrar evento de seguridad
  Future<void> _logSecurityEvent(String eventType, Map<String, dynamic> data) async {
    try {
      await FirebaseFirestore.instance.collection('security_logs').add({
        'event_type': eventType,
        'timestamp': FieldValue.serverTimestamp(),
        'device_id': await _getDeviceId(),
        'data': data,
      });
    } catch (e) {
      AppLogger.error('Error al registrar evento de seguridad', e);
    }
  }
  
  // ==================== AUTENTICACIÓN CON TELÉFONO ====================
  
  /// Iniciar verificación con teléfono - SISTEMA ANTI-BYPASS
  Future<bool> startPhoneVerification(String phoneNumber) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      // VALIDACIÓN CRÍTICA: Triple verificación obligatoria
      if (!_validatePhoneNumber(phoneNumber)) {
        _errorMessage = 'Número de teléfono peruano inválido. Debe ser 9XXXXXXXX';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      // Verificación adicional con patrón directo (redundancia de seguridad)
      if (!RegExp(r'^9[0-9]{8}$').hasMatch(phoneNumber)) {
        _errorMessage = 'Formato de número incorrecto. Use formato: 9XXXXXXXX';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      // Verificación de operador móvil válido
      final operatorCode = phoneNumber.substring(0, 2);
      final validOperators = {'90', '91', '92', '93', '94', '95', '96', '97', '98', '99'};
      if (!validOperators.contains(operatorCode)) {
        _errorMessage = 'Operador móvil no válido. Use un número de Claro, Movistar o Entel';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      _pendingPhoneNumber = phoneNumber;
      final fullPhoneNumber = ValidationPatterns.formatForFirebaseAuth(phoneNumber);

      // 🔍 LOG DETALLADO para debugging SMS - usando print() para modo release
      print('📱 ========================================');
      print('📱 ENVIANDO SMS DE VERIFICACIÓN');
      print('📱 ========================================');
      print('📱 Número ingresado: $phoneNumber');
      print('📱 Número formateado: $fullPhoneNumber');

      // 🔍 DEBUG: Verificar estado de autenticación actual
      final currentUser = FirebaseAuth.instance.currentUser;
      print('📱 Usuario actual: ${currentUser?.uid ?? "NINGUNO"}');
      print('📱 Email usuario: ${currentUser?.email ?? "N/A"}');
      print('📱 Providers vinculados: ${currentUser?.providerData.map((p) => p.providerId).toList() ?? []}');

      print('📱 Llamando a Firebase verifyPhoneNumber...');

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: fullPhoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verificación en Android
          print('✅ verificationCompleted - SMS verificado automáticamente');
          print('✅ Credential recibido: ${credential.smsCode ?? "auto"}');
          _phoneVerified = true;
          _errorMessage = null;
          _isLoading = false;
          notifyListeners();
          print('✅ Credenciales guardadas - usuario debe completar perfil antes de login');
        },
        verificationFailed: (FirebaseAuthException e) {
          print('❌ verificationFailed callback ejecutado');
          print('❌ Código de error: ${e.code}');
          print('❌ Mensaje: ${e.message}');
          print('❌ Stack: ${e.stackTrace}');
          _errorMessage = 'Error de verificación: ${e.message}';
          _isLoading = false;
          notifyListeners();
        },
        codeSent: (String verificationId, int? resendToken) {
          print('✅ codeSent callback ejecutado - SMS enviado!');
          print('✅ verificationId: ${verificationId.substring(0, 20)}...');
          print('✅ resendToken: $resendToken');
          _verificationId = verificationId;
          _isLoading = false;
          notifyListeners();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          print('⏱️ codeAutoRetrievalTimeout - Timeout de auto-recuperación');
          print('⏱️ verificationId en timeout: ${verificationId.substring(0, 20)}...');
          _verificationId = verificationId;
        },
        timeout: Duration(seconds: 120), // Aumentado a 120 segundos
      );

      print('📱 verifyPhoneNumber() ha retornado - esperando callbacks...');
      return true;
    } catch (e) {
      // ✅ Usar handler para mensaje amigable en español
      _errorMessage = FirestoreErrorHandler.getSpanishMessage(e);
      await _firebaseService.recordError(e, null);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Verificar código OTP y vincular teléfono a Firebase Auth
  Future<bool> verifyOTP(String otp) async {
    if (_verificationId == null) {
      _errorMessage = 'No hay verificación pendiente';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Crear el credential con el OTP
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      // Verificar si hay usuario autenticado para vincular el teléfono
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // Verificar si ya tiene el proveedor de teléfono vinculado
        final hasPhoneProvider = currentUser.providerData
            .any((provider) => provider.providerId == 'phone');

        if (!hasPhoneProvider) {
          try {
            // Vincular el teléfono a la cuenta existente
            await currentUser.linkWithCredential(credential);
            AppLogger.info('✅ Teléfono vinculado a Firebase Auth exitosamente');
          } catch (linkError) {
            // Si falla el link (ej: teléfono ya usado), solo logear pero continuar
            AppLogger.warning('⚠️ No se pudo vincular teléfono a Auth: $linkError');
          }
        }
      }

      // OTP verificado exitosamente
      AppLogger.info('✅ OTP verificado exitosamente');
      _phoneVerified = true;
      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
      AppLogger.info('✅ Credenciales guardadas - usuario debe completar perfil antes de login');
      return true;
    } catch (e) {
      _errorMessage = 'Código inválido';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Reenviar código OTP
  Future<bool> resendOTP() async {
    if (_pendingPhoneNumber == null) {
      _errorMessage = 'No hay número pendiente de verificación';
      notifyListeners();
      return false;
    }

    return await startPhoneVerification(_pendingPhoneNumber!);
  }

  // ==================== SISTEMA DUAL-ACCOUNT (INDRIVER STYLE) ====================

  /// Actualizar cuenta existente a dual-account (pasajero + conductor)
  ///
  /// Este método permite que un usuario pasajero se convierta en conductor (o viceversa)
  /// manteniendo la misma cuenta. Implementa el modelo InDriver de dual-account.
  ///
  /// Cambiar entre modo pasajero y conductor (solo para cuentas dual)
  ///
  /// Permite a usuarios con dual-account cambiar su modo activo.
  /// El usuario debe tener userType='dual' y el modo solicitado debe estar
  /// en availableRoles.
  ///
  /// @param newMode 'passenger', 'driver' o 'admin'
  /// @return true si el cambio fue exitoso
  Future<bool> switchMode(String newMode) async {
    // Validar que el modo sea válido
    if (newMode != 'passenger' && newMode != 'driver' && newMode != 'admin') {
      _errorMessage = 'Modo inválido. Usa "passenger", "driver" o "admin"';
      notifyListeners();
      return false;
    }

    // Validar que haya usuario autenticado
    if (_currentUser == null) {
      _errorMessage = 'No hay usuario autenticado';
      notifyListeners();
      return false;
    }

    // Admins con múltiples roles SÍ pueden cambiar de modo
    // Solo bloquear si es admin sin roles adicionales
    if ((_currentUser!.isAdmin || _currentUser!.userType == 'admin') &&
        (_currentUser!.availableRoles == null || _currentUser!.availableRoles!.length <= 1)) {
      _errorMessage = 'La cuenta admin no tiene otros roles disponibles';
      AppLogger.warning('Intento bloqueado de cambio de modo para admin sin roles', {
        'userId': _currentUser!.id,
        'intentedMode': newMode,
      });
      notifyListeners();
      return false;
    }

    // Validar que el usuario tenga múltiples roles disponibles
    if (_currentUser!.availableRoles == null ||
        _currentUser!.availableRoles!.length <= 1) {
      _errorMessage = 'Tu cuenta solo tiene un rol disponible';
      notifyListeners();
      return false;
    }

    // Validar que el modo solicitado esté disponible
    if (!_currentUser!.availableRoles!.contains(newMode)) {
      _errorMessage = 'No tienes acceso al modo $newMode';
      notifyListeners();
      return false;
    }

    // Si ya está en ese modo, no hacer nada
    if (_currentUser!.currentMode == newMode) {
      _errorMessage = 'Ya estás en modo $newMode';
      notifyListeners();
      return true;
    }

    _isLoading = true;
    _isRoleSwitchInProgress = true; // ✅ Marcar inicio de cambio de rol
    notifyListeners();

    try {
      final oldMode = _currentUser!.currentMode;

      AppLogger.info('Cambiando modo de usuario', {
        'userId': _currentUser!.id,
        'from': oldMode,
        'to': newMode,
      });

      // ✅ Pequeño delay para permitir que listeners del rol anterior se detengan
      await Future.delayed(const Duration(milliseconds: 100));

      // ✅ FIX: Actualizar estado local PRIMERO para UI instantánea (optimistic update)
      _currentUser = _currentUser!.copyWith(currentMode: newMode);
      notifyListeners(); // UI se actualiza INMEDIATAMENTE con nuevo modo

      AppLogger.debug('Estado local actualizado, UI ya muestra nuevo modo', {
        'newMode': newMode,
      });

      // LUEGO actualizar currentMode en Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.id)
          .update({
        'currentMode': newMode,
        'updatedAt': FieldValue.serverTimestamp(),
        'modeHistory': FieldValue.arrayUnion([{
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'from': oldMode,
          'to': newMode,
        }]),
      });

      // Manejar topics FCM: desuscribir del anterior, suscribir al nuevo
      try {
        String oldTopic;
        String newTopic;

        // Determinar topic según modo
        switch (oldMode) {
          case 'driver':
            oldTopic = 'drivers';
            break;
          case 'admin':
            oldTopic = 'admins';
            break;
          case 'passenger':
          default:
            oldTopic = 'passengers';
            break;
        }

        switch (newMode) {
          case 'driver':
            newTopic = 'drivers';
            break;
          case 'admin':
            newTopic = 'admins';
            break;
          case 'passenger':
          default:
            newTopic = 'passengers';
            break;
        }

        // Desuscribirse del topic anterior
        await FCMService().unsubscribeFromTopic(oldTopic);
        // Suscribirse al nuevo topic
        await FCMService().subscribeToTopic(newTopic);

        AppLogger.info('Topics FCM actualizados por cambio de modo', {
          'oldTopic': oldTopic,
          'newTopic': newTopic,
        });
      } catch (e) {
        AppLogger.error('Error al actualizar topics FCM', e);
        // No fallar el switch si hay error en FCM
      }

      // Registrar evento en Analytics
      await _firebaseService.logEvent('mode_switch', {
        'user_id': _currentUser!.id,
        'from_mode': oldMode,
        'to_mode': newMode,
      });

      // Log de seguridad
      await _logSecurityEvent('MODE_SWITCHED', {
        'user_id': _currentUser!.id,
        'from_mode': oldMode,
        'to_mode': newMode,
      });

      // ✅ FIX: NO recargar desde Firestore porque puede sobreescribir el optimistic update
      // El estado local ya está correcto (línea 1221-1222) y Firestore se actualizó (línea 1229)
      // Recargar causaría race condition si Firestore aún no sincronizó
      // await _loadUserData(_currentUser!.id); // ❌ REMOVIDO: causaba desincronización

      AppLogger.info('Cambio de modo exitoso', {
        'userId': _currentUser!.id,
        'newMode': newMode,
      });

      _isLoading = false;
      _isRoleSwitchInProgress = false; // ✅ Marcar fin de cambio de rol
      _errorMessage = null;
      notifyListeners();
      return true;

    } catch (e, stackTrace) {
      AppLogger.error('Error al cambiar modo', e, stackTrace);
      // ✅ Usar handler para mensaje amigable en español
      _errorMessage = FirestoreErrorHandler.getSpanishMessage(e);
      await _firebaseService.recordError(e, stackTrace);
      _isLoading = false;
      _isRoleSwitchInProgress = false; // ✅ También resetear en error
      notifyListeners();
      return false;
    }
  }

  /// Recargar datos del usuario actual desde Firestore
  /// Útil después de cambios significativos en el perfil
  Future<void> reloadUserData() async {
    if (_currentUser == null) {
      AppLogger.warning('No se puede recargar: usuario no autenticado');
      return;
    }

    AppLogger.state('AuthProvider', 'Recargando datos del usuario', {
      'uid': _currentUser!.id,
    });

    try {
      await _loadUserData(_currentUser!.id);
      AppLogger.info('Datos del usuario recargados exitosamente');
    } catch (e) {
      AppLogger.error('Error al recargar datos del usuario', e);
    }
  }

  // ==================== UPGRADE PÚBLICO PARA USUARIOS AUTENTICADOS ====================

  /// Agregar rol de conductor a usuario autenticado (método público)
  ///
  /// Este método es para usuarios que YA están autenticados y quieren
  /// agregar el rol de conductor. NO requiere password porque el usuario
  /// ya pasó por autenticación de Firebase.
  ///
  /// @param driverData Datos del conductor (DNI, licencia, vehículo)
  /// @param dniPhoto Foto del documento de identidad
  /// @param licensePhoto Foto de la licencia de conducir
  /// @param vehiclePhoto Foto del vehículo
  /// @param criminalRecordPhoto Foto de antecedentes penales (opcional)
  /// @param soatPhoto Foto del SOAT (opcional)
  /// @param technicalReviewPhoto Foto de revisión técnica (opcional)
  /// @param ownershipPhoto Foto de tarjeta de propiedad (opcional)
  /// @return true si el upgrade fue exitoso
  Future<bool> upgradeToDriver({
    required Map<String, dynamic> driverData,
    File? dniPhoto,
    File? licensePhoto,
    File? vehiclePhoto,
    // ✅ NUEVO: Documentos adicionales de verificación
    File? criminalRecordPhoto,
    File? soatPhoto,
    File? technicalReviewPhoto,
    File? ownershipPhoto,
  }) async {
    // Validar que el usuario esté autenticado
    if (_currentUser == null) {
      _errorMessage = 'No hay usuario autenticado';
      AppLogger.error('upgradeToDriver FALLÓ: No hay usuario autenticado');
      notifyListeners();
      return false;
    }

    // ✅ DEBUG: Loguear estado actual del usuario
    AppLogger.critical('🔍 upgradeToDriver - Estado del usuario:', {
      'userType': _currentUser!.userType,
      'driverStatus': _currentUser!.driverStatus,
      'documentVerified': _currentUser!.documentVerified,
      'email': _currentUser!.email,
    });

    // ✅ CORREGIDO: Validar que el usuario pueda convertirse en conductor
    // Casos válidos:
    // 1. Pasajero (passenger) que quiere hacer upgrade a dual
    // 2. Conductor nuevo (driver con driverStatus=pending_documents) que necesita subir documentos
    final bool isPassengerUpgrade = _currentUser!.userType == 'passenger';
    final bool isNewDriverCompletingRegistration =
        _currentUser!.userType == 'driver' &&
        (_currentUser!.driverStatus == 'pending_documents' || _currentUser!.driverStatus == null);

    AppLogger.critical('🔍 upgradeToDriver - Validación:', {
      'isPassengerUpgrade': isPassengerUpgrade,
      'isNewDriverCompletingRegistration': isNewDriverCompletingRegistration,
    });

    if (!isPassengerUpgrade && !isNewDriverCompletingRegistration) {
      // Ya es conductor aprobado o dual, no puede hacer upgrade
      if (_currentUser!.userType == 'dual') {
        _errorMessage = 'Ya tienes cuenta de conductor activa';
      } else if (_currentUser!.driverStatus == 'pending_approval') {
        _errorMessage = 'Tus documentos ya están en revisión';
      } else if (_currentUser!.driverStatus == 'approved') {
        _errorMessage = 'Ya eres conductor aprobado';
      } else {
        _errorMessage = 'No puedes realizar esta acción';
      }
      notifyListeners();
      return false;
    }

    // Validar que Firebase Auth tenga usuario activo
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      _errorMessage = 'Sesión expirada. Por favor inicia sesión de nuevo';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      AppLogger.info('Iniciando proceso de conductor', {
        'userId': _currentUser!.id,
        'email': _currentUser!.email,
        'isPassengerUpgrade': isPassengerUpgrade,
        'isNewDriverCompletingRegistration': isNewDriverCompletingRegistration,
      });

      // PASO 1: Subir fotos a Firebase Storage con bucket correcto
      final storage = FirebaseStorage.instance;
      final userId = _currentUser!.id;
      String? dniPhotoUrl;
      String? licensePhotoUrl;
      String? vehiclePhotoUrl;
      // ✅ NUEVO: URLs para documentos adicionales de verificación
      String? criminalRecordPhotoUrl;
      String? soatPhotoUrl;
      String? technicalReviewPhotoUrl;
      String? ownershipPhotoUrl;

      if (dniPhoto != null) {
        AppLogger.debug('Subiendo documento de DNI...');
        try {
          final timestamp = DateTime.now().millisecondsSinceEpoch;

          // ✅ NUEVO: Detectar tipo de archivo por extensión
          final filePath = dniPhoto.path.toLowerCase();
          final isPdf = filePath.endsWith('.pdf');
          final extension = isPdf ? 'pdf' : 'jpg';
          final contentType = isPdf ? 'application/pdf' : 'image/jpeg';

          // ✅ CORREGIDO: Usar ruta que coincide con storage.rules (drivers/{driverId}/documents/{documentId})
          final dniRef = storage.ref('drivers/$userId/documents/dni_$timestamp.$extension');

          final metadata = SettableMetadata(
            contentType: contentType,
            customMetadata: {
              'uploadedBy': userId,
              'documentType': 'dni',
              'fileType': isPdf ? 'pdf' : 'image',
            },
          );

          final uploadTask = await dniRef.putFile(dniPhoto, metadata);
          dniPhotoUrl = await uploadTask.ref.getDownloadURL();
          AppLogger.info('✅ Documento de DNI subido exitosamente', {
            'url': dniPhotoUrl,
            'type': contentType,
          });
        } catch (e) {
          AppLogger.error('Error subiendo documento de DNI', e);
          throw Exception('Error al subir documento de DNI: $e');
        }
      }

      if (licensePhoto != null) {
        AppLogger.debug('Subiendo documento de licencia...');
        try {
          final timestamp = DateTime.now().millisecondsSinceEpoch;

          // ✅ NUEVO: Detectar tipo de archivo por extensión
          final filePath = licensePhoto.path.toLowerCase();
          final isPdf = filePath.endsWith('.pdf');
          final extension = isPdf ? 'pdf' : 'jpg';
          final contentType = isPdf ? 'application/pdf' : 'image/jpeg';

          // ✅ CORREGIDO: Usar ruta que coincide con storage.rules (drivers/{driverId}/documents/{documentId})
          final licenseRef = storage.ref('drivers/$userId/documents/license_$timestamp.$extension');

          final metadata = SettableMetadata(
            contentType: contentType,
            customMetadata: {
              'uploadedBy': userId,
              'documentType': 'license',
              'fileType': isPdf ? 'pdf' : 'image',
            },
          );

          final uploadTask = await licenseRef.putFile(licensePhoto, metadata);
          licensePhotoUrl = await uploadTask.ref.getDownloadURL();
          AppLogger.info('✅ Documento de licencia subido exitosamente', {
            'url': licensePhotoUrl,
            'type': contentType,
          });
        } catch (e) {
          AppLogger.error('Error subiendo documento de licencia', e);
          throw Exception('Error al subir documento de licencia: $e');
        }
      }

      if (vehiclePhoto != null) {
        AppLogger.debug('Subiendo documento de vehículo...');
        try {
          final timestamp = DateTime.now().millisecondsSinceEpoch;

          // ✅ NUEVO: Detectar tipo de archivo por extensión
          final filePath = vehiclePhoto.path.toLowerCase();
          final isPdf = filePath.endsWith('.pdf');
          final extension = isPdf ? 'pdf' : 'jpg';
          final contentType = isPdf ? 'application/pdf' : 'image/jpeg';

          // ✅ CORREGIDO: Usar ruta que coincide con storage.rules (drivers/{driverId}/documents/{documentId})
          final vehicleRef = storage.ref('drivers/$userId/documents/vehicle_$timestamp.$extension');

          final metadata = SettableMetadata(
            contentType: contentType,
            customMetadata: {
              'uploadedBy': userId,
              'documentType': 'vehicle',
              'fileType': isPdf ? 'pdf' : 'image',
            },
          );

          final uploadTask = await vehicleRef.putFile(vehiclePhoto, metadata);
          vehiclePhotoUrl = await uploadTask.ref.getDownloadURL();
          AppLogger.info('✅ Documento de vehículo subido exitosamente', {
            'url': vehiclePhotoUrl,
            'type': contentType,
          });
        } catch (e) {
          AppLogger.error('Error subiendo documento de vehículo', e);
          throw Exception('Error al subir documento de vehículo: $e');
        }
      }

      // ✅ NUEVO: Subir documentos adicionales de verificación
      if (criminalRecordPhoto != null) {
        AppLogger.debug('Subiendo antecedentes penales...');
        try {
          final timestamp = DateTime.now().millisecondsSinceEpoch;

          // Detectar tipo de archivo por extensión
          final filePath = criminalRecordPhoto.path.toLowerCase();
          final isPdf = filePath.endsWith('.pdf');
          final extension = isPdf ? 'pdf' : 'jpg';
          final contentType = isPdf ? 'application/pdf' : 'image/jpeg';

          // ✅ CORREGIDO: Usar ruta que coincide con storage.rules (drivers/{driverId}/documents/{documentId})
          final criminalRecordRef = storage.ref('drivers/$userId/documents/criminal_record_$timestamp.$extension');

          final metadata = SettableMetadata(
            contentType: contentType,
            customMetadata: {
              'uploadedBy': userId,
              'documentType': 'criminal_record',
              'fileType': isPdf ? 'pdf' : 'image',
            },
          );

          final uploadTask = await criminalRecordRef.putFile(criminalRecordPhoto, metadata);
          criminalRecordPhotoUrl = await uploadTask.ref.getDownloadURL();
          AppLogger.info('✅ Antecedentes penales subidos exitosamente', {
            'url': criminalRecordPhotoUrl,
            'type': contentType,
          });
        } catch (e) {
          AppLogger.error('Error subiendo antecedentes penales', e);
          throw Exception('Error al subir antecedentes penales: $e');
        }
      }

      if (soatPhoto != null) {
        AppLogger.debug('Subiendo SOAT...');
        try {
          final timestamp = DateTime.now().millisecondsSinceEpoch;

          // Detectar tipo de archivo por extensión
          final filePath = soatPhoto.path.toLowerCase();
          final isPdf = filePath.endsWith('.pdf');
          final extension = isPdf ? 'pdf' : 'jpg';
          final contentType = isPdf ? 'application/pdf' : 'image/jpeg';

          // ✅ CORREGIDO: Usar ruta que coincide con storage.rules (drivers/{driverId}/documents/{documentId})
          final soatRef = storage.ref('drivers/$userId/documents/soat_$timestamp.$extension');

          final metadata = SettableMetadata(
            contentType: contentType,
            customMetadata: {
              'uploadedBy': userId,
              'documentType': 'soat',
              'fileType': isPdf ? 'pdf' : 'image',
            },
          );

          final uploadTask = await soatRef.putFile(soatPhoto, metadata);
          soatPhotoUrl = await uploadTask.ref.getDownloadURL();
          AppLogger.info('✅ SOAT subido exitosamente', {
            'url': soatPhotoUrl,
            'type': contentType,
          });
        } catch (e) {
          AppLogger.error('Error subiendo SOAT', e);
          throw Exception('Error al subir SOAT: $e');
        }
      }

      if (technicalReviewPhoto != null) {
        AppLogger.debug('Subiendo revisión técnica...');
        try {
          final timestamp = DateTime.now().millisecondsSinceEpoch;

          // Detectar tipo de archivo por extensión
          final filePath = technicalReviewPhoto.path.toLowerCase();
          final isPdf = filePath.endsWith('.pdf');
          final extension = isPdf ? 'pdf' : 'jpg';
          final contentType = isPdf ? 'application/pdf' : 'image/jpeg';

          // ✅ CORREGIDO: Usar ruta que coincide con storage.rules (drivers/{driverId}/documents/{documentId})
          final technicalReviewRef = storage.ref('drivers/$userId/documents/technical_review_$timestamp.$extension');

          final metadata = SettableMetadata(
            contentType: contentType,
            customMetadata: {
              'uploadedBy': userId,
              'documentType': 'technical_review',
              'fileType': isPdf ? 'pdf' : 'image',
            },
          );

          final uploadTask = await technicalReviewRef.putFile(technicalReviewPhoto, metadata);
          technicalReviewPhotoUrl = await uploadTask.ref.getDownloadURL();
          AppLogger.info('✅ Revisión técnica subida exitosamente', {
            'url': technicalReviewPhotoUrl,
            'type': contentType,
          });
        } catch (e) {
          AppLogger.error('Error subiendo revisión técnica', e);
          throw Exception('Error al subir revisión técnica: $e');
        }
      }

      if (ownershipPhoto != null) {
        AppLogger.debug('Subiendo tarjeta de propiedad...');
        try {
          final timestamp = DateTime.now().millisecondsSinceEpoch;

          // Detectar tipo de archivo por extensión
          final filePath = ownershipPhoto.path.toLowerCase();
          final isPdf = filePath.endsWith('.pdf');
          final extension = isPdf ? 'pdf' : 'jpg';
          final contentType = isPdf ? 'application/pdf' : 'image/jpeg';

          // ✅ CORREGIDO: Usar ruta que coincide con storage.rules (drivers/{driverId}/documents/{documentId})
          final ownershipRef = storage.ref('drivers/$userId/documents/ownership_$timestamp.$extension');

          final metadata = SettableMetadata(
            contentType: contentType,
            customMetadata: {
              'uploadedBy': userId,
              'documentType': 'ownership',
              'fileType': isPdf ? 'pdf' : 'image',
            },
          );

          final uploadTask = await ownershipRef.putFile(ownershipPhoto, metadata);
          ownershipPhotoUrl = await uploadTask.ref.getDownloadURL();
          AppLogger.info('✅ Tarjeta de propiedad subida exitosamente', {
            'url': ownershipPhotoUrl,
            'type': contentType,
          });
        } catch (e) {
          AppLogger.error('Error subiendo tarjeta de propiedad', e);
          throw Exception('Error al subir tarjeta de propiedad: $e');
        }
      }

      // PASO 2: Crear documento de conductor en colección 'drivers'
      // ✅ CORREGIDO: Transferir TODOS los datos del pasajero al perfil de conductor
      final driverDocData = {
        'userId': userId,
        'email': _currentUser!.email,
        'fullName': _currentUser!.fullName,
        'phone': _currentUser!.phone,
        // ✅ NUEVO: Transferir foto de perfil del pasajero al conductor
        'profilePhotoUrl': _currentUser!.profilePhotoUrl,
        'dni': driverData['dni'],
        'license': driverData['license'],
        // ✅ FIX: Guardar como 'vehicleInfo' (no 'vehicle') para coincidir con UserModel
        'vehicleInfo': driverData['vehicleInfo'] ?? driverData['vehicle'],
        'documents': {
          // ✅ Documentos básicos requeridos
          'dniPhoto': dniPhotoUrl,
          'licensePhoto': licensePhotoUrl,
          'vehiclePhoto': vehiclePhotoUrl,
          // ✅ NUEVO: Documentos adicionales de verificación
          'criminalRecordPhoto': criminalRecordPhotoUrl,
          'soatPhoto': soatPhotoUrl,
          'technicalReviewPhoto': technicalReviewPhotoUrl,
          'ownershipPhoto': ownershipPhotoUrl,
        },
        'status': 'pending_approval', // Requiere aprobación del admin
        'isActive': false, // Se activa después de aprobación
        'verificationStatus': 'pending',
        // ✅ NUEVO: Transferir rating y trips existentes del pasajero
        'rating': _currentUser!.rating,
        'totalTrips': _currentUser!.totalTrips,
        'completedTrips': 0,
        'cancelledTrips': 0,
        'earnings': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(userId)
          .set(driverDocData);

      AppLogger.info('Documento de conductor creado en Firestore');

      // PASO 3: Actualizar usuario según el caso
      // Caso 1: Pasajero → Dual (upgrade)
      // Caso 2: Conductor nuevo → Solo actualizar driverStatus y agregar documentos
      final Map<String, dynamic> userUpdateData = {
        'driverStatus': 'pending_approval',
        'vehicleInfo': driverData['vehicleInfo'] ?? driverData['vehicle'],
        'dni': driverData['dni'],
        'license': driverData['license'],
        'documents': {
          'dniPhoto': dniPhotoUrl ?? '',
          'licensePhoto': licensePhotoUrl ?? '',
          'vehiclePhoto': vehiclePhotoUrl ?? '',
          'criminalRecordPhoto': criminalRecordPhotoUrl ?? '',
          'soatPhoto': soatPhotoUrl ?? '',
          'technicalReviewPhoto': technicalReviewPhotoUrl ?? '',
          'ownershipPhoto': ownershipPhotoUrl ?? '',
        },
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (isPassengerUpgrade) {
        // Pasajero haciendo upgrade a dual
        userUpdateData['userType'] = 'dual';
        userUpdateData['currentMode'] = 'passenger'; // Mantener como pasajero hasta aprobación
        userUpdateData['availableRoles'] = ['passenger', 'driver'];
        userUpdateData['upgradeHistory'] = FieldValue.arrayUnion([{
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'from': 'passenger',
          'to': 'dual',
          'requestedRole': 'driver',
        }]);
        AppLogger.info('Actualizando pasajero a dual-account');
      } else {
        // Conductor nuevo completando registro (ya es driver, solo actualizar estado)
        userUpdateData['currentMode'] = 'passenger'; // Usar como pasajero hasta aprobación
        AppLogger.info('Conductor nuevo completando registro de documentos');
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update(userUpdateData);

      AppLogger.info('Usuario actualizado correctamente', {
        'isPassengerUpgrade': isPassengerUpgrade,
      });

      // PASO 4: Suscribir a topics FCM para notificaciones de ambos roles
      try {
        await FCMService().subscribeToTopic('passengers');
        await FCMService().subscribeToTopic('drivers');
        AppLogger.info('Suscripción a topics FCM completada (dual-account)', {
          'topics': ['passengers', 'drivers'],
        });
      } catch (e) {
        AppLogger.error('Error al suscribir a topics FCM', e);
        // No fallar el upgrade si hay error en FCM
      }

      // ✅ PASO 4.5: Crear insignia de "Nuevo Conductor" como primer logro
      try {
        await FirebaseFirestore.instance
            .collection('achievements')
            .add({
          'userId': userId,
          'name': 'Nuevo Conductor',
          'description': '¡Bienvenido al equipo de conductores de RapiTeam! 🚗',
          'iconUrl': 'rookie_badge', // Placeholder para futuro icono
          'unlockedDate': FieldValue.serverTimestamp(),
          'category': 'milestone',
        });
        AppLogger.info('Insignia de Nuevo Conductor creada');
      } catch (e) {
        AppLogger.error('Error al crear achievement de Nuevo Conductor', e);
        // No fallar el upgrade si hay error creando el achievement
      }

      // PASO 5: Log de seguridad
      await _logSecurityEvent('ACCOUNT_UPGRADED_TO_DRIVER', {
        'user_id': userId,
        'email': _currentUser!.email,
        'from_type': 'passenger',
        'to_type': 'dual',
        'driver_status': 'pending_approval',
      });

      // PASO 6: Registrar evento en Analytics
      await _firebaseService.logEvent('driver_registration', {
        'user_id': userId,
        'from_type': 'passenger',
        'status': 'pending_approval',
      });

      // PASO 7: Recargar datos del usuario
      await _loadUserData(userId);

      AppLogger.info('Upgrade a conductor completado exitosamente');

      _errorMessage = 'Registro enviado. Revisaremos tus documentos en 24-48 horas';
      _isLoading = false;
      notifyListeners();
      return true;

    } catch (e, stackTrace) {
      AppLogger.error('Error en upgrade a conductor', e, stackTrace);
      // ✅ Usar handler para mensaje amigable en español
      _errorMessage = FirestoreErrorHandler.getSpanishMessage(e);
      await _firebaseService.recordError(e, stackTrace);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ==================== CAMBIO DE NÚMERO DE TELÉFONO ====================

  /// Iniciar proceso de cambio de número de teléfono con verificación OTP
  ///
  /// Este método permite a un usuario autenticado cambiar su número de teléfono.
  /// Requiere verificación OTP del NUEVO número antes de actualizar.
  ///
  /// Flujo de seguridad:
  /// 1. Validar formato del nuevo número peruano (9XXXXXXXX)
  /// 2. Verificar que el nuevo número NO esté ya registrado por otro usuario
  /// 3. Enviar código OTP al nuevo número
  /// 4. Usuario ingresa OTP en ChangePhoneNumberScreen
  /// 5. Validar OTP con verifyPhoneNumberChange()
  /// 6. Actualizar número en Firebase Auth Y Firestore
  Future<bool> startPhoneNumberChange(String newPhoneNumber) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // PASO 1: Validar que el usuario esté autenticado
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _errorMessage = 'Debes iniciar sesión para cambiar tu número';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // PASO 2: Validar formato del nuevo número
      if (!_validatePhoneNumber(newPhoneNumber)) {
        _errorMessage = 'Número de teléfono peruano inválido. Debe ser 9XXXXXXXX';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // PASO 3: Verificar que el nuevo número NO esté ya registrado
      final phoneQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: newPhoneNumber)
          .limit(1)
          .get();

      if (phoneQuery.docs.isNotEmpty) {
        // El número ya está registrado por otro usuario
        final existingUserId = phoneQuery.docs.first.id;

        // Verificar si es el mismo usuario (permitir re-verificación)
        if (existingUserId != currentUser.uid) {
          _errorMessage = 'Este número ya está registrado por otra cuenta';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      // PASO 4: Enviar código OTP al nuevo número
      _pendingPhoneNumber = newPhoneNumber;
      final fullPhoneNumber = ValidationPatterns.formatForFirebaseAuth(newPhoneNumber);

      AppLogger.info('Iniciando cambio de número de teléfono', {
        'userId': currentUser.uid,
        'newPhone': newPhoneNumber,
      });

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: fullPhoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verificación en Android (poco común en cambio de número)
          await _updatePhoneNumberWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          AppLogger.error('Error en verificación de cambio de número', e);
          _errorMessage = 'Error de verificación: ${e.message}';
          _isLoading = false;
          notifyListeners();
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _isLoading = false;
          notifyListeners();

          AppLogger.info('Código OTP enviado para cambio de número', {
            'userId': currentUser.uid,
            'verificationId': verificationId,
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        timeout: Duration(seconds: 60),
      );

      return true;

    } catch (e, stackTrace) {
      AppLogger.error('Error al iniciar cambio de número', e, stackTrace);
      // ✅ Usar handler para mensaje amigable en español
      _errorMessage = FirestoreErrorHandler.getSpanishMessage(e);
      await _firebaseService.recordError(e, stackTrace);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Verificar código OTP y actualizar número de teléfono
  ///
  /// Este método valida el código OTP ingresado por el usuario y actualiza
  /// el número de teléfono en Firebase Auth Y Firestore.
  Future<bool> verifyPhoneNumberChange(String otp) async {
    if (_verificationId == null) {
      _errorMessage = 'No hay verificación pendiente';
      notifyListeners();
      return false;
    }

    if (_pendingPhoneNumber == null) {
      _errorMessage = 'No hay número pendiente de cambio';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // PASO 1: Crear credencial con el código OTP
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      // PASO 2: Actualizar número en Firebase Auth y Firestore
      return await _updatePhoneNumberWithCredential(credential);

    } catch (e, stackTrace) {
      AppLogger.error('Error al verificar OTP de cambio de número', e, stackTrace);
      _errorMessage = 'Código inválido o expirado';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Actualizar número de teléfono con credencial verificada
  ///
  /// Este método interno actualiza el número en Firebase Auth usando updatePhoneNumber()
  /// y luego sincroniza el cambio en Firestore.
  Future<bool> _updatePhoneNumberWithCredential(PhoneAuthCredential credential) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _errorMessage = 'Usuario no autenticado';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      AppLogger.info('Actualizando número de teléfono en Firebase Auth', {
        'userId': currentUser.uid,
        'newPhone': _pendingPhoneNumber,
      });

      // PASO 1: Actualizar número en Firebase Authentication
      await currentUser.updatePhoneNumber(credential);

      AppLogger.info('✅ Número actualizado en Firebase Auth exitosamente');

      // PASO 2: Actualizar número en Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'phone': _pendingPhoneNumber,
        'phoneVerified': true,
        'lastPhoneVerification': FieldValue.serverTimestamp(),
        'phoneChangedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      AppLogger.info('✅ Número actualizado en Firestore exitosamente');

      // PASO 3: Recargar datos del usuario para actualizar el modelo completo
      _phoneVerified = true;
      await _loadUserData(currentUser.uid);

      // PASO 4: Log de seguridad
      await _logSecurityEvent('PHONE_NUMBER_CHANGED', {
        'user_id': currentUser.uid,
        'new_phone': _pendingPhoneNumber,
        'timestamp': DateTime.now().toIso8601String(),
      });

      // PASO 5: Limpiar variables temporales
      _pendingPhoneNumber = null;
      _verificationId = null;

      _isLoading = false;
      notifyListeners();

      AppLogger.info('✅ Cambio de número completado exitosamente');

      return true;

    } on FirebaseAuthException catch (e) {
      AppLogger.error('Error de Firebase Auth al cambiar número', {
        'code': e.code,
        'message': e.message,
      });

      // Manejar errores específicos
      switch (e.code) {
        case 'credential-already-in-use':
          _errorMessage = 'Este número ya está en uso por otra cuenta';
          break;
        case 'invalid-verification-code':
          _errorMessage = 'Código de verificación inválido';
          break;
        case 'session-expired':
          _errorMessage = 'La sesión ha expirado. Intenta nuevamente';
          break;
        default:
          _errorMessage = 'Error al actualizar número: ${e.message}';
      }

      _isLoading = false;
      notifyListeners();
      return false;

    } catch (e, stackTrace) {
      AppLogger.error('Error inesperado al cambiar número', e, stackTrace);
      // ✅ Usar handler para mensaje amigable en español
      _errorMessage = FirestoreErrorHandler.getSpanishMessage(e);
      await _firebaseService.recordError(e, stackTrace);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Cancelar proceso de cambio de número
  ///
  /// Limpia las variables temporales del proceso de cambio de número
  void cancelPhoneNumberChange() {
    _pendingPhoneNumber = null;
    _verificationId = null;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();

    AppLogger.info('Proceso de cambio de número cancelado');
  }

  // ==================== ELIMINACIÓN DE CUENTA ====================

  /// ✅ Re-autenticar usuario con contraseña
  ///
  /// Firebase requiere re-autenticación reciente para operaciones sensibles
  /// como cambiar contraseña o eliminar cuenta (requisito de seguridad)
  Future<void> reauthenticateWithPassword(String email, String password) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No hay usuario autenticado');
      }

      // Crear credencial con email y password
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );

      // Re-autenticar
      await user.reauthenticateWithCredential(credential);

      AppLogger.info('✅ Re-autenticación exitosa para operación sensible');
      await _firebaseService.logEvent('reauthentication_success', null);

    } on FirebaseAuthException catch (e) {
      AppLogger.error('Error en re-autenticación', {
        'code': e.code,
        'message': e.message,
      });

      await _firebaseService.logEvent('reauthentication_failed', {
        'error_code': e.code,
      });

      // Lanzar excepción específica para mejor manejo
      switch (e.code) {
        case 'wrong-password':
          throw Exception('wrong-password');
        case 'user-not-found':
          throw Exception('user-not-found');
        case 'too-many-requests':
          throw Exception('too-many-requests');
        case 'network-request-failed':
          throw Exception('network');
        default:
          throw Exception('Error de autenticación: ${e.message}');
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error inesperado en re-autenticación', e, stackTrace);
      await _firebaseService.recordError(e, stackTrace);
      throw Exception('Error al verificar contraseña');
    }
  }

  /// ✅ Eliminar cuenta de Firebase Auth (SOLO Auth, NO Firestore)
  ///
  /// IMPORTANTE: Este método SOLO elimina la cuenta de Firebase Auth.
  /// Debes eliminar PRIMERO los datos de Firestore y Storage ANTES
  /// de llamar a este método, porque después no podrás acceder al usuario.
  ///
  /// Flujo correcto:
  /// 1. Re-autenticar con reauthenticateWithPassword()
  /// 2. Eliminar datos de Storage (fotos)
  /// 3. Eliminar datos de Firestore (perfil, viajes, etc.)
  /// 4. Llamar a deleteAccount() ← ÚLTIMO PASO
  Future<void> deleteAccount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No hay usuario autenticado');
      }

      final userId = user.uid;
      final userEmail = user.email;

      AppLogger.warning('🗑️ INICIANDO ELIMINACIÓN DE CUENTA', {
        'userId': userId,
        'email': userEmail,
      });

      // Log de evento antes de eliminar (porque después ya no existirá)
      await _firebaseService.logEvent('account_deleted', {
        'user_id': userId,
      });

      await _logSecurityEvent('ACCOUNT_DELETED', {
        'user_id': userId,
        'email': userEmail,
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Eliminar cuenta de Firebase Auth
      await user.delete();

      AppLogger.info('✅ Cuenta de Firebase Auth eliminada correctamente');

      // Limpiar estado local
      _currentUser = null;
      _isAuthenticated = false;
      _phoneVerified = false;
      _errorMessage = null;
      notifyListeners();

      // Cerrar sesión de Firebase
      await FirebaseAuth.instance.signOut();

    } on FirebaseAuthException catch (e) {
      AppLogger.error('Error al eliminar cuenta de Firebase Auth', {
        'code': e.code,
        'message': e.message,
      });

      // Manejar errores específicos
      switch (e.code) {
        case 'requires-recent-login':
          throw Exception('requires-recent-login');
        case 'network-request-failed':
          throw Exception('network');
        default:
          throw Exception('Error al eliminar cuenta: ${e.message}');
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error inesperado al eliminar cuenta', e, stackTrace);
      await _firebaseService.recordError(e, stackTrace);
      throw Exception('Error al eliminar cuenta');
    }
  }

  // ==================== COMPLETAR PERFIL OBLIGATORIO (SOCIAL LOGIN) ====================

  /// Verificar si el usuario necesita completar su perfil
  ///
  /// Retorna true si el usuario necesita completar datos de perfil.
  ///
  /// Verificacion simplificada: solo verifica si tiene telefono y nombre.
  /// Ya NO verifica si tiene password provider (flujo sin contrasena).
  ///
  /// Se llama despues del login social para determinar si
  /// se debe redirigir a CompleteProfileScreen.
  bool needsProfileCompletion() {
    if (_currentUser == null) return false;

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return false;

    // Solo verificar si tiene telefono y nombre registrados
    final hasPhone = _currentUser!.phone.isNotEmpty;
    final hasName = _currentUser!.fullName.isNotEmpty;

    // Necesita completar perfil si:
    // 1. NO tiene telefono registrado O
    // 2. NO tiene nombre completo
    final needsCompletion = !hasPhone || !hasName;

    AppLogger.info('Verificando si necesita completar perfil', {
      'userId': _currentUser!.id,
      'email': _currentUser!.email,
      'hasPhone': hasPhone,
      'hasName': hasName,
      'phoneVerified': _phoneVerified,
      'needsCompletion': needsCompletion,
    });

    return needsCompletion;
  }

  // Metodo linkPasswordToAccount() ELIMINADO - Flujo simplificado: sin contrasena

  /// Actualizar email en Firestore
  ///
  /// Este método se usa cuando Google Sign-In no proporciona email
  /// y el usuario lo ingresa manualmente.
  ///
  /// @param email El email a guardar
  /// @return true si la actualización fue exitosa
  Future<bool> updateEmailInFirestore(String email) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _errorMessage = 'Debes iniciar sesión primero';
        notifyListeners();
        return false;
      }

      // Validar formato de email
      if (email.isEmpty || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
        _errorMessage = 'Email inválido';
        notifyListeners();
        return false;
      }

      AppLogger.info('📧 Actualizando email en Firestore: $email', {'userId': currentUser.uid});

      // Actualizar en Firestore (crear documento si no existe)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .set({
        'email': email,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Actualizar modelo local si existe
      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(email: email);
        notifyListeners();
      }

      AppLogger.info('✅ Email actualizado en Firestore exitosamente');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('❌ Error actualizando email en Firestore', e, stackTrace);
      // ✅ Usar handler para mensaje amigable en español
      _errorMessage = FirestoreErrorHandler.getSpanishMessage(e);
      notifyListeners();
      return false;
    }
  }

  /// Actualizar número de teléfono en Firestore (sin OTP)
  ///
  /// Este método SOLO actualiza el número en Firestore.
  /// Se usa después de verificar el OTP con verifyOTP().
  ///
  /// @param phoneNumber Número de teléfono en formato 9XXXXXXXX
  /// @return true si la actualización fue exitosa
  Future<bool> updatePhoneNumberInFirestore(String phoneNumber) async {
    try {
      // Validar que el usuario esté autenticado
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _errorMessage = 'Debes iniciar sesión primero';
        notifyListeners();
        return false;
      }

      // Validar formato del teléfono
      if (!_validatePhoneNumber(phoneNumber)) {
        _errorMessage = 'Número de teléfono peruano inválido. Debe ser 9XXXXXXXX';
        notifyListeners();
        return false;
      }

      AppLogger.info('Actualizando número de teléfono en Firestore', {
        'userId': currentUser.uid,
        'phone': phoneNumber,
      });

      // Actualizar en Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'phone': phoneNumber,
        'phoneVerified': true,
        'lastPhoneVerification': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      AppLogger.info('✅ Número de teléfono actualizado en Firestore');

      // Actualizar estado local
      _phoneVerified = true;

      // Recargar datos del usuario
      await _loadUserData(currentUser.uid);

      notifyListeners();

      return true;

    } catch (e, stackTrace) {
      AppLogger.error('Error al actualizar teléfono en Firestore', e, stackTrace);
      // ✅ Usar handler para mensaje amigable en español
      _errorMessage = FirestoreErrorHandler.getSpanishMessage(e);
      await _firebaseService.recordError(e, stackTrace);
      notifyListeners();
      return false;
    }
  }

  /// Guarda el número de teléfono sin verificar en Firestore.
  /// Útil cuando el usuario decide verificar después.
  ///
  /// @param phoneNumber Número de teléfono en formato 9XXXXXXXX
  /// @return true si la actualización fue exitosa
  Future<bool> updatePhoneNumberUnverified(String phoneNumber) async {
    try {
      // Validar que el usuario esté autenticado
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _errorMessage = 'Debes iniciar sesión primero';
        notifyListeners();
        return false;
      }

      // Validar formato del teléfono
      if (!_validatePhoneNumber(phoneNumber)) {
        _errorMessage = 'Número de teléfono peruano inválido. Debe ser 9XXXXXXXX';
        notifyListeners();
        return false;
      }

      AppLogger.info('Guardando número sin verificar en Firestore', {
        'userId': currentUser.uid,
        'phone': phoneNumber,
      });

      // Actualizar en Firestore con phoneVerified: false
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'phone': phoneNumber,
        'phoneVerified': false, // ⚠️ NO verificado
        'phoneVerificationPending': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      AppLogger.info('✅ Número guardado sin verificar en Firestore');

      // Recargar datos del usuario
      await _loadUserData(currentUser.uid);

      notifyListeners();

      return true;

    } catch (e, stackTrace) {
      AppLogger.error('Error al guardar teléfono sin verificar', e, stackTrace);
      // ✅ Usar handler para mensaje amigable en español
      _errorMessage = FirestoreErrorHandler.getSpanishMessage(e);
      await _firebaseService.recordError(e, stackTrace);
      notifyListeners();
      return false;
    }
  }

  /// ✅ CORRECCIÓN MEMORY LEAK: Cancelar listeners al destruir el provider
  @override
  void dispose() {
    AppLogger.state('AuthProvider', 'Cancelando listeners...');
    _authSubscription?.cancel(); // Cancelar listener de authStateChanges
    super.dispose();
  }
}