import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../config/oauth_config.dart';
import '../models/trip_model.dart';
import '../utils/logger.dart';
import 'rapi_api_client.dart';
import 'rapi_sse_client.dart';

/// Stub no-op para reemplazar FirebaseAnalytics tras Fase 4.
///
/// El pubspec ya no depende de `firebase_analytics`, pero muchas pantallas
/// llaman `_firebaseService.analytics.logEvent(...)`. Este stub las mantiene
/// compilables. Cuando se migre a un backend de analítica (Amplitude, PostHog,
/// Segment, …) se reemplaza la implementación aquí.
class AnalyticsStub {
  const AnalyticsStub();

  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    if (kDebugMode) {
      debugPrint('[analytics] $name ${parameters ?? const {}}');
    }
  }

  Future<void> setUserId({String? id}) async {}
  Future<void> setUserProperty({required String name, String? value}) async {}
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {}
  Future<void> logScreenView({
    String? screenName,
    String? screenClass,
    Map<String, Object>? parameters,
  }) async {}
}

/// Stub no-op para reemplazar FirebaseCrashlytics tras Fase 4.
class CrashlyticsStub {
  const CrashlyticsStub();

  Future<void> recordError(
    dynamic error,
    StackTrace? stackTrace, {
    dynamic reason,
    Iterable<Object> information = const [],
    bool fatal = false,
    bool printDetails = true,
  }) async {
    AppLogger.error('Crashlytics stub — recordError', error, stackTrace);
  }

  Future<void> recordFlutterError(FlutterErrorDetails details,
      {bool fatal = false}) async {
    AppLogger.error(
        'Crashlytics stub — recordFlutterError', details.exception);
  }

  Future<void> log(String message) async {
    if (kDebugMode) debugPrint('[crashlytics] $message');
  }

  Future<void> setUserIdentifier(String identifier) async {}
  Future<void> setCustomKey(String key, Object value) async {}
  Future<void> setCrashlyticsCollectionEnabled(bool enabled) async {}
}

/// Stub no-op para reemplazar FirebaseAppCheck tras Fase 4.
class AppCheckStub {
  const AppCheckStub();

  Future<String?> getToken([bool forceRefresh = false]) async => null;
  Future<void> setTokenAutoRefreshEnabled(bool enabled) async {}
}

