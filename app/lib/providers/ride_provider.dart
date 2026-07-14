import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/rapi_api_client.dart';
import '../services/rapi_sse_client.dart';
import '../services/notification_service.dart';
import '../models/trip_model.dart';
import '../models/user_model.dart';

/// Provider de Viajes usando backend Node (rapi-team-api) vía HTTP + SSE.
///
/// Reemplaza el uso previo de Firestore/Cloud Functions:
/// - Los `snapshots()` de Firestore se sustituyen por `RapiSseClient.rideUpdates`
///   filtrado por `rideId`.
/// - Las creaciones/actualizaciones de documentos se hacen contra
///   `RapiApiClient` (createRide, acceptRide, cancelRide, markRideArrived,
///   startRide, completeRide, rateRide).
/// - Las notificaciones push a conductores cercanos las gestiona el backend
///   automáticamente al crear el ride; la app ya no despacha FCM manualmente.
class RideProvider with ChangeNotifier {
  final RapiApiClient _api = RapiApiClient.instance;
  final RapiSseClient _sse = RapiSseClient.instance;
  final NotificationService _notificationService = NotificationService();

  TripModel? _currentTrip;
  List<TripModel> _tripHistory = [];
  List<UserModel> _nearbyDrivers = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Estado del viaje
  TripStatus _tripStatus = TripStatus.none;

  // Ofertas de conductores recibidas para la solicitud actual (estilo inDrive)
  final List<Map<String, dynamic>> _driverOffers = [];

  // Suscripciones SSE
  StreamSubscription<Map<String, dynamic>>? _rideUpdatesSub;
  StreamSubscription<Map<String, dynamic>>? _negotiationsSub;

  // Timer del auto-timeout (5min). Se cancela al aceptar/cancelar/completar
  // el ride o al hacer dispose del provider.
  Timer? _autoTimeoutTimer;

  RideProvider() {
    // Escuchamos rides en tiempo real desde que se instancia el provider.
    // El filtro por rideId se hace en cada evento recibido.
    _rideUpdatesSub = _sse.rideUpdates.listen(_onRideUpdateEvent);
    _negotiationsSub = _sse.negotiations.listen(_onNegotiationEvent);
  }

  // Getters
  TripModel? get currentTrip => _currentTrip;
  List<TripModel> get tripHistory => _tripHistory;
  List<UserModel> get nearbyDrivers => _nearbyDrivers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  TripStatus get tripStatus => _tripStatus;
  List<Map<String, dynamic>> get driverOffers => _driverOffers;
  bool get hasActiveTrip =>
      _currentTrip != null &&
      (_tripStatus == TripStatus.requested ||
          _tripStatus == TripStatus.accepted ||
          _tripStatus == TripStatus.driverArriving ||
          _tripStatus == TripStatus.inProgress);

  // ---------------------------------------------------------------------------
  // Helpers de parseo
  // ---------------------------------------------------------------------------

  /// Extrae un objeto `ride` de la respuesta HTTP (puede venir como
  /// `{ ride: {...} }` o directamente como el mapa raíz).
  Map<String, dynamic> _extractRide(Map<String, dynamic> response) {
    final nested = response['ride'];
    if (nested is Map<String, dynamic>) return nested;
    return response;
  }

  /// Extrae una lista de rides de la respuesta HTTP (busca `rides`, `items`
  /// o `data`).
  List<Map<String, dynamic>> _extractRideList(Map<String, dynamic> response) {
    final candidates = [response['rides'], response['items'], response['data']];
    for (final c in candidates) {
      if (c is List) {
        return c.whereType<Map<String, dynamic>>().toList();
      }
    }
    return const [];
  }

  /// Extrae una lista de conductores de la respuesta HTTP.
  List<Map<String, dynamic>> _extractDriverList(Map<String, dynamic> response) {
    final candidates = [
      response['drivers'],
      response['items'],
      response['data'],
    ];
    for (final c in candidates) {
      if (c is List) {
        return c.whereType<Map<String, dynamic>>().toList();
      }
    }
    return const [];
  }

  // ---------------------------------------------------------------------------
  // Búsqueda de conductores cercanos
  // ---------------------------------------------------------------------------

