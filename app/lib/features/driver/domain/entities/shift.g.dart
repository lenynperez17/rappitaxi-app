// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shift.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ShiftImpl _$$ShiftImplFromJson(Map<String, dynamic> json) => _$ShiftImpl(
      id: json['id'] as String,
      driverId: json['driverId'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      status: $enumDecode(_$ShiftStatusEnumMap, json['status']),
      workDays:
          (json['workDays'] as List<dynamic>).map((e) => e as String).toList(),
      notes: json['notes'] as String?,
      actualStartTime: json['actualStartTime'] == null
          ? null
          : DateTime.parse(json['actualStartTime'] as String),
      actualEndTime: json['actualEndTime'] == null
          ? null
          : DateTime.parse(json['actualEndTime'] as String),
      estimatedEarnings: (json['estimatedEarnings'] as num?)?.toDouble() ?? 0.0,
      actualEarnings: (json['actualEarnings'] as num?)?.toDouble() ?? 0.0,
      completedRides: (json['completedRides'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$ShiftImplToJson(_$ShiftImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'driverId': instance.driverId,
      'startTime': instance.startTime.toIso8601String(),
      'endTime': instance.endTime.toIso8601String(),
      'status': _$ShiftStatusEnumMap[instance.status]!,
      'workDays': instance.workDays,
      'notes': instance.notes,
      'actualStartTime': instance.actualStartTime?.toIso8601String(),
      'actualEndTime': instance.actualEndTime?.toIso8601String(),
      'estimatedEarnings': instance.estimatedEarnings,
      'actualEarnings': instance.actualEarnings,
      'completedRides': instance.completedRides,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };

const _$ShiftStatusEnumMap = {
  ShiftStatus.scheduled: 'scheduled',
  ShiftStatus.active: 'active',
  ShiftStatus.completed: 'completed',
  ShiftStatus.cancelled: 'cancelled',
  ShiftStatus.missed: 'missed',
};

_$ShiftTemplateImpl _$$ShiftTemplateImplFromJson(Map<String, dynamic> json) =>
    _$ShiftTemplateImpl(
      id: json['id'] as String,
      driverId: json['driverId'] as String,
      name: json['name'] as String,
      startTime: json['startTime'] as String,
      endTime: json['endTime'] as String,
      workDays:
          (json['workDays'] as List<dynamic>).map((e) => e as String).toList(),
      isActive: json['isActive'] as bool? ?? true,
      notes: json['notes'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$ShiftTemplateImplToJson(_$ShiftTemplateImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'driverId': instance.driverId,
      'name': instance.name,
      'startTime': instance.startTime,
      'endTime': instance.endTime,
      'workDays': instance.workDays,
      'isActive': instance.isActive,
      'notes': instance.notes,
      'createdAt': instance.createdAt?.toIso8601String(),
    };
