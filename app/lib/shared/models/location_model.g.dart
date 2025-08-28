// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'location_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$LocationModelImpl _$$LocationModelImplFromJson(Map<String, dynamic> json) =>
    _$LocationModelImpl(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      address: json['address'] as String,
      placeId: json['placeId'] as String?,
      name: json['name'] as String?,
      details: json['details'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      country: json['country'] as String?,
      postalCode: json['postalCode'] as String?,
    );

Map<String, dynamic> _$$LocationModelImplToJson(_$LocationModelImpl instance) =>
    <String, dynamic>{
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'address': instance.address,
      'placeId': instance.placeId,
      'name': instance.name,
      'details': instance.details,
      'city': instance.city,
      'state': instance.state,
      'country': instance.country,
      'postalCode': instance.postalCode,
    };

_$RouteModelImpl _$$RouteModelImplFromJson(Map<String, dynamic> json) =>
    _$RouteModelImpl(
      origin: LocationModel.fromJson(json['origin'] as Map<String, dynamic>),
      destination:
          LocationModel.fromJson(json['destination'] as Map<String, dynamic>),
      distanceKm: (json['distanceKm'] as num).toDouble(),
      durationMinutes: (json['durationMinutes'] as num).toInt(),
      polyline: json['polyline'] as String,
      waypoints: (json['waypoints'] as List<dynamic>?)
              ?.map((e) => LocationModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      bounds: json['bounds'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$$RouteModelImplToJson(_$RouteModelImpl instance) =>
    <String, dynamic>{
      'origin': instance.origin,
      'destination': instance.destination,
      'distanceKm': instance.distanceKm,
      'durationMinutes': instance.durationMinutes,
      'polyline': instance.polyline,
      'waypoints': instance.waypoints,
      'bounds': instance.bounds,
    };
