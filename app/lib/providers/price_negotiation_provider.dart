import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as math;
import '../models/price_negotiation_model.dart';
import '../services/rapi_api_client.dart';
import '../services/rapi_sse_client.dart';
import '../utils/error_messages.dart';

/// Provider para manejar las negociaciones de precios estilo InDrive.
/// Migrado de Firebase (Firestore / FirebaseAuth) al backend Node:
///   - Estado inicial: HTTP vía [RapiApiClient]
///   - Deltas en tiempo real: SSE vía [RapiSseClient]
///
/// En el nuevo modelo backend, la "negociación" y el "ride" son la misma
/// entidad: cuando el pasajero crea un ride con `negotiable: true`, el mismo
/// `rideId` funciona como identificador de negociación. Los conductores
/// contra-ofertan a través de "offers" asociadas al ride.
class PriceNegotiationProvider extends ChangeNotifier {
  // -------------------- Estado --------------------
  final List<PriceNegotiation> _activeNegotiations = [];
  List<PriceNegotiation> _driverVisibleRequests = [];
  PriceNegotiation? _currentNegotiation;

  /// Mapa rideId → (driverId → offerId).
  /// Necesario para poder llamar `api.acceptOffer(offerId)` conociendo solo
  /// el `driverId` (la UI acepta ofertas por conductor, no por offerId).
  final Map<String, Map<String, String>> _offerIdsByNegotiation = {};

  // Cache del usuario actual (evita golpear /me en cada operación).
  String? _cachedUserId;
  Map<String, dynamic>? _cachedUserData;

  // Última ubicación conocida del conductor. Se refresca en cada
  // [loadDriverRequests] preguntándola al backend.
  LatLng? _lastDriverLocation;

  // Suscripciones a los streams SSE.
  StreamSubscription<Map<String, dynamic>>? _passengerNegotiationSub;
  StreamSubscription<Map<String, dynamic>>? _passengerRideUpdatesSub;
  StreamSubscription<Map<String, dynamic>>? _driverRideUpdatesSub;
  StreamSubscription<Map<String, dynamic>>? _driverNegotiationSub;

  RapiApiClient get _api => RapiApiClient.instance;
  RapiSseClient get _sse => RapiSseClient.instance;

  // -------------------- Getters públicos --------------------
  List<PriceNegotiation> get activeNegotiations => _activeNegotiations;
  List<PriceNegotiation> get driverVisibleRequests => _driverVisibleRequests;
  PriceNegotiation? get currentNegotiation => _currentNegotiation;

