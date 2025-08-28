// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'scheduled_ride.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ScheduledRide _$ScheduledRideFromJson(Map<String, dynamic> json) {
  return _ScheduledRide.fromJson(json);
}

/// @nodoc
mixin _$ScheduledRide {
  String get id => throw _privateConstructorUsedError;
  String get passengerId => throw _privateConstructorUsedError;
  String? get driverId => throw _privateConstructorUsedError;
  Map<String, dynamic> get pickupLocation => throw _privateConstructorUsedError;
  Map<String, dynamic> get dropoffLocation =>
      throw _privateConstructorUsedError;
  DateTime get scheduledTime => throw _privateConstructorUsedError;
  String get vehicleType => throw _privateConstructorUsedError;
  double get estimatedFare => throw _privateConstructorUsedError;
  ScheduledRideStatus get status => throw _privateConstructorUsedError;
  String? get paymentMethod => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;
  String? get cancelReason => throw _privateConstructorUsedError;
  DateTime? get confirmedAt => throw _privateConstructorUsedError;
  DateTime? get assignedAt => throw _privateConstructorUsedError;
  DateTime? get completedAt => throw _privateConstructorUsedError;
  DateTime? get cancelledAt => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  bool get isRecurring => throw _privateConstructorUsedError;
  RecurrencePattern? get recurrencePattern =>
      throw _privateConstructorUsedError;
  int get reminderMinutesBefore => throw _privateConstructorUsedError;
  bool get allowAutoAssign => throw _privateConstructorUsedError;
  int get searchRadiusMinutes => throw _privateConstructorUsedError;

  /// Serializes this ScheduledRide to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ScheduledRide
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ScheduledRideCopyWith<ScheduledRide> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ScheduledRideCopyWith<$Res> {
  factory $ScheduledRideCopyWith(
          ScheduledRide value, $Res Function(ScheduledRide) then) =
      _$ScheduledRideCopyWithImpl<$Res, ScheduledRide>;
  @useResult
  $Res call(
      {String id,
      String passengerId,
      String? driverId,
      Map<String, dynamic> pickupLocation,
      Map<String, dynamic> dropoffLocation,
      DateTime scheduledTime,
      String vehicleType,
      double estimatedFare,
      ScheduledRideStatus status,
      String? paymentMethod,
      String? notes,
      String? cancelReason,
      DateTime? confirmedAt,
      DateTime? assignedAt,
      DateTime? completedAt,
      DateTime? cancelledAt,
      DateTime createdAt,
      bool isRecurring,
      RecurrencePattern? recurrencePattern,
      int reminderMinutesBefore,
      bool allowAutoAssign,
      int searchRadiusMinutes});

  $RecurrencePatternCopyWith<$Res>? get recurrencePattern;
}

/// @nodoc
class _$ScheduledRideCopyWithImpl<$Res, $Val extends ScheduledRide>
    implements $ScheduledRideCopyWith<$Res> {
  _$ScheduledRideCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ScheduledRide
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? passengerId = null,
    Object? driverId = freezed,
    Object? pickupLocation = null,
    Object? dropoffLocation = null,
    Object? scheduledTime = null,
    Object? vehicleType = null,
    Object? estimatedFare = null,
    Object? status = null,
    Object? paymentMethod = freezed,
    Object? notes = freezed,
    Object? cancelReason = freezed,
    Object? confirmedAt = freezed,
    Object? assignedAt = freezed,
    Object? completedAt = freezed,
    Object? cancelledAt = freezed,
    Object? createdAt = null,
    Object? isRecurring = null,
    Object? recurrencePattern = freezed,
    Object? reminderMinutesBefore = null,
    Object? allowAutoAssign = null,
    Object? searchRadiusMinutes = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      passengerId: null == passengerId
          ? _value.passengerId
          : passengerId // ignore: cast_nullable_to_non_nullable
              as String,
      driverId: freezed == driverId
          ? _value.driverId
          : driverId // ignore: cast_nullable_to_non_nullable
              as String?,
      pickupLocation: null == pickupLocation
          ? _value.pickupLocation
          : pickupLocation // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      dropoffLocation: null == dropoffLocation
          ? _value.dropoffLocation
          : dropoffLocation // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      scheduledTime: null == scheduledTime
          ? _value.scheduledTime
          : scheduledTime // ignore: cast_nullable_to_non_nullable
              as DateTime,
      vehicleType: null == vehicleType
          ? _value.vehicleType
          : vehicleType // ignore: cast_nullable_to_non_nullable
              as String,
      estimatedFare: null == estimatedFare
          ? _value.estimatedFare
          : estimatedFare // ignore: cast_nullable_to_non_nullable
              as double,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as ScheduledRideStatus,
      paymentMethod: freezed == paymentMethod
          ? _value.paymentMethod
          : paymentMethod // ignore: cast_nullable_to_non_nullable
              as String?,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
      cancelReason: freezed == cancelReason
          ? _value.cancelReason
          : cancelReason // ignore: cast_nullable_to_non_nullable
              as String?,
      confirmedAt: freezed == confirmedAt
          ? _value.confirmedAt
          : confirmedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      assignedAt: freezed == assignedAt
          ? _value.assignedAt
          : assignedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      completedAt: freezed == completedAt
          ? _value.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      cancelledAt: freezed == cancelledAt
          ? _value.cancelledAt
          : cancelledAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      isRecurring: null == isRecurring
          ? _value.isRecurring
          : isRecurring // ignore: cast_nullable_to_non_nullable
              as bool,
      recurrencePattern: freezed == recurrencePattern
          ? _value.recurrencePattern
          : recurrencePattern // ignore: cast_nullable_to_non_nullable
              as RecurrencePattern?,
      reminderMinutesBefore: null == reminderMinutesBefore
          ? _value.reminderMinutesBefore
          : reminderMinutesBefore // ignore: cast_nullable_to_non_nullable
              as int,
      allowAutoAssign: null == allowAutoAssign
          ? _value.allowAutoAssign
          : allowAutoAssign // ignore: cast_nullable_to_non_nullable
              as bool,
      searchRadiusMinutes: null == searchRadiusMinutes
          ? _value.searchRadiusMinutes
          : searchRadiusMinutes // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }

  /// Create a copy of ScheduledRide
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $RecurrencePatternCopyWith<$Res>? get recurrencePattern {
    if (_value.recurrencePattern == null) {
      return null;
    }

    return $RecurrencePatternCopyWith<$Res>(_value.recurrencePattern!, (value) {
      return _then(_value.copyWith(recurrencePattern: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ScheduledRideImplCopyWith<$Res>
    implements $ScheduledRideCopyWith<$Res> {
  factory _$$ScheduledRideImplCopyWith(
          _$ScheduledRideImpl value, $Res Function(_$ScheduledRideImpl) then) =
      __$$ScheduledRideImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String passengerId,
      String? driverId,
      Map<String, dynamic> pickupLocation,
      Map<String, dynamic> dropoffLocation,
      DateTime scheduledTime,
      String vehicleType,
      double estimatedFare,
      ScheduledRideStatus status,
      String? paymentMethod,
      String? notes,
      String? cancelReason,
      DateTime? confirmedAt,
      DateTime? assignedAt,
      DateTime? completedAt,
      DateTime? cancelledAt,
      DateTime createdAt,
      bool isRecurring,
      RecurrencePattern? recurrencePattern,
      int reminderMinutesBefore,
      bool allowAutoAssign,
      int searchRadiusMinutes});

  @override
  $RecurrencePatternCopyWith<$Res>? get recurrencePattern;
}

/// @nodoc
class __$$ScheduledRideImplCopyWithImpl<$Res>
    extends _$ScheduledRideCopyWithImpl<$Res, _$ScheduledRideImpl>
    implements _$$ScheduledRideImplCopyWith<$Res> {
  __$$ScheduledRideImplCopyWithImpl(
      _$ScheduledRideImpl _value, $Res Function(_$ScheduledRideImpl) _then)
      : super(_value, _then);

  /// Create a copy of ScheduledRide
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? passengerId = null,
    Object? driverId = freezed,
    Object? pickupLocation = null,
    Object? dropoffLocation = null,
    Object? scheduledTime = null,
    Object? vehicleType = null,
    Object? estimatedFare = null,
    Object? status = null,
    Object? paymentMethod = freezed,
    Object? notes = freezed,
    Object? cancelReason = freezed,
    Object? confirmedAt = freezed,
    Object? assignedAt = freezed,
    Object? completedAt = freezed,
    Object? cancelledAt = freezed,
    Object? createdAt = null,
    Object? isRecurring = null,
    Object? recurrencePattern = freezed,
    Object? reminderMinutesBefore = null,
    Object? allowAutoAssign = null,
    Object? searchRadiusMinutes = null,
  }) {
    return _then(_$ScheduledRideImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      passengerId: null == passengerId
          ? _value.passengerId
          : passengerId // ignore: cast_nullable_to_non_nullable
              as String,
      driverId: freezed == driverId
          ? _value.driverId
          : driverId // ignore: cast_nullable_to_non_nullable
              as String?,
      pickupLocation: null == pickupLocation
          ? _value._pickupLocation
          : pickupLocation // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      dropoffLocation: null == dropoffLocation
          ? _value._dropoffLocation
          : dropoffLocation // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      scheduledTime: null == scheduledTime
          ? _value.scheduledTime
          : scheduledTime // ignore: cast_nullable_to_non_nullable
              as DateTime,
      vehicleType: null == vehicleType
          ? _value.vehicleType
          : vehicleType // ignore: cast_nullable_to_non_nullable
              as String,
      estimatedFare: null == estimatedFare
          ? _value.estimatedFare
          : estimatedFare // ignore: cast_nullable_to_non_nullable
              as double,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as ScheduledRideStatus,
      paymentMethod: freezed == paymentMethod
          ? _value.paymentMethod
          : paymentMethod // ignore: cast_nullable_to_non_nullable
              as String?,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
      cancelReason: freezed == cancelReason
          ? _value.cancelReason
          : cancelReason // ignore: cast_nullable_to_non_nullable
              as String?,
      confirmedAt: freezed == confirmedAt
          ? _value.confirmedAt
          : confirmedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      assignedAt: freezed == assignedAt
          ? _value.assignedAt
          : assignedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      completedAt: freezed == completedAt
          ? _value.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      cancelledAt: freezed == cancelledAt
          ? _value.cancelledAt
          : cancelledAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      isRecurring: null == isRecurring
          ? _value.isRecurring
          : isRecurring // ignore: cast_nullable_to_non_nullable
              as bool,
      recurrencePattern: freezed == recurrencePattern
          ? _value.recurrencePattern
          : recurrencePattern // ignore: cast_nullable_to_non_nullable
              as RecurrencePattern?,
      reminderMinutesBefore: null == reminderMinutesBefore
          ? _value.reminderMinutesBefore
          : reminderMinutesBefore // ignore: cast_nullable_to_non_nullable
              as int,
      allowAutoAssign: null == allowAutoAssign
          ? _value.allowAutoAssign
          : allowAutoAssign // ignore: cast_nullable_to_non_nullable
              as bool,
      searchRadiusMinutes: null == searchRadiusMinutes
          ? _value.searchRadiusMinutes
          : searchRadiusMinutes // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ScheduledRideImpl implements _ScheduledRide {
  const _$ScheduledRideImpl(
      {required this.id,
      required this.passengerId,
      this.driverId,
      required final Map<String, dynamic> pickupLocation,
      required final Map<String, dynamic> dropoffLocation,
      required this.scheduledTime,
      required this.vehicleType,
      required this.estimatedFare,
      required this.status,
      this.paymentMethod,
      this.notes,
      this.cancelReason,
      this.confirmedAt,
      this.assignedAt,
      this.completedAt,
      this.cancelledAt,
      required this.createdAt,
      this.isRecurring = false,
      this.recurrencePattern,
      this.reminderMinutesBefore = 30,
      this.allowAutoAssign = false,
      this.searchRadiusMinutes = 60})
      : _pickupLocation = pickupLocation,
        _dropoffLocation = dropoffLocation;

  factory _$ScheduledRideImpl.fromJson(Map<String, dynamic> json) =>
      _$$ScheduledRideImplFromJson(json);

  @override
  final String id;
  @override
  final String passengerId;
  @override
  final String? driverId;
  final Map<String, dynamic> _pickupLocation;
  @override
  Map<String, dynamic> get pickupLocation {
    if (_pickupLocation is EqualUnmodifiableMapView) return _pickupLocation;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_pickupLocation);
  }

  final Map<String, dynamic> _dropoffLocation;
  @override
  Map<String, dynamic> get dropoffLocation {
    if (_dropoffLocation is EqualUnmodifiableMapView) return _dropoffLocation;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_dropoffLocation);
  }

  @override
  final DateTime scheduledTime;
  @override
  final String vehicleType;
  @override
  final double estimatedFare;
  @override
  final ScheduledRideStatus status;
  @override
  final String? paymentMethod;
  @override
  final String? notes;
  @override
  final String? cancelReason;
  @override
  final DateTime? confirmedAt;
  @override
  final DateTime? assignedAt;
  @override
  final DateTime? completedAt;
  @override
  final DateTime? cancelledAt;
  @override
  final DateTime createdAt;
  @override
  @JsonKey()
  final bool isRecurring;
  @override
  final RecurrencePattern? recurrencePattern;
  @override
  @JsonKey()
  final int reminderMinutesBefore;
  @override
  @JsonKey()
  final bool allowAutoAssign;
  @override
  @JsonKey()
  final int searchRadiusMinutes;

  @override
  String toString() {
    return 'ScheduledRide(id: $id, passengerId: $passengerId, driverId: $driverId, pickupLocation: $pickupLocation, dropoffLocation: $dropoffLocation, scheduledTime: $scheduledTime, vehicleType: $vehicleType, estimatedFare: $estimatedFare, status: $status, paymentMethod: $paymentMethod, notes: $notes, cancelReason: $cancelReason, confirmedAt: $confirmedAt, assignedAt: $assignedAt, completedAt: $completedAt, cancelledAt: $cancelledAt, createdAt: $createdAt, isRecurring: $isRecurring, recurrencePattern: $recurrencePattern, reminderMinutesBefore: $reminderMinutesBefore, allowAutoAssign: $allowAutoAssign, searchRadiusMinutes: $searchRadiusMinutes)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ScheduledRideImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.passengerId, passengerId) ||
                other.passengerId == passengerId) &&
            (identical(other.driverId, driverId) ||
                other.driverId == driverId) &&
            const DeepCollectionEquality()
                .equals(other._pickupLocation, _pickupLocation) &&
            const DeepCollectionEquality()
                .equals(other._dropoffLocation, _dropoffLocation) &&
            (identical(other.scheduledTime, scheduledTime) ||
                other.scheduledTime == scheduledTime) &&
            (identical(other.vehicleType, vehicleType) ||
                other.vehicleType == vehicleType) &&
            (identical(other.estimatedFare, estimatedFare) ||
                other.estimatedFare == estimatedFare) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.paymentMethod, paymentMethod) ||
                other.paymentMethod == paymentMethod) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.cancelReason, cancelReason) ||
                other.cancelReason == cancelReason) &&
            (identical(other.confirmedAt, confirmedAt) ||
                other.confirmedAt == confirmedAt) &&
            (identical(other.assignedAt, assignedAt) ||
                other.assignedAt == assignedAt) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt) &&
            (identical(other.cancelledAt, cancelledAt) ||
                other.cancelledAt == cancelledAt) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.isRecurring, isRecurring) ||
                other.isRecurring == isRecurring) &&
            (identical(other.recurrencePattern, recurrencePattern) ||
                other.recurrencePattern == recurrencePattern) &&
            (identical(other.reminderMinutesBefore, reminderMinutesBefore) ||
                other.reminderMinutesBefore == reminderMinutesBefore) &&
            (identical(other.allowAutoAssign, allowAutoAssign) ||
                other.allowAutoAssign == allowAutoAssign) &&
            (identical(other.searchRadiusMinutes, searchRadiusMinutes) ||
                other.searchRadiusMinutes == searchRadiusMinutes));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        passengerId,
        driverId,
        const DeepCollectionEquality().hash(_pickupLocation),
        const DeepCollectionEquality().hash(_dropoffLocation),
        scheduledTime,
        vehicleType,
        estimatedFare,
        status,
        paymentMethod,
        notes,
        cancelReason,
        confirmedAt,
        assignedAt,
        completedAt,
        cancelledAt,
        createdAt,
        isRecurring,
        recurrencePattern,
        reminderMinutesBefore,
        allowAutoAssign,
        searchRadiusMinutes
      ]);

  /// Create a copy of ScheduledRide
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ScheduledRideImplCopyWith<_$ScheduledRideImpl> get copyWith =>
      __$$ScheduledRideImplCopyWithImpl<_$ScheduledRideImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ScheduledRideImplToJson(
      this,
    );
  }
}

