import 'package:freezed_annotation/freezed_annotation.dart';

part 'price_negotiation.freezed.dart';
part 'price_negotiation.g.dart';

/// Estados posibles de la negociación de precios
enum NegotiationStatus {
  pending,
  active,
  accepted,
  rejected,
  expired,
  cancelled
}

/// Estados de una oferta de conductor
enum OfferStatus {
  pending,
  accepted,
  rejected,
  withdrawn,
  expired
}

/// Tipo de negociación
enum NegotiationType {
  openBidding,     // Subasta abierta (varios conductores ofertan)
  directOffer,     // Oferta directa a conductor específico
  counterOffer     // Contraoferta
}

@freezed
class PriceNegotiation with _$PriceNegotiation {
  const factory PriceNegotiation({
    required String id,
    required String rideRequestId,
    required String passengerId,
    required double suggestedPrice,
    required double? passengerOffer,
    required NegotiationType negotiationType,
    required NegotiationStatus status,
    required DateTime createdAt,
    required DateTime expiresAt,
    DateTime? acceptedAt,
    DateTime? rejectedAt,
    String? acceptedOfferId,
    int? maxOffers,
    List<String>? allowedDriverIds,
    Map<String, dynamic>? metadata,
  }) = _PriceNegotiation;

  factory PriceNegotiation.fromJson(Map<String, dynamic> json) =>
      _$PriceNegotiationFromJson(json);
}

@freezed
class DriverOffer with _$DriverOffer {
  const factory DriverOffer({
    required String id,
    required String negotiationId,
    required String driverId,
    required String driverName,
    required String? driverPhoto,
    required double driverRating,
    required int totalTrips,
    required String vehicleModel,
    required String vehiclePlate,
    required double offeredPrice,
    required double estimatedDistance,
    required int estimatedArrivalMinutes,
    required OfferStatus status,
    required DateTime createdAt,
    DateTime? expiresAt,
    DateTime? acceptedAt,
    DateTime? rejectedAt,
    String? message,
    bool? isCounterOffer,
    String? originalOfferId,
    Map<String, dynamic>? driverMetadata,
  }) = _DriverOffer;

  factory DriverOffer.fromJson(Map<String, dynamic> json) =>
      _$DriverOfferFromJson(json);
}

@freezed
class NegotiationConfig with _$NegotiationConfig {
  const factory NegotiationConfig({
    @Default(300) int defaultTimeoutSeconds,
    @Default(5) int maxOffersPerNegotiation,
    @Default(3) int maxCounterOffersPerDriver,
    @Default(0.1) double minPriceReductionPercentage,
    @Default(2.0) double maxPriceIncreaseMultiplier,
    @Default(120) int extensionTimeSeconds,
    @Default(3) int maxExtensions,
    @Default(30) int offerExpirationMinutes,
    @Default(true) bool allowCounterOffers,
    @Default(true) bool allowExtensions,
    @Default(false) bool requireDriverApproval,
    List<String>? blacklistedDriverIds,
    Map<String, dynamic>? rules,
  }) = _NegotiationConfig;

  factory NegotiationConfig.fromJson(Map<String, dynamic> json) =>
      _$NegotiationConfigFromJson(json);
}

@freezed
class NegotiationMetrics with _$NegotiationMetrics {
  const factory NegotiationMetrics({
    required String negotiationId,
    required int totalOffers,
    required double averageOffer,
    required double lowestOffer,
    required double highestOffer,
    required int totalDriversParticipated,
    required Duration averageResponseTime,
    required Duration totalNegotiationTime,
    required bool wasSuccessful,
    required bool wasExtended,
    required int extensionsUsed,
    Map<String, dynamic>? additionalMetrics,
  }) = _NegotiationMetrics;

  factory NegotiationMetrics.fromJson(Map<String, dynamic> json) =>
      _$NegotiationMetricsFromJson(json);
}