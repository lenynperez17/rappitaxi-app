// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ride_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$RideModelImpl _$$RideModelImplFromJson(Map<String, dynamic> json) =>
    _$RideModelImpl(
      id: json['id'] as String,
      passengerId: json['passengerId'] as String,
      driverId: json['driverId'] as String,
      pickup: LocationModel.fromJson(json['pickup'] as Map<String, dynamic>),
      destination:
          LocationModel.fromJson(json['destination'] as Map<String, dynamic>),
      requestedAt: DateTime.parse(json['requestedAt'] as String),
      acceptedAt: json['acceptedAt'] == null
          ? null
          : DateTime.parse(json['acceptedAt'] as String),
      startedAt: json['startedAt'] == null
          ? null
          : DateTime.parse(json['startedAt'] as String),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      cancelledAt: json['cancelledAt'] == null
          ? null
          : DateTime.parse(json['cancelledAt'] as String),
      status: json['status'] as String,
      vehicleType: json['vehicleType'] as String,
      fare: (json['fare'] as num).toDouble(),
      distance: (json['distance'] as num).toDouble(),
      duration: (json['duration'] as num).toInt(),
      paymentMethod: json['paymentMethod'] as String,
      paymentIntentId: json['paymentIntentId'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      comment: json['comment'] as String?,
      cancellationReason: json['cancellationReason'] as String?,
      cancelledBy: json['cancelledBy'] as String?,
      driverInfo: json['driverInfo'] == null
          ? null
          : DriverInfo.fromJson(json['driverInfo'] as Map<String, dynamic>),
      passengerInfo: json['passengerInfo'] == null
          ? null
          : PassengerInfo.fromJson(
              json['passengerInfo'] as Map<String, dynamic>),
      vehicleInfo: json['vehicleInfo'] == null
          ? null
          : RideVehicleInfo.fromJson(
              json['vehicleInfo'] as Map<String, dynamic>),
      routePoints: (json['routePoints'] as List<dynamic>?)
              ?.map((e) => RoutePoint.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$$RideModelImplToJson(_$RideModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'passengerId': instance.passengerId,
      'driverId': instance.driverId,
      'pickup': instance.pickup,
      'destination': instance.destination,
      'requestedAt': instance.requestedAt.toIso8601String(),
      'acceptedAt': instance.acceptedAt?.toIso8601String(),
      'startedAt': instance.startedAt?.toIso8601String(),
      'completedAt': instance.completedAt?.toIso8601String(),
      'cancelledAt': instance.cancelledAt?.toIso8601String(),
      'status': instance.status,
      'vehicleType': instance.vehicleType,
      'fare': instance.fare,
      'distance': instance.distance,
      'duration': instance.duration,
      'paymentMethod': instance.paymentMethod,
      'paymentIntentId': instance.paymentIntentId,
      'rating': instance.rating,
      'comment': instance.comment,
      'cancellationReason': instance.cancellationReason,
      'cancelledBy': instance.cancelledBy,
      'driverInfo': instance.driverInfo,
      'passengerInfo': instance.passengerInfo,
      'vehicleInfo': instance.vehicleInfo,
      'routePoints': instance.routePoints,
      'metadata': instance.metadata,
    };

_$DriverInfoImpl _$$DriverInfoImplFromJson(Map<String, dynamic> json) =>
    _$DriverInfoImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      photoUrl: json['photoUrl'] as String?,
      rating: (json['rating'] as num).toDouble(),
      totalRides: (json['totalRides'] as num).toInt(),
    );

Map<String, dynamic> _$$DriverInfoImplToJson(_$DriverInfoImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'phone': instance.phone,
      'photoUrl': instance.photoUrl,
      'rating': instance.rating,
      'totalRides': instance.totalRides,
    };

_$RideVehicleInfoImpl _$$RideVehicleInfoImplFromJson(
        Map<String, dynamic> json) =>
    _$RideVehicleInfoImpl(
      plate: json['plate'] as String,
      brand: json['brand'] as String,
      model: json['model'] as String,
      color: json['color'] as String,
      year: (json['year'] as num).toInt(),
    );

Map<String, dynamic> _$$RideVehicleInfoImplToJson(
        _$RideVehicleInfoImpl instance) =>
    <String, dynamic>{
      'plate': instance.plate,
      'brand': instance.brand,
      'model': instance.model,
      'color': instance.color,
      'year': instance.year,
    };

_$RoutePointImpl _$$RoutePointImplFromJson(Map<String, dynamic> json) =>
    _$RoutePointImpl(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );

Map<String, dynamic> _$$RoutePointImplToJson(_$RoutePointImpl instance) =>
    <String, dynamic>{
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'timestamp': instance.timestamp.toIso8601String(),
    };

_$PassengerInfoImpl _$$PassengerInfoImplFromJson(Map<String, dynamic> json) =>
    _$PassengerInfoImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      photoUrl: json['photoUrl'] as String?,
      rating: (json['rating'] as num).toDouble(),
      totalRides: (json['totalRides'] as num).toInt(),
    );

Map<String, dynamic> _$$PassengerInfoImplToJson(_$PassengerInfoImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'phone': instance.phone,
      'photoUrl': instance.photoUrl,
      'rating': instance.rating,
      'totalRides': instance.totalRides,
    };
