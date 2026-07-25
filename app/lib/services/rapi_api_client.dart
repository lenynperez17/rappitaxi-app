/// Cliente HTTP para el backend Node/Next del VPS.
/// -----------------------------------------------------------------------------
/// Uso: `final api = RapiApiClient();` — es singleton implícito (patron factory).
library;
/// El cliente maneja:
///   - Persistencia de accessToken/refreshToken en secure storage
///   - Auto-refresh automático al recibir 401 (con retry once)
///   - Emisión de FirebaseCustomToken al login (para la transición híbrida)
///   - Extracción del user + Deep-link al login screen si el refresh falla
///
/// La app existente sigue hablando con Firebase para reads directos. Este
/// cliente reemplaza SOLO los flujos de auth, wallet (recargas), vales, maps,
/// storage y delete-account.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/logger.dart';

class RapiApiException implements Exception {
  final int statusCode;
  final String code;
  final String? message;
  const RapiApiException(this.statusCode, this.code, [this.message]);
  @override
  String toString() => 'RapiApiException($statusCode, $code): $message';
}

class RapiApiClient {
  RapiApiClient._();
  static final RapiApiClient instance = RapiApiClient._();
  factory RapiApiClient() => instance;

  static const String baseUrl = 'https://rapi-team-api.nynelmkt.cloud';

  // Keys de secure storage — evitar naming clash con la app existente.
  static const String _kAccessToken = 'rapi_api_access_token';
  static const String _kRefreshToken = 'rapi_api_refresh_token';
  static const String _kAccessExpiresAt = 'rapi_api_access_expires_at';

  /// Timeout por defecto para requests HTTP. Sin esto, un backend colgado
  /// dejaba al usuario con spinner infinito en cualquier flow crítico
  /// (verify OTP, requestRide, complete, etc.).
  static const Duration _kHttpTimeout = Duration(seconds: 25);

  // http.Client envuelto con timeout global — cualquier `_http.post/get/etc`
  // hereda el timeout sin tocar los call-sites.
  final http.Client _http = _TimeoutClient(http.Client(), _kHttpTimeout);

  // Secure storage (encriptado por Android Keystore / iOS Keychain).
  // Reemplaza el uso previo de SharedPreferences que dejaba tokens en
  // plaintext XML accesible con root/ADB backup.
  // v11 de flutter_secure_storage migra automáticamente a custom ciphers;
  // AndroidOptions no requiere parámetros. IOSOptions solo accessibility.
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  // Cache en memoria (reduces reads a secure storage)
  String? _accessCache;
  String? _refreshCache;
  DateTime? _accessExpiresAtCache;

  /// Restaurar tokens del storage. Llamar al arrancar la app.
  /// MIGRACIÓN: leer de secure_storage primero; si vacío, fallback a
  /// SharedPreferences (para users viejos) y migrar en background.
  Future<void> restore() async {
    _accessCache = await _secureStorage.read(key: _kAccessToken);
    _refreshCache = await _secureStorage.read(key: _kRefreshToken);
    final expIso = await _secureStorage.read(key: _kAccessExpiresAt);
    if (expIso != null) _accessExpiresAtCache = DateTime.tryParse(expIso);

    // Fallback + migration: si secure_storage está vacío pero SharedPreferences
    // tiene tokens de una versión anterior, migrarlos al secure storage.
    if (_refreshCache == null) {
      final sp = await SharedPreferences.getInstance();
      final legacyAccess = sp.getString(_kAccessToken);
      final legacyRefresh = sp.getString(_kRefreshToken);
      final legacyExp = sp.getString(_kAccessExpiresAt);
      if (legacyRefresh != null) {
        _accessCache = legacyAccess;
        _refreshCache = legacyRefresh;
        if (legacyExp != null) _accessExpiresAtCache = DateTime.tryParse(legacyExp);
        // Migrar y borrar del SharedPreferences (plaintext ya no).
        await _secureStorage.write(key: _kAccessToken, value: legacyAccess ?? '');
        await _secureStorage.write(key: _kRefreshToken, value: legacyRefresh);
        if (legacyExp != null) {
          await _secureStorage.write(key: _kAccessExpiresAt, value: legacyExp);
        }
        await Future.wait([
          sp.remove(_kAccessToken),
          sp.remove(_kRefreshToken),
          sp.remove(_kAccessExpiresAt),
        ]);
      }
    }
  }

  /// True si tenemos refresh vigente (aún si el access expiró).
  bool get isSignedIn => _refreshCache != null;

