import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/price_negotiation.dart';
import '../../../../shared/models/location_model.dart';

class PriceNegotiationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, Timer> _negotiationTimers = {};
  final Map<String, StreamController<List<DriverOffer>>> _offerStreams = {};

  // Provider para la instancia del servicio
  static final provider = Provider<PriceNegotiationService>((ref) {
    return PriceNegotiationService();
  });

  /// Crear una nueva negociación de precios
  Future<PriceNegotiation> createNegotiation({
    required String rideRequestId,
    required String passengerId,
    required double suggestedPrice,
    required NegotiationType negotiationType,
    double? passengerOffer,
    List<String>? allowedDriverIds,
    NegotiationConfig? config,
  }) async {
    final negotiationConfig = config ?? const NegotiationConfig();
    
    final negotiation = PriceNegotiation(
      id: _firestore.collection('negotiations').doc().id,
      rideRequestId: rideRequestId,
      passengerId: passengerId,
      suggestedPrice: suggestedPrice,
      passengerOffer: passengerOffer,
      negotiationType: negotiationType,
      status: NegotiationStatus.pending,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(
        Duration(seconds: negotiationConfig.defaultTimeoutSeconds)
      ),
      maxOffers: negotiationConfig.maxOffersPerNegotiation,
      allowedDriverIds: allowedDriverIds,
      metadata: {
        'config': negotiationConfig.toJson(),
        'version': '2.0',
        'platform': 'flutter',
      },
    );

    await _firestore
        .collection('negotiations')
        .doc(negotiation.id)
        .set(negotiation.toJson());

    // Iniciar el timer de expiración
    _startNegotiationTimer(negotiation);

    // Notificar a conductores disponibles
    await _notifyAvailableDrivers(negotiation);

    return negotiation;
  }

  /// Enviar una oferta de conductor
  Future<DriverOffer> submitDriverOffer({
    required String negotiationId,
    required String driverId,
    required String driverName,
    String? driverPhoto,
    required double driverRating,
    required int totalTrips,
    required String vehicleModel,
    required String vehiclePlate,
    required double offeredPrice,
    required LocationModel driverLocation,
    required LocationModel pickupLocation,
    String? message,
    bool isCounterOffer = false,
    String? originalOfferId,
  }) async {
    // Verificar si la negociación está activa
    final negotiationDoc = await _firestore
        .collection('negotiations')
        .doc(negotiationId)
        .get();

    if (!negotiationDoc.exists) {
      throw Exception('Negociación no encontrada');
    }

    final negotiation = PriceNegotiation.fromJson(
      negotiationDoc.data()!
    );

    if (negotiation.status != NegotiationStatus.pending && 
        negotiation.status != NegotiationStatus.active) {
      throw Exception('La negociación ya no está disponible');
    }

    if (DateTime.now().isAfter(negotiation.expiresAt)) {
      await _expireNegotiation(negotiationId);
      throw Exception('La negociación ha expirado');
    }

    // Verificar límites de ofertas
    final existingOffersQuery = await _firestore
        .collection('negotiations')
        .doc(negotiationId)
        .collection('offers')
        .where('driverId', isEqualTo: driverId)
        .get();

    final config = NegotiationConfig.fromJson(
      negotiation.metadata?['config'] ?? {}
    );

    if (existingOffersQuery.docs.length >= config.maxCounterOffersPerDriver) {
      throw Exception('Has alcanzado el límite de ofertas para esta negociación');
    }

    // Calcular distancia y tiempo estimado
    final estimatedDistance = _calculateDistance(driverLocation, pickupLocation);
    final estimatedArrival = _calculateArrivalTime(estimatedDistance);

    final offer = DriverOffer(
      id: _firestore.collection('temp').doc().id,
      negotiationId: negotiationId,
      driverId: driverId,
      driverName: driverName,
      driverPhoto: driverPhoto,
      driverRating: driverRating,
      totalTrips: totalTrips,
      vehicleModel: vehicleModel,
      vehiclePlate: vehiclePlate,
      offeredPrice: offeredPrice,
      estimatedDistance: estimatedDistance,
      estimatedArrivalMinutes: estimatedArrival,
      status: OfferStatus.pending,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(
        Duration(minutes: config.offerExpirationMinutes)
      ),
      message: message,
      isCounterOffer: isCounterOffer,
      originalOfferId: originalOfferId,
      driverMetadata: {
        'submitLocation': driverLocation.toJson(),
        'estimatedPickupTime': estimatedArrival,
        'platformVersion': '2.0',
      },
    );

    // Guardar la oferta
    await _firestore
        .collection('negotiations')
        .doc(negotiationId)
        .collection('offers')
        .doc(offer.id)
        .set(offer.toJson());

    // Actualizar estado de la negociación a activa si es la primera oferta
    if (negotiation.status == NegotiationStatus.pending) {
      await _firestore
          .collection('negotiations')
          .doc(negotiationId)
          .update({
        'status': NegotiationStatus.active.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // Notificar al stream de ofertas
    _notifyOfferStream(negotiationId, offer);

    return offer;
  }

  /// Aceptar una oferta
  Future<void> acceptOffer({
    required String negotiationId,
    required String offerId,
    required String passengerId,
  }) async {
    final batch = _firestore.batch();

    // Actualizar la negociación
    batch.update(
      _firestore.collection('negotiations').doc(negotiationId),
      {
        'status': NegotiationStatus.accepted.name,
        'acceptedAt': FieldValue.serverTimestamp(),
        'acceptedOfferId': offerId,
      },
    );

    // Actualizar la oferta aceptada
    batch.update(
      _firestore
          .collection('negotiations')
          .doc(negotiationId)
          .collection('offers')
          .doc(offerId),
      {
        'status': OfferStatus.accepted.name,
        'acceptedAt': FieldValue.serverTimestamp(),
      },
    );

    // Rechazar todas las demás ofertas
    final otherOffersQuery = await _firestore
        .collection('negotiations')
        .doc(negotiationId)
        .collection('offers')
        .where('status', isEqualTo: OfferStatus.pending.name)
        .get();

    for (final doc in otherOffersQuery.docs) {
      if (doc.id != offerId) {
        batch.update(doc.reference, {
          'status': OfferStatus.rejected.name,
          'rejectedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    await batch.commit();

    // Cancelar timer de negociación
    _cancelNegotiationTimer(negotiationId);

    // Crear el viaje
    await _createRideFromAcceptedOffer(negotiationId, offerId);
  }

  /// Rechazar todas las ofertas y cancelar negociación
  Future<void> cancelNegotiation({
    required String negotiationId,
    required String reason,
  }) async {
    final batch = _firestore.batch();

    // Actualizar la negociación
    batch.update(
      _firestore.collection('negotiations').doc(negotiationId),
      {
        'status': NegotiationStatus.cancelled.name,
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancellationReason': reason,
      },
    );

    // Rechazar todas las ofertas pendientes
    final offersQuery = await _firestore
        .collection('negotiations')
        .doc(negotiationId)
        .collection('offers')
        .where('status', isEqualTo: OfferStatus.pending.name)
        .get();

    for (final doc in offersQuery.docs) {
      batch.update(doc.reference, {
        'status': OfferStatus.rejected.name,
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectionReason': 'Negociación cancelada: $reason',
      });
    }

    await batch.commit();
    _cancelNegotiationTimer(negotiationId);
  }

  /// Extender tiempo de negociación
  Future<void> extendNegotiation({
    required String negotiationId,
    int? additionalSeconds,
  }) async {
    final negotiationDoc = await _firestore
        .collection('negotiations')
        .doc(negotiationId)
        .get();

    if (!negotiationDoc.exists) {
      throw Exception('Negociación no encontrada');
    }

    final negotiation = PriceNegotiation.fromJson(negotiationDoc.data()!);
    final config = NegotiationConfig.fromJson(
      negotiation.metadata?['config'] ?? {}
    );

    if (!config.allowExtensions) {
      throw Exception('Las extensiones no están permitidas');
    }

    final currentExtensions = negotiation.metadata?['extensionsUsed'] ?? 0;
    if (currentExtensions >= config.maxExtensions) {
      throw Exception('Se ha alcanzado el límite máximo de extensiones');
    }

    final extensionTime = additionalSeconds ?? config.extensionTimeSeconds;
    final newExpirationTime = negotiation.expiresAt.add(
      Duration(seconds: extensionTime)
    );

    await _firestore.collection('negotiations').doc(negotiationId).update({
      'expiresAt': Timestamp.fromDate(newExpirationTime),
      'extendedAt': FieldValue.serverTimestamp(),
      'metadata.extensionsUsed': currentExtensions + 1,
      'metadata.lastExtensionSeconds': extensionTime,
    });

    // Actualizar timer
    _cancelNegotiationTimer(negotiationId);
    _startNegotiationTimer(negotiation.copyWith(
      expiresAt: newExpirationTime,
    ));
  }

  /// Obtener stream de ofertas para una negociación
  Stream<List<DriverOffer>> getOffersStream(String negotiationId) {
    return _firestore
        .collection('negotiations')
        .doc(negotiationId)
        .collection('offers')
        .where('status', whereIn: [
          OfferStatus.pending.name,
          OfferStatus.accepted.name,
        ])
        .orderBy('offeredPrice', descending: false)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => DriverOffer.fromJson(doc.data()))
          .toList();
    });
  }

  /// Obtener negociación por ID
  Future<PriceNegotiation?> getNegotiation(String negotiationId) async {
    final doc = await _firestore
        .collection('negotiations')
        .doc(negotiationId)
        .get();

    if (!doc.exists) return null;

    return PriceNegotiation.fromJson(doc.data()!);
  }

  /// Stream de negociación
  Stream<PriceNegotiation> getNegotiationStream(String negotiationId) {
    return _firestore
        .collection('negotiations')
        .doc(negotiationId)
        .snapshots()
        .map((doc) => PriceNegotiation.fromJson(doc.data()!));
  }

  // Métodos privados auxiliares

  void _startNegotiationTimer(PriceNegotiation negotiation) {
    final duration = negotiation.expiresAt.difference(DateTime.now());
    if (duration.isNegative) return;

    _negotiationTimers[negotiation.id] = Timer(duration, () {
      _expireNegotiation(negotiation.id);
    });
  }

  void _cancelNegotiationTimer(String negotiationId) {
    _negotiationTimers[negotiationId]?.cancel();
    _negotiationTimers.remove(negotiationId);
  }

  Future<void> _expireNegotiation(String negotiationId) async {
    await _firestore.collection('negotiations').doc(negotiationId).update({
      'status': NegotiationStatus.expired.name,
      'expiredAt': FieldValue.serverTimestamp(),
    });

    // Rechazar ofertas pendientes
    final offersQuery = await _firestore
        .collection('negotiations')
        .doc(negotiationId)
        .collection('offers')
        .where('status', isEqualTo: OfferStatus.pending.name)
        .get();

    for (final doc in offersQuery.docs) {
      await doc.reference.update({
        'status': OfferStatus.expired.name,
        'expiredAt': FieldValue.serverTimestamp(),
      });
    }

    _cancelNegotiationTimer(negotiationId);
  }

  Future<void> _notifyAvailableDrivers(PriceNegotiation negotiation) async {
    // Implementar lógica de notificación a conductores
    // Esto puede incluir push notifications, sockets, etc.
    
    await _firestore.collection('driver_notifications').add({
      'type': 'price_negotiation',
      'negotiationId': negotiation.id,
      'suggestedPrice': negotiation.suggestedPrice,
      'passengerOffer': negotiation.passengerOffer,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(negotiation.expiresAt),
      'allowedDriverIds': negotiation.allowedDriverIds,
    });
  }

  void _notifyOfferStream(String negotiationId, DriverOffer offer) {
    if (_offerStreams.containsKey(negotiationId)) {
      // Lógica para notificar al stream
      // Esto sería manejado por el stream de Firestore
    }
  }

  Future<void> _createRideFromAcceptedOffer(
    String negotiationId,
    String offerId,
  ) async {
    // Obtener datos de la negociación y oferta
    final negotiationDoc = await _firestore
        .collection('negotiations')
        .doc(negotiationId)
        .get();
    
    final offerDoc = await _firestore
        .collection('negotiations')
        .doc(negotiationId)
        .collection('offers')
        .doc(offerId)
        .get();

    if (!negotiationDoc.exists || !offerDoc.exists) {
      throw Exception('No se pudo encontrar la negociación u oferta');
    }

    final negotiation = PriceNegotiation.fromJson(negotiationDoc.data()!);
    final offer = DriverOffer.fromJson(offerDoc.data()!);

    // Crear el viaje
    await _firestore.collection('rides').add({
      'id': _firestore.collection('rides').doc().id,
      'passengerId': negotiation.passengerId,
      'driverId': offer.driverId,
      'rideRequestId': negotiation.rideRequestId,
      'negotiationId': negotiationId,
      'acceptedOfferId': offerId,
      'finalPrice': offer.offeredPrice,
      'status': 'confirmed',
      'createdAt': FieldValue.serverTimestamp(),
      'negotiatedPrice': true,
      'originalSuggestedPrice': negotiation.suggestedPrice,
      'priceReduction': negotiation.suggestedPrice - offer.offeredPrice,
      'metadata': {
        'negotiationType': negotiation.negotiationType.name,
        'driverRating': offer.driverRating,
        'estimatedDistance': offer.estimatedDistance,
        'estimatedArrival': offer.estimatedArrivalMinutes,
      },
    });
  }

  double _calculateDistance(LocationModel from, LocationModel to) {
    // Implementar cálculo de distancia usando fórmula de Haversine
    const double earthRadius = 6371; // Radio de la Tierra en km

    final double lat1Rad = from.latitude * (pi / 180);
    final double lat2Rad = to.latitude * (pi / 180);
    final double deltaLat = (to.latitude - from.latitude) * (pi / 180);
    final double deltaLon = (to.longitude - from.longitude) * (pi / 180);

    final double a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(deltaLon / 2) * sin(deltaLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  int _calculateArrivalTime(double distanceKm) {
    // Estimación basada en velocidad promedio urbana de 25 km/h
    const double averageSpeed = 25.0;
    final double timeHours = distanceKm / averageSpeed;
    return (timeHours * 60).round(); // Convertir a minutos
  }

  /// Obtener métricas de una negociación
  Future<NegotiationMetrics> getNegotiationMetrics(
    String negotiationId,
  ) async {
    final negotiationDoc = await _firestore
        .collection('negotiations')
        .doc(negotiationId)
        .get();

    final offersQuery = await _firestore
        .collection('negotiations')
        .doc(negotiationId)
        .collection('offers')
        .get();

    if (!negotiationDoc.exists) {
      throw Exception('Negociación no encontrada');
    }

    final negotiation = PriceNegotiation.fromJson(negotiationDoc.data()!);
    final offers = offersQuery.docs
        .map((doc) => DriverOffer.fromJson(doc.data()))
        .toList();

    if (offers.isEmpty) {
      return NegotiationMetrics(
        negotiationId: negotiationId,
        totalOffers: 0,
        averageOffer: 0.0,
        lowestOffer: 0.0,
        highestOffer: 0.0,
        totalDriversParticipated: 0,
        averageResponseTime: Duration.zero,
        totalNegotiationTime: DateTime.now().difference(negotiation.createdAt),
        wasSuccessful: negotiation.status == NegotiationStatus.accepted,
        wasExtended: (negotiation.metadata?['extensionsUsed'] ?? 0) > 0,
        extensionsUsed: negotiation.metadata?['extensionsUsed'] ?? 0,
      );
    }

    final offerPrices = offers.map((offer) => offer.offeredPrice).toList();
    final uniqueDrivers = offers.map((offer) => offer.driverId).toSet();
    
    final responseTimes = offers.map((offer) => 
        offer.createdAt.difference(negotiation.createdAt)
    ).toList();

    final averageResponseTime = responseTimes.isEmpty 
        ? Duration.zero 
        : Duration(
            milliseconds: responseTimes
                .map((d) => d.inMilliseconds)
                .reduce((a, b) => a + b) ~/ responseTimes.length
          );

    return NegotiationMetrics(
      negotiationId: negotiationId,
      totalOffers: offers.length,
      averageOffer: offerPrices.reduce((a, b) => a + b) / offerPrices.length,
      lowestOffer: offerPrices.reduce(min),
      highestOffer: offerPrices.reduce(max),
      totalDriversParticipated: uniqueDrivers.length,
      averageResponseTime: averageResponseTime,
      totalNegotiationTime: (negotiation.acceptedAt ?? DateTime.now())
          .difference(negotiation.createdAt),
      wasSuccessful: negotiation.status == NegotiationStatus.accepted,
      wasExtended: (negotiation.metadata?['extensionsUsed'] ?? 0) > 0,
      extensionsUsed: negotiation.metadata?['extensionsUsed'] ?? 0,
      additionalMetrics: {
        'totalUniqueDrivers': uniqueDrivers.length,
        'priceRange': offerPrices.reduce(max) - offerPrices.reduce(min),
        'averageDriverRating': offers
            .map((o) => o.driverRating)
            .reduce((a, b) => a + b) / offers.length,
        'averageEstimatedDistance': offers
            .map((o) => o.estimatedDistance)
            .reduce((a, b) => a + b) / offers.length,
      },
    );
  }

  /// Limpiar recursos al destruir el servicio
  void dispose() {
    for (final timer in _negotiationTimers.values) {
      timer.cancel();
    }
    _negotiationTimers.clear();

    for (final controller in _offerStreams.values) {
      controller.close();
    }
    _offerStreams.clear();
  }
}