abstract class _ScheduledRide implements ScheduledRide {
  const factory _ScheduledRide(
      {required final String id,
      required final String passengerId,
      final String? driverId,
      required final Map<String, dynamic> pickupLocation,
      required final Map<String, dynamic> dropoffLocation,
      required final DateTime scheduledTime,
      required final String vehicleType,
      required final double estimatedFare,
      required final ScheduledRideStatus status,
      final String? paymentMethod,
      final String? notes,
      final String? cancelReason,
      final DateTime? confirmedAt,
      final DateTime? assignedAt,
      final DateTime? completedAt,
      final DateTime? cancelledAt,
      required final DateTime createdAt,
      final bool isRecurring,
      final RecurrencePattern? recurrencePattern,
      final int reminderMinutesBefore,
      final bool allowAutoAssign,
      final int searchRadiusMinutes}) = _$ScheduledRideImpl;

  factory _ScheduledRide.fromJson(Map<String, dynamic> json) =
      _$ScheduledRideImpl.fromJson;

  @override
  String get id;
  @override
  String get passengerId;
  @override
  String? get driverId;
  @override
  Map<String, dynamic> get pickupLocation;
  @override
  Map<String, dynamic> get dropoffLocation;
  @override
  DateTime get scheduledTime;
  @override
  String get vehicleType;
  @override
  double get estimatedFare;
  @override
  ScheduledRideStatus get status;
  @override
  String? get paymentMethod;
  @override
  String? get notes;
  @override
  String? get cancelReason;
  @override
  DateTime? get confirmedAt;
  @override
  DateTime? get assignedAt;
  @override
  DateTime? get completedAt;
  @override
  DateTime? get cancelledAt;
  @override
  DateTime get createdAt;
  @override
  bool get isRecurring;
  @override
  RecurrencePattern? get recurrencePattern;
  @override
  int get reminderMinutesBefore;
  @override
  bool get allowAutoAssign;
  @override
  int get searchRadiusMinutes;

