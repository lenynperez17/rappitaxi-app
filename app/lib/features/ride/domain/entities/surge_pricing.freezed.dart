// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'surge_pricing.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

SurgePricing _$SurgePricingFromJson(Map<String, dynamic> json) {
  return _SurgePricing.fromJson(json);
}

/// @nodoc
mixin _$SurgePricing {
  String get id => throw _privateConstructorUsedError;
  String get zoneId => throw _privateConstructorUsedError;
  double get latitude => throw _privateConstructorUsedError;
  double get longitude => throw _privateConstructorUsedError;
  double get radiusKm => throw _privateConstructorUsedError;
  double get surgeMultiplier => throw _privateConstructorUsedError;
  int get activeDrivers => throw _privateConstructorUsedError;
  int get pendingRequests => throw _privateConstructorUsedError;
  DateTime get startTime => throw _privateConstructorUsedError;
  DateTime get endTime => throw _privateConstructorUsedError;
  SurgeReason get reason => throw _privateConstructorUsedError;
  bool get isActive => throw _privateConstructorUsedError;
  String? get message => throw _privateConstructorUsedError;
  Map<String, dynamic> get metadata => throw _privateConstructorUsedError;

  /// Serializes this SurgePricing to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SurgePricing
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SurgePricingCopyWith<SurgePricing> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SurgePricingCopyWith<$Res> {
  factory $SurgePricingCopyWith(
          SurgePricing value, $Res Function(SurgePricing) then) =
      _$SurgePricingCopyWithImpl<$Res, SurgePricing>;
  @useResult
  $Res call(
      {String id,
      String zoneId,
      double latitude,
      double longitude,
      double radiusKm,
      double surgeMultiplier,
      int activeDrivers,
      int pendingRequests,
      DateTime startTime,
      DateTime endTime,
      SurgeReason reason,
      bool isActive,
      String? message,
      Map<String, dynamic> metadata});
}

/// @nodoc
class _$SurgePricingCopyWithImpl<$Res, $Val extends SurgePricing>
    implements $SurgePricingCopyWith<$Res> {
  _$SurgePricingCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SurgePricing
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? zoneId = null,
    Object? latitude = null,
    Object? longitude = null,
    Object? radiusKm = null,
    Object? surgeMultiplier = null,
    Object? activeDrivers = null,
    Object? pendingRequests = null,
    Object? startTime = null,
    Object? endTime = null,
    Object? reason = null,
    Object? isActive = null,
    Object? message = freezed,
    Object? metadata = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      zoneId: null == zoneId
          ? _value.zoneId
          : zoneId // ignore: cast_nullable_to_non_nullable
              as String,
      latitude: null == latitude
          ? _value.latitude
          : latitude // ignore: cast_nullable_to_non_nullable
              as double,
      longitude: null == longitude
          ? _value.longitude
          : longitude // ignore: cast_nullable_to_non_nullable
              as double,
      radiusKm: null == radiusKm
          ? _value.radiusKm
          : radiusKm // ignore: cast_nullable_to_non_nullable
              as double,
      surgeMultiplier: null == surgeMultiplier
          ? _value.surgeMultiplier
          : surgeMultiplier // ignore: cast_nullable_to_non_nullable
              as double,
      activeDrivers: null == activeDrivers
          ? _value.activeDrivers
          : activeDrivers // ignore: cast_nullable_to_non_nullable
              as int,
      pendingRequests: null == pendingRequests
          ? _value.pendingRequests
          : pendingRequests // ignore: cast_nullable_to_non_nullable
              as int,
      startTime: null == startTime
          ? _value.startTime
          : startTime // ignore: cast_nullable_to_non_nullable
              as DateTime,
      endTime: null == endTime
          ? _value.endTime
          : endTime // ignore: cast_nullable_to_non_nullable
              as DateTime,
      reason: null == reason
          ? _value.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as SurgeReason,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      message: freezed == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
      metadata: null == metadata
          ? _value.metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SurgePricingImplCopyWith<$Res>
    implements $SurgePricingCopyWith<$Res> {
  factory _$$SurgePricingImplCopyWith(
          _$SurgePricingImpl value, $Res Function(_$SurgePricingImpl) then) =
      __$$SurgePricingImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String zoneId,
      double latitude,
      double longitude,
      double radiusKm,
      double surgeMultiplier,
      int activeDrivers,
      int pendingRequests,
      DateTime startTime,
      DateTime endTime,
      SurgeReason reason,
      bool isActive,
      String? message,
      Map<String, dynamic> metadata});
}