/// Servicio Firebase (stub post-migración al backend Node).
///
/// La aplicación migró de Firestore + Firebase Auth + Realtime Database +
/// Firebase Storage al backend Node (RapiApiClient / RapiSseClient). Este
/// wrapper se mantiene como capa de compatibilidad para código legado que
/// aún importa FirebaseService y consume:
///   - `analytics` / `crashlytics` / `appCheck` (stubs no-op)
///   - `messaging`                             (FCM push — Firebase real)
///   - `logEvent` / `recordError`              (helpers de telemetría)
///   - `signInWithGoogle` / `signInWithApple`  (RapiApiClient)
///   - `getRideById` / `listenToRideUpdates`   (RapiApiClient/SSE)
///   - `getDriverLocation*` / `getUserById`    (RapiApiClient)
///   - `cancelRide` / `reportEmergency`        (RapiApiClient)
///   - `uploadFile` / `signOut` / `currentUserId` (RapiApiClient)
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  // Analytics/Crashlytics/AppCheck son stubs no-op — el pubspec ya no depende
  // de firebase_analytics / firebase_crashlytics / firebase_app_check.
  static const AnalyticsStub _analyticsStub = AnalyticsStub();
  static const CrashlyticsStub _crashlyticsStub = CrashlyticsStub();
  static const AppCheckStub _appCheckStub = AppCheckStub();

  AnalyticsStub get analytics => _analyticsStub;
  CrashlyticsStub get crashlytics => _crashlyticsStub;
  AppCheckStub get appCheck => _appCheckStub;

  // Messaging sigue siendo Firebase real — se usa para push notifications.
  late FirebaseMessaging messaging;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  // Google Sign-In inicialización única (requisito v7.x)
  bool _googleSignInInitialized = false;

  // Suscripción de refresh del token FCM
  // ignore: unused_field
  StreamSubscription<String>? _tokenRefreshSubscription;

  /// Inicializa Messaging. Analytics/Crashlytics/AppCheck son no-op.
  Future<void> initialize() async {
    if (_initialized) {
      AppLogger.warning('Firebase (stub) ya estaba inicializado, saltando...');
      return;
    }

    try {
      AppLogger.firebase('Inicializando FirebaseService (stub)');

      // Firebase.initializeApp ya se ejecuta en main.dart
      if (Firebase.apps.isEmpty) {
        AppLogger.error('Firebase no ha sido inicializado en main.dart');
        throw Exception('Firebase debe ser inicializado en main.dart primero');
      }

      messaging = FirebaseMessaging.instance;

      if (!kIsWeb) {
        try {
          AppLogger.firebase('Configurando Firebase Cloud Messaging');
          await _setupMessaging();
        } catch (e) {
          AppLogger.warning('Messaging no disponible en esta plataforma', e);
        }
      }

      _initialized = true;
      AppLogger.firebase(
          'FirebaseService (stub) listo — messaging Firebase real, analytics/crashlytics stub');
    } catch (e, stackTrace) {
      AppLogger.error('Error inicializando FirebaseService (stub)', e, stackTrace);
      rethrow;
    }
  }

  /// Configura FCM y registra el token en el backend Node
  Future<void> _setupMessaging() async {
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: true,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      debugPrint('Permisos de notificación otorgados');

      final token = await messaging.getToken();
      if (token != null) {
        await _registerFcmToken(token);
        debugPrint('FCM Token: $token');
      }

      // Ronda 214: cancelar suscripción previa antes de crear otra. Sin esto,
      // si _setupMessaging se llama múltiples veces (nueva inicialización tras
      // logout/login), se apilan listeners y cada refresh dispara N POSTs de
      // registerFcmToken.
      await _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = messaging.onTokenRefresh.listen((token) async {
        await _registerFcmToken(token);
      });
    }
  }

  /// Ronda 214: liberar subscription + estado. Llamar desde signOut/logout
  /// para no arrastrar el listener del user anterior a la próxima sesión.
  Future<void> disposeMessaging() async {
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
  }

  /// Registra el token FCM en el backend Node (sustituye escritura en Firestore)
  Future<void> _registerFcmToken(String token) async {
    if (!RapiApiClient.instance.isSignedIn) return;
    try {
      String? platform;
      if (kIsWeb) {
        platform = 'web';
      } else if (Platform.isAndroid) {
        platform = 'android';
      } else if (Platform.isIOS) {
        platform = 'ios';
      }
      await RapiApiClient.instance.registerFcmToken(token, platform: platform);
    } catch (e) {
      debugPrint('Error registrando token FCM en backend: $e');
    }
  }

  /// Registrar evento en Analytics (stub — logs a debug).
  Future<void> logEvent(String name, Map<String, dynamic>? parameters) async {
    try {
      await analytics.logEvent(
        name: name,
        parameters:
            parameters?.map((key, value) => MapEntry(key, value as Object)),
      );
    } catch (e) {
      debugPrint('Error registrando evento: $e');
    }
  }

  /// Registrar error (stub — logs a AppLogger).
  Future<void> recordError(dynamic error, StackTrace? stackTrace) async {
    try {
      await crashlytics.recordError(error, stackTrace);
    } catch (_) {}
  }

  /// Sube un archivo al backend Node. Retorna la URL pública/firmada.
  Future<String> uploadFile(String scope, File file) async {
    try {
      final res =
          await RapiApiClient.instance.uploadFile(file: file, scope: scope);
      return (res['url'] as String?) ?? '';
    } catch (e) {
      debugPrint('Error subiendo archivo: $e');
      rethrow;
    }
  }

  /// UID del usuario actual (el backend Node reusa los mismos IDs).
  String? get currentUserId {
    return RapiApiClient.instance.isSignedIn ? '__signed_in__' : null;
  }

  /// Compatibilidad con código antiguo — indica si hay sesión activa.
  bool get hasSession => RapiApiClient.instance.isSignedIn;

  /// Stream de estado de autenticación basado en la conectividad SSE.
  Stream<bool> get authStateChanges async* {
    yield RapiApiClient.instance.isSignedIn;
    yield* RapiSseClient.instance.connected;
  }

  // ==========================================================================
  // OAUTH: Google + Apple sign-in usando el backend Node
  // ==========================================================================

  /// Google Sign-In. Obtiene idToken y lo cambia por sesión en el backend.
  Future<Map<String, dynamic>?> signInWithGoogle() async {
    try {
      AppLogger.firebase('Iniciando autenticación con Google');
      await logEvent('google_login_attempt', {});

      final googleSignIn = GoogleSignIn.instance;

      if (!_googleSignInInitialized) {
        await googleSignIn.initialize(
          hostedDomain: null,
          serverClientId: OAuthConfig.googleWebClientId,
          clientId: Platform.isIOS ? OAuthConfig.googleIosClientId : null,
        );
        _googleSignInInitialized = true;
        AppLogger.debug('GoogleSignIn initialized (once)');
      }

      try {
        await googleSignIn.signOut();
      } catch (e) {
        AppLogger.debug('signOut before authenticate (ignorable): $e');
      }

      final googleUser = await googleSignIn.authenticate(
        scopeHint: ['email', 'profile'],
      );

      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw Exception('Google Sign-In no devolvió idToken');
      }

      final data =
          await RapiApiClient.instance.loginWithGoogleIdToken(idToken);

      RapiSseClient.instance.start();

      await logEvent('google_login_success', {
        'user_id': (data['user'] as Map?)?['id']?.toString() ?? '',
        'email': googleUser.email,
      });

      AppLogger.firebase('Google Sign-In completado exitosamente');
      return data;
    } on GoogleSignInException catch (e, stackTrace) {
      AppLogger.error(
          'GoogleSignInException: code=${e.code}, description=${e.description}',
          e,
          stackTrace);
      await recordError(e, stackTrace);
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error('Error en login con Google: ${e.runtimeType}: $e', e,
          stackTrace);
      await recordError(e, stackTrace);
      rethrow;
    }
  }

  /// Sign in with Apple.
  Future<Map<String, dynamic>?> signInWithApple() async {
    try {
      AppLogger.firebase('Iniciando autenticación con Apple');
      await logEvent('apple_login_attempt', {});

      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
        webAuthenticationOptions: Platform.isAndroid
            ? WebAuthenticationOptions(
                clientId: OAuthConfig.appleServiceId,
                redirectUri: Uri.parse(OAuthConfig.appleRedirectUri),
              )
            : null,
      );

      if (appleCredential.identityToken == null) {
        throw Exception('Apple Sign-In: no se recibió identityToken');
      }

      String? fullName;
      if (appleCredential.givenName != null ||
          appleCredential.familyName != null) {
        fullName =
            [appleCredential.givenName, appleCredential.familyName]
                .whereType<String>()
                .join(' ')
                .trim();
        if (fullName.isEmpty) fullName = null;
      }

      final data = await RapiApiClient.instance.loginWithAppleIdentityToken(
        identityToken: appleCredential.identityToken!,
        fullName: fullName,
      );

      RapiSseClient.instance.start();

      await logEvent('apple_login_success', {
        'user_id': (data['user'] as Map?)?['id']?.toString() ?? '',
        'email': appleCredential.email ?? '',
      });

      return data;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        AppLogger.firebase('Usuario canceló Sign in with Apple');
        return null;
      }
      AppLogger.error('Error de autorización Apple: ${e.code}', e);
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error('Error en login con Apple', e, stackTrace);
      await recordError(e, stackTrace);
      rethrow;
    }
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = math.Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ==========================================================================
  // EMERGENCIAS — delegan al backend Node
  // ==========================================================================

  /// Reporta emergencia SOS al backend.
  ///
  /// Ronda 214 CRÍTICO: antes atrapaba TODOS los errores y solo los enviaba
  /// a Crashlytics — el passenger veía "SOS enviado" en la UI aunque el
  /// backend nunca recibiera el request (sin red, backend caído, token
  /// expirado). Un SOS SILENCIOSO durante emergencia real es peor que
  /// ningún SOS: el passenger deja de intentar otras vías creyendo que
  /// alguien viene en camino.
  ///
  /// Ahora: registramos el evento y Crashlytics, PERO re-lanzamos el error
  /// para que el UI muestre banner "SOS falló, reintenta o llama 105".
  Future<void> reportEmergency(String rideId, dynamic position) async {
    try {
      AppLogger.firebase('Reportando emergencia para viaje: $rideId');
      await logEvent('emergency_reported', {'ride_id': rideId});

      await RapiApiClient.instance.createEmergency(
        rideId: rideId,
        latitude: (position?.latitude as num?)?.toDouble() ?? 0.0,
        longitude: (position?.longitude as num?)?.toDouble() ?? 0.0,
        type: 'sos',
        description: 'Emergencia reportada desde seguimiento de viaje',
      );

      AppLogger.firebase('Emergencia reportada al backend');
    } catch (e, stackTrace) {
      AppLogger.error('Error reportando emergencia', e, stackTrace);
      await recordError(e, stackTrace);
      // Ronda 214: propagar SIEMPRE. El caller UI debe mostrar error visible.
      rethrow;
    }
  }

  // ==========================================================================
  // AUTENTICACIÓN — sesión / logout
  // ==========================================================================

  Future<void> signOut() async {
    try {
      await RapiApiClient.instance.logout();
    } finally {
      await RapiSseClient.instance.stop();
    }
  }

  // ==========================================================================
  // RIDES — obtener/cancelar/escuchar viajes vía backend Node
  // ==========================================================================

  /// Obtiene un viaje por ID (delegado a RapiApiClient.getRide).
  Future<TripModel?> getRideById(String rideId) async {
    try {
      final res = await RapiApiClient.instance.getRide(rideId);
      final data = (res['ride'] as Map<String, dynamic>?) ??
          (res['data'] as Map<String, dynamic>?) ??
          res;
      return _tripFromJson(rideId, data);
    } catch (e) {
      AppLogger.firebase('Error obteniendo viaje',
          {'error': e.toString(), 'rideId': rideId});
      return null;
    }
  }

  /// Escucha actualizaciones del viaje en tiempo real vía SSE.
  /// Al reconectar SSE tras un drop, refetch el estado del ride para no perder
  /// eventos que ocurrieron mientras el socket estaba caído.
  StreamSubscription<Map<String, dynamic>> listenToRideUpdates(
    String rideId,
    void Function(TripModel) onUpdate,
  ) {
    // Al arrancar, cargar el estado inicial vía HTTP
    getRideById(rideId).then((trip) {
      if (trip != null) onUpdate(trip);
    });

    // Asegurar que el SSE está corriendo
    RapiSseClient.instance.start();

    // Suscripción auxiliar: cuando SSE se reconecte (false→true), refetch
    // del ride para no perder eventos ocurridos durante el drop.
    // La guardamos y la cancelamos junto con el SSE sub via onCancel del wrapper.
    var wasConnected = false;
    final reconnectSub = RapiSseClient.instance.connected.listen((isConnected) {
      if (isConnected && !wasConnected) {
        wasConnected = true;
        // Skip el primer emit al conectarse por primera vez — el initial fetch
        // arriba ya cubre eso. Solo refetch en reconexiones subsecuentes.
        Future.microtask(() async {
          final trip = await getRideById(rideId);
          if (trip != null) onUpdate(trip);
        });
      } else if (!isConnected) {
        wasConnected = false;
      }
    });

    final sseSub = RapiSseClient.instance.rideUpdates.listen((event) {
      final eventRideId = (event['rideId'] ?? event['id'])?.toString();
      if (eventRideId != null && eventRideId != rideId) return;
      final trip = _tripFromJson(rideId, event);
      if (trip != null) onUpdate(trip);
    });

    // Cuando el caller cancela la subscription retornada, tambien cancelamos
    // la del reconnect — sin esto queda leak del listener a `connected`.
    sseSub.onDone(() { reconnectSub.cancel(); });
    // Wrap para asegurar que cancel() también limpia reconnectSub.
    return _WrappedSubscription(sseSub, reconnectSub);
  }

  /// Construye un TripModel a partir del JSON del backend Node.
  /// Ronda 245: arma el mapa `vehicleInfo` que espera la UI a partir de los
  /// campos que el backend sí envía en la raíz del ride. Devuelve null si no
  /// hay nada útil, para no crear un objeto vacío que dispare secciones de UI.
  Map<String, dynamic>? _vehicleInfoFromRoot(Map<String, dynamic> data) {
    final vehicle = (data['vehicle'] as Map?)?.cast<String, dynamic>();
    final info = <String, dynamic>{
      if (data['driverName'] != null) 'driverName': data['driverName'],
      if (data['driverPhone'] != null) 'driverPhone': data['driverPhone'],
      if (data['driverPhotoUrl'] != null) 'driverPhoto': data['driverPhotoUrl'],
      if (data['driverRating'] != null) 'driverRating': data['driverRating'],
      if (data['vehicleType'] != null) 'type': data['vehicleType'],
      if (vehicle?['plate'] != null) 'plate': vehicle!['plate'],
      if (vehicle?['make'] != null) 'brand': vehicle!['make'],
      if (vehicle?['model'] != null) 'model': vehicle!['model'],
      if (vehicle?['color'] != null) 'color': vehicle!['color'],
    };
    return info.isEmpty ? null : info;
  }

  TripModel? _tripFromJson(String rideId, Map<String, dynamic> data) {
    try {
      // Ronda 245 BUG BLOQUEANTE: el backend serializa
      //   pickup:      { address, lat, lng }
      //   destination: { address, lat, lng }
      // pero acá se leían las claves `pickupLocation`/`destinationLocation`
      // y `pickupAddress`/`destinationAddress`, que NO existen en la
      // respuesta. Resultado: TODO viaje en la pantalla de seguimiento
      // aterrizaba en LatLng(0,0) — la Isla Nula, en medio del Atlántico —
      // con la cámara allí, la ruta trazada hacia el océano, ETA delirante y
      // las direcciones en blanco. Y como cada evento SSE vuelve a pasar por
      // esta misma función, cualquier dato bueno se pisaba al siguiente tick.
      final pickupLoc = (data['pickup'] as Map?)?.cast<String, dynamic>() ??
          (data['pickupLocation'] as Map?)?.cast<String, dynamic>() ??
          {};
      final destLoc = (data['destination'] as Map?)?.cast<String, dynamic>() ??
          (data['destinationLocation'] as Map?)?.cast<String, dynamic>() ??
          {};

      return TripModel(
        id: (data['id'] ?? data['rideId'] ?? rideId).toString(),
        userId: (data['userId'] ?? data['passengerId'] ?? '').toString(),
        driverId: data['driverId']?.toString(),
        pickupLocation: LatLng(
          _asDouble(pickupLoc['lat'] ?? pickupLoc['latitude']) ?? 0.0,
          _asDouble(pickupLoc['lng'] ?? pickupLoc['longitude']) ?? 0.0,
        ),
        destinationLocation: LatLng(
          _asDouble(destLoc['lat'] ?? destLoc['latitude']) ?? 0.0,
          _asDouble(destLoc['lng'] ?? destLoc['longitude']) ?? 0.0,
        ),
        pickupAddress:
            (pickupLoc['address'] ?? data['pickupAddress'] ?? '').toString(),
        destinationAddress:
            (destLoc['address'] ?? data['destinationAddress'] ?? '').toString(),
        status: (data['status'] ?? 'searching').toString(),
        requestedAt: _parseIsoDate(data['requestedAt']) ?? DateTime.now(),
        acceptedAt: _parseIsoDate(data['acceptedAt']),
        startedAt: _parseIsoDate(data['startedAt']),
        completedAt: _parseIsoDate(data['completedAt']),
        cancelledAt: _parseIsoDate(data['cancelledAt']),
        cancelledBy: data['cancelledBy']?.toString(),
        // Ronda 245: el backend envía `distanceMeters`; `estimatedDistance`
        // no existe → la distancia salía siempre 0.0. TripModel espera km.
        estimatedDistance: _asDouble(data['estimatedDistance']) ??
            (_asDouble(data['distanceMeters']) != null
                ? _asDouble(data['distanceMeters'])! / 1000.0
                : null) ??
            _asDouble(data['distanceKm']) ??
            0.0,
        estimatedFare: _asDouble(data['estimatedFare']) ?? 0.0,
        finalFare: _asDouble(data['finalFare']),
        passengerRating: _asDouble(data['passengerRating']),
        passengerComment: data['passengerComment']?.toString(),
        driverRating: _asDouble(data['driverRating']),
        driverComment: data['driverComment']?.toString(),
        // Ronda 245: el backend NO envía un objeto `vehicleInfo`; manda
        // `driverName`, `driverPhone`, `driverPhotoUrl` y `vehicleType` en la
        // RAÍZ del ride. Al leer solo `vehicleInfo`, quedaba null y en la
        // pantalla de seguimiento no se veía placa ni vehículo, el rating
        // mostraba un 5.00 inventado, y el botón de llamar al conductor decía
        // "Teléfono no disponible" AUNQUE el teléfono sí venía en la respuesta.
        // Lo componemos a partir de lo que realmente llega.
        vehicleInfo: (data['vehicleInfo'] as Map?)?.cast<String, dynamic>() ??
            _vehicleInfoFromRoot(data),
        route: data['route'] is List
            ? (data['route'] as List)
                .whereType<Map>()
                .map((p) => LatLng(
                      _asDouble(p['lat']) ?? 0.0,
                      _asDouble(p['lng']) ?? 0.0,
                    ))
                .toList()
            : null,
        verificationCode: (data['verificationCode'] ??
                data['passengerVerificationCode'])
            ?.toString(),
        isVerificationCodeUsed:
            data['isVerificationCodeUsed'] as bool? ??
                data['isPassengerVerified'] as bool? ??
                false,
        passengerVerificationCode:
            data['passengerVerificationCode']?.toString(),
        driverVerificationCode: data['driverVerificationCode']?.toString(),
        isPassengerVerified: data['isPassengerVerified'] as bool? ?? false,
        isDriverVerified: data['isDriverVerified'] as bool? ?? false,
      );
    } catch (e) {
      AppLogger.firebase(
          'Error mapeando ride JSON → TripModel', {'error': e.toString()});
      return null;
    }
  }

  double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  DateTime? _parseIsoDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  /// Ubicación del conductor con heading.
  Future<Map<String, double>?> getDriverLocationWithHeading(String? driverId) async {
    if (driverId == null || driverId.isEmpty) return null;
    try {
      final res = await RapiApiClient.instance.driverLocation(driverId);
      final loc = (res['location'] as Map?)?.cast<String, dynamic>() ?? res;
      final lat = _asDouble(loc['lat'] ?? loc['latitude']);
      final lng = _asDouble(loc['lng'] ?? loc['longitude']);
      final heading = _asDouble(loc['heading']) ?? 0.0;
      if (lat != null && lng != null) {
        return {'lat': lat, 'lng': lng, 'heading': heading};
      }
      return null;
    } catch (e) {
      AppLogger.firebase(
          'Error obteniendo ubicación del conductor', {'error': e.toString()});
      return null;
    }
  }

  /// Ubicación del conductor (solo LatLng, para compatibilidad).
  Future<LatLng?> getDriverLocation(String? driverId) async {
    final data = await getDriverLocationWithHeading(driverId);
    if (data == null) return null;
    return LatLng(data['lat']!, data['lng']!);
  }

  /// Perfil de usuario. Si `userId` es el actual, llama a `me()`; si no,
  /// retorna null (no hay endpoint público para perfiles ajenos).
  Future<Map<String, dynamic>?> getUserById(String userId) async {
    try {
      if (!RapiApiClient.instance.isSignedIn) return null;
      final me = await RapiApiClient.instance.me();
      if (me == null) return null;
      final user = (me['user'] as Map?)?.cast<String, dynamic>() ?? me;
      final myId = user['id']?.toString() ?? user['uid']?.toString();
      if (myId == userId) return user;
      return null;
    } catch (e) {
      AppLogger.firebase(
          'Error obteniendo usuario', {'error': e.toString()});
      return null;
    }
  }

  /// Cancelar un viaje (delegado a RapiApiClient).
  Future<void> cancelRide(String rideId) async {
    try {
      await RapiApiClient.instance.cancelRide(rideId);
      await logEvent('ride_cancelled', {'ride_id': rideId});
    } catch (e) {
      AppLogger.firebase('Error cancelando viaje', {'error': e.toString()});
      throw Exception('No se pudo cancelar el viaje');
    }
  }
}

/// Wrapper de StreamSubscription que cancela una subscription secundaria
/// junto con la primaria. Usado por listenToRideUpdates para no filtrar
/// el listener al `connected` stream cuando el caller cancela.
class _WrappedSubscription<T> implements StreamSubscription<T> {
  final StreamSubscription<T> _inner;
  final StreamSubscription<dynamic> _secondary;
  _WrappedSubscription(this._inner, this._secondary);

  @override
  Future<void> cancel() async {
    await _secondary.cancel();
    await _inner.cancel();
  }

  @override
  void onData(void Function(T data)? handleData) => _inner.onData(handleData);
  @override
  void onError(Function? handleError) => _inner.onError(handleError);
  @override
  void onDone(void Function()? handleDone) => _inner.onDone(handleDone);
  @override
  void pause([Future<void>? resumeSignal]) => _inner.pause(resumeSignal);
  @override
  void resume() => _inner.resume();
  @override
  bool get isPaused => _inner.isPaused;
  @override
  Future<E> asFuture<E>([E? futureValue]) => _inner.asFuture<E>(futureValue);
}
