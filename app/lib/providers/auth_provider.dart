/// AuthProvider — versión Node/Postgres (sin Firebase).
/// -----------------------------------------------------------------------------
/// Reescrito completamente para migrar de Firebase Auth + Firestore al backend
/// propio del VPS (rapi-team-api.nynelmkt.cloud) usando RapiApiClient.
///
/// Preserva la API pública (getters y métodos) que consumen las pantallas de la
/// app, para no obligar a tocarlas todas.
///
/// Los flujos soportados:
///   - SMS OTP (startPhoneVerification → verifyOTP)
///   - Google Sign-In (idToken)
///   - Apple Sign-In (identityToken)
///   - Logout / eliminar cuenta
///   - Cambio de rol (passenger ↔ dual)
///   - Actualización de perfil, email y teléfono
///
/// Deprecados (throw UnimplementedError con mensaje claro):
///   - login (email+password) — la app usa OAuth + SMS ahora
///   - resetPassword (Firebase envía email) — usar OAuth reset
///   - reauthenticateWithPassword, linkPasswordToAccount, changePassword
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../models/user_model.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../services/rapi_api_client.dart';
import '../services/rapi_sse_client.dart';
import '../utils/logger.dart';

class AuthProvider with ChangeNotifier {
  final RapiApiClient _api = RapiApiClient.instance;

  // ─── Estado ────────────────────────────────────────────────────────────────
  UserModel? _currentUser;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  bool _isInitializing = true;
  String? _errorMessage;
  final bool _isAccountLocked = false;
  bool _isRoleSwitchInProgress = false;

  bool _emailVerified = false;
  bool _phoneVerified = false;
  bool _documentVerified = false;

  // Estado de verificación de teléfono
  String? _pendingPhoneNumber;

  // ─── Getters (API pública) ─────────────────────────────────────────────────
  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  bool get isFullyVerified => _isAuthenticated && _emailVerified;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;
  String? get errorMessage => _errorMessage;
  bool get isAccountLocked => _isAccountLocked;
  bool get isRoleSwitchInProgress => _isRoleSwitchInProgress;
  bool get emailVerified => _emailVerified;
  bool get phoneVerified => _phoneVerified;
  bool get documentVerified => _documentVerified;
  String? get pendingPhoneNumber => _pendingPhoneNumber;
  int get maxLoginAttempts => 5;
  int get remainingAttempts => 5;
  String? get verificationId => _pendingPhoneNumber;

  AuthProvider() {
    _initialize();
  }

  // ─── Inicialización ────────────────────────────────────────────────────────

