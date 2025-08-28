// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'shift.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Shift _$ShiftFromJson(Map<String, dynamic> json) {
  return _Shift.fromJson(json);
}

/// @nodoc
mixin _$Shift {
  String get id => throw _privateConstructorUsedError;
  String get driverId => throw _privateConstructorUsedError;
  DateTime get startTime => throw _privateConstructorUsedError;
  DateTime get endTime => throw _privateConstructorUsedError;
  ShiftStatus get status => throw _privateConstructorUsedError;
  List<String> get workDays =>
      throw _privateConstructorUsedError; // ['monday', 'tuesday', etc.]
  String? get notes => throw _privateConstructorUsedError;
  DateTime? get actualStartTime => throw _privateConstructorUsedError;
  DateTime? get actualEndTime => throw _privateConstructorUsedError;
  double get estimatedEarnings => throw _privateConstructorUsedError;
  double get actualEarnings => throw _privateConstructorUsedError;
  int get completedRides => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this Shift to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Shift
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ShiftCopyWith<Shift> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ShiftCopyWith<$Res> {
  factory $ShiftCopyWith(Shift value, $Res Function(Shift) then) =
      _$ShiftCopyWithImpl<$Res, Shift>;
  @useResult
  $Res call(
      {String id,
      String driverId,
      DateTime startTime,
      DateTime endTime,
      ShiftStatus status,
      List<String> workDays,
      String? notes,
      DateTime? actualStartTime,
      DateTime? actualEndTime,
      double estimatedEarnings,
      double actualEarnings,
      int completedRides,
      DateTime? createdAt,
      DateTime? updatedAt});
}

/// @nodoc
class _$ShiftCopyWithImpl<$Res, $Val extends Shift>
    implements $ShiftCopyWith<$Res> {
  _$ShiftCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Shift
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? driverId = null,
    Object? startTime = null,
    Object? endTime = null,
    Object? status = null,
    Object? workDays = null,
    Object? notes = freezed,
    Object? actualStartTime = freezed,
    Object? actualEndTime = freezed,
    Object? estimatedEarnings = null,
    Object? actualEarnings = null,
    Object? completedRides = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      driverId: null == driverId
          ? _value.driverId
          : driverId // ignore: cast_nullable_to_non_nullable
              as String,
      startTime: null == startTime
          ? _value.startTime
          : startTime // ignore: cast_nullable_to_non_nullable
              as DateTime,
      endTime: null == endTime
          ? _value.endTime
          : endTime // ignore: cast_nullable_to_non_nullable
              as DateTime,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as ShiftStatus,
      workDays: null == workDays
          ? _value.workDays
          : workDays // ignore: cast_nullable_to_non_nullable
              as List<String>,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
      actualStartTime: freezed == actualStartTime
          ? _value.actualStartTime
          : actualStartTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      actualEndTime: freezed == actualEndTime
          ? _value.actualEndTime
          : actualEndTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      estimatedEarnings: null == estimatedEarnings
          ? _value.estimatedEarnings
          : estimatedEarnings // ignore: cast_nullable_to_non_nullable
              as double,
      actualEarnings: null == actualEarnings
          ? _value.actualEarnings
          : actualEarnings // ignore: cast_nullable_to_non_nullable
              as double,
      completedRides: null == completedRides
          ? _value.completedRides
          : completedRides // ignore: cast_nullable_to_non_nullable
              as int,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ShiftImplCopyWith<$Res> implements $ShiftCopyWith<$Res> {
  factory _$$ShiftImplCopyWith(
          _$ShiftImpl value, $Res Function(_$ShiftImpl) then) =
      __$$ShiftImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String driverId,
      DateTime startTime,
      DateTime endTime,
      ShiftStatus status,
      List<String> workDays,
      String? notes,
      DateTime? actualStartTime,
      DateTime? actualEndTime,
      double estimatedEarnings,
      double actualEarnings,
      int completedRides,
      DateTime? createdAt,
      DateTime? updatedAt});
}