  /// Create a copy of ScheduledRide
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ScheduledRideImplCopyWith<_$ScheduledRideImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

RecurrencePattern _$RecurrencePatternFromJson(Map<String, dynamic> json) {
  return _RecurrencePattern.fromJson(json);
}

/// @nodoc
mixin _$RecurrencePattern {
  RecurrenceType get type => throw _privateConstructorUsedError;
  List<int> get daysOfWeek =>
      throw _privateConstructorUsedError; // 1=Lunes, 7=Domingo
  int get interval =>
      throw _privateConstructorUsedError; // Cada N días/semanas/meses
  DateTime? get endDate => throw _privateConstructorUsedError;
  int get maxOccurrences => throw _privateConstructorUsedError;
  List<DateTime> get exceptions => throw _privateConstructorUsedError;

  /// Serializes this RecurrencePattern to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RecurrencePattern
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RecurrencePatternCopyWith<RecurrencePattern> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RecurrencePatternCopyWith<$Res> {
  factory $RecurrencePatternCopyWith(
          RecurrencePattern value, $Res Function(RecurrencePattern) then) =
      _$RecurrencePatternCopyWithImpl<$Res, RecurrencePattern>;
  @useResult
  $Res call(
      {RecurrenceType type,
      List<int> daysOfWeek,
      int interval,
      DateTime? endDate,
      int maxOccurrences,
      List<DateTime> exceptions});
}

/// @nodoc
class _$RecurrencePatternCopyWithImpl<$Res, $Val extends RecurrencePattern>
    implements $RecurrencePatternCopyWith<$Res> {
  _$RecurrencePatternCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RecurrencePattern
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? daysOfWeek = null,
    Object? interval = null,
    Object? endDate = freezed,
    Object? maxOccurrences = null,
    Object? exceptions = null,
  }) {
    return _then(_value.copyWith(
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as RecurrenceType,
      daysOfWeek: null == daysOfWeek
          ? _value.daysOfWeek
          : daysOfWeek // ignore: cast_nullable_to_non_nullable
              as List<int>,
      interval: null == interval
          ? _value.interval
          : interval // ignore: cast_nullable_to_non_nullable
              as int,
      endDate: freezed == endDate
          ? _value.endDate
          : endDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      maxOccurrences: null == maxOccurrences
          ? _value.maxOccurrences
          : maxOccurrences // ignore: cast_nullable_to_non_nullable
              as int,
      exceptions: null == exceptions
          ? _value.exceptions
          : exceptions // ignore: cast_nullable_to_non_nullable
              as List<DateTime>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$RecurrencePatternImplCopyWith<$Res>
    implements $RecurrencePatternCopyWith<$Res> {
  factory _$$RecurrencePatternImplCopyWith(_$RecurrencePatternImpl value,
          $Res Function(_$RecurrencePatternImpl) then) =
      __$$RecurrencePatternImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {RecurrenceType type,
      List<int> daysOfWeek,
      int interval,
      DateTime? endDate,
      int maxOccurrences,
      List<DateTime> exceptions});
}

/// @nodoc
class __$$RecurrencePatternImplCopyWithImpl<$Res>
    extends _$RecurrencePatternCopyWithImpl<$Res, _$RecurrencePatternImpl>
    implements _$$RecurrencePatternImplCopyWith<$Res> {
  __$$RecurrencePatternImplCopyWithImpl(_$RecurrencePatternImpl _value,
      $Res Function(_$RecurrencePatternImpl) _then)
      : super(_value, _then);

  /// Create a copy of RecurrencePattern
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? daysOfWeek = null,
    Object? interval = null,
    Object? endDate = freezed,
    Object? maxOccurrences = null,
    Object? exceptions = null,
  }) {
    return _then(_$RecurrencePatternImpl(
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as RecurrenceType,
      daysOfWeek: null == daysOfWeek
          ? _value._daysOfWeek
          : daysOfWeek // ignore: cast_nullable_to_non_nullable
              as List<int>,
      interval: null == interval
          ? _value.interval
          : interval // ignore: cast_nullable_to_non_nullable
              as int,
      endDate: freezed == endDate
          ? _value.endDate
          : endDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      maxOccurrences: null == maxOccurrences
          ? _value.maxOccurrences
          : maxOccurrences // ignore: cast_nullable_to_non_nullable
              as int,
      exceptions: null == exceptions
          ? _value._exceptions
          : exceptions // ignore: cast_nullable_to_non_nullable
              as List<DateTime>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$RecurrencePatternImpl implements _RecurrencePattern {
  const _$RecurrencePatternImpl(
      {required this.type,
      required final List<int> daysOfWeek,
      this.interval = 1,
      this.endDate,
      this.maxOccurrences = 0,
      final List<DateTime> exceptions = const []})
      : _daysOfWeek = daysOfWeek,
        _exceptions = exceptions;

  factory _$RecurrencePatternImpl.fromJson(Map<String, dynamic> json) =>
      _$$RecurrencePatternImplFromJson(json);

  @override
  final RecurrenceType type;
  final List<int> _daysOfWeek;
  @override
  List<int> get daysOfWeek {
    if (_daysOfWeek is EqualUnmodifiableListView) return _daysOfWeek;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_daysOfWeek);
  }

// 1=Lunes, 7=Domingo
  @override
  @JsonKey()
  final int interval;
// Cada N días/semanas/meses
  @override
  final DateTime? endDate;
  @override
  @JsonKey()
  final int maxOccurrences;
  final List<DateTime> _exceptions;
  @override
  @JsonKey()
  List<DateTime> get exceptions {
    if (_exceptions is EqualUnmodifiableListView) return _exceptions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_exceptions);
  }

  @override
  String toString() {
    return 'RecurrencePattern(type: $type, daysOfWeek: $daysOfWeek, interval: $interval, endDate: $endDate, maxOccurrences: $maxOccurrences, exceptions: $exceptions)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RecurrencePatternImpl &&
            (identical(other.type, type) || other.type == type) &&
            const DeepCollectionEquality()
                .equals(other._daysOfWeek, _daysOfWeek) &&
            (identical(other.interval, interval) ||
                other.interval == interval) &&
            (identical(other.endDate, endDate) || other.endDate == endDate) &&
            (identical(other.maxOccurrences, maxOccurrences) ||
                other.maxOccurrences == maxOccurrences) &&
            const DeepCollectionEquality()
                .equals(other._exceptions, _exceptions));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      type,
      const DeepCollectionEquality().hash(_daysOfWeek),
      interval,
      endDate,
      maxOccurrences,
      const DeepCollectionEquality().hash(_exceptions));

  /// Create a copy of RecurrencePattern
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RecurrencePatternImplCopyWith<_$RecurrencePatternImpl> get copyWith =>
      __$$RecurrencePatternImplCopyWithImpl<_$RecurrencePatternImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$RecurrencePatternImplToJson(
      this,
    );
  }
}

abstract class _RecurrencePattern implements RecurrencePattern {
  const factory _RecurrencePattern(
      {required final RecurrenceType type,
      required final List<int> daysOfWeek,
      final int interval,
      final DateTime? endDate,
      final int maxOccurrences,
      final List<DateTime> exceptions}) = _$RecurrencePatternImpl;