  Future<void> _initialize() async {
    _isInitializing = true;
    notifyListeners();
    try {
      await _api.restore();
      if (_api.isSignedIn) {
        // Cargar user cachado del último login exitoso — permite abrir la app
        // sin red mientras hubo un login previo con tokens válidos.
        await _loadCachedUser();

        final ok = await _refreshFromBackend();
        if (ok) {
          RapiSseClient.instance.start();
          await _registerFcmTokenSafely();
        } else if (_currentUser != null) {
          // Refresh falló (probable network/timeout, no 401) pero tenemos user
          // cachado — mantenemos sesión y arrancamos SSE de forma optimista.
          // Si el token está realmente revocado, cualquier request 401 hará
          // logout más tarde.
          _isAuthenticated = true;
          RapiSseClient.instance.start();
        }
      }
    } catch (e, st) {
      AppLogger.error('AuthProvider init failed', e, st);
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  static const String _kCachedUserPref = 'rapi_cached_user_v1';

  // Ronda 164 SECURITY/LEY 29733: PII (DNI, phone, email, fecha nacimiento)
  // se guardaba en SharedPreferences plaintext XML → accesible con root o
  // adb backup si allowBackup=true. Migrar a flutter_secure_storage
  // (Keychain iOS / EncryptedSharedPreferences Android). Los JWT ya usaban
  // secure storage; el user cache se olvidó en la migración inicial.
  static const _secureUserStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  Future<void> _loadCachedUser() async {
    try {
      // 1) Intentar secure storage primero (nuevo).
      final secureRaw = await _secureUserStorage.read(key: _kCachedUserPref);
      if (secureRaw != null && secureRaw.isNotEmpty) {
        final json = jsonDecode(secureRaw) as Map<String, dynamic>;
        _currentUser = _userFromApi(json);
        _updateVerificationFlags();
        return;
      }
      // 2) Migración: user cache legacy en SharedPreferences → mover a secure
      //    y borrar de SharedPreferences para no dejar PII plaintext atrás.
      final sp = await SharedPreferences.getInstance();
      final legacyRaw = sp.getString(_kCachedUserPref);
      if (legacyRaw != null && legacyRaw.isNotEmpty) {
        await _secureUserStorage.write(key: _kCachedUserPref, value: legacyRaw);
        await sp.remove(_kCachedUserPref);
        final json = jsonDecode(legacyRaw) as Map<String, dynamic>;
        _currentUser = _userFromApi(json);
        _updateVerificationFlags();
      }
    } catch (e) {
      AppLogger.error('loadCachedUser fallo', e);
    }
  }

  Future<void> _saveCachedUser() async {
    try {
      if (_currentUser == null) return;
      final json = _currentUser!.toJson();
      await _secureUserStorage.write(key: _kCachedUserPref, value: jsonEncode(json));
    } catch (e) {
      AppLogger.error('saveCachedUser fallo', e);
    }
  }

  Future<bool> _refreshFromBackend() async {
    try {
      final resp = await _api.me();
      if (resp == null) return false;
      final userJson = resp['user'] as Map<String, dynamic>?;
      if (userJson == null) return false;
      _currentUser = _userFromApi(userJson);
      _isAuthenticated = true;
      _updateVerificationFlags();
      // Cachear user para próximo cold-start offline.
      await _saveCachedUser();
      return true;
    } catch (e) {
      AppLogger.error('refreshFromBackend fallo', e);
      return false;
    }
  }

  void _updateVerificationFlags() {
    if (_currentUser == null) {
      _emailVerified = false;
      _phoneVerified = false;
      _documentVerified = false;
    } else {
      _emailVerified = _currentUser!.emailVerified;
      _phoneVerified = _currentUser!.phoneVerified;
      _documentVerified = _currentUser!.documentVerified;
    }
  }

  /// Mapea la respuesta `/api/auth/me` al UserModel de la app.
  UserModel _userFromApi(Map<String, dynamic> u) {
    return UserModel(
      id: (u['id'] ?? '') as String,
      fullName: (u['fullName'] ?? u['full_name'] ?? '') as String,
      email: (u['email'] ?? '') as String,
      phone: (u['phone'] ?? u['phone_number'] ?? '') as String,
      userType: (u['userType'] ?? u['user_type'] ?? 'passenger') as String,
      profilePhotoUrl: (u['profilePhotoUrl'] ?? u['profile_photo_url'] ?? '') as String,
      isActive: (u['isActive'] ?? u['is_active'] ?? true) as bool,
      isVerified: (u['isVerified'] ?? u['is_verified'] ?? false) as bool,
      emailVerified: (u['emailVerified'] ?? u['email_verified'] ?? false) as bool,
      phoneVerified: (u['phoneVerified'] ?? u['phone_verified'] ?? false) as bool,
      documentVerified: (u['documentVerified'] ?? u['document_verified'] ?? false) as bool,
      identityDocument: (u['identityDocument'] ?? u['identity_document'])?.toString(),
      createdAt: _parseDate(u['createdAt'] ?? u['created_at']) ?? DateTime.now(),
      updatedAt: _parseDate(u['updatedAt'] ?? u['updated_at']) ?? DateTime.now(),
      rating: (u['rating'] as num?)?.toDouble() ?? 5.0,
      totalTrips: (u['totalTrips'] as num?)?.toInt() ?? 0,
      balance: (u['balance'] as num?)?.toDouble() ?? 0.0,
      currentMode: u['currentMode'] as String?,
      availableRoles: (u['availableRoles'] as List?)?.cast<String>(),
      driverProfile: u['driverProfile'] as Map<String, dynamic>?,
      driverStatus: u['driverStatus'] as String?,
      birthDate: u['birthDate'] as String?,
    );
  }

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  // ─── Login SMS (OTP) ───────────────────────────────────────────────────────

  Future<bool> startPhoneVerification(String phoneNumber) async {
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();
    try {
      await _api.sendSmsCode(phoneNumber);
      _pendingPhoneNumber = phoneNumber;
      return true;
    } on RapiApiException catch (e) {
      _errorMessage = _humanizeError(e);
      return false;
    } catch (e) {
      _errorMessage = 'No se pudo enviar el código. Intenta de nuevo.';
      AppLogger.error('startPhoneVerification', e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> verifyOTP(String code) async {
    if (_pendingPhoneNumber == null) {
      _errorMessage = 'No hay un número pendiente de verificar';
      notifyListeners();
      return false;
    }
    _isLoading = true;
    notifyListeners();
    try {
      await _api.verifySmsCode(phoneNumber: _pendingPhoneNumber!, code: code);
      final ok = await _refreshFromBackend();
      if (ok) {
        _pendingPhoneNumber = null;
        RapiSseClient.instance.start();
        await _registerFcmTokenSafely();
      }
      return ok;
    } on RapiApiException catch (e) {
      _errorMessage = _humanizeError(e);
      return false;
    } catch (e) {
      _errorMessage = 'Código inválido';
      AppLogger.error('verifyOTP', e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> resendOTP() async {
    if (_pendingPhoneNumber == null) return false;
    return startPhoneVerification(_pendingPhoneNumber!);
  }

  // ─── Asociar teléfono al user ya autenticado (tras Google/Apple) ────────────
  //
  // A diferencia de startPhoneVerification/verifyOTP (que crea sesión nueva y
  // puede crear un user distinto), estos métodos usan endpoints autenticados
  // que solo actualizan `users.phone` del user actual sin tocar la sesión.

  Future<bool> sendPhoneCodeForCurrentUser(String phoneNumber) async {
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();
    try {
      await _api.sendPhoneCodeAuthed(phoneNumber);
      _pendingPhoneNumber = phoneNumber;
      return true;
    } on RapiApiException catch (e) {
      _errorMessage = _humanizeError(e);
      return false;
    } catch (e) {
      _errorMessage = 'No se pudo enviar el código. Intenta de nuevo.';
      AppLogger.error('sendPhoneCodeForCurrentUser', e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> verifyPhoneCodeForCurrentUser(String code) async {
    if (_pendingPhoneNumber == null) {
      _errorMessage = 'No hay un número pendiente de verificar';
      notifyListeners();
      return false;
    }
    _isLoading = true;
    notifyListeners();
    try {
      final resp = await _api.verifyPhoneCodeAuthed(
        phoneNumber: _pendingPhoneNumber!,
        code: code,
      );
      // El endpoint devuelve el user actualizado directamente. Actualizamos
      // el estado local sin llamar de nuevo a /api/auth/me.
      final userJson = resp['user'] as Map<String, dynamic>?;
      if (userJson != null) {
        _currentUser = _userFromApi(userJson);
        _updateVerificationFlags();
        // Ronda 90: persistir cache para offline (mismo patrón que updateProfile)
        await _saveCachedUser();
      }
      _pendingPhoneNumber = null;
      RapiSseClient.instance.start();
      await _registerFcmTokenSafely();
      return true;
    } on RapiApiException catch (e) {
      _errorMessage = _humanizeError(e);
      return false;
    } catch (e) {
      _errorMessage = 'Código inválido';
      AppLogger.error('verifyPhoneCodeForCurrentUser', e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void cancelPhoneNumberChange() {
    _pendingPhoneNumber = null;
    _errorMessage = null;
    notifyListeners();
  }

  // ─── Google Sign-In ────────────────────────────────────────────────────────

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final gsi = GoogleSignIn.instance;
      await gsi.initialize();
      final account = await gsi.authenticate();
      // GoogleSignInAuthentication ya no es Future en v7+ — no await.
      final auth = account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        _errorMessage = 'No se obtuvo idToken de Google';
        return false;
      }
      await _api.loginWithGoogleIdToken(idToken);
      final ok = await _refreshFromBackend();
      if (ok) {
        RapiSseClient.instance.start();
        await _registerFcmTokenSafely();
      }
      return ok;
    } on GoogleSignInException catch (e) {
      switch (e.code) {
        case GoogleSignInExceptionCode.canceled:
        case GoogleSignInExceptionCode.interrupted:
          _errorMessage = null; // el user canceló
          break;
        default:
          _errorMessage = 'Error de Google: ${e.description ?? e.code.name}';
      }
      return false;
    } on RapiApiException catch (e) {
      _errorMessage = _humanizeError(e);
      return false;
    } catch (e) {
      _errorMessage = 'No se pudo iniciar sesión con Google';
      AppLogger.error('signInWithGoogle', e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Apple Sign-In ─────────────────────────────────────────────────────────

  Future<bool> signInWithApple() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final identityToken = credential.identityToken;
      if (identityToken == null) {
        _errorMessage = 'No se obtuvo identityToken de Apple';
        return false;
      }
      final fullName = [credential.givenName, credential.familyName]
          .where((s) => s != null && s.isNotEmpty)
          .join(' ')
          .trim();
      await _api.loginWithAppleIdentityToken(
        identityToken: identityToken,
        fullName: fullName.isEmpty ? null : fullName,
      );
      final ok = await _refreshFromBackend();
      if (ok) {
        RapiSseClient.instance.start();
        await _registerFcmTokenSafely();
      }
      return ok;
    } on SignInWithAppleException {
      _errorMessage = null; // el user canceló
      return false;
    } on RapiApiException catch (e) {
      _errorMessage = _humanizeError(e);
      return false;
    } catch (e) {
      _errorMessage = 'No se pudo iniciar sesión con Apple';
      AppLogger.error('signInWithApple', e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Logout ────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _api.logout();
    } catch (e) {
      AppLogger.error('logout', e);
    }
    await RapiSseClient.instance.stop();
    try {
      final gsi = GoogleSignIn.instance;
      await gsi.signOut();
    } catch (_) {}
    // Limpiar cache del user para que la próxima apertura offline no lo revierta.
    // Ronda 164: borrar de ambos storages (secure primary + legacy sp) para
    // asegurar que ningún residuo PII quede después del logout.
    try {
      await _secureUserStorage.delete(key: _kCachedUserPref);
    } catch (_) {}
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.remove(_kCachedUserPref);
    } catch (_) {}
    _currentUser = null;
    _isAuthenticated = false;
    _emailVerified = false;
    _phoneVerified = false;
    _documentVerified = false;
    _pendingPhoneNumber = null;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> deleteAccount({String? reason}) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _api.deleteAccount(reason: reason);
      await RapiSseClient.instance.stop();
      _currentUser = null;
      _isAuthenticated = false;
      return true;
    } on RapiApiException catch (e) {
      _errorMessage = _humanizeError(e);
      return false;
    } catch (e) {
      _errorMessage = 'No se pudo eliminar la cuenta';
      AppLogger.error('deleteAccount', e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Perfil ────────────────────────────────────────────────────────────────

  Future<bool> refreshUserData() async {
    final ok = await _refreshFromBackend();
    notifyListeners();
    return ok;
  }

  Future<bool> reloadUserData() => refreshUserData();

  Future<bool> updateProfile({
    String? fullName,
    String? email,
    String? phone,
    String? profilePhotoUrl,
    String? birthDate,
    String? identityDocument,
    Map<String, dynamic>? extraFields,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final resp = await _api.updateMe(
        fullName: fullName,
        email: email,
        phone: phone,
        profilePhotoUrl: profilePhotoUrl,
        birthDate: birthDate,
        identityDocument: identityDocument,
      );
      final userJson = resp?['user'] as Map<String, dynamic>?;
      if (userJson != null) {
        _currentUser = _userFromApi(userJson);
        _updateVerificationFlags();
        // Ronda 90: persistir cache al actualizar perfil. Sin esto, al matar
        // la app y reabrirla sin red, mostraba datos viejos hasta el próximo
        // refresh online exitoso.
        await _saveCachedUser();
        return true;
      }
      return false;
    } on RapiApiException catch (e) {
      _errorMessage = _humanizeError(e);
      return false;
    } catch (e) {
      _errorMessage = 'No se pudo actualizar el perfil';
      AppLogger.error('updateProfile', e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateEmail(String email) async {
    return updateProfile(email: email);
  }
  @Deprecated('Nombre legacy (ya no toca Firestore). Usa updateEmail().')
  Future<bool> updateEmailInFirestore(String email) async {
    // Alias por compatibilidad — la actualización de email debe pasar por
    // el flujo de verificación de OTP al email (a implementar en backend).
    return updateProfile(email: email);
  }

  Future<bool> updatePhoneNumber(String phone) async {
    return updateProfile(phone: phone);
  }
  @Deprecated('Nombre legacy (ya no toca Firestore). Usa updatePhoneNumber().')
  Future<bool> updatePhoneNumberInFirestore(String phone) async {
    return updateProfile(phone: phone);
  }

  Future<bool> updatePhoneNumberUnverified(String phone) async {
    return updateProfile(phone: phone);
  }

  Future<bool> startPhoneNumberChange(String newPhone) async {
    return startPhoneVerification(newPhone);
  }

  Future<bool> verifyPhoneNumberChange(String code) => verifyOTP(code);

  // ─── Cambio de rol (passenger ↔ dual) ──────────────────────────────────────

  Future<bool> switchMode(String newMode) async {
    if (_currentUser == null) return false;
    _isRoleSwitchInProgress = true;
    notifyListeners();
    try {
      final resp = await _api.updateMe(currentMode: newMode);
      final userJson = resp?['user'] as Map<String, dynamic>?;
      if (userJson != null) {
        _currentUser = _userFromApi(userJson);
        _updateVerificationFlags();
        // Ronda 90: persistir cache tras switch de modo
        await _saveCachedUser();
        return true;
      }
      return false;
    } on RapiApiException catch (e) {
      _errorMessage = _humanizeError(e);
      return false;
    } catch (e) {
      AppLogger.error('switchMode', e);
      return false;
    } finally {
      _isRoleSwitchInProgress = false;
      notifyListeners();
    }
  }

  Future<bool> upgradeToDriver() async {
    try {
      await _api.upgradeToDriver();
      return await _refreshFromBackend();
    } on RapiApiException catch (e) {
      _errorMessage = _humanizeError(e);
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'No se pudo activar el modo conductor';
      AppLogger.error('upgradeToDriver', e);
      notifyListeners();
      return false;
    }
  }

  bool needsProfileCompletion() {
    // Solo pedir completar si falta el teléfono. Login SMS ya tiene teléfono
    // por definición; login Google/Apple no siempre lo provee y se pide después.
    if (_currentUser == null) return true;
    return _currentUser!.phone.isEmpty;
  }

  // ─── Deprecados (compatibilidad hacia atrás) ───────────────────────────────

  Future<bool> login(String email, String password) async {
    _errorMessage = 'Este método ya no se usa. Inicia sesión con SMS, Google o Apple.';
    notifyListeners();
    return false;
  }

  Future<bool> resetPassword(String email) async {
    _errorMessage = 'Recuperación de contraseña no está disponible. Usa Google o SMS.';
    notifyListeners();
    return false;
  }

  Future<bool> changePassword(String currentPassword, String newPassword) async {
    _errorMessage = 'Cambio de contraseña no está disponible.';
    notifyListeners();
    return false;
  }

  Future<bool> linkPasswordToAccount(String password) async {
    _errorMessage = 'Vincular contraseña no está disponible.';
    notifyListeners();
    return false;
  }

  Future<bool> reauthenticateWithPassword(String password) async {
    // Sin passwords en la app móvil, este flujo se salta.
    return _isAuthenticated;
  }

  // ─── Utilidades ────────────────────────────────────────────────────────────

  Future<void> _registerFcmTokenSafely() async {
    try {
      // Timeout defensivo: en iOS con APNS lento o Firebase con degradación,
      // getToken() puede bloquear minutos sin retornar. No queremos que el
      // flow post-login (verifyOTP → registerFcm → SSE) se atore.
      final token = await FirebaseMessaging.instance.getToken().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          AppLogger.warning('FCM getToken timeout — se reintentará más tarde');
          return null;
        },
      );
      if (token != null && token.isNotEmpty) {
        await _api.registerFcmToken(token);
      }
    } catch (e) {
      AppLogger.error('registerFcmToken', e);
    }
  }

  String _humanizeError(RapiApiException e) {
    switch (e.code) {
      case 'invalid_credentials':
        return 'Credenciales inválidas';
      case 'account_suspended':
        return 'Cuenta suspendida. Contacta soporte.';
      case 'account_inactive':
        return 'Cuenta inactiva';
      case 'account_deleted':
        return 'Esta cuenta fue eliminada';
      case 'unauthorized':
        return 'Sesión expirada. Vuelve a iniciar sesión.';
      case 'invalid_code':
      case 'invalid_otp':
        return 'Código incorrecto';
      case 'expired_code':
        return 'El código expiró. Solicita uno nuevo.';
      case 'rate_limited':
        return 'Demasiados intentos. Espera un momento.';
      default:
        return e.message ?? 'Ocurrió un error. Intenta de nuevo.';
    }
  }

}
