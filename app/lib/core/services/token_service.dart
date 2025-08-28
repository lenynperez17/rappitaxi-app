import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/logger.dart';

final tokenServiceProvider = Provider<TokenService>((ref) {
  return TokenService();
});

class TokenService {
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _accessTokenKey = 'access_token';
  static const String _userIdKey = 'user_id';
  static const String _fcmTokenKey = 'fcm_token';
  
  // Secure storage para tokens sensibles
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      // accessibility: KeychainItemAccessibility.first_unlock_this_device,
    ),
  );
  
  final SharedPreferences? _prefs;
  
  TokenService([this._prefs]);
  
  // Token básico con secure storage
  Future<void> saveToken(String token) async {
    try {
      await _secureStorage.write(key: _tokenKey, value: token);
      Logger.info('Token guardado de forma segura');
    } catch (e) {
      Logger.error('Error guardando token', e);
      // Fallback a SharedPreferences
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
    }
  }
  
  Future<String?> getToken() async {
    try {
      return await _secureStorage.read(key: _tokenKey);
    } catch (e) {
      Logger.error('Error obteniendo token de secure storage', e);
      // Fallback a SharedPreferences
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    }
  }
  
  Future<void> deleteToken() async {
    try {
      await _secureStorage.delete(key: _tokenKey);
      await _secureStorage.delete(key: _refreshTokenKey);
      await _secureStorage.delete(key: _accessTokenKey);
      await _secureStorage.delete(key: _userIdKey);
      await _secureStorage.delete(key: _fcmTokenKey);
      Logger.info('Tokens eliminados de forma segura');
    } catch (e) {
      Logger.error('Error eliminando tokens', e);
      // Fallback a SharedPreferences
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_refreshTokenKey);
      await prefs.remove(_accessTokenKey);
      await prefs.remove(_userIdKey);
      await prefs.remove(_fcmTokenKey);
    }
  }
  
  // Refresh token
  Future<void> saveRefreshToken(String token) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString(_refreshTokenKey, token);
  }
  
  Future<String?> getRefreshToken() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }
  
  // Access token
  Future<void> saveAccessToken(String token) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, token);
  }
  
  Future<String?> getAccessToken() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }
  
  // Guardar múltiples tokens
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await saveAccessToken(accessToken);
    await saveRefreshToken(refreshToken);
  }
  
  // Limpiar todos los tokens
  Future<void> clearTokens() async {
    await deleteToken();
  }
  
  // Verificar si hay token
  Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
  
  // Guardar user ID
  Future<void> saveUserId(String userId) async {
    try {
      await _secureStorage.write(key: _userIdKey, value: userId);
    } catch (e) {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setString(_userIdKey, userId);
    }
  }
  
  // Obtener user ID
  Future<String?> getUserId() async {
    try {
      return await _secureStorage.read(key: _userIdKey);
    } catch (e) {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      return prefs.getString(_userIdKey);
    }
  }
  
  // Guardar FCM token
  Future<void> saveFcmToken(String token) async {
    try {
      await _secureStorage.write(key: _fcmTokenKey, value: token);
    } catch (e) {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setString(_fcmTokenKey, token);
    }
  }
  
  // Obtener FCM token
  Future<String?> getFcmToken() async {
    try {
      return await _secureStorage.read(key: _fcmTokenKey);
    } catch (e) {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      return prefs.getString(_fcmTokenKey);
    }
  }
  
  // Validar si el token está expirado (básico)
  Future<bool> isTokenValid() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return false;
    
    // TODO: Implementar validación JWT real
    // Por ahora solo verificamos si existe
    return true;
  }
  
  // Limpiar todos los datos de sesión
  Future<void> clearSession() async {
    await deleteToken();
    Logger.info('Sesión limpiada completamente');
  }
}