  Future<void> _persistSession({
    required String accessToken,
    required String refreshToken,
    required int accessTtlSec,
  }) async {
    _accessCache = accessToken;
    _refreshCache = refreshToken;
    _accessExpiresAtCache = DateTime.now().add(Duration(seconds: accessTtlSec - 30));
    await Future.wait([
      _secureStorage.write(key: _kAccessToken, value: accessToken),
      _secureStorage.write(key: _kRefreshToken, value: refreshToken),
      _secureStorage.write(key: _kAccessExpiresAt, value: _accessExpiresAtCache!.toIso8601String()),
    ]);
  }

  Future<void> _clearSession() async {
    _accessCache = null;
    _refreshCache = null;
    _accessExpiresAtCache = null;
    await Future.wait([
      _secureStorage.delete(key: _kAccessToken),
      _secureStorage.delete(key: _kRefreshToken),
      _secureStorage.delete(key: _kAccessExpiresAt),
    ])
    ;
    // Cleanup de posibles restos de SharedPreferences (legacy)
    try {
      final sp = await SharedPreferences.getInstance();
      await Future.wait([
        sp.remove(_kAccessToken),
        sp.remove(_kRefreshToken),
        sp.remove(_kAccessExpiresAt),
      ]);
    } catch (_) { /* fallback silent */ }
  }

  bool get _accessLikelyValid {
    if (_accessCache == null) return false;
    if (_accessExpiresAtCache == null) return false;
    return DateTime.now().isBefore(_accessExpiresAtCache!);
  }