  factory _RecurrencePattern.fromJson(Map<String, dynamic> json) =
      _$RecurrencePatternImpl.fromJson;

  @override
  RecurrenceType get type;
  @override
  List<int> get daysOfWeek; // 1=Lunes, 7=Domingo
  @override
  int get interval; // Cada N días/semanas/meses
  @override
  DateTime? get endDate;
  @override
  int get maxOccurrences;
  @override
  List<DateTime> get exceptions;

  /// Create a copy of RecurrencePattern
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RecurrencePatternImplCopyWith<_$RecurrencePatternImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ScheduledRideConfig _$ScheduledRideConfigFromJson(Map<String, dynamic> json) {
  return _ScheduledRideConfig.fromJson(json);
}

/// @nodoc
mixin _$ScheduledRideConfig {
  bool get enableScheduledRides => throw _privateConstructorUsedError;
  int get minMinutesInAdvance =>
      throw _privateConstructorUsedError; // Mínimo 30 minutos antes
  int get maxMinutesInAdvance =>
      throw _privateConstructorUsedError; // Máximo 7 días antes (7*24*60)
  bool get allowRecurring => throw _privateConstructorUsedError;
  int get maxRecurringRides => throw _privateConstructorUsedError;
  bool get sendReminders => throw _privateConstructorUsedError;
  List<int> get reminderIntervals =>
      throw _privateConstructorUsedError; // Minutos antes
  bool get allowModification => throw _privateConstructorUsedError;
  int get modificationDeadlineMinutes =>
      throw _privateConstructorUsedError; // No modificar 1 hora antes
  bool get allowCancellation => throw _privateConstructorUsedError;
  int get cancellationDeadlineMinutes => throw _privateConstructorUsedError;
  double get cancellationFeePercent =>
      throw _privateConstructorUsedError; // 10% de penalización
  bool get priorityMatching => throw _privateConstructorUsedError;

  /// Serializes this ScheduledRideConfig to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ScheduledRideConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ScheduledRideConfigCopyWith<ScheduledRideConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ScheduledRideConfigCopyWith<$Res> {
  factory $ScheduledRideConfigCopyWith(
          ScheduledRideConfig value, $Res Function(ScheduledRideConfig) then) =
      _$ScheduledRideConfigCopyWithImpl<$Res, ScheduledRideConfig>;
  @useResult
  $Res call(
      {bool enableScheduledRides,
      int minMinutesInAdvance,
      int maxMinutesInAdvance,
      bool allowRecurring,
      int maxRecurringRides,
      bool sendReminders,
      List<int> reminderIntervals,
      bool allowModification,
      int modificationDeadlineMinutes,
      bool allowCancellation,
      int cancellationDeadlineMinutes,
      double cancellationFeePercent,
      bool priorityMatching});
}

/// @nodoc
class _$ScheduledRideConfigCopyWithImpl<$Res, $Val extends ScheduledRideConfig>
    implements $ScheduledRideConfigCopyWith<$Res> {
  _$ScheduledRideConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ScheduledRideConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? enableScheduledRides = null,
    Object? minMinutesInAdvance = null,
    Object? maxMinutesInAdvance = null,
    Object? allowRecurring = null,
    Object? maxRecurringRides = null,
    Object? sendReminders = null,
    Object? reminderIntervals = null,
    Object? allowModification = null,
    Object? modificationDeadlineMinutes = null,
    Object? allowCancellation = null,
    Object? cancellationDeadlineMinutes = null,
    Object? cancellationFeePercent = null,
    Object? priorityMatching = null,
  }) {
    return _then(_value.copyWith(
      enableScheduledRides: null == enableScheduledRides
          ? _value.enableScheduledRides
          : enableScheduledRides // ignore: cast_nullable_to_non_nullable
              as bool,
      minMinutesInAdvance: null == minMinutesInAdvance
          ? _value.minMinutesInAdvance
          : minMinutesInAdvance // ignore: cast_nullable_to_non_nullable
              as int,
      maxMinutesInAdvance: null == maxMinutesInAdvance
          ? _value.maxMinutesInAdvance
          : maxMinutesInAdvance // ignore: cast_nullable_to_non_nullable
              as int,
      allowRecurring: null == allowRecurring
          ? _value.allowRecurring
          : allowRecurring // ignore: cast_nullable_to_non_nullable
              as bool,
      maxRecurringRides: null == maxRecurringRides
          ? _value.maxRecurringRides
          : maxRecurringRides // ignore: cast_nullable_to_non_nullable
              as int,
      sendReminders: null == sendReminders
          ? _value.sendReminders
          : sendReminders // ignore: cast_nullable_to_non_nullable
              as bool,
      reminderIntervals: null == reminderIntervals
          ? _value.reminderIntervals
          : reminderIntervals // ignore: cast_nullable_to_non_nullable
              as List<int>,
      allowModification: null == allowModification
          ? _value.allowModification
          : allowModification // ignore: cast_nullable_to_non_nullable
              as bool,
      modificationDeadlineMinutes: null == modificationDeadlineMinutes
          ? _value.modificationDeadlineMinutes
          : modificationDeadlineMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      allowCancellation: null == allowCancellation
          ? _value.allowCancellation
          : allowCancellation // ignore: cast_nullable_to_non_nullable
              as bool,
      cancellationDeadlineMinutes: null == cancellationDeadlineMinutes
          ? _value.cancellationDeadlineMinutes
          : cancellationDeadlineMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      cancellationFeePercent: null == cancellationFeePercent
          ? _value.cancellationFeePercent
          : cancellationFeePercent // ignore: cast_nullable_to_non_nullable
              as double,
      priorityMatching: null == priorityMatching
          ? _value.priorityMatching
          : priorityMatching // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ScheduledRideConfigImplCopyWith<$Res>
    implements $ScheduledRideConfigCopyWith<$Res> {
  factory _$$ScheduledRideConfigImplCopyWith(_$ScheduledRideConfigImpl value,
          $Res Function(_$ScheduledRideConfigImpl) then) =
      __$$ScheduledRideConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool enableScheduledRides,
      int minMinutesInAdvance,
      int maxMinutesInAdvance,
      bool allowRecurring,
      int maxRecurringRides,
      bool sendReminders,
      List<int> reminderIntervals,
      bool allowModification,
      int modificationDeadlineMinutes,
      bool allowCancellation,
      int cancellationDeadlineMinutes,
      double cancellationFeePercent,
      bool priorityMatching});
}

/// @nodoc
class __$$ScheduledRideConfigImplCopyWithImpl<$Res>
    extends _$ScheduledRideConfigCopyWithImpl<$Res, _$ScheduledRideConfigImpl>
    implements _$$ScheduledRideConfigImplCopyWith<$Res> {
  __$$ScheduledRideConfigImplCopyWithImpl(_$ScheduledRideConfigImpl _value,
      $Res Function(_$ScheduledRideConfigImpl) _then)
      : super(_value, _then);

  /// Create a copy of ScheduledRideConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? enableScheduledRides = null,
    Object? minMinutesInAdvance = null,
    Object? maxMinutesInAdvance = null,
    Object? allowRecurring = null,
    Object? maxRecurringRides = null,
    Object? sendReminders = null,
    Object? reminderIntervals = null,
    Object? allowModification = null,
    Object? modificationDeadlineMinutes = null,
    Object? allowCancellation = null,
    Object? cancellationDeadlineMinutes = null,
    Object? cancellationFeePercent = null,
    Object? priorityMatching = null,
  }) {
    return _then(_$ScheduledRideConfigImpl(
      enableScheduledRides: null == enableScheduledRides
          ? _value.enableScheduledRides
          : enableScheduledRides // ignore: cast_nullable_to_non_nullable
              as bool,
      minMinutesInAdvance: null == minMinutesInAdvance
          ? _value.minMinutesInAdvance
          : minMinutesInAdvance // ignore: cast_nullable_to_non_nullable
              as int,
      maxMinutesInAdvance: null == maxMinutesInAdvance
          ? _value.maxMinutesInAdvance
          : maxMinutesInAdvance // ignore: cast_nullable_to_non_nullable
              as int,
      allowRecurring: null == allowRecurring
          ? _value.allowRecurring
          : allowRecurring // ignore: cast_nullable_to_non_nullable
              as bool,
      maxRecurringRides: null == maxRecurringRides
          ? _value.maxRecurringRides
          : maxRecurringRides // ignore: cast_nullable_to_non_nullable
              as int,
      sendReminders: null == sendReminders
          ? _value.sendReminders
          : sendReminders // ignore: cast_nullable_to_non_nullable
              as bool,
      reminderIntervals: null == reminderIntervals
          ? _value._reminderIntervals
          : reminderIntervals // ignore: cast_nullable_to_non_nullable
              as List<int>,
      allowModification: null == allowModification
          ? _value.allowModification
          : allowModification // ignore: cast_nullable_to_non_nullable
              as bool,
      modificationDeadlineMinutes: null == modificationDeadlineMinutes
          ? _value.modificationDeadlineMinutes
          : modificationDeadlineMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      allowCancellation: null == allowCancellation
          ? _value.allowCancellation
          : allowCancellation // ignore: cast_nullable_to_non_nullable
              as bool,
      cancellationDeadlineMinutes: null == cancellationDeadlineMinutes
          ? _value.cancellationDeadlineMinutes
          : cancellationDeadlineMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      cancellationFeePercent: null == cancellationFeePercent
          ? _value.cancellationFeePercent
          : cancellationFeePercent // ignore: cast_nullable_to_non_nullable
              as double,
      priorityMatching: null == priorityMatching
          ? _value.priorityMatching
          : priorityMatching // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ScheduledRideConfigImpl implements _ScheduledRideConfig {
  const _$ScheduledRideConfigImpl(
      {this.enableScheduledRides = true,
      this.minMinutesInAdvance = 30,
      this.maxMinutesInAdvance = 10080,
      this.allowRecurring = true,
      this.maxRecurringRides = 5,
      this.sendReminders = true,
      final List<int> reminderIntervals = const [30, 60],
      this.allowModification = true,
      this.modificationDeadlineMinutes = 60,
      this.allowCancellation = true,
      this.cancellationDeadlineMinutes = 30,
      this.cancellationFeePercent = 0.1,
      this.priorityMatching = true})
      : _reminderIntervals = reminderIntervals;

  factory _$ScheduledRideConfigImpl.fromJson(Map<String, dynamic> json) =>
      _$$ScheduledRideConfigImplFromJson(json);

  @override
  @JsonKey()
  final bool enableScheduledRides;
  @override
  @JsonKey()
  final int minMinutesInAdvance;
// Mínimo 30 minutos antes
  @override
  @JsonKey()
  final int maxMinutesInAdvance;
// Máximo 7 días antes (7*24*60)
  @override
  @JsonKey()
  final bool allowRecurring;
  @override
  @JsonKey()
  final int maxRecurringRides;
  @override
  @JsonKey()
  final bool sendReminders;
  final List<int> _reminderIntervals;
  @override
  @JsonKey()
  List<int> get reminderIntervals {
    if (_reminderIntervals is EqualUnmodifiableListView)
      return _reminderIntervals;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_reminderIntervals);
  }

// Minutos antes
  @override
  @JsonKey()
  final bool allowModification;
  @override
  @JsonKey()
  final int modificationDeadlineMinutes;
// No modificar 1 hora antes
  @override
  @JsonKey()
  final bool allowCancellation;
  @override
  @JsonKey()
  final int cancellationDeadlineMinutes;
  @override
  @JsonKey()
  final double cancellationFeePercent;
// 10% de penalización
  @override
  @JsonKey()
  final bool priorityMatching;

  @override
  String toString() {
    return 'ScheduledRideConfig(enableScheduledRides: $enableScheduledRides, minMinutesInAdvance: $minMinutesInAdvance, maxMinutesInAdvance: $maxMinutesInAdvance, allowRecurring: $allowRecurring, maxRecurringRides: $maxRecurringRides, sendReminders: $sendReminders, reminderIntervals: $reminderIntervals, allowModification: $allowModification, modificationDeadlineMinutes: $modificationDeadlineMinutes, allowCancellation: $allowCancellation, cancellationDeadlineMinutes: $cancellationDeadlineMinutes, cancellationFeePercent: $cancellationFeePercent, priorityMatching: $priorityMatching)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ScheduledRideConfigImpl &&
            (identical(other.enableScheduledRides, enableScheduledRides) ||
                other.enableScheduledRides == enableScheduledRides) &&
            (identical(other.minMinutesInAdvance, minMinutesInAdvance) ||
                other.minMinutesInAdvance == minMinutesInAdvance) &&
            (identical(other.maxMinutesInAdvance, maxMinutesInAdvance) ||
                other.maxMinutesInAdvance == maxMinutesInAdvance) &&
            (identical(other.allowRecurring, allowRecurring) ||
                other.allowRecurring == allowRecurring) &&
            (identical(other.maxRecurringRides, maxRecurringRides) ||
                other.maxRecurringRides == maxRecurringRides) &&
            (identical(other.sendReminders, sendReminders) ||
                other.sendReminders == sendReminders) &&
            const DeepCollectionEquality()
                .equals(other._reminderIntervals, _reminderIntervals) &&
            (identical(other.allowModification, allowModification) ||
                other.allowModification == allowModification) &&
            (identical(other.modificationDeadlineMinutes,
                    modificationDeadlineMinutes) ||
                other.modificationDeadlineMinutes ==
                    modificationDeadlineMinutes) &&
            (identical(other.allowCancellation, allowCancellation) ||
                other.allowCancellation == allowCancellation) &&
            (identical(other.cancellationDeadlineMinutes,
                    cancellationDeadlineMinutes) ||
                other.cancellationDeadlineMinutes ==
                    cancellationDeadlineMinutes) &&
            (identical(other.cancellationFeePercent, cancellationFeePercent) ||
                other.cancellationFeePercent == cancellationFeePercent) &&
            (identical(other.priorityMatching, priorityMatching) ||
                other.priorityMatching == priorityMatching));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      enableScheduledRides,
      minMinutesInAdvance,
      maxMinutesInAdvance,
      allowRecurring,
      maxRecurringRides,
      sendReminders,
      const DeepCollectionEquality().hash(_reminderIntervals),
      allowModification,
      modificationDeadlineMinutes,
      allowCancellation,
      cancellationDeadlineMinutes,
      cancellationFeePercent,
      priorityMatching);

  /// Create a copy of ScheduledRideConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ScheduledRideConfigImplCopyWith<_$ScheduledRideConfigImpl> get copyWith =>
      __$$ScheduledRideConfigImplCopyWithImpl<_$ScheduledRideConfigImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ScheduledRideConfigImplToJson(
      this,
    );
  }
}