/// @nodoc
class __$$ShiftImplCopyWithImpl<$Res>
    extends _$ShiftCopyWithImpl<$Res, _$ShiftImpl>
    implements _$$ShiftImplCopyWith<$Res> {
  __$$ShiftImplCopyWithImpl(
      _$ShiftImpl _value, $Res Function(_$ShiftImpl) _then)
      : super(_value, _then);

  /// Create a copy of Shift
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? driverId = null,
    Object? startTime = null,
    Object? endTime = null,
    Object? status = null,
    Object? workDays = null,
    Object? notes = freezed,
    Object? actualStartTime = freezed,
    Object? actualEndTime = freezed,
    Object? estimatedEarnings = null,
    Object? actualEarnings = null,
    Object? completedRides = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_$ShiftImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      driverId: null == driverId
          ? _value.driverId
          : driverId // ignore: cast_nullable_to_non_nullable
              as String,
      startTime: null == startTime
          ? _value.startTime
          : startTime // ignore: cast_nullable_to_non_nullable
              as DateTime,
      endTime: null == endTime
          ? _value.endTime
          : endTime // ignore: cast_nullable_to_non_nullable
              as DateTime,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as ShiftStatus,
      workDays: null == workDays
          ? _value._workDays
          : workDays // ignore: cast_nullable_to_non_nullable
              as List<String>,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
      actualStartTime: freezed == actualStartTime
          ? _value.actualStartTime
          : actualStartTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      actualEndTime: freezed == actualEndTime
          ? _value.actualEndTime
          : actualEndTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      estimatedEarnings: null == estimatedEarnings
          ? _value.estimatedEarnings
          : estimatedEarnings // ignore: cast_nullable_to_non_nullable
              as double,
      actualEarnings: null == actualEarnings
          ? _value.actualEarnings
          : actualEarnings // ignore: cast_nullable_to_non_nullable
              as double,
      completedRides: null == completedRides
          ? _value.completedRides
          : completedRides // ignore: cast_nullable_to_non_nullable
              as int,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ShiftImpl implements _Shift {
  const _$ShiftImpl(
      {required this.id,
      required this.driverId,
      required this.startTime,
      required this.endTime,
      required this.status,
      required final List<String> workDays,
      this.notes,
      this.actualStartTime,
      this.actualEndTime,
      this.estimatedEarnings = 0.0,
      this.actualEarnings = 0.0,
      this.completedRides = 0,
      this.createdAt,
      this.updatedAt})
      : _workDays = workDays;

  factory _$ShiftImpl.fromJson(Map<String, dynamic> json) =>
      _$$ShiftImplFromJson(json);

  @override
  final String id;
  @override
  final String driverId;
  @override
  final DateTime startTime;
  @override
  final DateTime endTime;
  @override
  final ShiftStatus status;
  final List<String> _workDays;
  @override
  List<String> get workDays {
    if (_workDays is EqualUnmodifiableListView) return _workDays;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_workDays);
  }

// ['monday', 'tuesday', etc.]
  @override
  final String? notes;
  @override
  final DateTime? actualStartTime;
  @override
  final DateTime? actualEndTime;
  @override
  @JsonKey()
  final double estimatedEarnings;
  @override
  @JsonKey()
  final double actualEarnings;
  @override
  @JsonKey()
  final int completedRides;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'Shift(id: $id, driverId: $driverId, startTime: $startTime, endTime: $endTime, status: $status, workDays: $workDays, notes: $notes, actualStartTime: $actualStartTime, actualEndTime: $actualEndTime, estimatedEarnings: $estimatedEarnings, actualEarnings: $actualEarnings, completedRides: $completedRides, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ShiftImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.driverId, driverId) ||
                other.driverId == driverId) &&
            (identical(other.startTime, startTime) ||
                other.startTime == startTime) &&
            (identical(other.endTime, endTime) || other.endTime == endTime) &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other._workDays, _workDays) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.actualStartTime, actualStartTime) ||
                other.actualStartTime == actualStartTime) &&
            (identical(other.actualEndTime, actualEndTime) ||
                other.actualEndTime == actualEndTime) &&
            (identical(other.estimatedEarnings, estimatedEarnings) ||
                other.estimatedEarnings == estimatedEarnings) &&
            (identical(other.actualEarnings, actualEarnings) ||
                other.actualEarnings == actualEarnings) &&
            (identical(other.completedRides, completedRides) ||
                other.completedRides == completedRides) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      driverId,
      startTime,
      endTime,
      status,
      const DeepCollectionEquality().hash(_workDays),
      notes,
      actualStartTime,
      actualEndTime,
      estimatedEarnings,
      actualEarnings,
      completedRides,
      createdAt,
      updatedAt);

  /// Create a copy of Shift
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ShiftImplCopyWith<_$ShiftImpl> get copyWith =>
      __$$ShiftImplCopyWithImpl<_$ShiftImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ShiftImplToJson(
      this,
    );
  }
}