  // ---------------------------------------------------------------------------
  // Endpoints de auth
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> sendSmsCode(String phoneNumber) async {
    final r = await _http.post(
      Uri.parse('$baseUrl/api/auth/sms/send'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'phoneNumber': phoneNumber}),
    );
    return _decodeOrThrow(r);
  }

  /// Verifica OTP. Al éxito guarda tokens en secure storage.
  Future<Map<String, dynamic>> verifySmsCode({
    required String phoneNumber,
    required String code,
  }) async {
    final r = await _http.post(
      Uri.parse('$baseUrl/api/auth/sms/verify'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'phoneNumber': phoneNumber, 'code': code}),
    );
    final data = _decodeOrThrow(r);
    await _persistSession(
      accessToken: data['jwt'] as String,
      refreshToken: data['refreshToken'] as String,
      accessTtlSec: data['accessTtlSec'] as int? ?? 3600,
    );
    return data;
  }

  /// Envía OTP al `phoneNumber` para **asociarlo al user ya autenticado**
  /// (no crea sesión nueva). Usado en complete-profile tras OAuth.
  Future<Map<String, dynamic>> sendPhoneCodeAuthed(String phoneNumber) async {
    return (await _authedPost('/api/auth/phone/send-code', body: {'phoneNumber': phoneNumber}))!;
  }

  /// Verifica el OTP y **actualiza el phone del user autenticado**. No crea
  /// sesión ni usuario nuevo. Retorna `{ user: {...} }`.
  Future<Map<String, dynamic>> verifyPhoneCodeAuthed({
    required String phoneNumber,
    required String code,
  }) async {
    return (await _authedPost('/api/auth/phone/verify', body: {
      'phoneNumber': phoneNumber,
      'code': code,
    }))!;
  }

  Future<Map<String, dynamic>> loginWithGoogleIdToken(String idToken) async {
    final r = await _http.post(
      Uri.parse('$baseUrl/api/auth/google/idtoken'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'idToken': idToken}),
    );
    final data = _decodeOrThrow(r);
    await _persistSession(
      accessToken: data['jwt'] as String,
      refreshToken: data['refreshToken'] as String,
      accessTtlSec: data['accessTtlSec'] as int? ?? 3600,
    );
    return data;
  }

  Future<Map<String, dynamic>> loginWithAppleIdentityToken({
    required String identityToken,
    String? fullName,
  }) async {
    final r = await _http.post(
      Uri.parse('$baseUrl/api/auth/apple/idtoken'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'identityToken': identityToken,
        if (fullName != null) 'fullName': fullName,
      }),
    );
    final data = _decodeOrThrow(r);
    await _persistSession(
      accessToken: data['jwt'] as String,
      refreshToken: data['refreshToken'] as String,
      accessTtlSec: data['accessTtlSec'] as int? ?? 3600,
    );
    return data;
  }

  Future<Map<String, dynamic>?> me() async {
    return _authedGet('/api/auth/me');
  }

  /// Actualiza el perfil del user autenticado. Envía solo los campos no-null.
  Future<Map<String, dynamic>?> updateMe({
    String? fullName,
    String? email,
    String? phone,
    String? profilePhotoUrl,
    String? birthDate,
    String? identityDocument,
    String? currentMode,
  }) async {
    return _authedPatch('/api/auth/me', body: {
      if (fullName != null) 'fullName': fullName,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (profilePhotoUrl != null) 'profilePhotoUrl': profilePhotoUrl,
      if (birthDate != null) 'birthDate': birthDate,
      if (identityDocument != null) 'identityDocument': identityDocument,
      if (currentMode != null) 'currentMode': currentMode,
    });
  }

  // Passkeys — begin/finish para register + authenticate.
  // El cliente Flutter usa el paquete `passkeys` para invocar la API nativa,
  // solo llama a estos endpoints para orquestar el server.

  Future<Map<String, dynamic>> passkeyRegisterBegin({String? email}) async =>
      (await _authedPost('/api/auth/passkey/register/begin', body: {
        if (email != null) 'email': email,
      }))!;

  Future<Map<String, dynamic>> passkeyRegisterFinish(
    Map<String, dynamic> attestation,
  ) async =>
      (await _authedPost('/api/auth/passkey/register/finish', body: attestation))!;

  Future<Map<String, dynamic>> passkeyAuthenticateBegin({String? email}) async {
    final r = await _http.post(
      Uri.parse('$baseUrl/api/auth/passkey/authenticate/begin'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({if (email != null) 'email': email}),
    );
    return _decodeOrThrow(r);
  }

  Future<Map<String, dynamic>> passkeyAuthenticateFinish(
    Map<String, dynamic> assertion,
  ) async {
    final r = await _http.post(
      Uri.parse('$baseUrl/api/auth/passkey/authenticate/finish'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(assertion),
    );
    final data = _decodeOrThrow(r);
    if (data['jwt'] != null && data['refreshToken'] != null) {
      await _persistSession(
        accessToken: data['jwt'] as String,
        refreshToken: data['refreshToken'] as String,
        accessTtlSec: data['accessTtlSec'] as int? ?? 3600,
      );
    }
    return data;
  }

  /// Fuerza refresh del access token con el refresh actual.
  /// Retorna false si el refresh falló (cliente debe cerrar sesión).
  ///
  /// Single-flight: si dos llamadas concurrentes reciben 401 y disparan
  /// refresh en paralelo, ambos POST /api/auth/refresh usan el MISMO refresh
  /// token. El server (sessions.ts) marca el primero como usado y trata al
  /// segundo como token-reuse ATTACK → revoca TODAS las sesiones del user en
  /// TODOS los dispositivos (defensa correcta contra robo real). Para no
  /// disparar el sistema anti-reuse en flujo normal, serializamos las llamadas
  /// concurrentes tras un Completer: la primera hace el refresh de verdad,
  /// las demás esperan y comparten el resultado. Ronda 17 HIGH#3.
  Completer<bool>? _refreshInFlight;

  Future<bool> refreshAccessToken() async {
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight.future;
    final completer = Completer<bool>();
    _refreshInFlight = completer;
    try {
      if (_refreshCache == null) {
        completer.complete(false);
        return false;
      }
      final r = await _http.post(
        Uri.parse('$baseUrl/api/auth/refresh'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': _refreshCache}),
      );
      if (r.statusCode != 200) {
        await _clearSession();
        completer.complete(false);
        return false;
      }
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      await _persistSession(
        accessToken: data['jwt'] as String,
        refreshToken: data['refreshToken'] as String,
        accessTtlSec: data['accessTtlSec'] as int? ?? 3600,
      );
      completer.complete(true);
      return true;
    } catch (e, st) {
      // Ronda 167 UX/BATTERY: en excepción (timeout, red caída, DNS fail)
      // NO propagar el error. Antes: completer.completeError → rethrow
      // hacía que la request original abortara con TimeoutException en vez
      // de manejarse como 401. Peor: los callers no atrapaban esto y
      // reintentaban infinito, drain batería + datos en zonas con red mala.
      // Ahora: log del error, tratar como refresh fallido (false), NO
      // limpiar la sesión (para reintentar cuando vuelva la red), y los
      // callers que ven false pueden mostrar "sin conexión" al user.
      AppLogger.error('[refresh] network error', e, st);
      completer.complete(false);
      return false;
    } finally {
      _refreshInFlight = null;
    }
  }

  /// Cierra sesión — revoca refresh en el server y limpia storage.
  Future<void> logout({bool allDevices = false}) async {
    if (_accessCache != null) {
      try {
        await _http.post(
          Uri.parse('$baseUrl/api/auth/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_accessCache',
          },
          body: jsonEncode({
            if (_refreshCache != null) 'refreshToken': _refreshCache,
            if (allDevices) 'allDevices': true,
          }),
        );
      } catch (_) {
        // ignore — clear local anyway
      }
    }
    await _clearSession();
  }

  Future<Map<String, dynamic>> deleteAccount({String? reason}) async {
    final data = await _authedPost('/api/account/delete', body: {
      'confirmation': 'DELETE',
      if (reason != null) 'reason': reason,
    });
    await _clearSession();
    return data ?? const {};
  }

  // ---------------------------------------------------------------------------
  // Endpoints de dominio
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> walletBalance() async =>
      (await _authedGet('/api/wallet/balance'))!;

  Future<Map<String, dynamic>> createRechargeCheckout(double amount) async =>
      (await _authedPost('/api/wallet/recharge/checkout', body: {'amount': amount}))!;

  Future<Map<String, dynamic>> validateVale({required String code, double? rideAmount}) async =>
      (await _authedPost('/api/vales/validate', body: {
        'code': code,
        if (rideAmount != null) 'rideAmount': rideAmount,
      }))!;

  Future<Map<String, dynamic>> applyVale({
    required String code,
    required String rideId,
    required double rideAmount,
  }) async =>
      (await _authedPost('/api/vales/apply', body: {
        'code': code,
        'rideId': rideId,
        'rideAmount': rideAmount,
      }))!;

  /// Reverse geocode: convierte lat/lng en una dirección legible.
  /// Ronda 216: usa el backend proxy (Nominatim) — antes la app llamaba
  /// Google directo con key expuesta.
  Future<Map<String, dynamic>> mapsReverseGeocode({
    required double lat,
    required double lng,
  }) async {
    return (await _authedGet(
      '/api/maps/reverse-geocode',
      queryParams: {'lat': lat.toString(), 'lng': lng.toString()},
    ))!;
  }

  Future<Map<String, dynamic>> mapsAutocomplete({
    required String query,
    String? session,
    double? lat,
    double? lng,
  }) async {
    final qp = <String, String>{
      'q': query,
      if (session != null) 'session': session,
      if (lat != null) 'lat': lat.toString(),
      if (lng != null) 'lng': lng.toString(),
    };
    return (await _authedGet('/api/maps/autocomplete', queryParams: qp))!;
  }

  Future<Map<String, dynamic>> mapsDirections({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    String mode = 'driving',
  }) async =>
      (await _authedGet('/api/maps/directions', queryParams: {
        'originLat': originLat.toString(),
        'originLng': originLng.toString(),
        'destLat': destLat.toString(),
        'destLng': destLng.toString(),
        'mode': mode,
      }))!;

  /// Sube un archivo. Retorna { id, key, url, mime, size, isPublic }.
  Future<Map<String, dynamic>> uploadFile({
    required File file,
    required String scope,
    bool retried = false,
  }) async {
    await _ensureFreshAccess();
    final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/storage/upload'))
      ..headers['Authorization'] = 'Bearer $_accessCache'
      ..fields['scope'] = scope
      ..files.add(await http.MultipartFile.fromPath('file', file.path));
    // Ronda 214: MultipartRequest.send() no pasa por _TimeoutClient (que solo
    // envuelve el http.Client interno de _http). Sin este timeout explícito,
    // subir documentos de verificación en 3G podía colgar el UI indefinidamente
    // hasta que el SO cerrara el socket (~90s). 60s es tiempo suficiente para
    // un DNI/licencia (fotos ~500KB-2MB) en conexiones lentas.
    final streamed = await req.send().timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        throw const RapiApiException(408, 'upload_timeout',
          'La subida tardó demasiado. Verifica tu conexión e intenta de nuevo.');
      },
    );
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode == 401) {
      // Ronda 91: retry counter — sin esto, un 401 persistente (sesión revocada
      // por ban admin/rotación forzada) causaba recursión infinita: refresh
      // rota → upload 401 → refresh rota → ... loop con re-lectura del archivo
      // cada iteración (banda + batería + stack).
      if (retried) throw const RapiApiException(401, 'refresh_failed_after_retry');
      final refreshed = await refreshAccessToken();
      if (!refreshed) throw const RapiApiException(401, 'refresh_failed');
      return uploadFile(file: file, scope: scope, retried: true);
    }
    return _decodeOrThrow(resp);
  }

  // ---------------------------------------------------------------------------
  // Helpers HTTP con auto-refresh
  // ---------------------------------------------------------------------------

  Future<void> _ensureFreshAccess() async {
    if (!_accessLikelyValid && _refreshCache != null) {
      await refreshAccessToken();
    }
  }

  Future<Map<String, dynamic>?> _authedGet(
    String path, {
    Map<String, String>? queryParams,
  }) async {
    await _ensureFreshAccess();
    final uri = Uri.parse('$baseUrl$path')
        .replace(queryParameters: queryParams);
    final r = await _http.get(uri, headers: {'Authorization': 'Bearer $_accessCache'});
    if (r.statusCode == 401 && _refreshCache != null) {
      if (await refreshAccessToken()) {
        final r2 = await _http.get(uri, headers: {'Authorization': 'Bearer $_accessCache'});
        return _decodeOrThrow(r2);
      }
    }
    return _decodeOrThrow(r);
  }

  Future<Map<String, dynamic>?> _authedDelete(String path) async {
    await _ensureFreshAccess();
    final uri = Uri.parse('$baseUrl$path');
    Future<http.Response> doDelete() => _http.delete(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_accessCache',
          },
        );
    final r = await doDelete();
    if (r.statusCode == 401 && _refreshCache != null) {
      if (await refreshAccessToken()) {
        final r2 = await doDelete();
        return _decodeOrThrow(r2);
      }
    }
    return _decodeOrThrow(r);
  }

  Future<Map<String, dynamic>?> _authedPatch(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    await _ensureFreshAccess();
    final uri = Uri.parse('$baseUrl$path');
    Future<http.Response> doPatch() => _http.patch(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_accessCache',
          },
          body: jsonEncode(body ?? const {}),
        );
    final r = await doPatch();
    if (r.statusCode == 401 && _refreshCache != null) {
      if (await refreshAccessToken()) {
        final r2 = await doPatch();
        return _decodeOrThrow(r2);
      }
    }
    return _decodeOrThrow(r);
  }

  Future<Map<String, dynamic>?> _authedPut(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    await _ensureFreshAccess();
    final uri = Uri.parse('$baseUrl$path');
    Future<http.Response> doPut() => _http.put(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_accessCache',
          },
          body: jsonEncode(body ?? const {}),
        );
    final r = await doPut();
    if (r.statusCode == 401 && _refreshCache != null) {
      if (await refreshAccessToken()) {
        final r2 = await doPut();
        return _decodeOrThrow(r2);
      }
    }
    return _decodeOrThrow(r);
  }

  Future<Map<String, dynamic>?> _authedPost(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    await _ensureFreshAccess();
    final uri = Uri.parse('$baseUrl$path');
    Future<http.Response> doPost() => _http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_accessCache',
          },
          body: jsonEncode(body ?? const {}),
        );
    final r = await doPost();
    if (r.statusCode == 401 && _refreshCache != null) {
      if (await refreshAccessToken()) {
        final r2 = await doPost();
        return _decodeOrThrow(r2);
      }
    }
    return _decodeOrThrow(r);
  }

  // ---------------------------------------------------------------------------
  // RIDES — viajes
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> createRide({
    required Map<String, dynamic> pickup,      // { lat, lng, address }
    required Map<String, dynamic> destination,
    required String vehicleType,
    required String paymentMethod,
    double? proposedFare,
    bool negotiable = false,
    String? notes,
  }) async =>
      (await _authedPost('/api/rides', body: {
        'pickup': pickup,
        'destination': destination,
        'vehicleType': vehicleType,
        'paymentMethod': paymentMethod,
        if (proposedFare != null) 'proposedFare': proposedFare,
        'negotiable': negotiable,
        if (notes != null) 'notes': notes,
      }))!;

  Future<Map<String, dynamic>> listRides({
    String? role,     // 'passenger' | 'driver'
    String? status,
    int page = 1,
    int pageSize = 20,
  }) async =>
      (await _authedGet('/api/rides', queryParams: {
        if (role != null) 'role': role,
        if (status != null) 'status': status,
        'page': page.toString(),
        'pageSize': pageSize.toString(),
      }))!;

  Future<Map<String, dynamic>> getRide(String rideId) async =>
      (await _authedGet('/api/rides/$rideId'))!;

  Future<Map<String, dynamic>> acceptRide(String rideId) async =>
      (await _authedPost('/api/rides/$rideId/accept'))!;

  Future<Map<String, dynamic>> cancelRide(String rideId, {String? reason}) async =>
      (await _authedPost('/api/rides/$rideId/cancel', body: {
        if (reason != null) 'reason': reason,
      }))!;

  Future<Map<String, dynamic>> markRideArrived(String rideId) async =>
      (await _authedPost('/api/rides/$rideId/arrived'))!;

  Future<Map<String, dynamic>> startRide(String rideId) async =>
      (await _authedPost('/api/rides/$rideId/start'))!;

  Future<Map<String, dynamic>> completeRide(String rideId, {
    required double finalFare,
    int? distanceMeters,
    int? durationSeconds,
  }) async =>
      (await _authedPost('/api/rides/$rideId/complete', body: {
        'finalFare': finalFare,
        if (distanceMeters != null) 'distanceMeters': distanceMeters,
        if (durationSeconds != null) 'durationSeconds': durationSeconds,
      }))!;

  Future<Map<String, dynamic>> rateRide(String rideId, {
    required double stars,
    String? comment,
  }) async =>
      (await _authedPost('/api/rides/$rideId/rate', body: {
        'stars': stars,
        if (comment != null) 'comment': comment,
      }))!;

  Future<Map<String, dynamic>> listAvailableRides({
    required double lat,
    required double lng,
    double radiusKm = 5,
    int limit = 20,
  }) async =>
      (await _authedGet('/api/rides/available', queryParams: {
        'lat': lat.toString(),
        'lng': lng.toString(),
        'radiusKm': radiusKm.toString(),
        'limit': limit.toString(),
      }))!;

  // ---------------------------------------------------------------------------
  // CHAT — mensajes por viaje
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> listRideMessages(String rideId, {
    DateTime? since,
    int limit = 100,
  }) async =>
      (await _authedGet('/api/rides/$rideId/messages', queryParams: {
        if (since != null) 'since': since.toIso8601String(),
        'limit': limit.toString(),
      }))!;

  Future<Map<String, dynamic>> sendRideMessage(String rideId, {
    String? body,
    String? attachmentUrl,
  }) async =>
      (await _authedPost('/api/rides/$rideId/messages', body: {
        if (body != null) 'body': body,
        if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
      }))!;

  Future<Map<String, dynamic>> markMessagesRead(String rideId) async =>
      (await _authedPost('/api/rides/$rideId/messages/read'))!;

  // ---------------------------------------------------------------------------
  // NEGOTIATIONS + OFFERS
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> listNegotiations(String rideId) async =>
      (await _authedGet('/api/rides/$rideId/negotiations'))!;

  Future<Map<String, dynamic>> proposeNegotiation(String rideId, {
    required double amount,
    String? message,
  }) async =>
      (await _authedPost('/api/rides/$rideId/negotiations', body: {
        'amount': amount,
        if (message != null) 'message': message,
      }))!;

  Future<Map<String, dynamic>> acceptNegotiation(String negotiationId) async =>
      (await _authedPost('/api/negotiations/$negotiationId/accept'))!;

  Future<Map<String, dynamic>> rejectNegotiation(String negotiationId) async =>
      (await _authedPost('/api/negotiations/$negotiationId/reject'))!;

  Future<Map<String, dynamic>> listRideOffers(String rideId) async =>
      (await _authedGet('/api/rides/$rideId/offers'))!;

  Future<Map<String, dynamic>> submitRideOffer(String rideId, {
    double? amount,
    int? etaSeconds,
    String? message,
  }) async =>
      (await _authedPost('/api/rides/$rideId/offers', body: {
        if (amount != null) 'amount': amount,
        if (etaSeconds != null) 'etaSeconds': etaSeconds,
        if (message != null) 'message': message,
      }))!;

  Future<Map<String, dynamic>> acceptOffer(String offerId) async =>
      (await _authedPost('/api/offers/$offerId/accept'))!;

  // ---------------------------------------------------------------------------
  // PRESENCE + DRIVERS
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> heartbeat({
    required double latitude,
    required double longitude,
    double? heading,
    double? accuracy,
    double? speed,
    String? vehicleType,
    String? activeRideId,
  }) async =>
      (await _authedPost('/api/drivers/presence', body: {
        'latitude': latitude,
        'longitude': longitude,
        if (heading != null) 'heading': heading,
        if (accuracy != null) 'accuracy': accuracy,
        if (speed != null) 'speed': speed,
        if (vehicleType != null) 'vehicleType': vehicleType,
        if (activeRideId != null) 'activeRideId': activeRideId,
      }))!;

  Future<Map<String, dynamic>> setDriverOnline(bool isOnline) async =>
      (await _authedPost('/api/drivers/status', body: {'isOnline': isOnline}))!;

  Future<Map<String, dynamic>> driverStatus() async =>
      (await _authedGet('/api/drivers/status'))!;

  Future<Map<String, dynamic>> nearbyDrivers({
    required double latitude,
    required double longitude,
    double radiusKm = 3,
    String? vehicleType,
    int limit = 10,
  }) async =>
      (await _authedPost('/api/drivers/nearby', body: {
        'latitude': latitude,
        'longitude': longitude,
        'radiusKm': radiusKm,
        if (vehicleType != null) 'vehicleType': vehicleType,
        'limit': limit,
      }))!;

  Future<Map<String, dynamic>> driverLocation(String driverId) async =>
      (await _authedGet('/api/drivers/$driverId/location'))!;

  Future<Map<String, dynamic>> myDriverProfile() async =>
      (await _authedGet('/api/drivers/me/profile'))!;

  Future<Map<String, dynamic>> upsertVehicle({
    required String vehicleType,
    required String plate,
    String? make,
    String? model,
    String? color,
    int? year,
  }) async =>
      (await _authedPut('/api/drivers/me/vehicle', body: {
        'vehicleType': vehicleType,
        'plate': plate,
        if (make != null) 'make': make,
        if (model != null) 'model': model,
        if (color != null) 'color': color,
        if (year != null) 'year': year,
      }))!;

  Future<Map<String, dynamic>> myVehicle() async =>
      (await _authedGet('/api/drivers/me/vehicle'))!;

  Future<Map<String, dynamic>> myDocuments() async =>
      (await _authedGet('/api/drivers/me/documents'))!;

  /// Ronda 235: descarga un archivo protegido de /api/media/... con el token
  /// del user. Devuelve (bytes, mime). Sin esto, un <a href> abre 401 (el
  /// endpoint requiere Authorization Bearer).
  Future<({List<int> bytes, String mime})> fetchMediaBytes(String urlOrPath) async {
    await _ensureFreshAccess();
    final uri = Uri.parse(urlOrPath.startsWith('http') ? urlOrPath : '$baseUrl$urlOrPath');
    Future<http.Response> doGet() => _http.get(uri, headers: {'Authorization': 'Bearer $_accessCache'});
    var r = await doGet();
    if (r.statusCode == 401 && _refreshCache != null) {
      if (await refreshAccessToken()) r = await doGet();
    }
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw RapiApiException(r.statusCode, 'media_fetch_failed', 'HTTP ${r.statusCode}');
    }
    return (bytes: r.bodyBytes, mime: r.headers['content-type'] ?? 'application/octet-stream');
  }

  Future<Map<String, dynamic>> uploadDocument({
    required String docType,
    required String fileUrl,
  }) async =>
      (await _authedPost('/api/drivers/me/documents', body: {
        'docType': docType,
        'fileUrl': fileUrl,
      }))!;

  Future<Map<String, dynamic>> upgradeToDriver() async =>
      (await _authedPost('/api/drivers/me/upgrade'))!;

  // ---------------------------------------------------------------------------
  // EMERGENCIES + CONTACTS
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> createEmergency({
    String type = 'panic',
    required double latitude,
    required double longitude,
    String? address,
    String? description,
    String? rideId,
  }) async =>
      (await _authedPost('/api/emergencies', body: {
        'type': type,
        'latitude': latitude,
        'longitude': longitude,
        if (address != null) 'address': address,
        if (description != null) 'description': description,
        if (rideId != null) 'rideId': rideId,
      }))!;

  Future<Map<String, dynamic>> listEmergencies({String? status}) async =>
      (await _authedGet('/api/emergencies', queryParams: {
        if (status != null) 'status': status,
      }))!;

  Future<Map<String, dynamic>> listEmergencyContacts() async =>
      (await _authedGet('/api/emergency-contacts'))!;

  Future<Map<String, dynamic>> addEmergencyContact({
    required String name,
    required String phone,
    String? relationship,
    bool isPrimary = false,
  }) async =>
      (await _authedPost('/api/emergency-contacts', body: {
        'name': name,
        'phone': phone,
        if (relationship != null) 'relationship': relationship,
        'isPrimary': isPrimary,
      }))!;

  // ---------------------------------------------------------------------------
  // NOTIFICATIONS + FAVORITES + PAYMENT METHODS
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> listNotifications({bool onlyUnread = false, int limit = 50}) async =>
      (await _authedGet('/api/notifications', queryParams: {
        if (onlyUnread) 'onlyUnread': '1',
        'limit': limit.toString(),
      }))!;

  Future<Map<String, dynamic>> markNotificationRead(String id) async =>
      (await _authedPost('/api/notifications/$id/read'))!;

  Future<Map<String, dynamic>> markAllNotificationsRead() async =>
      (await _authedPost('/api/notifications/read-all'))!;

  Future<Map<String, dynamic>> listFavorites() async =>
      (await _authedGet('/api/favorites'))!;

  Future<Map<String, dynamic>> addFavorite({
    required String label,
    required String address,
    double? latitude,
    double? longitude,
    String? icon,
  }) async =>
      (await _authedPost('/api/favorites', body: {
        'label': label,
        'address': address,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (icon != null) 'icon': icon,
      }))!;

  Future<Map<String, dynamic>> listPaymentMethods() async =>
      (await _authedGet('/api/payment-methods'))!;

  Future<Map<String, dynamic>> addPaymentMethod({
    required String methodType,
    String? label,
    bool isDefault = false,
  }) async =>
      (await _authedPost('/api/payment-methods', body: {
        'methodType': methodType,
        if (label != null) 'label': label,
        'isDefault': isDefault,
      }))!;

  Future<void> deletePaymentMethod(String paymentMethodId) async {
    await _authedDelete('/api/payment-methods/$paymentMethodId');
  }

  Future<Map<String, dynamic>> listWalletTransactions({
    String? type,
    int page = 1,
    int pageSize = 50,
  }) async =>
      (await _authedGet('/api/wallet/transactions', queryParams: {
        if (type != null) 'type': type,
        'page': page.toString(),
        'pageSize': pageSize.toString(),
      }))!;

  // ─── Cuentas bancarias del conductor ───────────────────────────────────────

  Future<Map<String, dynamic>> listBankAccounts() async =>
      (await _authedGet('/api/drivers/me/bank-accounts'))!;

  Future<Map<String, dynamic>> addBankAccount({
    required String bankName,
    required String accountType,     // 'savings' | 'checking'
    required String accountNumber,
    required String holderName,
    required String holderDocument,
    String? cci,
    bool isDefault = false,
  }) async =>
      (await _authedPost('/api/drivers/me/bank-accounts', body: {
        'bankName': bankName,
        'accountType': accountType,
        'accountNumber': accountNumber,
        'holderName': holderName,
        'holderDocument': holderDocument,
        if (cci != null) 'cci': cci,
        'isDefault': isDefault,
      }))!;

  Future<Map<String, dynamic>> deleteBankAccount(String id) async =>
      (await _authedDelete('/api/drivers/me/bank-accounts/$id'))!;

  // ─── Retiros ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> listWithdrawals() async =>
      (await _authedGet('/api/wallet/withdrawals'))!;

  Future<Map<String, dynamic>> requestWithdrawal({
    required String bankAccountId,
    required double amount,
  }) async =>
      (await _authedPost('/api/wallet/withdrawals', body: {
        'bankAccountId': bankAccountId,
        'amount': amount,
      }))!;

  Future<Map<String, dynamic>> cancelWithdrawal(String id) async =>
      (await _authedDelete('/api/wallet/withdrawals/$id'))!;

  // ─── Place details (autocomplete → coords) ────────────────────────────────

  Future<Map<String, dynamic>> mapsPlaceDetails(String placeId) async =>
      (await _authedGet('/api/maps/place-details', queryParams: {
        'placeId': placeId,
      }))!;

  // ---------------------------------------------------------------------------
  // FCM push token registration
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> registerFcmToken(String token, {String? platform}) async =>
      (await _authedPost('/api/notifications/register-token', body: {
        'token': token,
        if (platform != null) 'platform': platform,
      }))!;

  // ---------------------------------------------------------------------------
  // SSE stream — pide ticket de un solo uso (60s) y devuelve la URL segura.
  // El JWT NUNCA viaja en la URL: se cambia por un ticket UUID que se consume
  // al abrir el stream (mitiga logs/referrer leaks del access_token).
  // ---------------------------------------------------------------------------

  /// Obtiene un ticket SSE de un solo uso. Devuelve la URL lista para EventSource.
  /// Uso:
  ///   final url = await api.getSseStreamUrl();
  ///   final sse = SSEClient.subscribeToSSE(url: url, ...);
  Future<String> getSseStreamUrl() async {
    final data = await _authedPost('/api/events/ticket');
    final ticket = data?['ticket'] as String?;
    if (ticket == null) {
      throw const RapiApiException(500, 'no_ticket');
    }
    return '$baseUrl/api/events/stream?ticket=$ticket';
  }

  /// Getter para el access token (para clientes que necesiten header Authorization).
  String? get currentAccessToken => _accessCache;

  Map<String, dynamic> _decodeOrThrow(http.Response r) {
    if (r.statusCode >= 200 && r.statusCode < 300) {
      // Ronda 214: antes hacíamos `jsonDecode(r.body) as Map<String,dynamic>`
      // en el happy-path sin try. Si nginx/proxy mal-configurado devolvía
      // HTML de error con 200, o el server respondía con un JSON array o
      // string, FormatException / TypeError subía UNHANDLED y los callers
      // solo atrapaban RapiApiException → crash silencioso o "Error inesperado".
      // Ahora también lo envolvemos.
      try {
        final decoded = jsonDecode(r.body);
        if (decoded is Map<String, dynamic>) return decoded;
        throw RapiApiException(
          r.statusCode,
          'bad_response_shape',
          'Se esperaba objeto JSON, se recibió ${decoded.runtimeType}',
        );
      } on FormatException catch (e) {
        throw RapiApiException(
          r.statusCode,
          'bad_response_format',
          'Server respondió con contenido no-JSON: ${e.message}',
        );
      }
    }
    try {
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      throw RapiApiException(
        r.statusCode,
        data['error']?.toString() ?? 'http_error',
        data['message']?.toString(),
      );
    } catch (e) {
      if (e is RapiApiException) rethrow;
      throw RapiApiException(r.statusCode, 'unexpected_response', r.body);
    }
  }
}

/// Wrapper de `http.Client` que aplica un timeout a cada request.
/// Se propaga automáticamente a `get/post/patch/delete/head/put` porque
/// todos esos van a través de `send()` en `BaseClient`.
class _TimeoutClient extends http.BaseClient {
  final http.Client _inner;
  final Duration _timeout;
  _TimeoutClient(this._inner, this._timeout);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request).timeout(
      _timeout,
      onTimeout: () => throw TimeoutException(
        'La solicitud tardó demasiado. Revisa tu conexión.',
        _timeout,
      ),
    );
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