abstract class _ScheduledRideConfig implements ScheduledRideConfig {
  const factory _ScheduledRideConfig(
      {final bool enableScheduledRides,
      final int minMinutesInAdvance,
      final int maxMinutesInAdvance,
      final bool allowRecurring,
      final int maxRecurringRides,
      final bool sendReminders,
      final List<int> reminderIntervals,
      final bool allowModification,
      final int modificationDeadlineMinutes,
      final bool allowCancellation,
      final int cancellationDeadlineMinutes,
      final double cancellationFeePercent,
      final bool priorityMatching}) = _$ScheduledRideConfigImpl;

  factory _ScheduledRideConfig.fromJson(Map<String, dynamic> json) =
      _$ScheduledRideConfigImpl.fromJson;

  @override
  bool get enableScheduledRides;
  @override
  int get minMinutesInAdvance; // Mínimo 30 minutos antes
  @override
  int get maxMinutesInAdvance; // Máximo 7 días antes (7*24*60)
  @override
  bool get allowRecurring;
  @override
  int get maxRecurringRides;
  @override
  bool get sendReminders;
  @override
  List<int> get reminderIntervals; // Minutos antes
  @override
  bool get allowModification;
  @override
  int get modificationDeadlineMinutes; // No modificar 1 hora antes
  @override
  bool get allowCancellation;
  @override
  int get cancellationDeadlineMinutes;
  @override
  double get cancellationFeePercent; // 10% de penalización
  @override
  bool get priorityMatching;

  /// Create a copy of ScheduledRideConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ScheduledRideConfigImplCopyWith<_$ScheduledRideConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