/// @nodoc
class __$$SurgePricingImplCopyWithImpl<$Res>
    extends _$SurgePricingCopyWithImpl<$Res, _$SurgePricingImpl>
    implements _$$SurgePricingImplCopyWith<$Res> {
  __$$SurgePricingImplCopyWithImpl(
      _$SurgePricingImpl _value, $Res Function(_$SurgePricingImpl) _then)
      : super(_value, _then);

  /// Create a copy of SurgePricing
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? zoneId = null,
    Object? latitude = null,
    Object? longitude = null,
    Object? radiusKm = null,
    Object? surgeMultiplier = null,
    Object? activeDrivers = null,
    Object? pendingRequests = null,
    Object? startTime = null,
    Object? endTime = null,
    Object? reason = null,
    Object? isActive = null,
    Object? message = freezed,
    Object? metadata = null,
  }) {
    return _then(_$SurgePricingImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      zoneId: null == zoneId
          ? _value.zoneId
          : zoneId // ignore: cast_nullable_to_non_nullable
              as String,
      latitude: null == latitude
          ? _value.latitude
          : latitude // ignore: cast_nullable_to_non_nullable
              as double,
      longitude: null == longitude
          ? _value.longitude
          : longitude // ignore: cast_nullable_to_non_nullable
              as double,
      radiusKm: null == radiusKm
          ? _value.radiusKm
          : radiusKm // ignore: cast_nullable_to_non_nullable
              as double,
      surgeMultiplier: null == surgeMultiplier
          ? _value.surgeMultiplier
          : surgeMultiplier // ignore: cast_nullable_to_non_nullable
              as double,
      activeDrivers: null == activeDrivers
          ? _value.activeDrivers
          : activeDrivers // ignore: cast_nullable_to_non_nullable
              as int,
      pendingRequests: null == pendingRequests
          ? _value.pendingRequests
          : pendingRequests // ignore: cast_nullable_to_non_nullable
              as int,
      startTime: null == startTime
          ? _value.startTime
          : startTime // ignore: cast_nullable_to_non_nullable
              as DateTime,
      endTime: null == endTime
          ? _value.endTime
          : endTime // ignore: cast_nullable_to_non_nullable
              as DateTime,
      reason: null == reason
          ? _value.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as SurgeReason,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      message: freezed == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
      metadata: null == metadata
          ? _value._metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SurgePricingImpl implements _SurgePricing {
  const _$SurgePricingImpl(
      {required this.id,
      required this.zoneId,
      required this.latitude,
      required this.longitude,
      required this.radiusKm,
      required this.surgeMultiplier,
      required this.activeDrivers,
      required this.pendingRequests,
      required this.startTime,
      required this.endTime,
      required this.reason,
      this.isActive = true,
      this.message,
      final Map<String, dynamic> metadata = const {}})
      : _metadata = metadata;

  factory _$SurgePricingImpl.fromJson(Map<String, dynamic> json) =>
      _$$SurgePricingImplFromJson(json);

  @override
  final String id;
  @override
  final String zoneId;
  @override
  final double latitude;
  @override
  final double longitude;
  @override
  final double radiusKm;
  @override
  final double surgeMultiplier;
  @override
  final int activeDrivers;
  @override
  final int pendingRequests;
  @override
  final DateTime startTime;
  @override
  final DateTime endTime;
  @override
  final SurgeReason reason;
  @override
  @JsonKey()
  final bool isActive;
  @override
  final String? message;
  final Map<String, dynamic> _metadata;
  @override
  @JsonKey()
  Map<String, dynamic> get metadata {
    if (_metadata is EqualUnmodifiableMapView) return _metadata;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_metadata);
  }

  @override
  String toString() {
    return 'SurgePricing(id: $id, zoneId: $zoneId, latitude: $latitude, longitude: $longitude, radiusKm: $radiusKm, surgeMultiplier: $surgeMultiplier, activeDrivers: $activeDrivers, pendingRequests: $pendingRequests, startTime: $startTime, endTime: $endTime, reason: $reason, isActive: $isActive, message: $message, metadata: $metadata)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SurgePricingImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.zoneId, zoneId) || other.zoneId == zoneId) &&
            (identical(other.latitude, latitude) ||
                other.latitude == latitude) &&
            (identical(other.longitude, longitude) ||
                other.longitude == longitude) &&
            (identical(other.radiusKm, radiusKm) ||
                other.radiusKm == radiusKm) &&
            (identical(other.surgeMultiplier, surgeMultiplier) ||
                other.surgeMultiplier == surgeMultiplier) &&
            (identical(other.activeDrivers, activeDrivers) ||
                other.activeDrivers == activeDrivers) &&
            (identical(other.pendingRequests, pendingRequests) ||
                other.pendingRequests == pendingRequests) &&
            (identical(other.startTime, startTime) ||
                other.startTime == startTime) &&
            (identical(other.endTime, endTime) || other.endTime == endTime) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.message, message) || other.message == message) &&
            const DeepCollectionEquality().equals(other._metadata, _metadata));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      zoneId,
      latitude,
      longitude,
      radiusKm,
      surgeMultiplier,
      activeDrivers,
      pendingRequests,
      startTime,
      endTime,
      reason,
      isActive,
      message,
      const DeepCollectionEquality().hash(_metadata));

  /// Create a copy of SurgePricing
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SurgePricingImplCopyWith<_$SurgePricingImpl> get copyWith =>
      __$$SurgePricingImplCopyWithImpl<_$SurgePricingImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SurgePricingImplToJson(
      this,
    );
  }
}

abstract class _SurgePricing implements SurgePricing {
  const factory _SurgePricing(
      {required final String id,
      required final String zoneId,
      required final double latitude,
      required final double longitude,
      required final double radiusKm,
      required final double surgeMultiplier,
      required final int activeDrivers,
      required final int pendingRequests,
      required final DateTime startTime,
      required final DateTime endTime,
      required final SurgeReason reason,
      final bool isActive,
      final String? message,
      final Map<String, dynamic> metadata}) = _$SurgePricingImpl;

  factory _SurgePricing.fromJson(Map<String, dynamic> json) =
      _$SurgePricingImpl.fromJson;

