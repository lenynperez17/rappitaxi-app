// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scheduled_ride.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ScheduledRideImpl _$$ScheduledRideImplFromJson(Map<String, dynamic> json) =>
    _$ScheduledRideImpl(
      id: json['id'] as String,
      passengerId: json['passengerId'] as String,
      driverId: json['driverId'] as String?,
      pickupLocation: json['pickupLocation'] as Map<String, dynamic>,
      dropoffLocation: json['dropoffLocation'] as Map<String, dynamic>,
      scheduledTime: DateTime.parse(json['scheduledTime'] as String),
      vehicleType: json['vehicleType'] as String,
      estimatedFare: (json['estimatedFare'] as num).toDouble(),
      status: $enumDecode(_$ScheduledRideStatusEnumMap, json['status']),
      paymentMethod: json['paymentMethod'] as String?,
      notes: json['notes'] as String?,
      cancelReason: json['cancelReason'] as String?,
      confirmedAt: json['confirmedAt'] == null
          ? null
          : DateTime.parse(json['confirmedAt'] as String),
      assignedAt: json['assignedAt'] == null
          ? null
          : DateTime.parse(json['assignedAt'] as String),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      cancelledAt: json['cancelledAt'] == null
          ? null
          : DateTime.parse(json['cancelledAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      isRecurring: json['isRecurring'] as bool? ?? false,
      recurrencePattern: json['recurrencePattern'] == null
          ? null
          : RecurrencePattern.fromJson(
              json['recurrencePattern'] as Map<String, dynamic>),
      reminderMinutesBefore:
          (json['reminderMinutesBefore'] as num?)?.toInt() ?? 30,
      allowAutoAssign: json['allowAutoAssign'] as bool? ?? false,
      searchRadiusMinutes: (json['searchRadiusMinutes'] as num?)?.toInt() ?? 60,
    );

Map<String, dynamic> _$$ScheduledRideImplToJson(_$ScheduledRideImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'passengerId': instance.passengerId,
      'driverId': instance.driverId,
      'pickupLocation': instance.pickupLocation,
      'dropoffLocation': instance.dropoffLocation,
      'scheduledTime': instance.scheduledTime.toIso8601String(),
      'vehicleType': instance.vehicleType,
      'estimatedFare': instance.estimatedFare,
      'status': _$ScheduledRideStatusEnumMap[instance.status]!,
      'paymentMethod': instance.paymentMethod,
      'notes': instance.notes,
      'cancelReason': instance.cancelReason,
      'confirmedAt': instance.confirmedAt?.toIso8601String(),
      'assignedAt': instance.assignedAt?.toIso8601String(),
      'completedAt': instance.completedAt?.toIso8601String(),
      'cancelledAt': instance.cancelledAt?.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
      'isRecurring': instance.isRecurring,
      'recurrencePattern': instance.recurrencePattern,
      'reminderMinutesBefore': instance.reminderMinutesBefore,
      'allowAutoAssign': instance.allowAutoAssign,
      'searchRadiusMinutes': instance.searchRadiusMinutes,
    };

const _$ScheduledRideStatusEnumMap = {
  ScheduledRideStatus.pending: 'pending',
  ScheduledRideStatus.confirmed: 'confirmed',
  ScheduledRideStatus.driverAssigned: 'driverAssigned',
  ScheduledRideStatus.inProgress: 'inProgress',
  ScheduledRideStatus.completed: 'completed',
  ScheduledRideStatus.cancelled: 'cancelled',
  ScheduledRideStatus.expired: 'expired',
  ScheduledRideStatus.failed: 'failed',
};

_$RecurrencePatternImpl _$$RecurrencePatternImplFromJson(
        Map<String, dynamic> json) =>
    _$RecurrencePatternImpl(
      type: $enumDecode(_$RecurrenceTypeEnumMap, json['type']),
      daysOfWeek: (json['daysOfWeek'] as List<dynamic>)
          .map((e) => (e as num).toInt())
          .toList(),
      interval: (json['interval'] as num?)?.toInt() ?? 1,
      endDate: json['endDate'] == null
          ? null
          : DateTime.parse(json['endDate'] as String),
      maxOccurrences: (json['maxOccurrences'] as num?)?.toInt() ?? 0,
      exceptions: (json['exceptions'] as List<dynamic>?)
              ?.map((e) => DateTime.parse(e as String))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$RecurrencePatternImplToJson(
        _$RecurrencePatternImpl instance) =>
    <String, dynamic>{
      'type': _$RecurrenceTypeEnumMap[instance.type]!,
      'daysOfWeek': instance.daysOfWeek,
      'interval': instance.interval,
      'endDate': instance.endDate?.toIso8601String(),
      'maxOccurrences': instance.maxOccurrences,
      'exceptions':
          instance.exceptions.map((e) => e.toIso8601String()).toList(),
    };

const _$RecurrenceTypeEnumMap = {
  RecurrenceType.none: 'none',
  RecurrenceType.daily: 'daily',
  RecurrenceType.weekly: 'weekly',
  RecurrenceType.monthly: 'monthly',
  RecurrenceType.weekdays: 'weekdays',
  RecurrenceType.custom: 'custom',
};

_$ScheduledRideConfigImpl _$$ScheduledRideConfigImplFromJson(
        Map<String, dynamic> json) =>
    _$ScheduledRideConfigImpl(
      enableScheduledRides: json['enableScheduledRides'] as bool? ?? true,
      minMinutesInAdvance: (json['minMinutesInAdvance'] as num?)?.toInt() ?? 30,
      maxMinutesInAdvance:
          (json['maxMinutesInAdvance'] as num?)?.toInt() ?? 10080,
      allowRecurring: json['allowRecurring'] as bool? ?? true,
      maxRecurringRides: (json['maxRecurringRides'] as num?)?.toInt() ?? 5,
      sendReminders: json['sendReminders'] as bool? ?? true,
      reminderIntervals: (json['reminderIntervals'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [30, 60],
      allowModification: json['allowModification'] as bool? ?? true,
      modificationDeadlineMinutes:
          (json['modificationDeadlineMinutes'] as num?)?.toInt() ?? 60,
      allowCancellation: json['allowCancellation'] as bool? ?? true,
      cancellationDeadlineMinutes:
          (json['cancellationDeadlineMinutes'] as num?)?.toInt() ?? 30,
      cancellationFeePercent:
          (json['cancellationFeePercent'] as num?)?.toDouble() ?? 0.1,
      priorityMatching: json['priorityMatching'] as bool? ?? true,
    );

Map<String, dynamic> _$$ScheduledRideConfigImplToJson(
        _$ScheduledRideConfigImpl instance) =>
    <String, dynamic>{
      'enableScheduledRides': instance.enableScheduledRides,
      'minMinutesInAdvance': instance.minMinutesInAdvance,
      'maxMinutesInAdvance': instance.maxMinutesInAdvance,
      'allowRecurring': instance.allowRecurring,
      'maxRecurringRides': instance.maxRecurringRides,
      'sendReminders': instance.sendReminders,
      'reminderIntervals': instance.reminderIntervals,
      'allowModification': instance.allowModification,
      'modificationDeadlineMinutes': instance.modificationDeadlineMinutes,
      'allowCancellation': instance.allowCancellation,
      'cancellationDeadlineMinutes': instance.cancellationDeadlineMinutes,
      'cancellationFeePercent': instance.cancellationFeePercent,
      'priorityMatching': instance.priorityMatching,
    };
