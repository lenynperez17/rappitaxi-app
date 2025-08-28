// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'driver_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$DriverModelImpl _$$DriverModelImplFromJson(Map<String, dynamic> json) =>
    _$DriverModelImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      photoUrl: json['photoUrl'] as String?,
      rating: (json['rating'] as num).toDouble(),
      totalRides: (json['totalRides'] as num).toInt(),
      vehicle: VehicleModel.fromJson(json['vehicle'] as Map<String, dynamic>),
      isOnline: json['isOnline'] as bool,
      isAvailable: json['isAvailable'] as bool,
      currentLocation: json['currentLocation'] == null
          ? null
          : LocationData.fromJson(
              json['currentLocation'] as Map<String, dynamic>),
      languages: (json['languages'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      memberSince: json['memberSince'] == null
          ? null
          : DateTime.parse(json['memberSince'] as String),
    );

Map<String, dynamic> _$$DriverModelImplToJson(_$DriverModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'phone': instance.phone,
      'photoUrl': instance.photoUrl,
      'rating': instance.rating,
      'totalRides': instance.totalRides,
      'vehicle': instance.vehicle,
      'isOnline': instance.isOnline,
      'isAvailable': instance.isAvailable,
      'currentLocation': instance.currentLocation,
      'languages': instance.languages,
      'memberSince': instance.memberSince?.toIso8601String(),
    };

_$VehicleModelImpl _$$VehicleModelImplFromJson(Map<String, dynamic> json) =>
    _$VehicleModelImpl(
      brand: json['brand'] as String,
      model: json['model'] as String,
      year: (json['year'] as num).toInt(),
      plate: json['plate'] as String,
      color: json['color'] as String,
      type: json['type'] as String? ?? 'standard',
      capacity: (json['capacity'] as num?)?.toInt() ?? 4,
      photoUrl: json['photoUrl'] as String?,
    );

Map<String, dynamic> _$$VehicleModelImplToJson(_$VehicleModelImpl instance) =>
    <String, dynamic>{
      'brand': instance.brand,
      'model': instance.model,
      'year': instance.year,
      'plate': instance.plate,
      'color': instance.color,
      'type': instance.type,
      'capacity': instance.capacity,
      'photoUrl': instance.photoUrl,
    };

_$LocationDataImpl _$$LocationDataImplFromJson(Map<String, dynamic> json) =>
    _$LocationDataImpl(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      heading: (json['heading'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
      lastUpdate: json['lastUpdate'] == null
          ? null
          : DateTime.parse(json['lastUpdate'] as String),
    );

Map<String, dynamic> _$$LocationDataImplToJson(_$LocationDataImpl instance) =>
    <String, dynamic>{
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'heading': instance.heading,
      'speed': instance.speed,
      'lastUpdate': instance.lastUpdate?.toIso8601String(),
    };