  @override
  String get id;
  @override
  String get zoneId;
  @override
  double get latitude;
  @override
  double get longitude;
  @override
  double get radiusKm;
  @override
  double get surgeMultiplier;
  @override
  int get activeDrivers;
  @override
  int get pendingRequests;
  @override
  DateTime get startTime;
  @override
  DateTime get endTime;
  @override
  SurgeReason get reason;
  @override
  bool get isActive;
  @override
  String? get message;
  @override
  Map<String, dynamic> get metadata;

  /// Create a copy of SurgePricing
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SurgePricingImplCopyWith<_$SurgePricingImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SurgePricingConfig _$SurgePricingConfigFromJson(Map<String, dynamic> json) {
  return _SurgePricingConfig.fromJson(json);
}

/// @nodoc
mixin _$SurgePricingConfig {
  bool get enableSurgePricing => throw _privateConstructorUsedError;
  double get minMultiplier => throw _privateConstructorUsedError;
  double get maxMultiplier => throw _privateConstructorUsedError;
  double get incrementStep => throw _privateConstructorUsedError;
  int get demandThreshold =>
      throw _privateConstructorUsedError; // Solicitudes pendientes para activar surge
  int get supplyThreshold =>
      throw _privateConstructorUsedError; // Mínimo de conductores para desactivar surge
  int get updateIntervalSeconds => throw _privateConstructorUsedError;
  int get zoneSizeKm => throw _privateConstructorUsedError;
  bool get showSurgeWarning => throw _privateConstructorUsedError;
  bool get allowUserOptOut => throw _privateConstructorUsedError;
  Map<String, double> get peakHours => throw _privateConstructorUsedError;

  /// Serializes this SurgePricingConfig to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SurgePricingConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SurgePricingConfigCopyWith<SurgePricingConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SurgePricingConfigCopyWith<$Res> {
  factory $SurgePricingConfigCopyWith(
          SurgePricingConfig value, $Res Function(SurgePricingConfig) then) =
      _$SurgePricingConfigCopyWithImpl<$Res, SurgePricingConfig>;
  @useResult
  $Res call(
      {bool enableSurgePricing,
      double minMultiplier,
      double maxMultiplier,
      double incrementStep,
      int demandThreshold,
      int supplyThreshold,
      int updateIntervalSeconds,
      int zoneSizeKm,
      bool showSurgeWarning,
      bool allowUserOptOut,
      Map<String, double> peakHours});
}

/// @nodoc
class _$SurgePricingConfigCopyWithImpl<$Res, $Val extends SurgePricingConfig>
    implements $SurgePricingConfigCopyWith<$Res> {
  _$SurgePricingConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SurgePricingConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? enableSurgePricing = null,
    Object? minMultiplier = null,
    Object? maxMultiplier = null,
    Object? incrementStep = null,
    Object? demandThreshold = null,
    Object? supplyThreshold = null,
    Object? updateIntervalSeconds = null,
    Object? zoneSizeKm = null,
    Object? showSurgeWarning = null,
    Object? allowUserOptOut = null,
    Object? peakHours = null,
  }) {
    return _then(_value.copyWith(
      enableSurgePricing: null == enableSurgePricing
          ? _value.enableSurgePricing
          : enableSurgePricing // ignore: cast_nullable_to_non_nullable
              as bool,
      minMultiplier: null == minMultiplier
          ? _value.minMultiplier
          : minMultiplier // ignore: cast_nullable_to_non_nullable
              as double,
      maxMultiplier: null == maxMultiplier
          ? _value.maxMultiplier
          : maxMultiplier // ignore: cast_nullable_to_non_nullable
              as double,
      incrementStep: null == incrementStep
          ? _value.incrementStep
          : incrementStep // ignore: cast_nullable_to_non_nullable
              as double,
      demandThreshold: null == demandThreshold
          ? _value.demandThreshold
          : demandThreshold // ignore: cast_nullable_to_non_nullable
              as int,
      supplyThreshold: null == supplyThreshold
          ? _value.supplyThreshold
          : supplyThreshold // ignore: cast_nullable_to_non_nullable
              as int,
      updateIntervalSeconds: null == updateIntervalSeconds
          ? _value.updateIntervalSeconds
          : updateIntervalSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      zoneSizeKm: null == zoneSizeKm
          ? _value.zoneSizeKm
          : zoneSizeKm // ignore: cast_nullable_to_non_nullable
              as int,
      showSurgeWarning: null == showSurgeWarning
          ? _value.showSurgeWarning
          : showSurgeWarning // ignore: cast_nullable_to_non_nullable
              as bool,
      allowUserOptOut: null == allowUserOptOut
          ? _value.allowUserOptOut
          : allowUserOptOut // ignore: cast_nullable_to_non_nullable
              as bool,
      peakHours: null == peakHours
          ? _value.peakHours
          : peakHours // ignore: cast_nullable_to_non_nullable
              as Map<String, double>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SurgePricingConfigImplCopyWith<$Res>
    implements $SurgePricingConfigCopyWith<$Res> {
  factory _$$SurgePricingConfigImplCopyWith(_$SurgePricingConfigImpl value,
          $Res Function(_$SurgePricingConfigImpl) then) =
      __$$SurgePricingConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool enableSurgePricing,
      double minMultiplier,
      double maxMultiplier,
      double incrementStep,
      int demandThreshold,
      int supplyThreshold,
      int updateIntervalSeconds,
      int zoneSizeKm,
      bool showSurgeWarning,
      bool allowUserOptOut,
      Map<String, double> peakHours});
}

/// @nodoc
class __$$SurgePricingConfigImplCopyWithImpl<$Res>
    extends _$SurgePricingConfigCopyWithImpl<$Res, _$SurgePricingConfigImpl>
    implements _$$SurgePricingConfigImplCopyWith<$Res> {
  __$$SurgePricingConfigImplCopyWithImpl(_$SurgePricingConfigImpl _value,
      $Res Function(_$SurgePricingConfigImpl) _then)
      : super(_value, _then);

  /// Create a copy of SurgePricingConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? enableSurgePricing = null,
    Object? minMultiplier = null,
    Object? maxMultiplier = null,
    Object? incrementStep = null,
    Object? demandThreshold = null,
    Object? supplyThreshold = null,
    Object? updateIntervalSeconds = null,
    Object? zoneSizeKm = null,
    Object? showSurgeWarning = null,
    Object? allowUserOptOut = null,
    Object? peakHours = null,
  }) {
    return _then(_$SurgePricingConfigImpl(
      enableSurgePricing: null == enableSurgePricing
          ? _value.enableSurgePricing
          : enableSurgePricing // ignore: cast_nullable_to_non_nullable
              as bool,
      minMultiplier: null == minMultiplier
          ? _value.minMultiplier
          : minMultiplier // ignore: cast_nullable_to_non_nullable
              as double,
      maxMultiplier: null == maxMultiplier
          ? _value.maxMultiplier
          : maxMultiplier // ignore: cast_nullable_to_non_nullable
              as double,
      incrementStep: null == incrementStep
          ? _value.incrementStep
          : incrementStep // ignore: cast_nullable_to_non_nullable
              as double,
      demandThreshold: null == demandThreshold
          ? _value.demandThreshold
          : demandThreshold // ignore: cast_nullable_to_non_nullable
              as int,
      supplyThreshold: null == supplyThreshold
          ? _value.supplyThreshold
          : supplyThreshold // ignore: cast_nullable_to_non_nullable
              as int,
      updateIntervalSeconds: null == updateIntervalSeconds
          ? _value.updateIntervalSeconds
          : updateIntervalSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      zoneSizeKm: null == zoneSizeKm
          ? _value.zoneSizeKm
          : zoneSizeKm // ignore: cast_nullable_to_non_nullable
              as int,
      showSurgeWarning: null == showSurgeWarning
          ? _value.showSurgeWarning
          : showSurgeWarning // ignore: cast_nullable_to_non_nullable
              as bool,
      allowUserOptOut: null == allowUserOptOut
          ? _value.allowUserOptOut
          : allowUserOptOut // ignore: cast_nullable_to_non_nullable
              as bool,
      peakHours: null == peakHours
          ? _value._peakHours
          : peakHours // ignore: cast_nullable_to_non_nullable
              as Map<String, double>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SurgePricingConfigImpl implements _SurgePricingConfig {
  const _$SurgePricingConfigImpl(
      {this.enableSurgePricing = true,
      this.minMultiplier = 1.0,
      this.maxMultiplier = 3.0,
      this.incrementStep = 0.1,
      this.demandThreshold = 5,
      this.supplyThreshold = 3,
      this.updateIntervalSeconds = 300,
      this.zoneSizeKm = 15,
      this.showSurgeWarning = true,
      this.allowUserOptOut = true,
      required final Map<String, double> peakHours})
      : _peakHours = peakHours;

  factory _$SurgePricingConfigImpl.fromJson(Map<String, dynamic> json) =>
      _$$SurgePricingConfigImplFromJson(json);

  @override
  @JsonKey()
  final bool enableSurgePricing;
  @override
  @JsonKey()
  final double minMultiplier;
  @override
  @JsonKey()
  final double maxMultiplier;
  @override
  @JsonKey()
  final double incrementStep;
  @override
  @JsonKey()
  final int demandThreshold;
// Solicitudes pendientes para activar surge
  @override
  @JsonKey()
  final int supplyThreshold;
// Mínimo de conductores para desactivar surge
  @override
  @JsonKey()
  final int updateIntervalSeconds;
  @override
  @JsonKey()
  final int zoneSizeKm;
  @override
  @JsonKey()
  final bool showSurgeWarning;
  @override
  @JsonKey()
  final bool allowUserOptOut;
  final Map<String, double> _peakHours;
  @override
  Map<String, double> get peakHours {
    if (_peakHours is EqualUnmodifiableMapView) return _peakHours;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_peakHours);
  }

  @override
  String toString() {
    return 'SurgePricingConfig(enableSurgePricing: $enableSurgePricing, minMultiplier: $minMultiplier, maxMultiplier: $maxMultiplier, incrementStep: $incrementStep, demandThreshold: $demandThreshold, supplyThreshold: $supplyThreshold, updateIntervalSeconds: $updateIntervalSeconds, zoneSizeKm: $zoneSizeKm, showSurgeWarning: $showSurgeWarning, allowUserOptOut: $allowUserOptOut, peakHours: $peakHours)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SurgePricingConfigImpl &&
            (identical(other.enableSurgePricing, enableSurgePricing) ||
                other.enableSurgePricing == enableSurgePricing) &&
            (identical(other.minMultiplier, minMultiplier) ||
                other.minMultiplier == minMultiplier) &&
            (identical(other.maxMultiplier, maxMultiplier) ||
                other.maxMultiplier == maxMultiplier) &&
            (identical(other.incrementStep, incrementStep) ||
                other.incrementStep == incrementStep) &&
            (identical(other.demandThreshold, demandThreshold) ||
                other.demandThreshold == demandThreshold) &&
            (identical(other.supplyThreshold, supplyThreshold) ||
                other.supplyThreshold == supplyThreshold) &&
            (identical(other.updateIntervalSeconds, updateIntervalSeconds) ||
                other.updateIntervalSeconds == updateIntervalSeconds) &&
            (identical(other.zoneSizeKm, zoneSizeKm) ||
                other.zoneSizeKm == zoneSizeKm) &&
            (identical(other.showSurgeWarning, showSurgeWarning) ||
                other.showSurgeWarning == showSurgeWarning) &&
            (identical(other.allowUserOptOut, allowUserOptOut) ||
                other.allowUserOptOut == allowUserOptOut) &&
            const DeepCollectionEquality()
                .equals(other._peakHours, _peakHours));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      enableSurgePricing,
      minMultiplier,
      maxMultiplier,
      incrementStep,
      demandThreshold,
      supplyThreshold,
      updateIntervalSeconds,
      zoneSizeKm,
      showSurgeWarning,
      allowUserOptOut,
      const DeepCollectionEquality().hash(_peakHours));

  /// Create a copy of SurgePricingConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SurgePricingConfigImplCopyWith<_$SurgePricingConfigImpl> get copyWith =>
      __$$SurgePricingConfigImplCopyWithImpl<_$SurgePricingConfigImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SurgePricingConfigImplToJson(
      this,
    );
  }
}