  /// Buscar conductores cercanos vía backend.
  Future<void> searchNearbyDrivers(LatLng userLocation, double radiusKm) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.nearbyDrivers(
        latitude: userLocation.latitude,
        longitude: userLocation.longitude,
        radiusKm: radiusKm,
      );

      final driversJson = _extractDriverList(response);
      _nearbyDrivers = driversJson.map((raw) {
        // Normalizamos la ubicación al formato esperado por UserModel
        // (`location: { lat, lng }`).
        final Map<String, dynamic> normalized = {...raw};
        if (normalized['location'] == null) {
          final lat = raw['latitude'] ?? raw['lat'];
          final lng = raw['longitude'] ?? raw['lng'];
          if (lat != null && lng != null) {
            normalized['location'] = {'lat': lat, 'lng': lng};
          }
        }
        normalized['userType'] ??= 'driver';
        return UserModel.fromJson(normalized);
      }).toList();

      debugPrint('🚗 Conductores encontrados: ${_nearbyDrivers.length}');
    } catch (e) {
      _errorMessage = 'Error buscando conductores: $e';
      debugPrint('❌ $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Solicitud / ciclo de vida del viaje (pasajero)
  // ---------------------------------------------------------------------------

  /// Solicitar viaje.
  Future<bool> requestRide({
    required LatLng pickupLocation,
    required LatLng destinationLocation,
    required String pickupAddress,
    required String destinationAddress,
    required String userId,
    String paymentMethod = 'cash',
    String? paymentMethodId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final estimatedFare = _calculateFare(pickupLocation, destinationLocation);

      final response = await _api.createRide(
        pickup: {
          'lat': pickupLocation.latitude,
          'lng': pickupLocation.longitude,
          'address': pickupAddress,
        },
        destination: {
          'lat': destinationLocation.latitude,
          'lng': destinationLocation.longitude,
          'address': destinationAddress,
        },
        vehicleType: 'standard',
        paymentMethod: paymentMethod,
        proposedFare: estimatedFare,
      );

      final rideJson = _extractRide(response);
      _currentTrip = TripModel.fromJson({
        ..._defaultTripFieldsForRequest(
          userId: userId,
          pickupLocation: pickupLocation,
          destinationLocation: destinationLocation,
          pickupAddress: pickupAddress,
          destinationAddress: destinationAddress,
          estimatedFare: estimatedFare,
          paymentMethod: paymentMethod,
          paymentMethodId: paymentMethodId,
        ),
        ...rideJson,
      });

      _tripStatus = TripStatus.requested;

      // Timeout automático si no hay conductor en 5 minutos. Usar Timer
      // (cancelable) en vez de Future.delayed para evitar leaks cuando el
      // usuario cancela manualmente o el provider muere.
      _autoTimeoutTimer?.cancel();
      final rideId = _currentTrip!.id;
      _autoTimeoutTimer = Timer(const Duration(minutes: 5), () async {
        if (_currentTrip?.id == rideId && _tripStatus == TripStatus.requested) {
          try {
            await _api.cancelRide(
              rideId,
              reason: 'No hay conductores disponibles en este momento',
            );
            _tripStatus = TripStatus.cancelled;
            _currentTrip = null;
            _driverOffers.clear();
            _errorMessage =
                'No se encontraron conductores disponibles. Intenta de nuevo.';
            notifyListeners();

            await _notificationService.showNotification(
              title: 'Viaje cancelado',
              body: 'No hay conductores disponibles en este momento',
            );
          } catch (e) {
            debugPrint('❌ Error en timeout automático: $e');
          }
        }
      });

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error solicitando viaje: $e';
      debugPrint('❌ $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Cancelar viaje.
  Future<bool> cancelRide() async {
    if (_currentTrip == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      await _api.cancelRide(_currentTrip!.id, reason: 'passenger_cancelled');

      _currentTrip = null;
      _tripStatus = TripStatus.cancelled;
      _driverOffers.clear();
      _autoTimeoutTimer?.cancel();
      _autoTimeoutTimer = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error cancelando viaje: $e';
      debugPrint('❌ $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Completar viaje.
  ///
  /// Llamado por el conductor al finalizar. El backend dispara automáticamente
  /// el procesamiento del pago al recibir el complete.
  Future<bool> completeTrip({
    required String tripId,
    required double finalFare,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (finalFare <= 0) {
        throw Exception('La tarifa final debe ser mayor a 0');
      }

      await _api.completeRide(tripId, finalFare: finalFare);

      debugPrint(
          '✅ Viaje completado: $tripId con tarifa S/ ${finalFare.toStringAsFixed(2)}');

      if (_currentTrip?.id == tripId) {
        _currentTrip = _currentTrip!.copyWith(
          status: 'completed',
          completedAt: DateTime.now(),
          finalFare: finalFare,
        );
        _tripStatus = TripStatus.completed;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error completando viaje: $e';
      debugPrint('❌ Error completando viaje: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Calificar viaje.
  Future<bool> rateTrip(String tripId, double rating, String? comment) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _api.rateRide(tripId, stars: rating, comment: comment);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error calificando viaje: $e';
      debugPrint('❌ $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Cargar historial de viajes del pasajero autenticado.
  ///
  /// El `userId` se mantiene por compatibilidad de firma con las pantallas,
  /// pero el backend infiere el usuario del JWT.
  Future<void> loadTripHistory(String userId) async {
    try {
      final response = await _api.listRides(role: 'passenger', pageSize: 50);
      final rides = _extractRideList(response);
      _tripHistory = rides.map((r) => TripModel.fromJson(r)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error cargando historial: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Escucha en tiempo real del viaje actual (SSE)
  // ---------------------------------------------------------------------------

  /// Refresca el estado del viaje actual desde el backend y asegura que la
  /// suscripción SSE está activa. Compatible con la vieja API que usaba
  /// `snapshots()` de Firestore.
  void listenToCurrentTrip() {
    if (_currentTrip == null) return;

    // Fetch inicial para no depender exclusivamente del próximo evento SSE.
    _api.getRide(_currentTrip!.id).then((data) {
      final rideJson = _extractRide(data);
      _currentTrip = TripModel.fromJson(rideJson);
      _updateTripStatus(_currentTrip!.status);
      notifyListeners();
    }).catchError((e) {
      debugPrint('Error refrescando viaje actual: $e');
    });

    // La suscripción global ya está viva desde el constructor. Nos aseguramos
    // de que el cliente SSE esté corriendo.
    _sse.start();
  }

  /// Handler de eventos `ride_update` provenientes del SSE.
  void _onRideUpdateEvent(Map<String, dynamic> event) {
    // El evento puede traer el ride completo o sólo un id + estado.
    final rideId = (event['rideId'] as String?) ??
        (event['id'] as String?) ??
        ((event['ride'] as Map<String, dynamic>?)?['id'] as String?);
    if (rideId == null) return;
    if (_currentTrip == null || _currentTrip!.id != rideId) return;

    try {
      final ridePartial = _extractRide(event);
      // Merge: partimos del ride actual y sobreescribimos los campos recibidos.
      final merged = {..._currentTrip!.toJson(), ...ridePartial, 'id': rideId};
      _currentTrip = TripModel.fromJson(merged);
      final status = _currentTrip!.status;
      _updateTripStatus(status);
      notifyListeners();
    } catch (e) {
      debugPrint('Error procesando ride_update SSE: $e');
    }
  }

  /// Handler de eventos `negotiation` provenientes del SSE.
  void _onNegotiationEvent(Map<String, dynamic> event) {
    final rideId =
        (event['rideId'] as String?) ?? (event['ride_id'] as String?);
    if (rideId == null || _currentTrip?.id != rideId) return;

    // Almacenamos la oferta (usada por la UI estilo inDrive).
    _driverOffers.add(event);
    notifyListeners();
  }

  /// Actualizar estado del viaje.
  void _updateTripStatus(String status) {
    switch (status) {
      case 'requested':
        _tripStatus = TripStatus.requested;
        break;
      case 'accepted':
        _tripStatus = TripStatus.accepted;
        break;
      case 'driver_arriving':
      case 'arrived':
        _tripStatus = TripStatus.driverArriving;
        break;
      case 'in_progress':
      case 'started':
        _tripStatus = TripStatus.inProgress;
        break;
      case 'completed':
        _tripStatus = TripStatus.completed;
        break;
      case 'cancelled':
        _tripStatus = TripStatus.cancelled;
        break;
      default:
        _tripStatus = TripStatus.none;
    }
  }

  // ---------------------------------------------------------------------------
  // Cálculos geométricos y de tarifa (locales)
  // ---------------------------------------------------------------------------

  /// Calcular distancia entre dos puntos (metros).
  double _calculateDistance(LatLng start, LatLng end) {
    const double earthRadius = 6371000; // metros
    double lat1Rad = start.latitude * pi / 180;
    double lat2Rad = end.latitude * pi / 180;
    double deltaLatRad = (end.latitude - start.latitude) * pi / 180;
    double deltaLngRad = (end.longitude - start.longitude) * pi / 180;

    double a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(deltaLngRad / 2) * sin(deltaLngRad / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  // Tarifas por defecto (el backend calcula la tarifa real; esto es solo un
  // estimado local para mostrar preview al usuario).
  static const double _configBaseFare = 5.0;
  static const double _configRatePerKm = 2.0;

  /// Calcular tarifa estimada localmente (en soles PEN).
  double _calculateFare(LatLng start, LatLng end) {
    double distanceKm = _calculateDistance(start, end) / 1000;
    return _configBaseFare + (distanceKm * _configRatePerKm);
  }

  // ---------------------------------------------------------------------------
  // Helpers de payload
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _defaultTripFieldsForRequest({
    required String userId,
    required LatLng pickupLocation,
    required LatLng destinationLocation,
    required String pickupAddress,
    required String destinationAddress,
    required double estimatedFare,
    required String paymentMethod,
    String? paymentMethodId,
  }) {
    final bool isPaidOutsideApp = paymentMethod == 'cash' ||
        paymentMethod == 'yape_external' ||
        paymentMethod == 'plin_external';
    return {
      'passengerId': userId,
      'userId': userId,
      'pickupLocation': {
        'lat': pickupLocation.latitude,
        'lng': pickupLocation.longitude,
      },
      'destinationLocation': {
        'lat': destinationLocation.latitude,
        'lng': destinationLocation.longitude,
      },
      'pickupAddress': pickupAddress,
      'destinationAddress': destinationAddress,
      'status': 'requested',
      'requestedAt': DateTime.now().toIso8601String(),
      'estimatedDistance':
          _calculateDistance(pickupLocation, destinationLocation),
      'estimatedFare': estimatedFare,
      'paymentMethod': paymentMethod,
      'isPaidOutsideApp': isPaidOutsideApp,
      'paymentMethodId': paymentMethodId,
    };
  }

  /// Limpiar error.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Verificación mutua de códigos
  // ---------------------------------------------------------------------------

  /// Generar código de verificación de 4 dígitos localmente (fallback).
  String _generateVerificationCode() {
    final random = Random();
    String code = '';
    for (int i = 0; i < 4; i++) {
      code += random.nextInt(10).toString();
    }
    return code;
  }

  /// Crear viaje con código de verificación para el pasajero.
  ///
  /// El backend genera el `passengerVerificationCode`; si no viene en la
  /// respuesta se calcula localmente para preservar el flujo UX.
  Future<TripModel?> createTripWithVerification({
    required String userId,
    required LatLng pickupLocation,
    required LatLng destinationLocation,
    required String pickupAddress,
    required String destinationAddress,
    required double estimatedDistance,
    required double estimatedFare,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final response = await _api.createRide(
        pickup: {
          'lat': pickupLocation.latitude,
          'lng': pickupLocation.longitude,
          'address': pickupAddress,
        },
        destination: {
          'lat': destinationLocation.latitude,
          'lng': destinationLocation.longitude,
          'address': destinationAddress,
        },
        vehicleType: 'standard',
        paymentMethod: 'cash',
        proposedFare: estimatedFare,
      );

      final rideJson = _extractRide(response);
      // Si el backend no devuelve el código, lo generamos localmente.
      final passengerCode = rideJson['passengerVerificationCode'] ??
          rideJson['verificationCode'] ??
          _generateVerificationCode();

      final trip = TripModel.fromJson({
        ..._defaultTripFieldsForRequest(
          userId: userId,
          pickupLocation: pickupLocation,
          destinationLocation: destinationLocation,
          pickupAddress: pickupAddress,
          destinationAddress: destinationAddress,
          estimatedFare: estimatedFare,
          paymentMethod: 'cash',
        ),
        ...rideJson,
        'passengerVerificationCode': passengerCode,
        'verificationCode': passengerCode,
        'estimatedDistance': estimatedDistance,
      });

      _currentTrip = trip;
      _tripStatus = TripStatus.requested;
      _isLoading = false;
      notifyListeners();

      debugPrint(
          '✅ Viaje creado con código de verificación del pasajero: $passengerCode');
      return trip;
    } catch (e) {
      _errorMessage = 'Error creando viaje: $e';
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ Error creando viaje: $e');
      return null;
    }
  }

  /// Generar código del conductor al aceptar (server-side).
  ///
  /// Delegado al endpoint `acceptRide`. El backend genera el
  /// `driverVerificationCode` y lo devuelve en la respuesta.
  Future<bool> generateDriverCodeOnAccept(
      String tripId, String driverId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await _api.acceptRide(tripId);
      final rideJson = _extractRide(response);

      final driverCode = rideJson['driverVerificationCode'] ??
          _generateVerificationCode();

      if (_currentTrip?.id == tripId) {
        _currentTrip = _currentTrip!.copyWith(
          driverVerificationCode: driverCode,
          driverId: driverId,
          status: 'accepted',
          acceptedAt: DateTime.now(),
        );
        _tripStatus = TripStatus.accepted;
        // Al aceptar ya no necesitamos el timeout ni las ofertas pendientes.
        _autoTimeoutTimer?.cancel();
        _autoTimeoutTimer = null;
        _driverOffers.clear();
      }

      _isLoading = false;
      notifyListeners();

      debugPrint('✅ Ride aceptado y código del conductor generado: $tripId');
      return true;
    } catch (e) {
      _errorMessage = 'Error generando código del conductor: $e';
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ Error generando código del conductor: $e');
      return false;
    }
  }

  /// Conductor verifica el código del pasajero.
  ///
  /// Se compara localmente contra `_currentTrip.passengerVerificationCode`.
  /// Si es correcto, marcamos `isPassengerVerified = true` y si ambos códigos
  /// están verificados iniciamos el viaje contra el backend.
  Future<bool> driverVerifiesPassengerCode(
      String tripId, String enteredCode) async {
    try {
      _isLoading = true;
      notifyListeners();

      if (_currentTrip?.id != tripId || _currentTrip == null) {
        _errorMessage = 'Viaje no encontrado en el estado local';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final expected = _currentTrip!.passengerVerificationCode;
      if (expected == null || expected.trim() != enteredCode.trim()) {
        _errorMessage = 'Código del pasajero incorrecto';
        _isLoading = false;
        notifyListeners();
        debugPrint('❌ Código del pasajero incorrecto: $tripId');
        return false;
      }

      _currentTrip = _currentTrip!.copyWith(isPassengerVerified: true);

      // Si ambos están verificados iniciamos el viaje en el backend.
      if (_currentTrip!.isMutualVerificationComplete) {
        await _startRideOnBackend(tripId);
      }

      _isLoading = false;
      notifyListeners();
      debugPrint('✅ Conductor verificó al pasajero correctamente: $tripId');
      return true;
    } catch (e) {
      _errorMessage = 'Error verificando código del pasajero: $e';
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ Error verificando código del pasajero: $e');
      return false;
    }
  }

  /// Pasajero verifica el código del conductor.
  Future<bool> passengerVerifiesDriverCode(
      String tripId, String enteredCode) async {
    try {
      _isLoading = true;
      notifyListeners();

      if (_currentTrip?.id != tripId || _currentTrip == null) {
        _errorMessage = 'Viaje no encontrado en el estado local';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final expected = _currentTrip!.driverVerificationCode;
      if (expected == null || expected.trim() != enteredCode.trim()) {
        _errorMessage = 'Código del conductor incorrecto';
        _isLoading = false;
        notifyListeners();
        debugPrint('❌ Código del conductor incorrecto: $tripId');
        return false;
      }

      _currentTrip = _currentTrip!.copyWith(isDriverVerified: true);

      bool tripStarted = false;
      if (_currentTrip!.isMutualVerificationComplete) {
        tripStarted = await _startRideOnBackend(tripId);
      }

      _isLoading = false;
      notifyListeners();

      if (tripStarted) {
        debugPrint(
            '✅ VERIFICACIÓN MUTUA COMPLETADA - Viaje iniciado: $tripId');
      } else {
        debugPrint(
            '✅ Pasajero verificó al conductor - Esperando verificación del conductor: $tripId');
      }
      return true;
    } catch (e) {
      _errorMessage = 'Error verificando código del conductor: $e';
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ Error verificando código del conductor: $e');
      return false;
    }
  }

  /// Dispara el `startRide` en el backend y actualiza el estado local.
  Future<bool> _startRideOnBackend(String tripId) async {
    try {
      await _api.startRide(tripId);
      if (_currentTrip?.id == tripId) {
        // ignore: deprecated_member_use_from_same_package
        _currentTrip = _currentTrip!.copyWith(
          status: 'in_progress',
          startedAt: DateTime.now(),
          verificationCompletedAt: DateTime.now(),
          isVerificationCodeUsed: true,
        );
        _tripStatus = TripStatus.inProgress;
      }
      return true;
    } catch (e) {
      debugPrint('❌ Error iniciando viaje en backend: $e');
      return false;
    }
  }

  /// ⚠️ DEPRECADO: Usar `driverVerifiesPassengerCode` o
  /// `passengerVerifiesDriverCode`.
  @Deprecated(
      'Usar driverVerifiesPassengerCode o passengerVerifiesDriverCode según corresponda')
  Future<bool> verifyTripCode(String tripId, String enteredCode) async {
    return driverVerifiesPassengerCode(tripId, enteredCode);
  }

  /// Obtener código de verificación del pasajero.
  String? get passengerVerificationCode =>
      _currentTrip?.passengerVerificationCode;

  /// Obtener código de verificación del conductor.
  String? get driverVerificationCode => _currentTrip?.driverVerificationCode;

  /// ¿Ya verificó el conductor al pasajero?
  bool get isPassengerVerified => _currentTrip?.isPassengerVerified ?? false;

  /// ¿Ya verificó el pasajero al conductor?
  bool get isDriverVerified => _currentTrip?.isDriverVerified ?? false;

  /// ¿Está completa la verificación mutua?
  bool get isMutualVerificationComplete =>
      _currentTrip?.isMutualVerificationComplete ?? false;

  /// ¿Puede iniciar el viaje?
  bool get canStartRide => _currentTrip?.canStartRide ?? false;

  /// ⚠️ DEPRECADO: Usar `passengerVerificationCode`.
  @Deprecated('Usar passengerVerificationCode en su lugar')
  String? get currentTripVerificationCode {
    // ignore: deprecated_member_use_from_same_package
    return _currentTrip?.verificationCode;
  }

  /// ⚠️ DEPRECADO: Usar `isMutualVerificationComplete`.
  @Deprecated('Usar isMutualVerificationComplete en su lugar')
  bool get isCurrentTripCodeUsed {
    // ignore: deprecated_member_use_from_same_package
    return _currentTrip?.isVerificationCodeUsed ?? false;
  }

  // ---------------------------------------------------------------------------
  // Transiciones de estado del conductor
  // ---------------------------------------------------------------------------

  /// Marcar al conductor como llegado.
  Future<void> markDriverArrived(String tripId) async {
    try {
      await _api.markRideArrived(tripId);

      if (_currentTrip?.id == tripId) {
        // Backend escribe 'arrived' — mantenemos consistencia. Antes ponía
        // 'driver_arriving' localmente y luego el SSE con 'arrived' hacía
        // que la UI cayera al default y "retrocediera" al panel de pickup.
        _currentTrip = _currentTrip!.copyWith(status: 'arrived');
        _tripStatus = TripStatus.driverArriving;
        notifyListeners();
      }

      debugPrint('✅ Conductor marcado como llegado para viaje: $tripId');
    } catch (e) {
      debugPrint('❌ Error marcando conductor como llegado: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Historial
  // ---------------------------------------------------------------------------

  /// Historial de viajes del usuario (pasajero).
  Future<List<TripModel>> getUserTripHistory(String userId) async {
    try {
      final response = await _api.listRides(role: 'passenger', pageSize: 50);
      final rides = _extractRideList(response);
      return rides.map((r) => TripModel.fromJson(r)).toList();
    } catch (e) {
      debugPrint('Error obteniendo historial de usuario: $e');
      return [];
    }
  }

  /// Historial de viajes del conductor (opcionalmente filtrado por rango de
  /// fechas — el filtro se aplica en cliente si el backend no lo soporta).
  Future<List<TripModel>> getDriverTripHistory(
    String driverId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final response = await _api.listRides(
        role: 'driver',
        status: 'completed',
        pageSize: 100,
      );
      final rides = _extractRideList(response);
      List<TripModel> trips =
          rides.map((r) => TripModel.fromJson(r)).toList();

      if (startDate != null) {
        trips = trips
            .where((t) =>
                t.completedAt != null &&
                !t.completedAt!.isBefore(startDate))
            .toList();
      }
      if (endDate != null) {
        trips = trips
            .where((t) =>
                t.completedAt != null &&
                !t.completedAt!.isAfter(endDate))
            .toList();
      }
      return trips;
    } catch (e) {
      debugPrint('Error obteniendo historial del conductor: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Notificaciones (compat)
  // ---------------------------------------------------------------------------

  /// Enviar notificación de cambio de estado del viaje.
  ///
  /// El backend Node se encarga automáticamente de despachar el push a los
  /// destinatarios correctos al detectar el cambio de estado; esta función
  /// se conserva para compatibilidad con las pantallas y no realiza
  /// operaciones adicionales.
  Future<void> sendTripStatusNotification({
    required String fcmToken,
    required String status,
    required String title,
    required String body,
    Map<String, dynamic>? additionalData,
  }) async {
    if (_currentTrip == null) return;
    debugPrint(
        'ℹ️ sendTripStatusNotification (delegado al backend): $status - $title');
  }

  /// Estadísticas de notificaciones para un viaje.
  ///
  /// El backend ya no expone estas métricas al cliente. Devolvemos `null`
  /// para preservar el contrato con las pantallas.
  Future<Map<String, int>?> getTripNotificationStats(String tripId) async {
    return null;
  }

  /// Reenviar notificaciones a conductores. En el nuevo backend basta con
  /// mantener el ride en estado `requested`: los conductores cercanos son
  /// notificados automáticamente. Aquí sólo refrescamos la lista local.
  Future<void> resendNotificationsToDrivers() async {
    if (_currentTrip == null || _tripStatus != TripStatus.requested) {
      debugPrint('No se puede reenviar notificaciones: no hay viaje activo');
      return;
    }

    try {
      final pickup = LatLng(
        _currentTrip!.pickupLocation.latitude,
        _currentTrip!.pickupLocation.longitude,
      );
      await searchNearbyDrivers(pickup, 5.0);
      debugPrint('🔄 Lista de conductores cercanos refrescada');
    } catch (e) {
      debugPrint('Error refrescando conductores cercanos: $e');
    }
  }

  /// Limpieza de tokens FCM inválidos — la mantiene el backend.
  Future<void> cleanupInvalidFCMTokens() async {
    // No-op: gestionado en el servidor.
  }

  // ---------------------------------------------------------------------------
  // Rating extendido con tags
  // ---------------------------------------------------------------------------

  /// Actualizar calificación del viaje.
  Future<void> updateTripRating(
    String tripId,
    String userId,
    double rating,
    String comment,
    List<String> tags,
  ) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Concatenamos los tags al comentario para no perder información,
      // dado que el endpoint sólo acepta `stars` y `comment`.
      final combinedComment = tags.isEmpty
          ? comment
          : (comment.isEmpty
              ? tags.join(', ')
              : '$comment [${tags.join(', ')}]');

      await _api.rateRide(tripId, stars: rating, comment: combinedComment);

      final tripIndex = _tripHistory.indexWhere((trip) => trip.id == tripId);
      if (tripIndex != -1) {
        _tripHistory[tripIndex] = _tripHistory[tripIndex].copyWith(
          passengerRating: rating,
          passengerComment: comment,
        );
      }

      debugPrint('Calificación actualizada: $rating estrellas para viaje $tripId');
    } catch (e) {
      debugPrint('Error actualizando calificación: $e');
      _errorMessage = 'Error al guardar calificación: $e';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _rideUpdatesSub?.cancel();
    _negotiationsSub?.cancel();
    _autoTimeoutTimer?.cancel();
    _autoTimeoutTimer = null;
    super.dispose();
  }
}

/// Estados del viaje.
enum TripStatus {
  none,
  requested,
  accepted,
  driverArriving,
  inProgress,
  completed,
  cancelled,
}
