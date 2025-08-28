// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'price_negotiation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PriceNegotiationImpl _$$PriceNegotiationImplFromJson(
        Map<String, dynamic> json) =>
    _$PriceNegotiationImpl(
      id: json['id'] as String,
      rideRequestId: json['rideRequestId'] as String,
      passengerId: json['passengerId'] as String,
      suggestedPrice: (json['suggestedPrice'] as num).toDouble(),
      passengerOffer: (json['passengerOffer'] as num?)?.toDouble(),
      negotiationType:
          $enumDecode(_$NegotiationTypeEnumMap, json['negotiationType']),
      status: $enumDecode(_$NegotiationStatusEnumMap, json['status']),
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      acceptedAt: json['acceptedAt'] == null
          ? null
          : DateTime.parse(json['acceptedAt'] as String),
      rejectedAt: json['rejectedAt'] == null
          ? null
          : DateTime.parse(json['rejectedAt'] as String),
      acceptedOfferId: json['acceptedOfferId'] as String?,
      maxOffers: (json['maxOffers'] as num?)?.toInt(),
      allowedDriverIds: (json['allowedDriverIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$$PriceNegotiationImplToJson(
        _$PriceNegotiationImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'rideRequestId': instance.rideRequestId,
      'passengerId': instance.passengerId,
      'suggestedPrice': instance.suggestedPrice,
      'passengerOffer': instance.passengerOffer,
      'negotiationType': _$NegotiationTypeEnumMap[instance.negotiationType]!,
      'status': _$NegotiationStatusEnumMap[instance.status]!,
      'createdAt': instance.createdAt.toIso8601String(),
      'expiresAt': instance.expiresAt.toIso8601String(),
      'acceptedAt': instance.acceptedAt?.toIso8601String(),
      'rejectedAt': instance.rejectedAt?.toIso8601String(),
      'acceptedOfferId': instance.acceptedOfferId,
      'maxOffers': instance.maxOffers,
      'allowedDriverIds': instance.allowedDriverIds,
      'metadata': instance.metadata,
    };

const _$NegotiationTypeEnumMap = {
  NegotiationType.openBidding: 'openBidding',
  NegotiationType.directOffer: 'directOffer',
  NegotiationType.counterOffer: 'counterOffer',
};

const _$NegotiationStatusEnumMap = {
  NegotiationStatus.pending: 'pending',
  NegotiationStatus.active: 'active',
  NegotiationStatus.accepted: 'accepted',
  NegotiationStatus.rejected: 'rejected',
  NegotiationStatus.expired: 'expired',
  NegotiationStatus.cancelled: 'cancelled',
};

_$DriverOfferImpl _$$DriverOfferImplFromJson(Map<String, dynamic> json) =>
    _$DriverOfferImpl(
      id: json['id'] as String,
      negotiationId: json['negotiationId'] as String,
      driverId: json['driverId'] as String,
      driverName: json['driverName'] as String,
      driverPhoto: json['driverPhoto'] as String?,
      driverRating: (json['driverRating'] as num).toDouble(),
      totalTrips: (json['totalTrips'] as num).toInt(),
      vehicleModel: json['vehicleModel'] as String,
      vehiclePlate: json['vehiclePlate'] as String,
      offeredPrice: (json['offeredPrice'] as num).toDouble(),
      estimatedDistance: (json['estimatedDistance'] as num).toDouble(),
      estimatedArrivalMinutes: (json['estimatedArrivalMinutes'] as num).toInt(),
      status: $enumDecode(_$OfferStatusEnumMap, json['status']),
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.parse(json['expiresAt'] as String),
      acceptedAt: json['acceptedAt'] == null
          ? null
          : DateTime.parse(json['acceptedAt'] as String),
      rejectedAt: json['rejectedAt'] == null
          ? null
          : DateTime.parse(json['rejectedAt'] as String),
      message: json['message'] as String?,
      isCounterOffer: json['isCounterOffer'] as bool?,
      originalOfferId: json['originalOfferId'] as String?,
      driverMetadata: json['driverMetadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$$DriverOfferImplToJson(_$DriverOfferImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'negotiationId': instance.negotiationId,
      'driverId': instance.driverId,
      'driverName': instance.driverName,
      'driverPhoto': instance.driverPhoto,
      'driverRating': instance.driverRating,
      'totalTrips': instance.totalTrips,
      'vehicleModel': instance.vehicleModel,
      'vehiclePlate': instance.vehiclePlate,
      'offeredPrice': instance.offeredPrice,
      'estimatedDistance': instance.estimatedDistance,
      'estimatedArrivalMinutes': instance.estimatedArrivalMinutes,
      'status': _$OfferStatusEnumMap[instance.status]!,
      'createdAt': instance.createdAt.toIso8601String(),
      'expiresAt': instance.expiresAt?.toIso8601String(),
      'acceptedAt': instance.acceptedAt?.toIso8601String(),
      'rejectedAt': instance.rejectedAt?.toIso8601String(),
      'message': instance.message,
      'isCounterOffer': instance.isCounterOffer,
      'originalOfferId': instance.originalOfferId,
      'driverMetadata': instance.driverMetadata,
    };

const _$OfferStatusEnumMap = {
  OfferStatus.pending: 'pending',
  OfferStatus.accepted: 'accepted',
  OfferStatus.rejected: 'rejected',
  OfferStatus.withdrawn: 'withdrawn',
  OfferStatus.expired: 'expired',
};

_$NegotiationConfigImpl _$$NegotiationConfigImplFromJson(
        Map<String, dynamic> json) =>
    _$NegotiationConfigImpl(
      defaultTimeoutSeconds:
          (json['defaultTimeoutSeconds'] as num?)?.toInt() ?? 300,
      maxOffersPerNegotiation:
          (json['maxOffersPerNegotiation'] as num?)?.toInt() ?? 5,
      maxCounterOffersPerDriver:
          (json['maxCounterOffersPerDriver'] as num?)?.toInt() ?? 3,
      minPriceReductionPercentage:
          (json['minPriceReductionPercentage'] as num?)?.toDouble() ?? 0.1,
      maxPriceIncreaseMultiplier:
          (json['maxPriceIncreaseMultiplier'] as num?)?.toDouble() ?? 2.0,
      extensionTimeSeconds:
          (json['extensionTimeSeconds'] as num?)?.toInt() ?? 120,
      maxExtensions: (json['maxExtensions'] as num?)?.toInt() ?? 3,
      offerExpirationMinutes:
          (json['offerExpirationMinutes'] as num?)?.toInt() ?? 30,
      allowCounterOffers: json['allowCounterOffers'] as bool? ?? true,
      allowExtensions: json['allowExtensions'] as bool? ?? true,
      requireDriverApproval: json['requireDriverApproval'] as bool? ?? false,
      blacklistedDriverIds: (json['blacklistedDriverIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      rules: json['rules'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$$NegotiationConfigImplToJson(
        _$NegotiationConfigImpl instance) =>
    <String, dynamic>{
      'defaultTimeoutSeconds': instance.defaultTimeoutSeconds,
      'maxOffersPerNegotiation': instance.maxOffersPerNegotiation,
      'maxCounterOffersPerDriver': instance.maxCounterOffersPerDriver,
      'minPriceReductionPercentage': instance.minPriceReductionPercentage,
      'maxPriceIncreaseMultiplier': instance.maxPriceIncreaseMultiplier,
      'extensionTimeSeconds': instance.extensionTimeSeconds,
      'maxExtensions': instance.maxExtensions,
      'offerExpirationMinutes': instance.offerExpirationMinutes,
      'allowCounterOffers': instance.allowCounterOffers,
      'allowExtensions': instance.allowExtensions,
      'requireDriverApproval': instance.requireDriverApproval,
      'blacklistedDriverIds': instance.blacklistedDriverIds,
      'rules': instance.rules,
    };

_$NegotiationMetricsImpl _$$NegotiationMetricsImplFromJson(
        Map<String, dynamic> json) =>
    _$NegotiationMetricsImpl(
      negotiationId: json['negotiationId'] as String,
      totalOffers: (json['totalOffers'] as num).toInt(),
      averageOffer: (json['averageOffer'] as num).toDouble(),
      lowestOffer: (json['lowestOffer'] as num).toDouble(),
      highestOffer: (json['highestOffer'] as num).toDouble(),
      totalDriversParticipated:
          (json['totalDriversParticipated'] as num).toInt(),
      averageResponseTime:
          Duration(microseconds: (json['averageResponseTime'] as num).toInt()),
      totalNegotiationTime:
          Duration(microseconds: (json['totalNegotiationTime'] as num).toInt()),
      wasSuccessful: json['wasSuccessful'] as bool,
      wasExtended: json['wasExtended'] as bool,
      extensionsUsed: (json['extensionsUsed'] as num).toInt(),
      additionalMetrics: json['additionalMetrics'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$$NegotiationMetricsImplToJson(
        _$NegotiationMetricsImpl instance) =>
    <String, dynamic>{
      'negotiationId': instance.negotiationId,
      'totalOffers': instance.totalOffers,
      'averageOffer': instance.averageOffer,
      'lowestOffer': instance.lowestOffer,
      'highestOffer': instance.highestOffer,
      'totalDriversParticipated': instance.totalDriversParticipated,
      'averageResponseTime': instance.averageResponseTime.inMicroseconds,
      'totalNegotiationTime': instance.totalNegotiationTime.inMicroseconds,
      'wasSuccessful': instance.wasSuccessful,
      'wasExtended': instance.wasExtended,
      'extensionsUsed': instance.extensionsUsed,
      'additionalMetrics': instance.additionalMetrics,
    };