abstract class _SurgePricingConfig implements SurgePricingConfig {
  const factory _SurgePricingConfig(
      {final bool enableSurgePricing,
      final double minMultiplier,
      final double maxMultiplier,
      final double incrementStep,
      final int demandThreshold,
      final int supplyThreshold,
      final int updateIntervalSeconds,
      final int zoneSizeKm,
      final bool showSurgeWarning,
      final bool allowUserOptOut,
      required final Map<String, double> peakHours}) = _$SurgePricingConfigImpl;

  factory _SurgePricingConfig.fromJson(Map<String, dynamic> json) =
      _$SurgePricingConfigImpl.fromJson;

  @override
  bool get enableSurgePricing;
  @override
  double get minMultiplier;
  @override
  double get maxMultiplier;
  @override
  double get incrementStep;
  @override
  int get demandThreshold; // Solicitudes pendientes para activar surge
  @override
  int get supplyThreshold; // Mínimo de conductores para desactivar surge
  @override
  int get updateIntervalSeconds;
  @override
  int get zoneSizeKm;
  @override
  bool get showSurgeWarning;
  @override
  bool get allowUserOptOut;
  @override
  Map<String, double> get peakHours;

  /// Create a copy of SurgePricingConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SurgePricingConfigImplCopyWith<_$SurgePricingConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SurgePricingHistory _$SurgePricingHistoryFromJson(Map<String, dynamic> json) {
  return _SurgePricingHistory.fromJson(json);
}

