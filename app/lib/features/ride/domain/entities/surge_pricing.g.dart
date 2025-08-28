// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'surge_pricing.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SurgePricingImpl _$$SurgePricingImplFromJson(Map<String, dynamic> json) =>
    _$SurgePricingImpl(
      id: json['id'] as String,
      zoneId: json['zoneId'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      radiusKm: (json['radiusKm'] as num).toDouble(),
      surgeMultiplier: (json['surgeMultiplier'] as num).toDouble(),
      activeDrivers: (json['activeDrivers'] as num).toInt(),
      pendingRequests: (json['pendingRequests'] as num).toInt(),
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      reason: $enumDecode(_$SurgeReasonEnumMap, json['reason']),
      isActive: json['isActive'] as bool? ?? true,
      message: json['message'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
    );

Map<String, dynamic> _$$SurgePricingImplToJson(_$SurgePricingImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'zoneId': instance.zoneId,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'radiusKm': instance.radiusKm,
      'surgeMultiplier': instance.surgeMultiplier,
      'activeDrivers': instance.activeDrivers,
      'pendingRequests': instance.pendingRequests,
      'startTime': instance.startTime.toIso8601String(),
      'endTime': instance.endTime.toIso8601String(),
      'reason': _$SurgeReasonEnumMap[instance.reason]!,
      'isActive': instance.isActive,
      'message': instance.message,
      'metadata': instance.metadata,
    };

const _$SurgeReasonEnumMap = {
  SurgeReason.highDemand: 'highDemand',
  SurgeReason.lowSupply: 'lowSupply',
  SurgeReason.peakHours: 'peakHours',
  SurgeReason.specialEvent: 'specialEvent',
  SurgeReason.weatherConditions: 'weatherConditions',
  SurgeReason.manualOverride: 'manualOverride',
};

_$SurgePricingConfigImpl _$$SurgePricingConfigImplFromJson(
        Map<String, dynamic> json) =>
    _$SurgePricingConfigImpl(
      enableSurgePricing: json['enableSurgePricing'] as bool? ?? true,
      minMultiplier: (json['minMultiplier'] as num?)?.toDouble() ?? 1.0,
      maxMultiplier: (json['maxMultiplier'] as num?)?.toDouble() ?? 3.0,
      incrementStep: (json['incrementStep'] as num?)?.toDouble() ?? 0.1,
      demandThreshold: (json['demandThreshold'] as num?)?.toInt() ?? 5,
      supplyThreshold: (json['supplyThreshold'] as num?)?.toInt() ?? 3,
      updateIntervalSeconds:
          (json['updateIntervalSeconds'] as num?)?.toInt() ?? 300,
      zoneSizeKm: (json['zoneSizeKm'] as num?)?.toInt() ?? 15,
      showSurgeWarning: json['showSurgeWarning'] as bool? ?? true,
      allowUserOptOut: json['allowUserOptOut'] as bool? ?? true,
      peakHours: (json['peakHours'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, (e as num).toDouble()),
      ),
    );

Map<String, dynamic> _$$SurgePricingConfigImplToJson(
        _$SurgePricingConfigImpl instance) =>
    <String, dynamic>{
      'enableSurgePricing': instance.enableSurgePricing,
      'minMultiplier': instance.minMultiplier,
      'maxMultiplier': instance.maxMultiplier,
      'incrementStep': instance.incrementStep,
      'demandThreshold': instance.demandThreshold,
      'supplyThreshold': instance.supplyThreshold,
      'updateIntervalSeconds': instance.updateIntervalSeconds,
      'zoneSizeKm': instance.zoneSizeKm,
      'showSurgeWarning': instance.showSurgeWarning,
      'allowUserOptOut': instance.allowUserOptOut,
      'peakHours': instance.peakHours,
    };

_$SurgePricingHistoryImpl _$$SurgePricingHistoryImplFromJson(
        Map<String, dynamic> json) =>
    _$SurgePricingHistoryImpl(
      id: json['id'] as String,
      zoneId: json['zoneId'] as String,
      multiplier: (json['multiplier'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      activeDrivers: (json['activeDrivers'] as num).toInt(),
      pendingRequests: (json['pendingRequests'] as num).toInt(),
      reason: $enumDecode(_$SurgeReasonEnumMap, json['reason']),
      averageFare: (json['averageFare'] as num).toDouble(),
      completedRides: (json['completedRides'] as num).toInt(),
    );

Map<String, dynamic> _$$SurgePricingHistoryImplToJson(
        _$SurgePricingHistoryImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'zoneId': instance.zoneId,
      'multiplier': instance.multiplier,
      'timestamp': instance.timestamp.toIso8601String(),
      'activeDrivers': instance.activeDrivers,
      'pendingRequests': instance.pendingRequests,
      'reason': _$SurgeReasonEnumMap[instance.reason]!,
      'averageFare': instance.averageFare,
      'completedRides': instance.completedRides,
    };

_$SurgeZoneImpl _$$SurgeZoneImplFromJson(Map<String, dynamic> json) =>
    _$SurgeZoneImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      centerLatitude: (json['centerLatitude'] as num).toDouble(),
      centerLongitude: (json['centerLongitude'] as num).toDouble(),
      radiusKm: (json['radiusKm'] as num).toDouble(),
      currentMultiplier: (json['currentMultiplier'] as num).toDouble(),
      activeDrivers: (json['activeDrivers'] as num).toInt(),
      pendingRequests: (json['pendingRequests'] as num).toInt(),
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
      isActive: json['isActive'] as bool? ?? true,
      polygonGeojson: json['polygonGeojson'] as String?,
      recentHistory: (json['recentHistory'] as List<dynamic>?)
              ?.map((e) =>
                  SurgePricingHistory.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$SurgeZoneImplToJson(_$SurgeZoneImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'centerLatitude': instance.centerLatitude,
      'centerLongitude': instance.centerLongitude,
      'radiusKm': instance.radiusKm,
      'currentMultiplier': instance.currentMultiplier,
      'activeDrivers': instance.activeDrivers,
      'pendingRequests': instance.pendingRequests,
      'lastUpdated': instance.lastUpdated.toIso8601String(),
      'isActive': instance.isActive,
      'polygonGeojson': instance.polygonGeojson,
      'recentHistory': instance.recentHistory,
    };