  // -------------------- Helpers de usuario --------------------
  Future<String?> _getCurrentUserId() async {
    if (_cachedUserId != null) return _cachedUserId;
    try {
      final me = await _api.me();
      if (me == null) return null;
      _cachedUserData = me;
      _cachedUserId = (me['id'] ?? me['userId'] ?? me['uid'])?.toString();
      return _cachedUserId;
    } catch (e) {
      debugPrint('❌ Error obteniendo usuario actual: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> _getCurrentUserData() async {
    if (_cachedUserData != null) return _cachedUserData!;
    try {
      final me = await _api.me();
      if (me != null) {
        _cachedUserData = me;
        _cachedUserId = (me['id'] ?? me['userId'] ?? me['uid'])?.toString();
        return me;
      }
    } catch (e) {
      // Log para observabilidad — antes silencio total ocultaba fallos de red.
      debugPrint('getCachedUserData falló: $e');
    }
    return const {};
  }

  // -------------------- Listener PASAJERO --------------------
  /// Inicia la escucha en tiempo real para el pasajero.
  /// @param isRoleSwitchInProgress - Si `true`, no iniciar (cambio de rol en curso).
  void startListeningToMyNegotiations({bool isRoleSwitchInProgress = false}) {
    if (isRoleSwitchInProgress) {
      debugPrint('⚠️ Cambio de rol en progreso, no iniciar listener de pasajero');
      return;
    }

    debugPrint('🔄 Iniciando listener de negociaciones (pasajero)');

    // Cancelar suscripciones anteriores.
    _passengerNegotiationSub?.cancel();
    _passengerRideUpdatesSub?.cancel();

    // Estado inicial via HTTP — el SSE solo entrega deltas.
    _refreshMyNegotiations();

    // SSE: nueva contraoferta / oferta aceptada / rechazada.
    _passengerNegotiationSub = _sse.negotiations.listen(
      (event) async {
        debugPrint('📡 SSE negotiation (pasajero) → $event');
        await _refreshMyNegotiations();
      },
      onError: (e) => debugPrint('❌ SSE negociaciones (pasajero) error: $e'),
    );

    // SSE: cambios de estado del viaje/negociación.
    _passengerRideUpdatesSub = _sse.rideUpdates.listen(
      (event) async {
        debugPrint('📡 SSE ride_update (pasajero) → $event');
        await _refreshMyNegotiations();
      },
      onError: (e) => debugPrint('❌ SSE rideUpdates (pasajero) error: $e'),
    );
  }

  /// Detiene solo el listener del pasajero.
  void stopListeningToNegotiations() {
    debugPrint('🛑 Deteniendo listener de negociaciones (pasajero)');
    _passengerNegotiationSub?.cancel();
    _passengerNegotiationSub = null;
    _passengerRideUpdatesSub?.cancel();
    _passengerRideUpdatesSub = null;
  }

  /// Cleanup centralizado — detener TODOS los listeners al cambiar de rol.
  void stopAllListeners() {
    debugPrint('🛑 Deteniendo TODOS los listeners de negociaciones');
    _passengerNegotiationSub?.cancel();
    _passengerNegotiationSub = null;
    _passengerRideUpdatesSub?.cancel();
    _passengerRideUpdatesSub = null;
    _driverRideUpdatesSub?.cancel();
    _driverRideUpdatesSub = null;
    _driverNegotiationSub?.cancel();
    _driverNegotiationSub = null;
    _activeNegotiations.clear();
    _driverVisibleRequests.clear();
    _currentNegotiation = null;
    notifyListeners();
  }

  /// Detener solo listeners de pasajero (limpia estado local también).
  void stopPassengerListeners() {
    debugPrint('🛑 Deteniendo listeners de pasajero');
    _passengerNegotiationSub?.cancel();
    _passengerNegotiationSub = null;
    _passengerRideUpdatesSub?.cancel();
    _passengerRideUpdatesSub = null;
    _activeNegotiations.clear();
    _currentNegotiation = null;
  }

  /// Detener solo listeners de conductor (limpia estado local también).
  void stopDriverListeners() {
    debugPrint('🛑 Deteniendo listeners de conductor');
    _driverRideUpdatesSub?.cancel();
    _driverRideUpdatesSub = null;
    _driverNegotiationSub?.cancel();
    _driverNegotiationSub = null;
    _driverVisibleRequests.clear();
  }

  // -------------------- Listener CONDUCTOR --------------------
  /// Inicia la escucha en tiempo real de solicitudes disponibles para conductores.
  /// @param isRoleSwitchInProgress - Si `true`, no iniciar (cambio de rol en curso).
  void startListeningToDriverRequests({bool isRoleSwitchInProgress = false}) {
    if (isRoleSwitchInProgress) {
      debugPrint('⚠️ Cambio de rol en progreso, no iniciar listener de conductor');
      return;
    }

    debugPrint('🔄 Iniciando listener de solicitudes (conductor)');

    _driverRideUpdatesSub?.cancel();
    _driverNegotiationSub?.cancel();

    // Estado inicial.
    loadDriverRequests();

    // SSE: cualquier ride_update podría añadir/quitar rides disponibles.
    _driverRideUpdatesSub = _sse.rideUpdates.listen(
      (event) async {
        debugPrint('📡 SSE ride_update (conductor) → $event');
        await loadDriverRequests();
      },
      onError: (e) => debugPrint('❌ SSE rideUpdates (conductor) error: $e'),
    );

    // SSE: eventos de negociación (ofertas aceptadas/rechazadas por el pasajero).
    _driverNegotiationSub = _sse.negotiations.listen(
      (event) async {
        debugPrint('📡 SSE negotiation (conductor) → $event');
        await loadDriverRequests();
      },
      onError: (e) => debugPrint('❌ SSE negociaciones (conductor) error: $e'),
    );
  }

  /// Detiene solo el listener del conductor.
  void stopListeningToDriverRequests() {
    debugPrint('🛑 Deteniendo listener de conductor');
    _driverRideUpdatesSub?.cancel();
    _driverRideUpdatesSub = null;
    _driverNegotiationSub?.cancel();
    _driverNegotiationSub = null;
  }

  // -------------------- Refresh interno del pasajero --------------------
  Future<void> _refreshMyNegotiations() async {
    final userId = await _getCurrentUserId();
    if (userId == null) return;

    try {
      final response = await _api.listRides(role: 'passenger', pageSize: 50);
      final rides = _extractList(response, keys: ['rides', 'data', 'items']);

      // Estados considerados "abiertos" para el flujo InDrive.
      const openStatuses = <String>{
        'waiting', 'negotiating', 'requested', 'pending', 'accepted',
      };

      final List<PriceNegotiation> next = [];
      for (final raw in rides) {
        if (raw is! Map) continue;
        final ride = raw.cast<String, dynamic>();
        final status = (ride['status'] ?? '').toString();
        final negotiable =
            ride['negotiable'] == true || ride['isNegotiable'] == true;

        // Sólo negociables abiertas.
        if (!negotiable && status != 'accepted') continue;
        if (!openStatuses.contains(status)) continue;

        final rideId = (ride['id'] ?? ride['rideId'] ?? '').toString();
        if (rideId.isEmpty) continue;

        // status=accepted solo si coincide con currentNegotiation (aceptación reciente).
        if (status == 'accepted' && _currentNegotiation?.id != rideId) continue;

        // Traer ofertas del ride.
        final offers = await _fetchOffersForRide(rideId);
        next.add(_negotiationFromRide(ride, offers));
      }

      // Reemplazo idempotente.
      _activeNegotiations
        ..clear()
        ..addAll(next);

      // Mantener currentNegotiation sincronizado.
      if (_currentNegotiation != null) {
        final idx =
            _activeNegotiations.indexWhere((n) => n.id == _currentNegotiation!.id);
        if (idx >= 0) {
          _currentNegotiation = _activeNegotiations[idx];
        }
      } else {
        for (final n in _activeNegotiations) {
          if (n.status == NegotiationStatus.waiting ||
              n.status == NegotiationStatus.negotiating) {
            _currentNegotiation = n;
            debugPrint('📌 Auto-set currentNegotiation: ${n.id}');
            break;
          }
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error refrescando negociaciones (pasajero): $e');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchOffersForRide(String rideId) async {
    try {
      final resp = await _api.listRideOffers(rideId);
      final list = _extractList(resp, keys: ['offers', 'data', 'items']);
      final result = <Map<String, dynamic>>[];
      for (final raw in list) {
        if (raw is! Map) continue;
        result.add(raw.cast<String, dynamic>());
      }

      // Cachear offerId por driverId (necesario para acceptDriverOffer).
      final byDriver = <String, String>{};
      for (final offer in result) {
        final id = (offer['id'] ?? offer['offerId'] ?? '').toString();
        final driverId =
            (offer['driverId'] ?? offer['driver']?['id'] ?? '').toString();
        if (id.isNotEmpty && driverId.isNotEmpty) byDriver[driverId] = id;
      }
      _offerIdsByNegotiation[rideId] = byDriver;
      return result;
    } catch (e) {
      debugPrint('❌ Error listando ofertas del ride $rideId: $e');
      return const [];
    }
  }

  // -------------------- Utilidades sobre rides --------------------
  /// En el nuevo modelo backend la "negociación" y el "ride" son la misma
  /// entidad, así que rideId == negotiationId.
  Future<String?> getRideIdForNegotiation(String negotiationId) async {
    if (negotiationId.isEmpty) return null;
    return negotiationId;
  }

  /// Verifica si el viaje asociado está cancelado/completado y limpia estado local.
  Future<bool> checkAndHandleCancelledRide(String negotiationId) async {
    try {
      final response = await _api.getRide(negotiationId);
      final ride = _extractMap(response, keys: ['ride', 'data']) ?? response;
      final status = (ride['status'] ?? '').toString();

      if (status == 'cancelled' || status == 'canceled' || status == 'completed') {
        debugPrint(
            '🔄 Viaje terminado ($status), removiendo negociación local: $negotiationId');
        _activeNegotiations.removeWhere((n) => n.id == negotiationId);
        if (_currentNegotiation?.id == negotiationId) _currentNegotiation = null;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error verificando viaje cancelado: $e');
      return false;
    }
  }

  /// Limpiar negociaciones cuyo viaje está cancelado — refresca vía backend.
  Future<void> cleanupCancelledNegotiations() async {
    await _refreshMyNegotiations();
  }

  /// Cancelar negociación manualmente por el pasajero.
  Future<bool> cancelNegotiation(String negotiationId) async {
    try {
      debugPrint('🚫 Cancelando negociación: $negotiationId');
      await _api.cancelRide(negotiationId, reason: 'passenger_cancelled');

      _activeNegotiations.removeWhere((n) => n.id == negotiationId);
      if (_currentNegotiation?.id == negotiationId) _currentNegotiation = null;

      notifyListeners();
      debugPrint('✅ Negociación cancelada exitosamente');
      return true;
    } catch (e) {
      debugPrint('❌ Error cancelando negociación: $e');
      return false;
    }
  }

  /// Expirar negociaciones locales que hayan pasado su tiempo límite (5 min).
  /// Notifica al backend cancelándolas.
  Future<void> expireOldNegotiations() async {
    final now = DateTime.now();
    final expired = <String>[];

    _activeNegotiations.removeWhere((n) {
      final isExpired = n.expiresAt.isBefore(now) &&
          (n.status == NegotiationStatus.waiting ||
              n.status == NegotiationStatus.negotiating);
      if (isExpired) expired.add(n.id);
      return isExpired;
    });

    if (_currentNegotiation != null &&
        _currentNegotiation!.expiresAt.isBefore(now)) {
      _currentNegotiation = null;
    }

    // Cancelar en el servidor los que expiraron localmente.
    for (final id in expired) {
      try {
        await _api.cancelRide(id, reason: 'expired');
        debugPrint('⏰ Ride expirado cancelado en server: $id');
      } catch (e) {
        debugPrint('⚠️ No se pudo cancelar en server el ride expirado $id: $e');
      }
    }

    notifyListeners();
  }

  /// Verificar si hay negociaciones activas (no expiradas, no canceladas).
  bool hasActiveNegotiation() {
    final now = DateTime.now();
    return _activeNegotiations.any((n) =>
        n.expiresAt.isAfter(now) &&
        n.status != NegotiationStatus.cancelled &&
        n.status != NegotiationStatus.accepted);
  }

  /// Obtener negociaciones válidas (filtrar expiradas).
  List<PriceNegotiation> getValidNegotiations() {
    final now = DateTime.now();
    return _activeNegotiations
        .where((n) =>
            n.expiresAt.isAfter(now) &&
            n.status != NegotiationStatus.cancelled)
        .toList();
  }

  @override
  void dispose() {
    _passengerNegotiationSub?.cancel();
    _passengerRideUpdatesSub?.cancel();
    _driverRideUpdatesSub?.cancel();
    _driverNegotiationSub?.cancel();
    super.dispose();
  }

  // -------------------- Crear negociación (pasajero) --------------------
  /// Crear una nueva negociación (equivale a crear un ride negociable).
  ///
  /// Ronda 218: acepta `knownUserId`/`knownUserName` opcionales para el caso
  /// (frecuente) donde el caller ya tiene el user cargado desde AuthProvider.
  /// Sin esto, dependíamos EXCLUSIVAMENTE de `_api.me()` que a veces falla
  /// silenciosamente (JWT hipo, refresh en curso, red lenta) → `_getCurrentUserId`
  /// retorna null → throw `Exception('Usuario no autenticado')` → el user
  /// veía "Error al crear solicitud" aunque estuviera perfectamente logueado
  /// (mapa cargado, sesión válida). Con este fallback, ya no rompe.
  Future<void> createNegotiation({
    required LocationPoint pickup,
    required LocationPoint destination,
    required double offeredPrice,
    required PaymentMethod paymentMethod,
    String? notes,
    String? appliedPromotionId,
    String? appliedPromotionCode,
    double? discountAmount,
    double? discountPercentage,
    String? knownUserId,
    String? knownUserName,
    String? knownUserPhone,
    String? knownUserPhoto,
  }) async {
    try {
      String? userId = knownUserId ?? await _getCurrentUserId();
      if (userId == null || userId.isEmpty) {
        throw Exception('Usuario no autenticado');
      }
      // Cachear para las siguientes llamadas.
      _cachedUserId = userId;
      final userData = knownUserId != null
          ? {
              'id': knownUserId,
              if (knownUserName != null) 'displayName': knownUserName,
              if (knownUserPhone != null) 'phone': knownUserPhone,
              if (knownUserPhoto != null) 'photoUrl': knownUserPhoto,
            }
          : await _getCurrentUserData();

      // Cancelar cualquier negociación activa previa del pasajero (una por usuario).
      for (final n in List<PriceNegotiation>.from(_activeNegotiations)) {
        if (n.status == NegotiationStatus.waiting ||
            n.status == NegotiationStatus.negotiating) {
          try {
            await _api.cancelRide(n.id, reason: 'new_negotiation_created');
            debugPrint('🗑️ Cancelada negociación previa: ${n.id}');
          } catch (e) {
            debugPrint('⚠️ Error cancelando negociación previa ${n.id}: $e');
          }
        }
      }
      _activeNegotiations.clear();
      _currentNegotiation = null;

      // Calcular datos derivados.
      final pickupLatLng = _locationPointToLatLng(pickup);
      final destLatLng = _locationPointToLatLng(destination);
      final distance = _calculateHaversineDistance(pickupLatLng, destLatLng);
      final estimatedTime = (distance / 30 * 60).round();
      final suggestedPrice = _calculateSuggestedPrice(distance);

      // Crear el ride negociable en el backend.
      final response = await _api.createRide(
        pickup: {
          'lat': pickup.latitude,
          'lng': pickup.longitude,
          'address': pickup.address,
          if (pickup.reference != null) 'reference': pickup.reference,
        },
        destination: {
          'lat': destination.latitude,
          'lng': destination.longitude,
          'address': destination.address,
          if (destination.reference != null) 'reference': destination.reference,
        },
        vehicleType: 'car',
        paymentMethod: paymentMethod.name,
        proposedFare: offeredPrice,
        negotiable: true,
        notes: notes,
      );

      final ride = _extractMap(response, keys: ['ride', 'data']) ?? response;
      final rideId =
          (ride['id'] ?? ride['rideId'] ?? response['id'])?.toString();
      if (rideId == null || rideId.isEmpty) {
        throw Exception('No se recibió rideId del servidor');
      }

      final negotiation = PriceNegotiation(
        id: rideId,
        passengerId: userId,
        passengerName:
            (userData['displayName'] ?? userData['name'] ?? 'Usuario').toString(),
        passengerPhone: (userData['phone'] ?? '').toString(),
        passengerPhoto:
            (userData['photoUrl'] ?? userData['photoURL'] ?? '').toString(),
        passengerRating: _toDouble(userData['rating']) ?? 5.0,
        pickup: pickup,
        destination: destination,
        suggestedPrice: suggestedPrice,
        offeredPrice: offeredPrice,
        distance: distance,
        estimatedTime: estimatedTime,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        status: NegotiationStatus.waiting,
        driverOffers: const <DriverOffer>[],
        paymentMethod: paymentMethod,
        notes: notes,
        appliedPromotionId: appliedPromotionId,
        appliedPromotionCode: appliedPromotionCode,
        discountAmount: discountAmount,
        discountPercentage: discountPercentage,
      );

      _currentNegotiation = negotiation;
      _activeNegotiations.add(negotiation);
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error creando negociación: $e');
      rethrow;
    }
  }

  // -------------------- Cargar solicitudes (conductor) --------------------
  /// Para conductores: cargar solicitudes disponibles en la zona.
  Future<void> loadDriverRequests() async {
    try {
      final userId = await _getCurrentUserId();
      if (userId == null) return;

      // Intentar obtener ubicación fresca desde el backend.
      await _refreshDriverLocation();

      final loc = _lastDriverLocation;
      final response = loc != null
          ? await _api.listAvailableRides(
              lat: loc.latitude,
              lng: loc.longitude,
              radiusKm: 10,
              limit: 50,
            )
          : await _api.listRides(role: 'driver', pageSize: 50);

      final rides = _extractList(response, keys: ['rides', 'data', 'items']);
      final now = DateTime.now();
      final List<PriceNegotiation> filtered = [];

      for (final raw in rides) {
        if (raw is! Map) continue;
        final ride = raw.cast<String, dynamic>();

        // Solo mostrar negociables en estados abiertos.
        final status = (ride['status'] ?? '').toString();
        final negotiable =
            ride['negotiable'] == true || ride['isNegotiable'] == true;
        if (loc == null) {
          // Sin ubicación filtramos localmente por estado (listAvailableRides
          // ya lo hace en el server).
          if (!negotiable) continue;
          if (status != 'waiting' &&
              status != 'negotiating' &&
              status != 'requested' &&
              status != 'pending') {
            continue;
          }
        }

        // Excluir las propias solicitudes del conductor.
        final passengerId =
            (ride['passengerId'] ?? ride['userId'] ?? '').toString();
        if (passengerId == userId) {
          debugPrint('🚫 Excluyendo solicitud propia: ${ride['id']}');
          continue;
        }

        final negotiation = _negotiationFromRide(ride, const []);

        // Filtro local por expiración.
        if (negotiation.expiresAt.isBefore(now)) continue;

        // Si tenemos ubicación y el server no filtró por radio, filtrar aquí.
        if (loc != null) {
          final distanceKm = _calculateHaversineDistance(
            loc,
            _locationPointToLatLng(negotiation.pickup),
          );
          if (distanceKm > 10.0) continue;
        }

        filtered.add(negotiation);
      }

      _driverVisibleRequests = filtered;
      debugPrint('✅ Conductor ve ${_driverVisibleRequests.length} solicitudes');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error cargando solicitudes de conductores: $e');
    }
  }

  Future<void> _refreshDriverLocation() async {
    try {
      final status = await _api.driverStatus();
      final loc = _extractMap(status, keys: ['location', 'position']);
      if (loc != null) {
        final lat = _toDouble(loc['lat']) ?? _toDouble(loc['latitude']);
        final lng = _toDouble(loc['lng']) ?? _toDouble(loc['longitude']);
        if (lat != null && lng != null) {
          _lastDriverLocation = LatLng(lat, lng);
        }
      }
    } catch (e) {
      debugPrint('⚠️ No se pudo obtener ubicación del conductor: $e');
    }
  }

  // -------------------- Wallet check (conductor) --------------------
  static const double minDriverBalance = 0.0; // Solo comisión 12% al completar viaje.
  double get minimumDriverBalance => minDriverBalance;

  /// Verifica si el conductor tiene saldo suficiente para operar.
  Future<bool> checkDriverBalance(String driverId) async {
    try {
      final balance = await _api.walletBalance();
      final credits = _toDouble(balance['serviceCredits']) ??
          _toDouble(balance['balance']) ??
          _toDouble(balance['available']) ??
          0.0;
      debugPrint(
          '💰 Créditos conductor $driverId: S/ $credits (mínimo: S/ $minDriverBalance)');
      return credits >= minDriverBalance;
    } catch (e) {
      debugPrint('❌ Error verificando saldo: $e');
      return false;
    }
  }

  // -------------------- Oferta del conductor --------------------
  /// Para conductores: Hacer una oferta con datos reales.
  /// Retorna `null` si éxito, o un mensaje de error si falla.
  /// Ronda 241: `knownUserId` opcional para evitar el mismo bug que
  /// createNegotiation tenía (Ronda 218). Si el caller (driver home)
  /// ya tiene el user cargado en AuthProvider, lo pasa acá y evitamos
  /// depender de `_api.me()` que puede fallar temporalmente por JWT
  /// hipo, refresh en curso, red lenta, o session revocada tras
  /// login en otro device.
  Future<String?> makeDriverOffer(
      String negotiationId, double acceptedPrice,
      {String? knownUserId}) async {
    try {
      String? userId = knownUserId ?? await _getCurrentUserId();
      if (userId == null || userId.isEmpty) return 'Usuario no autenticado';
      _cachedUserId = userId;

      // Verificar saldo mínimo antes de hacer oferta.
      final hasBalance = await checkDriverBalance(userId);
      if (!hasBalance) {
        debugPrint('❌ Conductor sin saldo suficiente para hacer ofertas');
        return 'Saldo insuficiente. Necesitas mínimo S/ ${minDriverBalance.toStringAsFixed(2)} para hacer ofertas. Recarga tu billetera.';
      }

      // Datos del conductor.
      final userData = await _getCurrentUserData();
      Map<String, dynamic> driverProfile = const {};
      try {
        driverProfile = await _api.myDriverProfile();
      } catch (e) {
        debugPrint('⚠️ No se pudo obtener perfil de conductor: $e');
      }
      final vehicleData =
          _extractMap(driverProfile, keys: ['vehicle']) ?? const <String, dynamic>{};

      // Calcular ETA si tenemos ubicación del conductor y del ride.
      int estimatedArrival = 5;
      final rideIndex =
          _driverVisibleRequests.indexWhere((r) => r.id == negotiationId);
      if (_lastDriverLocation != null && rideIndex != -1) {
        final distKm = _calculateHaversineDistance(
          _lastDriverLocation!,
          _locationPointToLatLng(_driverVisibleRequests[rideIndex].pickup),
        );
        estimatedArrival = (distKm / 30 * 60).round().clamp(1, 60);
      }

      // Enviar oferta al backend.
      await _api.submitRideOffer(
        negotiationId,
        amount: acceptedPrice,
        etaSeconds: estimatedArrival * 60,
      );

      // Reflejar la oferta localmente para respuesta inmediata en la UI.
      final offer = DriverOffer(
        driverId: userId,
        driverName: (userData['displayName'] ?? userData['name'] ?? 'Conductor')
            .toString(),
        driverPhone: (userData['phone'] ?? '').toString(),
        driverPhoto:
            (userData['photoUrl'] ?? userData['photoURL'] ?? '').toString(),
        driverRating: _toDouble(userData['rating']) ?? 5.0,
        vehicleModel: _formatVehicleModel(vehicleData),
        vehiclePlate: (vehicleData['plate'] ?? '').toString(),
        vehicleColor: (vehicleData['color'] ?? '').toString(),
        acceptedPrice: acceptedPrice,
        estimatedArrival: estimatedArrival,
        offeredAt: DateTime.now(),
        status: OfferStatus.pending,
        completedTrips:
            (driverProfile['completedTrips'] as num?)?.toInt() ?? 0,
        acceptanceRate: _toDouble(driverProfile['acceptanceRate']) ?? 100.0,
      );

      final negIdx =
          _activeNegotiations.indexWhere((n) => n.id == negotiationId);
      if (negIdx != -1) {
        final updated = List<DriverOffer>.from(
            _activeNegotiations[negIdx].driverOffers)
          ..removeWhere((o) => o.driverId == userId)
          ..add(offer);
        _activeNegotiations[negIdx] = _activeNegotiations[negIdx].copyWith(
          driverOffers: updated,
          status: NegotiationStatus.negotiating,
        );
        if (_currentNegotiation?.id == negotiationId) {
          _currentNegotiation = _activeNegotiations[negIdx];
        }
      }

      notifyListeners();
      return null; // Éxito.
    } catch (e) {
      debugPrint('❌ Error haciendo oferta: $e');
      return userFriendlyError(e, fallback: 'Error al enviar oferta');
    }
  }

  // -------------------- Aceptar oferta (pasajero) --------------------
  /// Para pasajeros: aceptar la oferta de un conductor.
  /// Retorna el `rideId` (que coincide con `negotiationId`) si éxito.
  Future<String?> acceptDriverOffer(
      String negotiationId, String driverId) async {
    final negotiationIndex =
        _activeNegotiations.indexWhere((n) => n.id == negotiationId);
    if (negotiationIndex == -1) {
      debugPrint('⚠️ Negociación $negotiationId no encontrada en lista activa');
      return null;
    }
    final negotiation = _activeNegotiations[negotiationIndex];

    final offerIndex =
        negotiation.driverOffers.indexWhere((o) => o.driverId == driverId);
    if (offerIndex == -1) {
      debugPrint('⚠️ Oferta del conductor $driverId no encontrada');
      return null;
    }
    final acceptedOffer = negotiation.driverOffers[offerIndex];

    try {
      // Resolver offerId a partir de driverId (cache o refetch).
      String? offerId = _offerIdsByNegotiation[negotiationId]?[driverId];
      if (offerId == null) {
        await _fetchOffersForRide(negotiationId);
        offerId = _offerIdsByNegotiation[negotiationId]?[driverId];
      }
      if (offerId == null) {
        debugPrint(
            '❌ No se pudo resolver offerId para driverId=$driverId en $negotiationId');
        return null;
      }

      // Aceptar la oferta en el backend (crea el "match" ride↔driver).
      await _api.acceptOffer(offerId);

      // Actualizar estado local — aceptar esta oferta y marcar el resto como rechazadas.
      final updatedOffers = List<DriverOffer>.from(negotiation.driverOffers);
      for (int i = 0; i < updatedOffers.length; i++) {
        updatedOffers[i] = updatedOffers[i].copyWith(
          status:
              i == offerIndex ? OfferStatus.accepted : OfferStatus.rejected,
        );
      }

      _activeNegotiations[negotiationIndex] = negotiation.copyWith(
        driverOffers: updatedOffers,
        status: NegotiationStatus.accepted,
        acceptedDriverId: driverId,
      );

      if (_currentNegotiation?.id == negotiationId) {
        _currentNegotiation = _activeNegotiations[negotiationIndex];
      }

      notifyListeners();

      debugPrint(
          '✅ Oferta aceptada — rideId: $negotiationId, offer: $offerId, precio: ${acceptedOffer.acceptedPrice}');
      // rideId == negotiationId en el nuevo modelo backend.
      return negotiationId;
    } catch (e) {
      debugPrint('❌ Error aceptando oferta: $e');
      return null;
    }
  }

  // -------------------- Rechazar oferta (pasajero) --------------------
  /// Rechaza una oferta específica actualizando su status en el estado local.
  ///
  /// El backend no expone un endpoint por-oferta; la UX es que el pasajero
  /// simplemente esconde la oferta rechazada. La negociación sigue viva y
  /// otros conductores pueden seguir ofertando.
  Future<void> rejectDriverOffer(
      String negotiationId, String driverId) async {
    try {
      final negIndex =
          _activeNegotiations.indexWhere((n) => n.id == negotiationId);
      if (negIndex != -1) {
        final negotiation = _activeNegotiations[negIndex];
        final updated = negotiation.driverOffers.map((o) {
          return o.driverId == driverId
              ? o.copyWith(status: OfferStatus.rejected)
              : o;
        }).toList();

        // Si no quedan ofertas pendientes, volver a estado 'waiting' para que
        // otros conductores puedan seguir ofertando.
        final hasPending = updated.any((o) => o.status == OfferStatus.pending);
        _activeNegotiations[negIndex] = negotiation.copyWith(
          driverOffers: updated,
          status:
              hasPending ? negotiation.status : NegotiationStatus.waiting,
        );

        if (_currentNegotiation?.id == negotiationId) {
          _currentNegotiation = _activeNegotiations[negIndex];
        }
      }

      notifyListeners();
      debugPrint(
          '✅ Oferta rechazada localmente — driverId: $driverId en $negotiationId');
    } catch (e) {
      debugPrint('❌ Error rechazando oferta: $e');
      rethrow;
    }
  }

  // -------------------- Cleanup histórico --------------------
  /// Limpia negociaciones expiradas o stale. Con el backend, la expiración
  /// se gestiona server-side; solo reseteamos estado local aquí.
  Future<void> cleanupExpiredNegotiations() async {
    _activeNegotiations.clear();
    _currentNegotiation = null;
    notifyListeners();
  }

  // -------------------- Helpers privados --------------------
  /// Calcula precio sugerido basado en distancia real y tarifas de Perú.
  double _calculateSuggestedPrice(double distanceKm) {
    const double tarifaBase = 4.0; // S/ 4.00 tarifa base.
    const double tarifaPorKm = 2.5; // S/ 2.50 por kilómetro.
    const double tarifaMinima = 8.0; // S/ 8.00 mínimo.
    final precio = tarifaBase + (distanceKm * tarifaPorKm);
    return math.max(precio, tarifaMinima).roundToDouble();
  }

  String _formatVehicleModel(Map<String, dynamic> vehicleData) {
    final marca = (vehicleData['brand'] ?? vehicleData['make'] ?? '').toString();
    final modelo = (vehicleData['model'] ?? '').toString();
    final anio = (vehicleData['year'] ?? '').toString();
    if (marca.isNotEmpty && modelo.isNotEmpty) {
      return '$marca $modelo${anio.isNotEmpty ? ' $anio' : ''}'.trim();
    }
    return modelo;
  }

  LatLng _locationPointToLatLng(LocationPoint point) =>
      LatLng(point.latitude, point.longitude);

  double _calculateHaversineDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371;
    final lat1Rad = point1.latitude * (math.pi / 180);
    final lat2Rad = point2.latitude * (math.pi / 180);
    final deltaLat = (point2.latitude - point1.latitude) * (math.pi / 180);
    final deltaLng = (point2.longitude - point1.longitude) * (math.pi / 180);
    final a = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(deltaLng / 2) *
            math.sin(deltaLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.now();
  }

  Map<String, dynamic>? _extractMap(dynamic src, {required List<String> keys}) {
    if (src is! Map) return null;
    for (final k in keys) {
      final v = src[k];
      if (v is Map) return v.cast<String, dynamic>();
    }
    return null;
  }

  List<dynamic> _extractList(dynamic src, {required List<String> keys}) {
    if (src is! Map) return const [];
    for (final k in keys) {
      final v = src[k];
      if (v is List) return v;
    }
    return const [];
  }

  /// Construye un [PriceNegotiation] desde el shape que devuelve el backend Node
  /// para un ride. Es defensivo con nombres de campo alternativos.
  PriceNegotiation _negotiationFromRide(
    Map<String, dynamic> ride,
    List<Map<String, dynamic>> offers,
  ) {
    final rideId = (ride['id'] ?? ride['rideId'] ?? '').toString();
    final pickupMap =
        _extractMap(ride, keys: ['pickup', 'pickupLocation']) ?? const {};
    final destMap =
        _extractMap(ride, keys: ['destination', 'destinationLocation']) ?? const {};

    final pickupPoint = LocationPoint(
      latitude: _toDouble(pickupMap['latitude']) ??
          _toDouble(pickupMap['lat']) ??
          0.0,
      longitude: _toDouble(pickupMap['longitude']) ??
          _toDouble(pickupMap['lng']) ??
          0.0,
      address:
          (pickupMap['address'] ?? ride['pickupAddress'] ?? '').toString(),
      reference: pickupMap['reference']?.toString(),
    );
    final destPoint = LocationPoint(
      latitude: _toDouble(destMap['latitude']) ??
          _toDouble(destMap['lat']) ??
          0.0,
      longitude: _toDouble(destMap['longitude']) ??
          _toDouble(destMap['lng']) ??
          0.0,
      address:
          (destMap['address'] ?? ride['destinationAddress'] ?? '').toString(),
      reference: destMap['reference']?.toString(),
    );

    // Ofertas.
    final driverOffers = <DriverOffer>[];
    for (final raw in offers) {
      final rawDriver =
          _extractMap(raw, keys: ['driver']) ?? const <String, dynamic>{};
      final rawVehicle =
          _extractMap(raw, keys: ['vehicle']) ?? const <String, dynamic>{};

      driverOffers.add(DriverOffer(
        driverId:
            (raw['driverId'] ?? rawDriver['id'] ?? '').toString(),
        driverName: (raw['driverName'] ??
                rawDriver['displayName'] ??
                rawDriver['name'] ??
                'Conductor')
            .toString(),
        driverPhone:
            (raw['driverPhone'] ?? rawDriver['phone'] ?? '').toString(),
        driverPhoto:
            (raw['driverPhoto'] ?? rawDriver['photoUrl'] ?? '').toString(),
        driverRating: _toDouble(raw['driverRating']) ??
            _toDouble(rawDriver['rating']) ??
            5.0,
        vehicleModel:
            (raw['vehicleModel'] ?? rawVehicle['model'] ?? '').toString(),
        vehiclePlate:
            (raw['vehiclePlate'] ?? rawVehicle['plate'] ?? '').toString(),
        vehicleColor:
            (raw['vehicleColor'] ?? rawVehicle['color'] ?? '').toString(),
        acceptedPrice: _toDouble(raw['amount']) ??
            _toDouble(raw['acceptedPrice']) ??
            0.0,
        estimatedArrival: (raw['estimatedArrival'] as num?)?.toInt() ??
            ((raw['etaSeconds'] as num?) != null
                ? ((raw['etaSeconds'] as num).toInt() / 60).round()
                : 5),
        offeredAt: _parseDateTime(raw['offeredAt'] ?? raw['createdAt']),
        status: OfferStatus.values.firstWhere(
          (s) => s.name == (raw['status'] ?? 'pending'),
          orElse: () => OfferStatus.pending,
        ),
        completedTrips: (raw['completedTrips'] as num?)?.toInt() ?? 0,
        acceptanceRate: _toDouble(raw['acceptanceRate']) ?? 100.0,
      ));
    }

    // Timestamps: si no viene expiresAt, asumir 5 min desde createdAt.
    final createdAt = _parseDateTime(ride['createdAt'] ?? ride['requestedAt']);
    var expiresAt = _parseDateTime(ride['expiresAt']);
    if (expiresAt.difference(createdAt).inSeconds <= 0) {
      expiresAt = createdAt.add(const Duration(minutes: 5));
    }

    // Mapear ride.status → NegotiationStatus (soporta múltiples vocabularios).
    final rideStatus = (ride['status'] ?? 'waiting').toString();
    NegotiationStatus status;
    switch (rideStatus) {
      case 'requested':
      case 'pending':
      case 'waiting':
        status = driverOffers.isEmpty
            ? NegotiationStatus.waiting
            : NegotiationStatus.negotiating;
        break;
      case 'negotiating':
        status = NegotiationStatus.negotiating;
        break;
      case 'accepted':
        status = NegotiationStatus.accepted;
        break;
      case 'in_progress':
      case 'inProgress':
      case 'ongoing':
        status = NegotiationStatus.inProgress;
        break;
      case 'completed':
        status = NegotiationStatus.completed;
        break;
      case 'cancelled':
      case 'canceled':
        status = NegotiationStatus.cancelled;
        break;
      case 'expired':
        status = NegotiationStatus.expired;
        break;
      default:
        status = NegotiationStatus.waiting;
    }

    final passengerInfo =
        _extractMap(ride, keys: ['passengerInfo']) ?? const <String, dynamic>{};

    return PriceNegotiation(
      id: rideId,
      passengerId: (ride['passengerId'] ?? ride['userId'] ?? '').toString(),
      passengerName:
          (ride['passengerName'] ?? passengerInfo['passengerName'] ?? '')
              .toString(),
      passengerPhone:
          (ride['passengerPhone'] ?? passengerInfo['passengerPhone'] ?? '')
              .toString(),
      passengerPhoto:
          (ride['passengerPhoto'] ?? passengerInfo['passengerPhoto'] ?? '')
              .toString(),
      passengerRating: _toDouble(ride['passengerRating']) ??
          _toDouble(passengerInfo['passengerRating']) ??
          5.0,
      pickup: pickupPoint,
      destination: destPoint,
      suggestedPrice: _toDouble(ride['suggestedPrice']) ?? 0.0,
      offeredPrice: _toDouble(ride['proposedFare']) ??
          _toDouble(ride['offeredPrice']) ??
          _toDouble(ride['estimatedFare']) ??
          0.0,
      distance: _toDouble(ride['distance']) ??
          _toDouble(ride['estimatedDistance']) ??
          0.0,
      estimatedTime: (ride['estimatedTime'] as num?)?.toInt() ?? 0,
      createdAt: createdAt,
      expiresAt: expiresAt,
      status: status,
      driverOffers: driverOffers,
      selectedDriverId:
          (ride['acceptedDriverId'] ?? ride['driverId'])?.toString(),
      paymentMethod: PaymentMethod.values.firstWhere(
        (m) => m.name == (ride['paymentMethod'] ?? 'cash'),
        orElse: () => PaymentMethod.cash,
      ),
      notes: ride['notes']?.toString(),
      appliedPromotionId: ride['appliedPromotionId']?.toString(),
      appliedPromotionCode: ride['appliedPromotionCode']?.toString(),
      discountAmount: _toDouble(ride['discountAmount']),
      discountPercentage: _toDouble(ride['discountPercentage']),
    );
  }
}