/// @nodoc
mixin _$SurgePricingHistory {
  String get id => throw _privateConstructorUsedError;
  String get zoneId => throw _privateConstructorUsedError;
  double get multiplier => throw _privateConstructorUsedError;
  DateTime get timestamp => throw _privateConstructorUsedError;
  int get activeDrivers => throw _privateConstructorUsedError;
  int get pendingRequests => throw _privateConstructorUsedError;
  SurgeReason get reason => throw _privateConstructorUsedError;
  double get averageFare => throw _privateConstructorUsedError;
  int get completedRides => throw _privateConstructorUsedError;

  /// Serializes this SurgePricingHistory to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SurgePricingHistory
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SurgePricingHistoryCopyWith<SurgePricingHistory> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SurgePricingHistoryCopyWith<$Res> {
  factory $SurgePricingHistoryCopyWith(
          SurgePricingHistory value, $Res Function(SurgePricingHistory) then) =
      _$SurgePricingHistoryCopyWithImpl<$Res, SurgePricingHistory>;
  @useResult
  $Res call(
      {String id,
      String zoneId,
      double multiplier,
      DateTime timestamp,
      int activeDrivers,
      int pendingRequests,
      SurgeReason reason,
      double averageFare,
      int completedRides});
}

/// @nodoc
class _$SurgePricingHistoryCopyWithImpl<$Res, $Val extends SurgePricingHistory>
    implements $SurgePricingHistoryCopyWith<$Res> {
  _$SurgePricingHistoryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SurgePricingHistory
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? zoneId = null,
    Object? multiplier = null,
    Object? timestamp = null,
    Object? activeDrivers = null,
    Object? pendingRequests = null,
    Object? reason = null,
    Object? averageFare = null,
    Object? completedRides = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      zoneId: null == zoneId
          ? _value.zoneId
          : zoneId // ignore: cast_nullable_to_non_nullable
              as String,
      multiplier: null == multiplier
          ? _value.multiplier
          : multiplier // ignore: cast_nullable_to_non_nullable
              as double,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      activeDrivers: null == activeDrivers
          ? _value.activeDrivers
          : activeDrivers // ignore: cast_nullable_to_non_nullable
              as int,
      pendingRequests: null == pendingRequests
          ? _value.pendingRequests
          : pendingRequests // ignore: cast_nullable_to_non_nullable
              as int,
      reason: null == reason
          ? _value.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as SurgeReason,
      averageFare: null == averageFare
          ? _value.averageFare
          : averageFare // ignore: cast_nullable_to_non_nullable
              as double,
      completedRides: null == completedRides
          ? _value.completedRides
          : completedRides // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SurgePricingHistoryImplCopyWith<$Res>
    implements $SurgePricingHistoryCopyWith<$Res> {
  factory _$$SurgePricingHistoryImplCopyWith(_$SurgePricingHistoryImpl value,
          $Res Function(_$SurgePricingHistoryImpl) then) =
      __$$SurgePricingHistoryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String zoneId,
      double multiplier,
      DateTime timestamp,
      int activeDrivers,
      int pendingRequests,
      SurgeReason reason,
      double averageFare,
      int completedRides});
}