abstract class _Shift implements Shift {
  const factory _Shift(
      {required final String id,
      required final String driverId,
      required final DateTime startTime,
      required final DateTime endTime,
      required final ShiftStatus status,
      required final List<String> workDays,
      final String? notes,
      final DateTime? actualStartTime,
      final DateTime? actualEndTime,
      final double estimatedEarnings,
      final double actualEarnings,
      final int completedRides,
      final DateTime? createdAt,
      final DateTime? updatedAt}) = _$ShiftImpl;

  factory _Shift.fromJson(Map<String, dynamic> json) = _$ShiftImpl.fromJson;

  @override
  String get id;
  @override
  String get driverId;
  @override
  DateTime get startTime;
  @override
  DateTime get endTime;
  @override
  ShiftStatus get status;
  @override
  List<String> get workDays; // ['monday', 'tuesday', etc.]
  @override
  String? get notes;
  @override
  DateTime? get actualStartTime;
  @override
  DateTime? get actualEndTime;
  @override
  double get estimatedEarnings;
  @override
  double get actualEarnings;
  @override
  int get completedRides;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get updatedAt;

  /// Create a copy of Shift
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ShiftImplCopyWith<_$ShiftImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ShiftTemplate _$ShiftTemplateFromJson(Map<String, dynamic> json) {
  return _ShiftTemplate.fromJson(json);
}

/// @nodoc
mixin _$ShiftTemplate {
  String get id => throw _privateConstructorUsedError;
  String get driverId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get startTime => throw _privateConstructorUsedError; // "08:00"
  String get endTime => throw _privateConstructorUsedError; // "16:00"
  List<String> get workDays => throw _privateConstructorUsedError;
  bool get isActive => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;

  /// Serializes this ShiftTemplate to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ShiftTemplate
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ShiftTemplateCopyWith<ShiftTemplate> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ShiftTemplateCopyWith<$Res> {
  factory $ShiftTemplateCopyWith(
          ShiftTemplate value, $Res Function(ShiftTemplate) then) =
      _$ShiftTemplateCopyWithImpl<$Res, ShiftTemplate>;
  @useResult
  $Res call(
      {String id,
      String driverId,
      String name,
      String startTime,
      String endTime,
      List<String> workDays,
      bool isActive,
      String? notes,
      DateTime? createdAt});
}

/// @nodoc
class _$ShiftTemplateCopyWithImpl<$Res, $Val extends ShiftTemplate>
    implements $ShiftTemplateCopyWith<$Res> {
  _$ShiftTemplateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ShiftTemplate
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? driverId = null,
    Object? name = null,
    Object? startTime = null,
    Object? endTime = null,
    Object? workDays = null,
    Object? isActive = null,
    Object? notes = freezed,
    Object? createdAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      driverId: null == driverId
          ? _value.driverId
          : driverId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      startTime: null == startTime
          ? _value.startTime
          : startTime // ignore: cast_nullable_to_non_nullable
              as String,
      endTime: null == endTime
          ? _value.endTime
          : endTime // ignore: cast_nullable_to_non_nullable
              as String,
      workDays: null == workDays
          ? _value.workDays
          : workDays // ignore: cast_nullable_to_non_nullable
              as List<String>,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ShiftTemplateImplCopyWith<$Res>
    implements $ShiftTemplateCopyWith<$Res> {
  factory _$$ShiftTemplateImplCopyWith(
          _$ShiftTemplateImpl value, $Res Function(_$ShiftTemplateImpl) then) =
      __$$ShiftTemplateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String driverId,
      String name,
      String startTime,
      String endTime,
      List<String> workDays,
      bool isActive,
      String? notes,
      DateTime? createdAt});
}

/// @nodoc
class __$$ShiftTemplateImplCopyWithImpl<$Res>
    extends _$ShiftTemplateCopyWithImpl<$Res, _$ShiftTemplateImpl>
    implements _$$ShiftTemplateImplCopyWith<$Res> {
  __$$ShiftTemplateImplCopyWithImpl(
      _$ShiftTemplateImpl _value, $Res Function(_$ShiftTemplateImpl) _then)
      : super(_value, _then);

  /// Create a copy of ShiftTemplate
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? driverId = null,
    Object? name = null,
    Object? startTime = null,
    Object? endTime = null,
    Object? workDays = null,
    Object? isActive = null,
    Object? notes = freezed,
    Object? createdAt = freezed,
  }) {
    return _then(_$ShiftTemplateImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      driverId: null == driverId
          ? _value.driverId
          : driverId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      startTime: null == startTime
          ? _value.startTime
          : startTime // ignore: cast_nullable_to_non_nullable
              as String,
      endTime: null == endTime
          ? _value.endTime
          : endTime // ignore: cast_nullable_to_non_nullable
              as String,
      workDays: null == workDays
          ? _value._workDays
          : workDays // ignore: cast_nullable_to_non_nullable
              as List<String>,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ShiftTemplateImpl implements _ShiftTemplate {
  const _$ShiftTemplateImpl(
      {required this.id,
      required this.driverId,
      required this.name,
      required this.startTime,
      required this.endTime,
      required final List<String> workDays,
      this.isActive = true,
      this.notes,
      this.createdAt})
      : _workDays = workDays;

  factory _$ShiftTemplateImpl.fromJson(Map<String, dynamic> json) =>
      _$$ShiftTemplateImplFromJson(json);

  @override
  final String id;
  @override
  final String driverId;
  @override
  final String name;
  @override
  final String startTime;
// "08:00"
  @override
  final String endTime;
// "16:00"
  final List<String> _workDays;
// "16:00"
  @override
  List<String> get workDays {
    if (_workDays is EqualUnmodifiableListView) return _workDays;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_workDays);
  }

  @override
  @JsonKey()
  final bool isActive;
  @override
  final String? notes;
  @override
  final DateTime? createdAt;

  @override
  String toString() {
    return 'ShiftTemplate(id: $id, driverId: $driverId, name: $name, startTime: $startTime, endTime: $endTime, workDays: $workDays, isActive: $isActive, notes: $notes, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ShiftTemplateImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.driverId, driverId) ||
                other.driverId == driverId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.startTime, startTime) ||
                other.startTime == startTime) &&
            (identical(other.endTime, endTime) || other.endTime == endTime) &&
            const DeepCollectionEquality().equals(other._workDays, _workDays) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      driverId,
      name,
      startTime,
      endTime,
      const DeepCollectionEquality().hash(_workDays),
      isActive,
      notes,
      createdAt);

  /// Create a copy of ShiftTemplate
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ShiftTemplateImplCopyWith<_$ShiftTemplateImpl> get copyWith =>
      __$$ShiftTemplateImplCopyWithImpl<_$ShiftTemplateImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ShiftTemplateImplToJson(
      this,
    );
  }
}

abstract class _ShiftTemplate implements ShiftTemplate {
  const factory _ShiftTemplate(
      {required final String id,
      required final String driverId,
      required final String name,
      required final String startTime,
      required final String endTime,
      required final List<String> workDays,
      final bool isActive,
      final String? notes,
      final DateTime? createdAt}) = _$ShiftTemplateImpl;

  factory _ShiftTemplate.fromJson(Map<String, dynamic> json) =
      _$ShiftTemplateImpl.fromJson;

  @override
  String get id;
  @override
  String get driverId;
  @override
  String get name;
  @override
  String get startTime; // "08:00"
  @override
  String get endTime; // "16:00"
  @override
  List<String> get workDays;
  @override
  bool get isActive;
  @override
  String? get notes;
  @override
  DateTime? get createdAt;

  /// Create a copy of ShiftTemplate
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ShiftTemplateImplCopyWith<_$ShiftTemplateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
