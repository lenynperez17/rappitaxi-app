import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as math;
import '../models/price_negotiation_model.dart';

/// Provider para manejar las negociaciones de precios con implementación real
class PriceNegotiationProvider extends ChangeNotifier {
  final List<PriceNegotiation> _activeNegotiations = [];
  List<PriceNegotiation> _driverVisibleRequests = [];
  PriceNegotiation? _currentNegotiation;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ✅ NUEVO: StreamSubscription para escuchar cambios en tiempo real
  StreamSubscription<QuerySnapshot>? _negotiationsSubscription;

  List<PriceNegotiation> get activeNegotiations => _activeNegotiations;
  List<PriceNegotiation> get driverVisibleRequests => _driverVisibleRequests;
  PriceNegotiation? get currentNegotiation => _currentNegotiation;

  // ✅ NUEVO: Iniciar escucha en tiempo real para pasajeros
  // @param isRoleSwitchInProgress - Si true, no iniciar listener (cambio de rol en progreso)
  void startListeningToMyNegotiations({bool isRoleSwitchInProgress = false}) {
    // ✅ VALIDACIÓN: No iniciar si hay cambio de rol en progreso
    if (isRoleSwitchInProgress) {
      debugPrint('⚠️ Cambio de rol en progreso, no iniciar listener de pasajero');
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('❌ Usuario no autenticado para escuchar negociaciones');
      return;
    }

    debugPrint('🔄 Iniciando listener de negociaciones para pasajero: ${user.uid}');

    // Cancelar cualquier suscripción anterior
    _negotiationsSubscription?.cancel();

    // Escuchar en tiempo real las negociaciones del pasajero
    // ✅ FIX: Filtrar en cliente para evitar necesidad de índice compuesto
    _negotiationsSubscription = _firestore
        .collection('negotiations')
        .where('passengerId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) async {
      // ✅ FIX: Incluir 'accepted' para que el pasajero detecte cuando un conductor acepta su viaje
      // Sin esto, la negociación desaparece de la lista al ser aceptada y el pasajero nunca navega
      final activeDocs = snapshot.docs.where((doc) {
        final status = doc.data()['status'] as String? ?? '';
        return status == 'waiting' || status == 'negotiating' || status == 'accepted';
      }).toList();

      debugPrint('📥 Recibidas ${snapshot.docs.length} negociaciones totales, ${activeDocs.length} activas del pasajero');

      // ✅ Obtener IDs de negociaciones activas actuales
      final activeNegotiationIds = activeDocs.map((doc) => doc.data()['id'] ?? doc.id).toSet();

      // ✅ Remover negociaciones que ya no están activas (aceptadas, completadas, etc.)
      _activeNegotiations.removeWhere((negotiation) {
        final shouldRemove = !activeNegotiationIds.contains(negotiation.id);
        if (shouldRemove) {
          debugPrint('🗑️ Removiendo negociación no activa: ${negotiation.id} (status: ${negotiation.status.name})');
        }
        return shouldRemove;
      });

      // ✅ Iterar solo sobre documentos activos
      for (final doc in activeDocs) {
        final data = doc.data();
        final negotiationId = data['id'] ?? doc.id;

        // ✅ CORREGIDO: Leer ofertas directamente del campo driverOffers del documento
        final List<dynamic> offersData = data['driverOffers'] ?? [];
        final driverOffers = offersData.map((offerData) {
          return DriverOffer(
            driverId: offerData['driverId'] ?? '',
            driverName: offerData['driverName'] ?? 'Conductor',
            driverPhoto: offerData['driverPhoto'] ?? '',
            driverRating: (offerData['driverRating'] as num?)?.toDouble() ?? 5.0,
            vehicleModel: offerData['vehicleModel'] ?? '',
            vehiclePlate: offerData['vehiclePlate'] ?? '',
            vehicleColor: offerData['vehicleColor'] ?? '',
            acceptedPrice: (offerData['acceptedPrice'] as num?)?.toDouble() ?? 0.0,
            estimatedArrival: offerData['estimatedArrival'] ?? 5,
            offeredAt: _parseDateTime(offerData['offeredAt']),
            status: OfferStatus.values.firstWhere(
              (s) => s.name == (offerData['status'] ?? 'pending'),
              orElse: () => OfferStatus.pending,
            ),
            completedTrips: offerData['completedTrips'] ?? 0,
            acceptanceRate: (offerData['acceptanceRate'] as num?)?.toDouble() ?? 0.0,
          );
        }).toList();

        final negotiation = PriceNegotiation(
          id: negotiationId,
          passengerId: data['passengerId'] ?? '',
          passengerName: data['passengerName'] ?? '',
          passengerPhoto: data['passengerPhoto'] ?? '',
          passengerRating: (data['passengerRating'] as num?)?.toDouble() ?? 5.0,
          pickup: LocationPoint(
            latitude: (data['pickup']?['latitude'] as num?)?.toDouble() ?? 0.0,
            longitude: (data['pickup']?['longitude'] as num?)?.toDouble() ?? 0.0,
            address: data['pickup']?['address'] ?? '',
            reference: data['pickup']?['reference'],
          ),
          destination: LocationPoint(
            latitude: (data['destination']?['latitude'] as num?)?.toDouble() ?? 0.0,
            longitude: (data['destination']?['longitude'] as num?)?.toDouble() ?? 0.0,
            address: data['destination']?['address'] ?? '',
            reference: data['destination']?['reference'],
          ),
          suggestedPrice: (data['suggestedPrice'] as num?)?.toDouble() ?? 0.0,
          offeredPrice: (data['offeredPrice'] as num?)?.toDouble() ?? 0.0,
          distance: (data['distance'] as num?)?.toDouble() ?? 0.0,
          estimatedTime: data['estimatedTime'] ?? 0,
          createdAt: _parseDateTime(data['createdAt']),
          expiresAt: _parseDateTime(data['expiresAt']),
          status: NegotiationStatus.values.firstWhere(
            (s) => s.name == (data['status'] ?? 'waiting'),
            orElse: () => NegotiationStatus.waiting,
          ),
          driverOffers: driverOffers,
          selectedDriverId: data['acceptedDriverId'],
          paymentMethod: PaymentMethod.values.firstWhere(
            (m) => m.name == (data['paymentMethod'] ?? 'cash'),
            orElse: () => PaymentMethod.cash,
          ),
          notes: data['notes'],
        );

        // Actualizar o agregar la negociación
        final existingIndex = _activeNegotiations.indexWhere((n) => n.id == negotiationId);
        if (existingIndex >= 0) {
          _activeNegotiations[existingIndex] = negotiation;
          debugPrint('📝 Actualizada negociación: $negotiationId con ${driverOffers.length} ofertas, status: ${negotiation.status.name}');
        } else {
          _activeNegotiations.add(negotiation);
          debugPrint('➕ Agregada nueva negociación: $negotiationId');
        }

        // Actualizar currentNegotiation si corresponde
        if (_currentNegotiation?.id == negotiationId) {
          _currentNegotiation = negotiation;
        }
      }

      notifyListeners();
    }, onError: (e) {
      debugPrint('❌ Error en listener de negociaciones: $e');
    });
  }

  // ✅ NUEVO: Detener escucha
  void stopListeningToNegotiations() {
    debugPrint('🛑 Deteniendo listener de negociaciones');
    _negotiationsSubscription?.cancel();
    _negotiationsSubscription = null;
  }

  // ✅ CLEANUP CENTRALIZADO: Detener TODOS los listeners al cambiar de rol
  void stopAllListeners() {
    debugPrint('🛑 Deteniendo TODOS los listeners de negociaciones');
    _negotiationsSubscription?.cancel();
    _negotiationsSubscription = null;
    _driverNegotiationsSubscription?.cancel();
    _driverNegotiationsSubscription = null;
    _activeNegotiations.clear();
    _driverVisibleRequests.clear();
    _currentNegotiation = null;
    notifyListeners();
  }

  // ✅ CLEANUP: Detener solo listeners de pasajero
  void stopPassengerListeners() {
    debugPrint('🛑 Deteniendo listeners de pasajero');
    _negotiationsSubscription?.cancel();
    _negotiationsSubscription = null;
    _activeNegotiations.clear();
    _currentNegotiation = null;
  }

  // ✅ CLEANUP: Detener solo listeners de conductor
  void stopDriverListeners() {
    debugPrint('🛑 Deteniendo listeners de conductor');
    _driverNegotiationsSubscription?.cancel();
    _driverNegotiationsSubscription = null;
    _driverVisibleRequests.clear();
  }

  // ✅ NUEVO: Listener en tiempo real para conductores
  StreamSubscription<QuerySnapshot>? _driverNegotiationsSubscription;

  // Iniciar escucha en tiempo real de solicitudes disponibles para conductores
  // @param isRoleSwitchInProgress - Si true, no iniciar listener (cambio de rol en progreso)
  void startListeningToDriverRequests({bool isRoleSwitchInProgress = false}) {
    // ✅ VALIDACIÓN: No iniciar si hay cambio de rol en progreso
    if (isRoleSwitchInProgress) {
      debugPrint('⚠️ Cambio de rol en progreso, no iniciar listener de conductor');
      return;
    }

    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('❌ Conductor no autenticado');
      return;
    }

    debugPrint('🔄 Iniciando listener de solicitudes para conductor: ${user.uid}');

    // Cancelar suscripción anterior
    _driverNegotiationsSubscription?.cancel();

    // Escuchar negociaciones en estado 'waiting' o 'negotiating'
    _driverNegotiationsSubscription = _firestore
        .collection('negotiations')
        .where('status', whereIn: ['waiting', 'negotiating'])
        .snapshots()
        .listen((snapshot) async {
      debugPrint('📥 Conductor recibió ${snapshot.docs.length} solicitudes');

      // Obtener ubicación del conductor
      final driverDoc = await _firestore.collection('drivers').doc(user.uid).get();
      final driverData = driverDoc.data();

      if (driverData == null || driverData['location'] == null) {
        debugPrint('⚠️ Conductor sin ubicación');
        return;
      }

      final driverLat = (driverData['location']['lat'] as num?)?.toDouble() ?? 0.0;
      final driverLng = (driverData['location']['lng'] as num?)?.toDouble() ?? 0.0;
      final driverLocation = LatLng(driverLat, driverLng);

      final List<PriceNegotiation> filteredRequests = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();

        // ✅ FIX: Excluir las propias solicitudes del conductor (no puede aceptar su propio viaje)
        final passengerId = data['passengerId'] as String? ?? '';
        if (passengerId == user.uid) {
          debugPrint('🚫 Excluyendo solicitud propia del conductor: ${doc.id}');
          continue;
        }

        // Filtrar expirados
        final expiresAt = _parseDateTime(data['expiresAt']);
        if (expiresAt.isBefore(DateTime.now())) continue;

        // Parsear ubicación de recogida
        final pickupLat = (data['pickup']?['latitude'] as num?)?.toDouble() ?? 0.0;
        final pickupLng = (data['pickup']?['longitude'] as num?)?.toDouble() ?? 0.0;
        final pickupLocation = LatLng(pickupLat, pickupLng);

        // Filtrar por distancia (10km máximo)
        final distance = _calculateHaversineDistance(driverLocation, pickupLocation);
        if (distance > 10.0) continue;

        final negotiation = PriceNegotiation(
          id: data['id'] ?? doc.id,
          passengerId: data['passengerId'] ?? '',
          passengerName: data['passengerName'] ?? '',
          passengerPhoto: data['passengerPhoto'] ?? '',
          passengerRating: (data['passengerRating'] as num?)?.toDouble() ?? 5.0,
          pickup: LocationPoint(
            latitude: pickupLat,
            longitude: pickupLng,
            address: data['pickup']?['address'] ?? '',
            reference: data['pickup']?['reference'],
          ),
          destination: LocationPoint(
            latitude: (data['destination']?['latitude'] as num?)?.toDouble() ?? 0.0,
            longitude: (data['destination']?['longitude'] as num?)?.toDouble() ?? 0.0,
            address: data['destination']?['address'] ?? '',
            reference: data['destination']?['reference'],
          ),
          suggestedPrice: (data['suggestedPrice'] as num?)?.toDouble() ?? 0.0,
          offeredPrice: (data['offeredPrice'] as num?)?.toDouble() ?? 0.0,
          distance: (data['distance'] as num?)?.toDouble() ?? 0.0,
          estimatedTime: data['estimatedTime'] ?? 0,
          createdAt: _parseDateTime(data['createdAt']),
          expiresAt: expiresAt,
          status: NegotiationStatus.values.firstWhere(
            (s) => s.name == (data['status'] ?? 'waiting'),
            orElse: () => NegotiationStatus.waiting,
          ),
          driverOffers: [],
          paymentMethod: PaymentMethod.values.firstWhere(
            (m) => m.name == (data['paymentMethod'] ?? 'cash'),
            orElse: () => PaymentMethod.cash,
          ),
          notes: data['notes'],
        );

        filteredRequests.add(negotiation);
      }

      _driverVisibleRequests = filteredRequests;
      debugPrint('✅ Conductor ve ${_driverVisibleRequests.length} solicitudes cercanas');
      notifyListeners();
    }, onError: (e) {
      debugPrint('❌ Error en listener de conductor: $e');
    });
  }

  // Detener escucha de conductor
  void stopListeningToDriverRequests() {
    debugPrint('🛑 Deteniendo listener de conductor');
    _driverNegotiationsSubscription?.cancel();
    _driverNegotiationsSubscription = null;
  }

  // ✅ NUEVO: Obtener el rideId de una negociación aceptada
  Future<String?> getRideIdForNegotiation(String negotiationId) async {
    try {
      final doc = await _firestore.collection('negotiations').doc(negotiationId).get()
          .timeout(const Duration(seconds: 10), onTimeout: () {
            throw TimeoutException('Timeout obteniendo rideId para negociación');
          });
      if (doc.exists) {
        final rideId = doc.data()?['rideId'] as String?;
        if (rideId != null && rideId.isNotEmpty) return rideId;

        // Fallback: search rides collection by negotiationId
        debugPrint('⚠️ rideId no encontrado en negociación, buscando en rides...');
        final ridesQuery = await _firestore.collection('rides')
            .where('negotiationId', isEqualTo: negotiationId)
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 10));
        if (ridesQuery.docs.isNotEmpty) {
          return ridesQuery.docs.first.id;
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error obteniendo rideId: $e');
      return null;
    }
  }

  /// ✅ NUEVO: Verificar si el viaje asociado está cancelado y actualizar la negociación
  Future<bool> checkAndHandleCancelledRide(String negotiationId) async {
    try {
      final rideId = await getRideIdForNegotiation(negotiationId);
      if (rideId == null) {
        debugPrint('⚠️ No hay rideId para negociación: $negotiationId');
        return false;
      }

      // Verificar el estado del viaje (con timeout)
      final rideDoc = await _firestore.collection('rides').doc(rideId).get()
          .timeout(const Duration(seconds: 15), onTimeout: () {
            throw TimeoutException('Timeout verificando estado del viaje');
          });
      if (!rideDoc.exists) {
        debugPrint('⚠️ Viaje no encontrado: $rideId');
        return false;
      }

      final rideData = rideDoc.data();
      final rideStatus = rideData?['status'] as String?;

      // Si el viaje terminó (cancelado o completado), actualizar la negociación
      if (rideStatus == 'cancelled' || rideStatus == 'completed') {
        debugPrint('🔄 Viaje terminado ($rideStatus), actualizando negociación: $negotiationId');

        // Actualizar estado en Firestore (con timeout)
        await _firestore.collection('negotiations').doc(negotiationId).update({
          'status': rideStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        }).timeout(const Duration(seconds: 15), onTimeout: () {
          throw TimeoutException('Timeout actualizando negociación terminada');
        });

        // Actualizar estado local
        final index = _activeNegotiations.indexWhere((n) => n.id == negotiationId);
        if (index >= 0) {
          _activeNegotiations.removeAt(index);
          notifyListeners();
        }

        return true; // El viaje ya terminó
      }

      return false; // El viaje sigue activo
    } catch (e) {
      debugPrint('❌ Error verificando viaje cancelado: $e');
      return false;
    }
  }

  /// ✅ NUEVO: Limpiar negociaciones cuyo viaje está cancelado
  Future<void> cleanupCancelledNegotiations() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Buscar negociaciones aceptadas del usuario
      final snapshot = await _firestore
          .collection('negotiations')
          .where('passengerId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'accepted')
          .get();

      for (final doc in snapshot.docs) {
        final negotiationId = doc.data()['id'] ?? doc.id;
        await checkAndHandleCancelledRide(negotiationId);
      }
    } catch (e) {
      debugPrint('❌ Error limpiando negociaciones canceladas: $e');
    }
  }

  /// ✅ NUEVO: Cancelar negociación manualmente por el pasajero
  Future<bool> cancelNegotiation(String negotiationId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      debugPrint('🚫 Cancelando negociación: $negotiationId');

      // Actualizar en Firestore (con timeout)
      await _firestore.collection('negotiations').doc(negotiationId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': user.uid,
        'cancellationReason': 'passenger_cancelled',
      }).timeout(const Duration(seconds: 15), onTimeout: () {
        throw TimeoutException('Timeout cancelando negociación');
      });

      // Remover de la lista local
      _activeNegotiations.removeWhere((n) => n.id == negotiationId);

      // Limpiar currentNegotiation si es la que se canceló
      if (_currentNegotiation?.id == negotiationId) {
        _currentNegotiation = null;
      }

      notifyListeners();
      debugPrint('✅ Negociación cancelada exitosamente');
      return true;
    } catch (e) {
      debugPrint('❌ Error cancelando negociación: $e');
      return false;
    }
  }

  /// ✅ NUEVO: Expirar negociaciones que han pasado su tiempo límite (5 minutos)
  /// Elimina el documento de Firebase para evitar negociaciones "fantasma"
  Future<void> expireOldNegotiations() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final now = DateTime.now();

      // Buscar negociaciones activas del usuario que hayan expirado (con timeout)
      final snapshot = await _firestore
          .collection('negotiations')
          .where('passengerId', isEqualTo: user.uid)
          .where('status', whereIn: ['waiting', 'negotiating'])
          .get()
          .timeout(const Duration(seconds: 15), onTimeout: () {
            throw TimeoutException('Timeout buscando negociaciones expiradas');
          });

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final expiresAt = _parseDateTime(data['expiresAt']);

        // Si ya expiró, ELIMINAR el documento (no solo cambiar estado)
        if (expiresAt.isBefore(now)) {
          final negotiationId = data['id'] ?? doc.id;
          debugPrint('⏰ Eliminando negociación expirada: $negotiationId');

          // ✅ CAMBIO: Eliminar documento en lugar de solo actualizar estado
          await _firestore.collection('negotiations').doc(doc.id).delete();

          // Remover de lista local
          _activeNegotiations.removeWhere((n) => n.id == negotiationId);
        }
      }

      // Limpiar currentNegotiation si expiró
      if (_currentNegotiation != null && _currentNegotiation!.expiresAt.isBefore(now)) {
        _currentNegotiation = null;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error expirando negociaciones: $e');
    }
  }

  /// ✅ NUEVO: Verificar si hay negociaciones activas (no expiradas, no canceladas)
  bool hasActiveNegotiation() {
    final now = DateTime.now();
    return _activeNegotiations.any((n) =>
      n.expiresAt.isAfter(now) &&
      n.status != NegotiationStatus.cancelled &&
      n.status != NegotiationStatus.accepted
    );
  }

  /// ✅ NUEVO: Obtener negociaciones válidas (filtrar expiradas)
  List<PriceNegotiation> getValidNegotiations() {
    final now = DateTime.now();
    return _activeNegotiations.where((n) =>
      n.expiresAt.isAfter(now) &&
      n.status != NegotiationStatus.cancelled
    ).toList();
  }

  @override
  void dispose() {
    _negotiationsSubscription?.cancel();
    _driverNegotiationsSubscription?.cancel();
    super.dispose();
  }

  /// Para pasajeros: Crear nueva negociación con datos reales
  Future<void> createNegotiation({
    required LocationPoint pickup,
    required LocationPoint destination,
    required double offeredPrice,
    required PaymentMethod paymentMethod,
    String? notes,
    // ✅ NUEVO: Parámetros de promoción
    String? appliedPromotionId,
    String? appliedPromotionCode,
    double? discountAmount,
    double? discountPercentage,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      // Obtener datos del usuario desde Firestore
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      // Calcular datos reales
      final pickupLatLng = _locationPointToLatLng(pickup);
      final destLatLng = _locationPointToLatLng(destination);
      
      final distance = await _calculateRealDistance(pickupLatLng, destLatLng);
      final estimatedTime = await _calculateRealTime(pickupLatLng, destLatLng);
      final suggestedPrice = _calculateSuggestedPrice(distance);

      final negotiation = PriceNegotiation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        passengerId: user.uid,
        passengerName: user.displayName ?? userData['name'] ?? 'Usuario',
        passengerPhone: userData['phone'] ?? '',
        passengerPhoto: user.photoURL ?? userData['photoUrl'] ?? '',
        passengerRating: (userData['rating'] as num?)?.toDouble() ?? 5.0,
        pickup: pickup,
        destination: destination,
        suggestedPrice: suggestedPrice,
        offeredPrice: offeredPrice,
        distance: distance,
        estimatedTime: estimatedTime,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        status: NegotiationStatus.waiting,
        driverOffers: [],
        paymentMethod: paymentMethod,
        notes: notes,
        // ✅ Campos de promoción
        appliedPromotionId: appliedPromotionId,
        appliedPromotionCode: appliedPromotionCode,
        discountAmount: discountAmount,
        discountPercentage: discountPercentage,
      );
      
      _currentNegotiation = negotiation;
      _activeNegotiations.add(negotiation);
      await _broadcastToDrivers(negotiation);
      notifyListeners();
      
    } catch (e) {
      debugPrint('Error creando negociación: $e');
      rethrow;
    }
  }
  
  /// Para conductores: Ver todas las solicitudes activas desde Firestore
  Future<void> loadDriverRequests() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Obtener ubicación actual del conductor
      final driverDoc = await _firestore.collection('drivers').doc(user.uid).get();
      final driverData = driverDoc.data();
      
      if (driverData == null || driverData['location'] == null) {
        debugPrint('Conductor sin ubicación registrada');
        return;
      }

      // Buscar negociaciones activas en un radio de 10km
      final driverLat = driverData['location']['lat'];
      final driverLng = driverData['location']['lng'];
      
      // ✅ CORREGIDO: Sin filtro de expiresAt en query (puede ser String o Timestamp)
      // El filtro se hace en el cliente después de parsear
      final snapshot = await _firestore
          .collection('negotiations')
          .where('status', isEqualTo: 'waiting')
          .limit(50)
          .get();

      _driverVisibleRequests = snapshot.docs
          .map((doc) {
            final data = doc.data();
            return PriceNegotiation(
              id: data['id'] ?? '',
              passengerId: data['passengerId'] ?? '',
              passengerName: data['passengerName'] ?? '',
              passengerPhoto: data['passengerPhoto'] ?? '',
              passengerRating: (data['passengerRating'] as num?)?.toDouble() ?? 5.0,
              pickup: LocationPoint(
                latitude: (data['pickup']?['latitude'] as num?)?.toDouble() ?? 0.0,
                longitude: (data['pickup']?['longitude'] as num?)?.toDouble() ?? 0.0,
                address: data['pickup']?['address'] ?? '',
                reference: data['pickup']?['reference'],
              ),
              destination: LocationPoint(
                latitude: (data['destination']?['latitude'] as num?)?.toDouble() ?? 0.0,
                longitude: (data['destination']?['longitude'] as num?)?.toDouble() ?? 0.0,
                address: data['destination']?['address'] ?? '',
                reference: data['destination']?['reference'],
              ),
              suggestedPrice: (data['suggestedPrice'] as num?)?.toDouble() ?? 0.0,
              offeredPrice: (data['offeredPrice'] as num?)?.toDouble() ?? 0.0,
              distance: (data['distance'] as num?)?.toDouble() ?? 0.0,
              estimatedTime: data['estimatedTime'] ?? 0,
              createdAt: _parseDateTime(data['createdAt']),
              expiresAt: _parseDateTime(data['expiresAt']),
              status: NegotiationStatus.values.firstWhere(
                (status) => status.name == data['status'],
                orElse: () => NegotiationStatus.waiting,
              ),
              driverOffers: [],
              paymentMethod: PaymentMethod.values.firstWhere(
                (method) => method.name == data['paymentMethod'],
                orElse: () => PaymentMethod.cash,
              ),
              notes: data['notes'],
            );
          })
          .where((negotiation) {
            // ✅ FIX: Excluir las propias solicitudes del conductor (no puede aceptar su propio viaje)
            if (negotiation.passengerId == user.uid) {
              debugPrint('🚫 Excluyendo solicitud propia del conductor: ${negotiation.id}');
              return false;
            }
            // ✅ Filtrar expirados (el filtro que antes estaba en Firestore)
            if (negotiation.expiresAt.isBefore(DateTime.now())) {
              return false;
            }
            // Filtrar por proximidad (10km radio)
            final distance = _calculateHaversineDistance(
              LatLng(driverLat, driverLng),
              _locationPointToLatLng(negotiation.pickup),
            );
            return distance <= 10.0; // 10km máximo
          })
          .toList();
      
      notifyListeners();
      
    } catch (e) {
      debugPrint('Error cargando solicitudes de conductores: $e');
    }
  }
  
  // ✅ NUEVO: Constante para saldo mínimo requerido para conductores
  static const double minDriverBalance = 5.0; // S/. 5.00 mínimo para operar

  /// ✅ NUEVO: Verificar si el conductor tiene saldo suficiente para operar
  Future<bool> checkDriverBalance(String driverId) async {
    try {
      // ✅ FIX: Agregar timeout de 15 segundos para evitar congelamiento
      final walletDoc = await _firestore.collection('wallets').doc(driverId).get()
          .timeout(const Duration(seconds: 15), onTimeout: () {
            throw TimeoutException('Timeout verificando saldo del conductor');
          });
      if (!walletDoc.exists) {
        debugPrint('⚠️ Conductor sin billetera: $driverId');
        return false;
      }

      final walletData = walletDoc.data()!;
      final balance = (walletData['balance'] as num?)?.toDouble() ?? 0.0;
      final pendingBalance = (walletData['pendingBalance'] as num?)?.toDouble() ?? 0.0;
      final availableBalance = balance - pendingBalance;

      debugPrint('💰 Saldo conductor $driverId: S/. $availableBalance (mínimo: S/. $minDriverBalance)');
      return availableBalance >= minDriverBalance;
    } on TimeoutException {
      debugPrint('⏱️ Timeout verificando saldo, reintentando...');
      return false;
    } catch (e) {
      debugPrint('❌ Error verificando saldo: $e');
      return false;
    }
  }

  /// ✅ NUEVO: Getter para obtener el saldo mínimo requerido
  double get minimumDriverBalance => minDriverBalance;

  /// Para conductores: Hacer una oferta con datos reales
  /// ✅ MODIFICADO: Ahora retorna String? con mensaje de error o null si éxito
  Future<String?> makeDriverOffer(String negotiationId, double acceptedPrice) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'Usuario no autenticado';

      // ✅ NUEVO: Verificar saldo mínimo antes de hacer oferta
      final hasBalance = await checkDriverBalance(user.uid);
      if (!hasBalance) {
        debugPrint('❌ Conductor sin saldo suficiente para hacer ofertas');
        return 'Saldo insuficiente. Necesitas mínimo S/. ${minDriverBalance.toStringAsFixed(2)} para hacer ofertas. Recarga tu billetera.';
      }

      // Obtener datos del conductor desde Firestore (con timeout)
      final driverDoc = await _firestore.collection('drivers').doc(user.uid).get()
          .timeout(const Duration(seconds: 15), onTimeout: () {
            throw TimeoutException('Timeout obteniendo datos del conductor');
          });
      final driverData = driverDoc.data() ?? {};

      // Obtener teléfono del conductor desde users
      String driverPhone = '';
      try {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        driverPhone = userDoc.data()?['phone'] ?? '';
      } catch (_) {}

      // Obtener datos del vehículo
      final vehicleData = driverData['vehicle'] ?? {};
      
      // Calcular tiempo de llegada real
      final negotiationIndex = _activeNegotiations.indexWhere((n) => n.id == negotiationId);
      int estimatedArrival = 5; // default
      
      if (negotiationIndex != -1 && driverData['location'] != null) {
        final driverLocation = LatLng(
          (driverData['location']['lat'] as num?)?.toDouble() ?? 0.0,
          (driverData['location']['lng'] as num?)?.toDouble() ?? 0.0,
        );
        final pickupLocation = _locationPointToLatLng(
          _activeNegotiations[negotiationIndex].pickup,
        );
        
        estimatedArrival = await _calculateRealTime(driverLocation, pickupLocation);
      }

      final offer = DriverOffer(
        driverId: user.uid,
        driverName: user.displayName ?? driverData['name'] ?? 'Conductor',
        driverPhone: driverPhone,
        driverPhoto: user.photoURL ?? driverData['photoUrl'] ?? '',
        driverRating: (driverData['rating'] as num?)?.toDouble() ?? 5.0,
        vehicleModel: await _getDriverVehicleModel(),
        vehiclePlate: vehicleData['plate'] ?? 'XXX-000',
        vehicleColor: vehicleData['color'] ?? 'Color no especificado',
        acceptedPrice: acceptedPrice,
        estimatedArrival: estimatedArrival,
        offeredAt: DateTime.now(),
        status: OfferStatus.pending,
        completedTrips: driverData['completedTrips'] ?? 0,
        acceptanceRate: (driverData['acceptanceRate'] as num?)?.toDouble() ?? 100.0,
      );
      
      if (negotiationIndex != -1) {
        final updatedOffers = List<DriverOffer>.from(
          _activeNegotiations[negotiationIndex].driverOffers
        )..add(offer);
        
        _activeNegotiations[negotiationIndex] = 
            _activeNegotiations[negotiationIndex].copyWith(
          driverOffers: updatedOffers,
          status: NegotiationStatus.negotiating,
        );
        
        // Guardar oferta en Firestore (subcollección) con timeout
        await _firestore
            .collection('negotiations')
            .doc(negotiationId)
            .collection('offers')
            .doc(user.uid)
            .set({
              'driverId': offer.driverId,
              'driverName': offer.driverName,
              'driverPhone': offer.driverPhone,
              'driverPhoto': offer.driverPhoto,
              'driverRating': offer.driverRating,
              'vehicleModel': offer.vehicleModel,
              'vehiclePlate': offer.vehiclePlate,
              'vehicleColor': offer.vehicleColor,
              'acceptedPrice': offer.acceptedPrice,
              'estimatedArrival': offer.estimatedArrival,
              'offeredAt': offer.offeredAt.toIso8601String(),
              'status': offer.status.name,
              'completedTrips': offer.completedTrips,
              'acceptanceRate': offer.acceptanceRate,
            }).timeout(const Duration(seconds: 15), onTimeout: () {
              throw TimeoutException('Timeout guardando oferta');
            });

        // ✅ IMPORTANTE: También actualizar el documento principal para disparar el listener del pasajero
        // Agregamos la oferta al array driverOffers del documento para compatibilidad
        await _firestore.collection('negotiations').doc(negotiationId).update({
          'status': 'negotiating',
          'driverOffers': FieldValue.arrayUnion([{
            'driverId': offer.driverId,
            'driverName': offer.driverName,
            'driverPhone': offer.driverPhone,
            'driverPhoto': offer.driverPhoto,
            'driverRating': offer.driverRating,
            'vehicleModel': offer.vehicleModel,
            'vehiclePlate': offer.vehiclePlate,
            'vehicleColor': offer.vehicleColor,
            'acceptedPrice': offer.acceptedPrice,
            'estimatedArrival': offer.estimatedArrival,
            'offeredAt': offer.offeredAt.toIso8601String(),
            'status': offer.status.name,
            'completedTrips': offer.completedTrips,
            'acceptanceRate': offer.acceptanceRate / 100, // Normalizar a 0-1
          }]),
          'lastOfferAt': FieldValue.serverTimestamp(),
        }).timeout(const Duration(seconds: 15), onTimeout: () {
          throw TimeoutException('Timeout actualizando negociación');
        });
        
        if (_currentNegotiation?.id == negotiationId) {
          _currentNegotiation = _activeNegotiations[negotiationIndex];
        }

        notifyListeners();
        return null; // ✅ Éxito
      }

      return null; // Negociación no encontrada localmente pero no es error
    } catch (e) {
      debugPrint('Error haciendo oferta: $e');
      return 'Error al enviar oferta: $e';
    }
  }

  /// Para pasajeros: Aceptar oferta de conductor
  /// ✅ CORREGIDO: Usa Firestore Transaction para operación ATÓMICA
  /// Crea un viaje en Firestore y conecta la negociación con el ride
  Future<String?> acceptDriverOffer(String negotiationId, String driverId) async {
    // ✅ IMPORTANTE: Capturar datos inmediatamente para evitar condiciones de carrera
    // El listener de Firebase puede modificar _activeNegotiations mientras esperamos
    final negotiationIndex = _activeNegotiations
        .indexWhere((n) => n.id == negotiationId);

    if (negotiationIndex == -1) {
      debugPrint('⚠️ Negociación $negotiationId no encontrada en lista activa');
      return null;
    }

    // Copiar la negociación inmediatamente antes de cualquier await
    final negotiation = _activeNegotiations[negotiationIndex];

    final offerIndex = negotiation.driverOffers
        .indexWhere((o) => o.driverId == driverId);

    if (offerIndex == -1) {
      debugPrint('⚠️ Oferta del conductor $driverId no encontrada');
      return null;
    }

    // Copiar la oferta inmediatamente
    final acceptedOffer = negotiation.driverOffers[offerIndex];

    try {
      // ✅ TRANSACTION ATÓMICA: Crear ride y actualizar negociación juntos
      String? rideId;
      final driverVerificationCode = _generateVerificationCode();
      final passengerVerificationCode = _generateVerificationCode();

      await _firestore.runTransaction((transaction) async {
        // 1. Verificar que la negociación sigue activa (dentro de la transacción)
        final negotiationRef = _firestore.collection('negotiations').doc(negotiationId);
        final negotiationDoc = await transaction.get(negotiationRef);

        if (!negotiationDoc.exists) {
          throw Exception('Negociación no encontrada');
        }

        final negData = negotiationDoc.data()!;
        final currentStatus = negData['status'] as String?;

        // ✅ FIX RACE CONDITION: Si ya fue aceptada por otro, abortar
        if (currentStatus == 'accepted' || currentStatus == 'cancelled' || currentStatus == 'completed') {
          throw Exception('La negociación ya no está disponible (estado: $currentStatus)');
        }

        // 2. Crear el viaje en Firestore (dentro de transacción)
        final rideRef = _firestore.collection('rides').doc();
        rideId = rideRef.id;

        transaction.set(rideRef, {
          'userId': negotiation.passengerId,
          'driverId': driverId,
          'negotiationId': negotiationId,
          'pickupLocation': {
            'latitude': negotiation.pickup.latitude,
            'longitude': negotiation.pickup.longitude,
          },
          'destinationLocation': {
            'latitude': negotiation.destination.latitude,
            'longitude': negotiation.destination.longitude,
          },
          'pickupAddress': negotiation.pickup.address,
          'destinationAddress': negotiation.destination.address,
          'estimatedFare': acceptedOffer.acceptedPrice,
          'finalFare': acceptedOffer.acceptedPrice,
          'estimatedDistance': negotiation.distance,
          'status': 'accepted',
          'paymentMethod': negotiation.paymentMethod.name,
          'isPaidOutsideApp': negotiation.paymentMethod == PaymentMethod.cash,
          'requestedAt': FieldValue.serverTimestamp(),
          'acceptedAt': FieldValue.serverTimestamp(),
          // Códigos de verificación mutua
          'passengerVerificationCode': passengerVerificationCode,
          'driverVerificationCode': driverVerificationCode,
          'isPassengerVerified': false,
          'isDriverVerified': false,
          // Info del conductor
          'vehicleInfo': {
            'driverName': acceptedOffer.driverName,
            'driverPhone': acceptedOffer.driverPhone,
            'driverPhoto': acceptedOffer.driverPhoto,
            'driverRating': acceptedOffer.driverRating,
            'vehicleModel': acceptedOffer.vehicleModel,
            'vehiclePlate': acceptedOffer.vehiclePlate,
            'vehicleColor': acceptedOffer.vehicleColor,
          },
          // Info del pasajero
          'passengerInfo': {
            'passengerName': negotiation.passengerName,
            'passengerPhone': negotiation.passengerPhone,
            'passengerPhoto': negotiation.passengerPhoto,
            'passengerRating': negotiation.passengerRating,
          },
          // Campos de promoción (si aplica)
          if (negotiation.appliedPromotionId != null)
            'appliedPromotionId': negotiation.appliedPromotionId,
          if (negotiation.appliedPromotionCode != null)
            'appliedPromotionCode': negotiation.appliedPromotionCode,
          if (negotiation.discountAmount != null)
            'discountAmount': negotiation.discountAmount,
          if (negotiation.discountPercentage != null)
            'discountPercentage': negotiation.discountPercentage,
          if (negotiation.discountAmount != null)
            'originalFare': acceptedOffer.acceptedPrice,
        });

        // 3. Actualizar la negociación (dentro de transacción)
        transaction.update(negotiationRef, {
          'status': 'accepted',
          'acceptedDriverId': driverId,
          'rideId': rideId,
          'acceptedAt': FieldValue.serverTimestamp(),
        });
      }).timeout(const Duration(seconds: 30), onTimeout: () {
        throw TimeoutException('Timeout al aceptar oferta - operación muy lenta');
      });

      // ✅ Si llegamos aquí, la transacción fue exitosa

      // Actualizar ofertas localmente (si la negociación aún existe en la lista)
      final currentNegotiationIndex = _activeNegotiations
          .indexWhere((n) => n.id == negotiationId);

      if (currentNegotiationIndex != -1) {
        final updatedOffers = List<DriverOffer>.from(negotiation.driverOffers);
        for (int i = 0; i < updatedOffers.length; i++) {
          updatedOffers[i] = updatedOffers[i].copyWith(
            status: i == offerIndex
                ? OfferStatus.accepted
                : OfferStatus.rejected,
          );
        }

        _activeNegotiations[currentNegotiationIndex] = negotiation.copyWith(
          driverOffers: updatedOffers,
          status: NegotiationStatus.accepted,
          acceptedDriverId: driverId,
        );

        if (_currentNegotiation?.id == negotiationId) {
          _currentNegotiation = _activeNegotiations[currentNegotiationIndex];
        }
      } else {
        // La negociación fue removida durante el proceso
        if (_currentNegotiation?.id == negotiationId) {
          _currentNegotiation = negotiation.copyWith(
            status: NegotiationStatus.accepted,
            acceptedDriverId: driverId,
          );
        }
      }

      // Enviar notificación al conductor (fuera de transacción, no crítico)
      if (rideId != null) {
        await _sendAcceptanceNotification(driverId, rideId!, negotiation);
      }

      notifyListeners();

      debugPrint('✅ Viaje creado atómicamente: $rideId desde negociación: $negotiationId');
      return rideId;

    } on TimeoutException catch (e) {
      debugPrint('⏱️ $e');
      return null;
    } catch (e) {
      debugPrint('❌ Error aceptando oferta: $e');
      return null;
    }
  }

  /// Generar código de verificación de 4 dígitos
  String _generateVerificationCode() {
    final random = math.Random();
    String code = '';
    for (int i = 0; i < 4; i++) {
      code += random.nextInt(10).toString();
    }
    return code;
  }

  /// Enviar notificación al conductor cuando su oferta es aceptada
  Future<void> _sendAcceptanceNotification(
    String driverId,
    String rideId,
    PriceNegotiation negotiation
  ) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': driverId,
        'title': '¡Oferta Aceptada!',
        'message': 'Tu oferta de S/. ${negotiation.driverOffers.firstWhere((o) => o.driverId == driverId).acceptedPrice.toStringAsFixed(2)} ha sido aceptada. Dirígete al punto de recogida.',
        'type': 'offer_accepted',
        'data': {
          'rideId': rideId,
          'negotiationId': negotiation.id,
          'pickupAddress': negotiation.pickup.address,
          'destinationAddress': negotiation.destination.address,
        },
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Notificación enviada al conductor: $driverId');
    } catch (e) {
      debugPrint('❌ Error enviando notificación: $e');
    }
  }
  
  // MÉTODOS AUXILIARES REALES
  
  /// Calcular precio sugerido basado en distancia real y tarifas de Perú
  double _calculateSuggestedPrice(double distanceKm) {
    const double tarifaBase = 4.0; // S/ 4.00 tarifa base en Perú
    const double tarifaPorKm = 2.5; // S/ 2.50 por kilómetro
    const double tarifaMinima = 8.0; // S/ 8.00 mínimo
    
    final precio = tarifaBase + (distanceKm * tarifaPorKm);
    return math.max(precio, tarifaMinima).roundToDouble();
  }
  
  /// Obtener modelo del vehículo del conductor
  Future<String> _getDriverVehicleModel() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'Vehículo no especificado';
      
      final driverDoc = await _firestore.collection('drivers').doc(user.uid).get();
      final vehicleData = driverDoc.data()?['vehicle'] ?? {};
      
      final marca = vehicleData['brand'] ?? '';
      final modelo = vehicleData['model'] ?? '';
      final anio = vehicleData['year'] ?? '';
      
      if (marca.isNotEmpty && modelo.isNotEmpty) {
        return '$marca $modelo ${anio.isNotEmpty ? anio : ''}'.trim();
      }
      
      return 'Vehículo no especificado';
      
    } catch (e) {
      debugPrint('Error obteniendo modelo de vehículo: $e');
      return 'Vehículo no especificado';
    }
  }
  
  /// Broadcast real a conductores cercanos via Firestore
  Future<void> _broadcastToDrivers(PriceNegotiation negotiation) async {
    try {
      // Guardar negociación en Firestore para que los conductores la vean
      await _firestore
          .collection('negotiations')
          .doc(negotiation.id)
          .set({
            'id': negotiation.id,
            'passengerId': negotiation.passengerId,
            'passengerName': negotiation.passengerName,
            'passengerPhoto': negotiation.passengerPhoto,
            'passengerRating': negotiation.passengerRating,
            'pickup': {
              'latitude': negotiation.pickup.latitude,
              'longitude': negotiation.pickup.longitude,
              'address': negotiation.pickup.address,
              'reference': negotiation.pickup.reference,
            },
            'destination': {
              'latitude': negotiation.destination.latitude,
              'longitude': negotiation.destination.longitude,
              'address': negotiation.destination.address,
              'reference': negotiation.destination.reference,
            },
            'suggestedPrice': negotiation.suggestedPrice,
            'offeredPrice': negotiation.offeredPrice,
            'distance': negotiation.distance,
            'estimatedTime': negotiation.estimatedTime,
            'createdAt': Timestamp.fromDate(negotiation.createdAt),
            'expiresAt': Timestamp.fromDate(negotiation.expiresAt),
            'status': negotiation.status.name,
            'driverId': null,
            'paymentMethod': negotiation.paymentMethod.name,
            'notes': negotiation.notes,
          });
      
      // Buscar conductores activos en un radio de 15km
      final pickupLatLng = _locationPointToLatLng(negotiation.pickup);
      
      final driversSnapshot = await _firestore
          .collection('drivers')
          .where('isOnline', isEqualTo: true)
          .where('isAvailable', isEqualTo: true)
          .get();
      
      final List<String> nearbyDriverIds = [];
      
      for (final driverDoc in driversSnapshot.docs) {
        final driverData = driverDoc.data();
        if (driverData['location'] != null) {
          final driverLocation = LatLng(
            (driverData['location']['lat'] as num?)?.toDouble() ?? 0.0,
            (driverData['location']['lng'] as num?)?.toDouble() ?? 0.0,
          );
          
          final distance = _calculateHaversineDistance(
            pickupLatLng,
            driverLocation,
          );
          
          if (distance <= 15.0) { // 15km radio
            nearbyDriverIds.add(driverDoc.id);
          }
        }
      }
      
      // Enviar notificación push a conductores cercanos
      if (nearbyDriverIds.isNotEmpty) {
        await _sendPushNotificationToDrivers(nearbyDriverIds, negotiation);
      }
      
      _driverVisibleRequests.add(negotiation);
      debugPrint('Negociación broadcast a ${nearbyDriverIds.length} conductores');
      
    } catch (e) {
      debugPrint('Error haciendo broadcast a conductores: $e');
      rethrow;
    }
  }
  
  /// ✅ IMPLEMENTADO: Enviar notificaciones push a conductores
  Future<void> _sendPushNotificationToDrivers(List<String> driverIds, PriceNegotiation negotiation) async {
    try {
      for (final driverId in driverIds) {
        // Crear notificación en Firestore (será procesada por Cloud Functions)
        await _firestore.collection('notifications').add({
          'userId': driverId,
          'title': 'Nueva Solicitud de Viaje',
          'message': 'Nueva solicitud de viaje. Distancia: ${(negotiation.distance / 1000).toStringAsFixed(1)} km. Precio ofrecido: S/. ${negotiation.offeredPrice.toStringAsFixed(2)}',
          'type': 'price_negotiation',
          'data': {
            'negotiationId': negotiation.id,
            'passengerId': negotiation.passengerId,
            'pickup': {'lat': negotiation.pickup.latitude, 'lng': negotiation.pickup.longitude},
            'destination': {'lat': negotiation.destination.latitude, 'lng': negotiation.destination.longitude},
            'offeredPrice': negotiation.offeredPrice,
          },
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      debugPrint('✅ Notificaciones creadas para ${driverIds.length} conductores');
    } catch (e) {
      debugPrint('❌ Error enviando notificaciones: $e');
    }
  }

  LatLng _locationPointToLatLng(LocationPoint point) {
    return LatLng(point.latitude, point.longitude);
  }

  /// Helper para parsear DateTime desde Firestore (soporta Timestamp y String)
  DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  double _calculateHaversineDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371;
    double lat1Rad = point1.latitude * (math.pi / 180);
    double lat2Rad = point2.latitude * (math.pi / 180);
    double deltaLat = (point2.latitude - point1.latitude) * (math.pi / 180);
    double deltaLng = (point2.longitude - point1.longitude) * (math.pi / 180);

    double a = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.sin(deltaLng / 2) * math.sin(deltaLng / 2);
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  Future<double> _calculateRealDistance(LatLng point1, LatLng point2) async {
    return _calculateHaversineDistance(point1, point2);
  }

  Future<int> _calculateRealTime(LatLng point1, LatLng point2) async {
    double distanceKm = _calculateHaversineDistance(point1, point2);
    return (distanceKm / 30 * 60).round();
  }
}