/// @nodoc
class __$$SurgePricingHistoryImplCopyWithImpl<$Res>
    extends _$SurgePricingHistoryCopyWithImpl<$Res, _$SurgePricingHistoryImpl>
    implements _$$SurgePricingHistoryImplCopyWith<$Res> {
  __$$SurgePricingHistoryImplCopyWithImpl(_$SurgePricingHistoryImpl _value,
      $Res Function(_$SurgePricingHistoryImpl) _then)
      : super(_value, _then);

  /// Create a copy of SurgePricingHistory
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? zoneId = null,
    Object? multiplier = null,
    Object? timestamp = null,
    Object? activeDrivers = null,
    Object? pendingRequests = null,
    Object? reason = null,
    Object? averageFare = null,
    Object? completedRides = null,
  }) {
    return _then(_$SurgePricingHistoryImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      zoneId: null == zoneId
          ? _value.zoneId
          : zoneId // ignore: cast_nullable_to_non_nullable
              as String,
      multiplier: null == multiplier
          ? _value.multiplier
          : multiplier // ignore: cast_nullable_to_non_nullable
              as double,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      activeDrivers: null == activeDrivers
          ? _value.activeDrivers
          : activeDrivers // ignore: cast_nullable_to_non_nullable
              as int,
      pendingRequests: null == pendingRequests
          ? _value.pendingRequests
          : pendingRequests // ignore: cast_nullable_to_non_nullable
              as int,
      reason: null == reason
          ? _value.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as SurgeReason,
      averageFare: null == averageFare
          ? _value.averageFare
          : averageFare // ignore: cast_nullable_to_non_nullable
              as double,
      completedRides: null == completedRides
          ? _value.completedRides
          : completedRides // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SurgePricingHistoryImpl implements _SurgePricingHistory {
  const _$SurgePricingHistoryImpl(
      {required this.id,
      required this.zoneId,
      required this.multiplier,
      required this.timestamp,
      required this.activeDrivers,
      required this.pendingRequests,
      required this.reason,
      required this.averageFare,
      required this.completedRides});

  factory _$SurgePricingHistoryImpl.fromJson(Map<String, dynamic> json) =>
      _$$SurgePricingHistoryImplFromJson(json);

  @override
  final String id;
  @override
  final String zoneId;
  @override
  final double multiplier;
  @override
  final DateTime timestamp;
  @override
  final int activeDrivers;
  @override
  final int pendingRequests;
  @override
  final SurgeReason reason;
  @override
  final double averageFare;
  @override
  final int completedRides;

  @override
  String toString() {
    return 'SurgePricingHistory(id: $id, zoneId: $zoneId, multiplier: $multiplier, timestamp: $timestamp, activeDrivers: $activeDrivers, pendingRequests: $pendingRequests, reason: $reason, averageFare: $averageFare, completedRides: $completedRides)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SurgePricingHistoryImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.zoneId, zoneId) || other.zoneId == zoneId) &&
            (identical(other.multiplier, multiplier) ||
                other.multiplier == multiplier) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.activeDrivers, activeDrivers) ||
                other.activeDrivers == activeDrivers) &&
            (identical(other.pendingRequests, pendingRequests) ||
                other.pendingRequests == pendingRequests) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            (identical(other.averageFare, averageFare) ||
                other.averageFare == averageFare) &&
            (identical(other.completedRides, completedRides) ||
                other.completedRides == completedRides));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      zoneId,
      multiplier,
      timestamp,
      activeDrivers,
      pendingRequests,
      reason,
      averageFare,
      completedRides);

  /// Create a copy of SurgePricingHistory
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SurgePricingHistoryImplCopyWith<_$SurgePricingHistoryImpl> get copyWith =>
      __$$SurgePricingHistoryImplCopyWithImpl<_$SurgePricingHistoryImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SurgePricingHistoryImplToJson(
      this,
    );
  }
}

abstract class _SurgePricingHistory implements SurgePricingHistory {
  const factory _SurgePricingHistory(
      {required final String id,
      required final String zoneId,
      required final double multiplier,
      required final DateTime timestamp,
      required final int activeDrivers,
      required final int pendingRequests,
      required final SurgeReason reason,
      required final double averageFare,
      required final int completedRides}) = _$SurgePricingHistoryImpl;

  factory _SurgePricingHistory.fromJson(Map<String, dynamic> json) =
      _$SurgePricingHistoryImpl.fromJson;

  @override
  String get id;
  @override
  String get zoneId;
  @override
  double get multiplier;
  @override
  DateTime get timestamp;
  @override
  int get activeDrivers;
  @override
  int get pendingRequests;
  @override
  SurgeReason get reason;
  @override
  double get averageFare;
  @override
  int get completedRides;

