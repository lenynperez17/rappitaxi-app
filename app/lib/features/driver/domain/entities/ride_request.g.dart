// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ride_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$RideRequestImpl _$$RideRequestImplFromJson(Map<String, dynamic> json) =>
    _$RideRequestImpl(
      id: json['id'] as String,
      passengerId: json['passengerId'] as String,
      passengerName: json['passengerName'] as String,
      passengerPhone: json['passengerPhone'] as String,
      passengerPhoto: json['passengerPhoto'] as String?,
      passengerRating: (json['passengerRating'] as num).toDouble(),
      pickup: LocationModel.fromJson(json['pickup'] as Map<String, dynamic>),
      destination:
          LocationModel.fromJson(json['destination'] as Map<String, dynamic>),
      estimatedFare: (json['estimatedFare'] as num).toDouble(),
      estimatedDistance: (json['estimatedDistance'] as num).toDouble(),
      estimatedDuration: (json['estimatedDuration'] as num).toInt(),
      vehicleType: json['vehicleType'] as String,
      paymentMethod: json['paymentMethod'] as String,
      requestedAt: DateTime.parse(json['requestedAt'] as String),
      timeoutSeconds: (json['timeoutSeconds'] as num).toInt(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$$RideRequestImplToJson(_$RideRequestImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'passengerId': instance.passengerId,
      'passengerName': instance.passengerName,
      'passengerPhone': instance.passengerPhone,
      'passengerPhoto': instance.passengerPhoto,
      'passengerRating': instance.passengerRating,
      'pickup': instance.pickup,
      'destination': instance.destination,
      'estimatedFare': instance.estimatedFare,
      'estimatedDistance': instance.estimatedDistance,
      'estimatedDuration': instance.estimatedDuration,
      'vehicleType': instance.vehicleType,
      'paymentMethod': instance.paymentMethod,
      'requestedAt': instance.requestedAt.toIso8601String(),
      'timeoutSeconds': instance.timeoutSeconds,
      'metadata': instance.metadata,
    };