  /// Create a copy of SurgePricingHistory
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SurgePricingHistoryImplCopyWith<_$SurgePricingHistoryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SurgeZone _$SurgeZoneFromJson(Map<String, dynamic> json) {
  return _SurgeZone.fromJson(json);
}

/// @nodoc
mixin _$SurgeZone {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  double get centerLatitude => throw _privateConstructorUsedError;
  double get centerLongitude => throw _privateConstructorUsedError;
  double get radiusKm => throw _privateConstructorUsedError;
  double get currentMultiplier => throw _privateConstructorUsedError;
  int get activeDrivers => throw _privateConstructorUsedError;
  int get pendingRequests => throw _privateConstructorUsedError;
  DateTime get lastUpdated => throw _privateConstructorUsedError;
  bool get isActive => throw _privateConstructorUsedError;
  String? get polygonGeojson =>
      throw _privateConstructorUsedError; // Para zonas no circulares
  List<SurgePricingHistory> get recentHistory =>
      throw _privateConstructorUsedError;

  /// Serializes this SurgeZone to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SurgeZone
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SurgeZoneCopyWith<SurgeZone> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SurgeZoneCopyWith<$Res> {
  factory $SurgeZoneCopyWith(SurgeZone value, $Res Function(SurgeZone) then) =
      _$SurgeZoneCopyWithImpl<$Res, SurgeZone>;
  @useResult
  $Res call(
      {String id,
      String name,
      double centerLatitude,
      double centerLongitude,
      double radiusKm,
      double currentMultiplier,
      int activeDrivers,
      int pendingRequests,
      DateTime lastUpdated,
      bool isActive,
      String? polygonGeojson,
      List<SurgePricingHistory> recentHistory});
}

/// @nodoc
class _$SurgeZoneCopyWithImpl<$Res, $Val extends SurgeZone>
    implements $SurgeZoneCopyWith<$Res> {
  _$SurgeZoneCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SurgeZone
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? centerLatitude = null,
    Object? centerLongitude = null,
    Object? radiusKm = null,
    Object? currentMultiplier = null,
    Object? activeDrivers = null,
    Object? pendingRequests = null,
    Object? lastUpdated = null,
    Object? isActive = null,
    Object? polygonGeojson = freezed,
    Object? recentHistory = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      centerLatitude: null == centerLatitude
          ? _value.centerLatitude
          : centerLatitude // ignore: cast_nullable_to_non_nullable
              as double,
      centerLongitude: null == centerLongitude
          ? _value.centerLongitude
          : centerLongitude // ignore: cast_nullable_to_non_nullable
              as double,
      radiusKm: null == radiusKm
          ? _value.radiusKm
          : radiusKm // ignore: cast_nullable_to_non_nullable
              as double,
      currentMultiplier: null == currentMultiplier
          ? _value.currentMultiplier
          : currentMultiplier // ignore: cast_nullable_to_non_nullable
              as double,
      activeDrivers: null == activeDrivers
          ? _value.activeDrivers
          : activeDrivers // ignore: cast_nullable_to_non_nullable
              as int,
      pendingRequests: null == pendingRequests
          ? _value.pendingRequests
          : pendingRequests // ignore: cast_nullable_to_non_nullable
              as int,
      lastUpdated: null == lastUpdated
          ? _value.lastUpdated
          : lastUpdated // ignore: cast_nullable_to_non_nullable
              as DateTime,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      polygonGeojson: freezed == polygonGeojson
          ? _value.polygonGeojson
          : polygonGeojson // ignore: cast_nullable_to_non_nullable
              as String?,
      recentHistory: null == recentHistory
          ? _value.recentHistory
          : recentHistory // ignore: cast_nullable_to_non_nullable
              as List<SurgePricingHistory>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SurgeZoneImplCopyWith<$Res>
    implements $SurgeZoneCopyWith<$Res> {
  factory _$$SurgeZoneImplCopyWith(
          _$SurgeZoneImpl value, $Res Function(_$SurgeZoneImpl) then) =
      __$$SurgeZoneImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      double centerLatitude,
      double centerLongitude,
      double radiusKm,
      double currentMultiplier,
      int activeDrivers,
      int pendingRequests,
      DateTime lastUpdated,
      bool isActive,
      String? polygonGeojson,
      List<SurgePricingHistory> recentHistory});
}

/// @nodoc
class __$$SurgeZoneImplCopyWithImpl<$Res>
    extends _$SurgeZoneCopyWithImpl<$Res, _$SurgeZoneImpl>
    implements _$$SurgeZoneImplCopyWith<$Res> {
  __$$SurgeZoneImplCopyWithImpl(
      _$SurgeZoneImpl _value, $Res Function(_$SurgeZoneImpl) _then)
      : super(_value, _then);

  /// Create a copy of SurgeZone
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? centerLatitude = null,
    Object? centerLongitude = null,
    Object? radiusKm = null,
    Object? currentMultiplier = null,
    Object? activeDrivers = null,
    Object? pendingRequests = null,
    Object? lastUpdated = null,
    Object? isActive = null,
    Object? polygonGeojson = freezed,
    Object? recentHistory = null,
  }) {
    return _then(_$SurgeZoneImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      centerLatitude: null == centerLatitude
          ? _value.centerLatitude
          : centerLatitude // ignore: cast_nullable_to_non_nullable
              as double,
      centerLongitude: null == centerLongitude
          ? _value.centerLongitude
          : centerLongitude // ignore: cast_nullable_to_non_nullable
              as double,
      radiusKm: null == radiusKm
          ? _value.radiusKm
          : radiusKm // ignore: cast_nullable_to_non_nullable
              as double,
      currentMultiplier: null == currentMultiplier
          ? _value.currentMultiplier
          : currentMultiplier // ignore: cast_nullable_to_non_nullable
              as double,
      activeDrivers: null == activeDrivers
          ? _value.activeDrivers
          : activeDrivers // ignore: cast_nullable_to_non_nullable
              as int,
      pendingRequests: null == pendingRequests
          ? _value.pendingRequests
          : pendingRequests // ignore: cast_nullable_to_non_nullable
              as int,
      lastUpdated: null == lastUpdated
          ? _value.lastUpdated
          : lastUpdated // ignore: cast_nullable_to_non_nullable
              as DateTime,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      polygonGeojson: freezed == polygonGeojson
          ? _value.polygonGeojson
          : polygonGeojson // ignore: cast_nullable_to_non_nullable
              as String?,
      recentHistory: null == recentHistory
          ? _value._recentHistory
          : recentHistory // ignore: cast_nullable_to_non_nullable
              as List<SurgePricingHistory>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SurgeZoneImpl implements _SurgeZone {
  const _$SurgeZoneImpl(
      {required this.id,
      required this.name,
      required this.centerLatitude,
      required this.centerLongitude,
      required this.radiusKm,
      required this.currentMultiplier,
      required this.activeDrivers,
      required this.pendingRequests,
      required this.lastUpdated,
      this.isActive = true,
      this.polygonGeojson,
      final List<SurgePricingHistory> recentHistory = const []})
      : _recentHistory = recentHistory;

  factory _$SurgeZoneImpl.fromJson(Map<String, dynamic> json) =>
      _$$SurgeZoneImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final double centerLatitude;
  @override
  final double centerLongitude;
  @override
  final double radiusKm;
  @override
  final double currentMultiplier;
  @override
  final int activeDrivers;
  @override
  final int pendingRequests;
  @override
  final DateTime lastUpdated;
  @override
  @JsonKey()
  final bool isActive;
  @override
  final String? polygonGeojson;
// Para zonas no circulares
  final List<SurgePricingHistory> _recentHistory;
// Para zonas no circulares
  @override
  @JsonKey()
  List<SurgePricingHistory> get recentHistory {
    if (_recentHistory is EqualUnmodifiableListView) return _recentHistory;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_recentHistory);
  }

  @override
  String toString() {
    return 'SurgeZone(id: $id, name: $name, centerLatitude: $centerLatitude, centerLongitude: $centerLongitude, radiusKm: $radiusKm, currentMultiplier: $currentMultiplier, activeDrivers: $activeDrivers, pendingRequests: $pendingRequests, lastUpdated: $lastUpdated, isActive: $isActive, polygonGeojson: $polygonGeojson, recentHistory: $recentHistory)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SurgeZoneImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.centerLatitude, centerLatitude) ||
                other.centerLatitude == centerLatitude) &&
            (identical(other.centerLongitude, centerLongitude) ||
                other.centerLongitude == centerLongitude) &&
            (identical(other.radiusKm, radiusKm) ||
                other.radiusKm == radiusKm) &&
            (identical(other.currentMultiplier, currentMultiplier) ||
                other.currentMultiplier == currentMultiplier) &&
            (identical(other.activeDrivers, activeDrivers) ||
                other.activeDrivers == activeDrivers) &&
            (identical(other.pendingRequests, pendingRequests) ||
                other.pendingRequests == pendingRequests) &&
            (identical(other.lastUpdated, lastUpdated) ||
                other.lastUpdated == lastUpdated) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.polygonGeojson, polygonGeojson) ||
                other.polygonGeojson == polygonGeojson) &&
            const DeepCollectionEquality()
                .equals(other._recentHistory, _recentHistory));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      centerLatitude,
      centerLongitude,
      radiusKm,
      currentMultiplier,
      activeDrivers,
      pendingRequests,
      lastUpdated,
      isActive,
      polygonGeojson,
      const DeepCollectionEquality().hash(_recentHistory));

  /// Create a copy of SurgeZone
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SurgeZoneImplCopyWith<_$SurgeZoneImpl> get copyWith =>
      __$$SurgeZoneImplCopyWithImpl<_$SurgeZoneImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SurgeZoneImplToJson(
      this,
    );
  }
}

abstract class _SurgeZone implements SurgeZone {
  const factory _SurgeZone(
      {required final String id,
      required final String name,
      required final double centerLatitude,
      required final double centerLongitude,
      required final double radiusKm,
      required final double currentMultiplier,
      required final int activeDrivers,
      required final int pendingRequests,
      required final DateTime lastUpdated,
      final bool isActive,
      final String? polygonGeojson,
      final List<SurgePricingHistory> recentHistory}) = _$SurgeZoneImpl;

  factory _SurgeZone.fromJson(Map<String, dynamic> json) =
      _$SurgeZoneImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  double get centerLatitude;
  @override
  double get centerLongitude;
  @override
  double get radiusKm;
  @override
  double get currentMultiplier;
  @override
  int get activeDrivers;
  @override
  int get pendingRequests;
  @override
  DateTime get lastUpdated;
  @override
  bool get isActive;
  @override
  String? get polygonGeojson; // Para zonas no circulares
  @override
  List<SurgePricingHistory> get recentHistory;

  /// Create a copy of SurgeZone
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SurgeZoneImplCopyWith<_$SurgeZoneImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
