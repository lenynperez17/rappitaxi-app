// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ride_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

RideModel _$RideModelFromJson(Map<String, dynamic> json) {
  return _RideModel.fromJson(json);
}

/// @nodoc
mixin _$RideModel {
  String get id => throw _privateConstructorUsedError;
  String get passengerId => throw _privateConstructorUsedError;
  String get driverId => throw _privateConstructorUsedError;
  LocationModel get pickup => throw _privateConstructorUsedError;
  LocationModel get destination => throw _privateConstructorUsedError;
  DateTime get requestedAt => throw _privateConstructorUsedError;
  DateTime? get acceptedAt => throw _privateConstructorUsedError;
  DateTime? get startedAt => throw _privateConstructorUsedError;
  DateTime? get completedAt => throw _privateConstructorUsedError;
  DateTime? get cancelledAt => throw _privateConstructorUsedError;
  String get status =>
      throw _privateConstructorUsedError; // requested, accepted, arriving, in_progress, completed, cancelled
  String get vehicleType =>
      throw _privateConstructorUsedError; // economy, standard, premium
  double get fare => throw _privateConstructorUsedError;
  double get distance => throw _privateConstructorUsedError; // en kilómetros
  int get duration => throw _privateConstructorUsedError; // en minutos
  String get paymentMethod => throw _privateConstructorUsedError;
  String? get paymentIntentId => throw _privateConstructorUsedError;
  double? get rating => throw _privateConstructorUsedError;
  String? get comment => throw _privateConstructorUsedError;
  String? get cancellationReason => throw _privateConstructorUsedError;
  String? get cancelledBy =>
      throw _privateConstructorUsedError; // passenger, driver, system
  DriverInfo? get driverInfo => throw _privateConstructorUsedError;
  PassengerInfo? get passengerInfo => throw _privateConstructorUsedError;
  RideVehicleInfo? get vehicleInfo => throw _privateConstructorUsedError;
  List<RoutePoint> get routePoints => throw _privateConstructorUsedError;
  Map<String, dynamic>? get metadata => throw _privateConstructorUsedError;

  /// Serializes this RideModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RideModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RideModelCopyWith<RideModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RideModelCopyWith<$Res> {
  factory $RideModelCopyWith(RideModel value, $Res Function(RideModel) then) =
      _$RideModelCopyWithImpl<$Res, RideModel>;
  @useResult
  $Res call(
      {String id,
      String passengerId,
      String driverId,
      LocationModel pickup,
      LocationModel destination,
      DateTime requestedAt,
      DateTime? acceptedAt,
      DateTime? startedAt,
      DateTime? completedAt,
      DateTime? cancelledAt,
      String status,
      String vehicleType,
      double fare,
      double distance,
      int duration,
      String paymentMethod,
      String? paymentIntentId,
      double? rating,
      String? comment,
      String? cancellationReason,
      String? cancelledBy,
      DriverInfo? driverInfo,
      PassengerInfo? passengerInfo,
      RideVehicleInfo? vehicleInfo,
      List<RoutePoint> routePoints,
      Map<String, dynamic>? metadata});

  $LocationModelCopyWith<$Res> get pickup;
  $LocationModelCopyWith<$Res> get destination;
  $DriverInfoCopyWith<$Res>? get driverInfo;
  $PassengerInfoCopyWith<$Res>? get passengerInfo;
  $RideVehicleInfoCopyWith<$Res>? get vehicleInfo;
}

/// @nodoc
class _$RideModelCopyWithImpl<$Res, $Val extends RideModel>
    implements $RideModelCopyWith<$Res> {
  _$RideModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RideModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? passengerId = null,
    Object? driverId = null,
    Object? pickup = null,
    Object? destination = null,
    Object? requestedAt = null,
    Object? acceptedAt = freezed,
    Object? startedAt = freezed,
    Object? completedAt = freezed,
    Object? cancelledAt = freezed,
    Object? status = null,
    Object? vehicleType = null,
    Object? fare = null,
    Object? distance = null,
    Object? duration = null,
    Object? paymentMethod = null,
    Object? paymentIntentId = freezed,
    Object? rating = freezed,
    Object? comment = freezed,
    Object? cancellationReason = freezed,
    Object? cancelledBy = freezed,
    Object? driverInfo = freezed,
    Object? passengerInfo = freezed,
    Object? vehicleInfo = freezed,
    Object? routePoints = null,
    Object? metadata = freezed,
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
      driverId: null == driverId
          ? _value.driverId
          : driverId // ignore: cast_nullable_to_non_nullable
              as String,
      pickup: null == pickup
          ? _value.pickup
          : pickup // ignore: cast_nullable_to_non_nullable
              as LocationModel,
      destination: null == destination
          ? _value.destination
          : destination // ignore: cast_nullable_to_non_nullable
              as LocationModel,
      requestedAt: null == requestedAt
          ? _value.requestedAt
          : requestedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      acceptedAt: freezed == acceptedAt
          ? _value.acceptedAt
          : acceptedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      startedAt: freezed == startedAt
          ? _value.startedAt
          : startedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      completedAt: freezed == completedAt
          ? _value.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      cancelledAt: freezed == cancelledAt
          ? _value.cancelledAt
          : cancelledAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      vehicleType: null == vehicleType
          ? _value.vehicleType
          : vehicleType // ignore: cast_nullable_to_non_nullable
              as String,
      fare: null == fare
          ? _value.fare
          : fare // ignore: cast_nullable_to_non_nullable
              as double,
      distance: null == distance
          ? _value.distance
          : distance // ignore: cast_nullable_to_non_nullable
              as double,
      duration: null == duration
          ? _value.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as int,
      paymentMethod: null == paymentMethod
          ? _value.paymentMethod
          : paymentMethod // ignore: cast_nullable_to_non_nullable
              as String,
      paymentIntentId: freezed == paymentIntentId
          ? _value.paymentIntentId
          : paymentIntentId // ignore: cast_nullable_to_non_nullable
              as String?,
      rating: freezed == rating
          ? _value.rating
          : rating // ignore: cast_nullable_to_non_nullable
              as double?,
      comment: freezed == comment
          ? _value.comment
          : comment // ignore: cast_nullable_to_non_nullable
              as String?,
      cancellationReason: freezed == cancellationReason
          ? _value.cancellationReason
          : cancellationReason // ignore: cast_nullable_to_non_nullable
              as String?,
      cancelledBy: freezed == cancelledBy
          ? _value.cancelledBy
          : cancelledBy // ignore: cast_nullable_to_non_nullable
              as String?,
      driverInfo: freezed == driverInfo
          ? _value.driverInfo
          : driverInfo // ignore: cast_nullable_to_non_nullable
              as DriverInfo?,
      passengerInfo: freezed == passengerInfo
          ? _value.passengerInfo
          : passengerInfo // ignore: cast_nullable_to_non_nullable
              as PassengerInfo?,
      vehicleInfo: freezed == vehicleInfo
          ? _value.vehicleInfo
          : vehicleInfo // ignore: cast_nullable_to_non_nullable
              as RideVehicleInfo?,
      routePoints: null == routePoints
          ? _value.routePoints
          : routePoints // ignore: cast_nullable_to_non_nullable
              as List<RoutePoint>,
      metadata: freezed == metadata
          ? _value.metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ) as $Val);
  }

  /// Create a copy of RideModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $LocationModelCopyWith<$Res> get pickup {
    return $LocationModelCopyWith<$Res>(_value.pickup, (value) {
      return _then(_value.copyWith(pickup: value) as $Val);
    });
  }

  /// Create a copy of RideModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $LocationModelCopyWith<$Res> get destination {
    return $LocationModelCopyWith<$Res>(_value.destination, (value) {
      return _then(_value.copyWith(destination: value) as $Val);
    });
  }

  /// Create a copy of RideModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $DriverInfoCopyWith<$Res>? get driverInfo {
    if (_value.driverInfo == null) {
      return null;
    }

    return $DriverInfoCopyWith<$Res>(_value.driverInfo!, (value) {
      return _then(_value.copyWith(driverInfo: value) as $Val);
    });
  }

  /// Create a copy of RideModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PassengerInfoCopyWith<$Res>? get passengerInfo {
    if (_value.passengerInfo == null) {
      return null;
    }

    return $PassengerInfoCopyWith<$Res>(_value.passengerInfo!, (value) {
      return _then(_value.copyWith(passengerInfo: value) as $Val);
    });
  }

  /// Create a copy of RideModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $RideVehicleInfoCopyWith<$Res>? get vehicleInfo {
    if (_value.vehicleInfo == null) {
      return null;
    }

    return $RideVehicleInfoCopyWith<$Res>(_value.vehicleInfo!, (value) {
      return _then(_value.copyWith(vehicleInfo: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$RideModelImplCopyWith<$Res>
    implements $RideModelCopyWith<$Res> {
  factory _$$RideModelImplCopyWith(
          _$RideModelImpl value, $Res Function(_$RideModelImpl) then) =
      __$$RideModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String passengerId,
      String driverId,
      LocationModel pickup,
      LocationModel destination,
      DateTime requestedAt,
      DateTime? acceptedAt,
      DateTime? startedAt,
      DateTime? completedAt,
      DateTime? cancelledAt,
      String status,
      String vehicleType,
      double fare,
      double distance,
      int duration,
      String paymentMethod,
      String? paymentIntentId,
      double? rating,
      String? comment,
      String? cancellationReason,
      String? cancelledBy,
      DriverInfo? driverInfo,
      PassengerInfo? passengerInfo,
      RideVehicleInfo? vehicleInfo,
      List<RoutePoint> routePoints,
      Map<String, dynamic>? metadata});

  @override
  $LocationModelCopyWith<$Res> get pickup;
  @override
  $LocationModelCopyWith<$Res> get destination;
  @override
  $DriverInfoCopyWith<$Res>? get driverInfo;
  @override
  $PassengerInfoCopyWith<$Res>? get passengerInfo;
  @override
  $RideVehicleInfoCopyWith<$Res>? get vehicleInfo;
}

/// @nodoc
class __$$RideModelImplCopyWithImpl<$Res>
    extends _$RideModelCopyWithImpl<$Res, _$RideModelImpl>
    implements _$$RideModelImplCopyWith<$Res> {
  __$$RideModelImplCopyWithImpl(
      _$RideModelImpl _value, $Res Function(_$RideModelImpl) _then)
      : super(_value, _then);

  /// Create a copy of RideModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? passengerId = null,
    Object? driverId = null,
    Object? pickup = null,
    Object? destination = null,
    Object? requestedAt = null,
    Object? acceptedAt = freezed,
    Object? startedAt = freezed,
    Object? completedAt = freezed,
    Object? cancelledAt = freezed,
    Object? status = null,
    Object? vehicleType = null,
    Object? fare = null,
    Object? distance = null,
    Object? duration = null,
    Object? paymentMethod = null,
    Object? paymentIntentId = freezed,
    Object? rating = freezed,
    Object? comment = freezed,
    Object? cancellationReason = freezed,
    Object? cancelledBy = freezed,
    Object? driverInfo = freezed,
    Object? passengerInfo = freezed,
    Object? vehicleInfo = freezed,
    Object? routePoints = null,
    Object? metadata = freezed,
  }) {
    return _then(_$RideModelImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      passengerId: null == passengerId
          ? _value.passengerId
          : passengerId // ignore: cast_nullable_to_non_nullable
              as String,
      driverId: null == driverId
          ? _value.driverId
          : driverId // ignore: cast_nullable_to_non_nullable
              as String,
      pickup: null == pickup
          ? _value.pickup
          : pickup // ignore: cast_nullable_to_non_nullable
              as LocationModel,
      destination: null == destination
          ? _value.destination
          : destination // ignore: cast_nullable_to_non_nullable
              as LocationModel,
      requestedAt: null == requestedAt
          ? _value.requestedAt
          : requestedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      acceptedAt: freezed == acceptedAt
          ? _value.acceptedAt
          : acceptedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      startedAt: freezed == startedAt
          ? _value.startedAt
          : startedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      completedAt: freezed == completedAt
          ? _value.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      cancelledAt: freezed == cancelledAt
          ? _value.cancelledAt
          : cancelledAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      vehicleType: null == vehicleType
          ? _value.vehicleType
          : vehicleType // ignore: cast_nullable_to_non_nullable
              as String,
      fare: null == fare
          ? _value.fare
          : fare // ignore: cast_nullable_to_non_nullable
              as double,
      distance: null == distance
          ? _value.distance
          : distance // ignore: cast_nullable_to_non_nullable
              as double,
      duration: null == duration
          ? _value.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as int,
      paymentMethod: null == paymentMethod
          ? _value.paymentMethod
          : paymentMethod // ignore: cast_nullable_to_non_nullable
              as String,
      paymentIntentId: freezed == paymentIntentId
          ? _value.paymentIntentId
          : paymentIntentId // ignore: cast_nullable_to_non_nullable
              as String?,
      rating: freezed == rating
          ? _value.rating
          : rating // ignore: cast_nullable_to_non_nullable
              as double?,
      comment: freezed == comment
          ? _value.comment
          : comment // ignore: cast_nullable_to_non_nullable
              as String?,
      cancellationReason: freezed == cancellationReason
          ? _value.cancellationReason
          : cancellationReason // ignore: cast_nullable_to_non_nullable
              as String?,
      cancelledBy: freezed == cancelledBy
          ? _value.cancelledBy
          : cancelledBy // ignore: cast_nullable_to_non_nullable
              as String?,
      driverInfo: freezed == driverInfo
          ? _value.driverInfo
          : driverInfo // ignore: cast_nullable_to_non_nullable
              as DriverInfo?,
      passengerInfo: freezed == passengerInfo
          ? _value.passengerInfo
          : passengerInfo // ignore: cast_nullable_to_non_nullable
              as PassengerInfo?,
      vehicleInfo: freezed == vehicleInfo
          ? _value.vehicleInfo
          : vehicleInfo // ignore: cast_nullable_to_non_nullable
              as RideVehicleInfo?,
      routePoints: null == routePoints
          ? _value._routePoints
          : routePoints // ignore: cast_nullable_to_non_nullable
              as List<RoutePoint>,
      metadata: freezed == metadata
          ? _value._metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$RideModelImpl implements _RideModel {
  const _$RideModelImpl(
      {required this.id,
      required this.passengerId,
      required this.driverId,
      required this.pickup,
      required this.destination,
      required this.requestedAt,
      this.acceptedAt,
      this.startedAt,
      this.completedAt,
      this.cancelledAt,
      required this.status,
      required this.vehicleType,
      required this.fare,
      required this.distance,
      required this.duration,
      required this.paymentMethod,
      this.paymentIntentId,
      this.rating,
      this.comment,
      this.cancellationReason,
      this.cancelledBy,
      this.driverInfo,
      this.passengerInfo,
      this.vehicleInfo,
      final List<RoutePoint> routePoints = const [],
      final Map<String, dynamic>? metadata})
      : _routePoints = routePoints,
        _metadata = metadata;

  factory _$RideModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$RideModelImplFromJson(json);

  @override
  final String id;
  @override
  final String passengerId;
  @override
  final String driverId;
  @override
  final LocationModel pickup;
  @override
  final LocationModel destination;
  @override
  final DateTime requestedAt;
  @override
  final DateTime? acceptedAt;
  @override
  final DateTime? startedAt;
  @override
  final DateTime? completedAt;
  @override
  final DateTime? cancelledAt;
  @override
  final String status;
// requested, accepted, arriving, in_progress, completed, cancelled
  @override
  final String vehicleType;
// economy, standard, premium
  @override
  final double fare;
  @override
  final double distance;
// en kilómetros
  @override
  final int duration;
// en minutos
  @override
  final String paymentMethod;
  @override
  final String? paymentIntentId;
  @override
  final double? rating;
  @override
  final String? comment;
  @override
  final String? cancellationReason;
  @override
  final String? cancelledBy;
// passenger, driver, system
  @override
  final DriverInfo? driverInfo;
  @override
  final PassengerInfo? passengerInfo;
  @override
  final RideVehicleInfo? vehicleInfo;
  final List<RoutePoint> _routePoints;
  @override
  @JsonKey()
  List<RoutePoint> get routePoints {
    if (_routePoints is EqualUnmodifiableListView) return _routePoints;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_routePoints);
  }

  final Map<String, dynamic>? _metadata;
  @override
  Map<String, dynamic>? get metadata {
    final value = _metadata;
    if (value == null) return null;
    if (_metadata is EqualUnmodifiableMapView) return _metadata;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  String toString() {
    return 'RideModel(id: $id, passengerId: $passengerId, driverId: $driverId, pickup: $pickup, destination: $destination, requestedAt: $requestedAt, acceptedAt: $acceptedAt, startedAt: $startedAt, completedAt: $completedAt, cancelledAt: $cancelledAt, status: $status, vehicleType: $vehicleType, fare: $fare, distance: $distance, duration: $duration, paymentMethod: $paymentMethod, paymentIntentId: $paymentIntentId, rating: $rating, comment: $comment, cancellationReason: $cancellationReason, cancelledBy: $cancelledBy, driverInfo: $driverInfo, passengerInfo: $passengerInfo, vehicleInfo: $vehicleInfo, routePoints: $routePoints, metadata: $metadata)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RideModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.passengerId, passengerId) ||
                other.passengerId == passengerId) &&
            (identical(other.driverId, driverId) ||
                other.driverId == driverId) &&
            (identical(other.pickup, pickup) || other.pickup == pickup) &&
            (identical(other.destination, destination) ||
                other.destination == destination) &&
            (identical(other.requestedAt, requestedAt) ||
                other.requestedAt == requestedAt) &&
            (identical(other.acceptedAt, acceptedAt) ||
                other.acceptedAt == acceptedAt) &&
            (identical(other.startedAt, startedAt) ||
                other.startedAt == startedAt) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt) &&
            (identical(other.cancelledAt, cancelledAt) ||
                other.cancelledAt == cancelledAt) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.vehicleType, vehicleType) ||
                other.vehicleType == vehicleType) &&
            (identical(other.fare, fare) || other.fare == fare) &&
            (identical(other.distance, distance) ||
                other.distance == distance) &&
            (identical(other.duration, duration) ||
                other.duration == duration) &&
            (identical(other.paymentMethod, paymentMethod) ||
                other.paymentMethod == paymentMethod) &&
            (identical(other.paymentIntentId, paymentIntentId) ||
                other.paymentIntentId == paymentIntentId) &&
            (identical(other.rating, rating) || other.rating == rating) &&
            (identical(other.comment, comment) || other.comment == comment) &&
            (identical(other.cancellationReason, cancellationReason) ||
                other.cancellationReason == cancellationReason) &&
            (identical(other.cancelledBy, cancelledBy) ||
                other.cancelledBy == cancelledBy) &&
            (identical(other.driverInfo, driverInfo) ||
                other.driverInfo == driverInfo) &&
            (identical(other.passengerInfo, passengerInfo) ||
                other.passengerInfo == passengerInfo) &&
            (identical(other.vehicleInfo, vehicleInfo) ||
                other.vehicleInfo == vehicleInfo) &&
            const DeepCollectionEquality()
                .equals(other._routePoints, _routePoints) &&
            const DeepCollectionEquality().equals(other._metadata, _metadata));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        passengerId,
        driverId,
        pickup,
        destination,
        requestedAt,
        acceptedAt,
        startedAt,
        completedAt,
        cancelledAt,
        status,
        vehicleType,
        fare,
        distance,
        duration,
        paymentMethod,
        paymentIntentId,
        rating,
        comment,
        cancellationReason,
        cancelledBy,
        driverInfo,
        passengerInfo,
        vehicleInfo,
        const DeepCollectionEquality().hash(_routePoints),
        const DeepCollectionEquality().hash(_metadata)
      ]);

  /// Create a copy of RideModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RideModelImplCopyWith<_$RideModelImpl> get copyWith =>
      __$$RideModelImplCopyWithImpl<_$RideModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$RideModelImplToJson(
      this,
    );
  }
}

abstract class _RideModel implements RideModel {
  const factory _RideModel(
      {required final String id,
      required final String passengerId,
      required final String driverId,
      required final LocationModel pickup,
      required final LocationModel destination,
      required final DateTime requestedAt,
      final DateTime? acceptedAt,
      final DateTime? startedAt,
      final DateTime? completedAt,
      final DateTime? cancelledAt,
      required final String status,
      required final String vehicleType,
      required final double fare,
      required final double distance,
      required final int duration,
      required final String paymentMethod,
      final String? paymentIntentId,
      final double? rating,
      final String? comment,
      final String? cancellationReason,
      final String? cancelledBy,
      final DriverInfo? driverInfo,
      final PassengerInfo? passengerInfo,
      final RideVehicleInfo? vehicleInfo,
      final List<RoutePoint> routePoints,
      final Map<String, dynamic>? metadata}) = _$RideModelImpl;

  factory _RideModel.fromJson(Map<String, dynamic> json) =
      _$RideModelImpl.fromJson;

  @override
  String get id;
  @override
  String get passengerId;
  @override
  String get driverId;
  @override
  LocationModel get pickup;
  @override
  LocationModel get destination;
  @override
  DateTime get requestedAt;
  @override
  DateTime? get acceptedAt;
  @override
  DateTime? get startedAt;
  @override
  DateTime? get completedAt;
  @override
  DateTime? get cancelledAt;
  @override
  String
      get status; // requested, accepted, arriving, in_progress, completed, cancelled
  @override
  String get vehicleType; // economy, standard, premium
  @override
  double get fare;
  @override
  double get distance; // en kilómetros
  @override
  int get duration; // en minutos
  @override
  String get paymentMethod;
  @override
  String? get paymentIntentId;
  @override
  double? get rating;
  @override
  String? get comment;
  @override
  String? get cancellationReason;
  @override
  String? get cancelledBy; // passenger, driver, system
  @override
  DriverInfo? get driverInfo;
  @override
  PassengerInfo? get passengerInfo;
  @override
  RideVehicleInfo? get vehicleInfo;
  @override
  List<RoutePoint> get routePoints;
  @override
  Map<String, dynamic>? get metadata;

  /// Create a copy of RideModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RideModelImplCopyWith<_$RideModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

DriverInfo _$DriverInfoFromJson(Map<String, dynamic> json) {
  return _DriverInfo.fromJson(json);
}

/// @nodoc
mixin _$DriverInfo {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get phone => throw _privateConstructorUsedError;
  String? get photoUrl => throw _privateConstructorUsedError;
  double get rating => throw _privateConstructorUsedError;
  int get totalRides => throw _privateConstructorUsedError;

  /// Serializes this DriverInfo to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DriverInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DriverInfoCopyWith<DriverInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DriverInfoCopyWith<$Res> {
  factory $DriverInfoCopyWith(
          DriverInfo value, $Res Function(DriverInfo) then) =
      _$DriverInfoCopyWithImpl<$Res, DriverInfo>;
  @useResult
  $Res call(
      {String id,
      String name,
      String phone,
      String? photoUrl,
      double rating,
      int totalRides});
}

/// @nodoc
class _$DriverInfoCopyWithImpl<$Res, $Val extends DriverInfo>
    implements $DriverInfoCopyWith<$Res> {
  _$DriverInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DriverInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? phone = null,
    Object? photoUrl = freezed,
    Object? rating = null,
    Object? totalRides = null,
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
      phone: null == phone
          ? _value.phone
          : phone // ignore: cast_nullable_to_non_nullable
              as String,
      photoUrl: freezed == photoUrl
          ? _value.photoUrl
          : photoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      rating: null == rating
          ? _value.rating
          : rating // ignore: cast_nullable_to_non_nullable
              as double,
      totalRides: null == totalRides
          ? _value.totalRides
          : totalRides // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DriverInfoImplCopyWith<$Res>
    implements $DriverInfoCopyWith<$Res> {
  factory _$$DriverInfoImplCopyWith(
          _$DriverInfoImpl value, $Res Function(_$DriverInfoImpl) then) =
      __$$DriverInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String phone,
      String? photoUrl,
      double rating,
      int totalRides});
}

/// @nodoc
class __$$DriverInfoImplCopyWithImpl<$Res>
    extends _$DriverInfoCopyWithImpl<$Res, _$DriverInfoImpl>
    implements _$$DriverInfoImplCopyWith<$Res> {
  __$$DriverInfoImplCopyWithImpl(
      _$DriverInfoImpl _value, $Res Function(_$DriverInfoImpl) _then)
      : super(_value, _then);

  /// Create a copy of DriverInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? phone = null,
    Object? photoUrl = freezed,
    Object? rating = null,
    Object? totalRides = null,
  }) {
    return _then(_$DriverInfoImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      phone: null == phone
          ? _value.phone
          : phone // ignore: cast_nullable_to_non_nullable
              as String,
      photoUrl: freezed == photoUrl
          ? _value.photoUrl
          : photoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      rating: null == rating
          ? _value.rating
          : rating // ignore: cast_nullable_to_non_nullable
              as double,
      totalRides: null == totalRides
          ? _value.totalRides
          : totalRides // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$DriverInfoImpl implements _DriverInfo {
  const _$DriverInfoImpl(
      {required this.id,
      required this.name,
      required this.phone,
      this.photoUrl,
      required this.rating,
      required this.totalRides});

  factory _$DriverInfoImpl.fromJson(Map<String, dynamic> json) =>
      _$$DriverInfoImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String phone;
  @override
  final String? photoUrl;
  @override
  final double rating;
  @override
  final int totalRides;

  @override
  String toString() {
    return 'DriverInfo(id: $id, name: $name, phone: $phone, photoUrl: $photoUrl, rating: $rating, totalRides: $totalRides)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DriverInfoImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.phone, phone) || other.phone == phone) &&
            (identical(other.photoUrl, photoUrl) ||
                other.photoUrl == photoUrl) &&
            (identical(other.rating, rating) || other.rating == rating) &&
            (identical(other.totalRides, totalRides) ||
                other.totalRides == totalRides));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, name, phone, photoUrl, rating, totalRides);

  /// Create a copy of DriverInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DriverInfoImplCopyWith<_$DriverInfoImpl> get copyWith =>
      __$$DriverInfoImplCopyWithImpl<_$DriverInfoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$DriverInfoImplToJson(
      this,
    );
  }
}

abstract class _DriverInfo implements DriverInfo {
  const factory _DriverInfo(
      {required final String id,
      required final String name,
      required final String phone,
      final String? photoUrl,
      required final double rating,
      required final int totalRides}) = _$DriverInfoImpl;

  factory _DriverInfo.fromJson(Map<String, dynamic> json) =
      _$DriverInfoImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get phone;
  @override
  String? get photoUrl;
  @override
  double get rating;
  @override
  int get totalRides;

  /// Create a copy of DriverInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DriverInfoImplCopyWith<_$DriverInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

RideVehicleInfo _$RideVehicleInfoFromJson(Map<String, dynamic> json) {
  return _RideVehicleInfo.fromJson(json);
}

/// @nodoc
mixin _$RideVehicleInfo {
  String get plate => throw _privateConstructorUsedError;
  String get brand => throw _privateConstructorUsedError;
  String get model => throw _privateConstructorUsedError;
  String get color => throw _privateConstructorUsedError;
  int get year => throw _privateConstructorUsedError;

  /// Serializes this RideVehicleInfo to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RideVehicleInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RideVehicleInfoCopyWith<RideVehicleInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RideVehicleInfoCopyWith<$Res> {
  factory $RideVehicleInfoCopyWith(
          RideVehicleInfo value, $Res Function(RideVehicleInfo) then) =
      _$RideVehicleInfoCopyWithImpl<$Res, RideVehicleInfo>;
  @useResult
  $Res call({String plate, String brand, String model, String color, int year});
}

/// @nodoc
class _$RideVehicleInfoCopyWithImpl<$Res, $Val extends RideVehicleInfo>
    implements $RideVehicleInfoCopyWith<$Res> {
  _$RideVehicleInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RideVehicleInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? plate = null,
    Object? brand = null,
    Object? model = null,
    Object? color = null,
    Object? year = null,
  }) {
    return _then(_value.copyWith(
      plate: null == plate
          ? _value.plate
          : plate // ignore: cast_nullable_to_non_nullable
              as String,
      brand: null == brand
          ? _value.brand
          : brand // ignore: cast_nullable_to_non_nullable
              as String,
      model: null == model
          ? _value.model
          : model // ignore: cast_nullable_to_non_nullable
              as String,
      color: null == color
          ? _value.color
          : color // ignore: cast_nullable_to_non_nullable
              as String,
      year: null == year
          ? _value.year
          : year // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$RideVehicleInfoImplCopyWith<$Res>
    implements $RideVehicleInfoCopyWith<$Res> {
  factory _$$RideVehicleInfoImplCopyWith(_$RideVehicleInfoImpl value,
          $Res Function(_$RideVehicleInfoImpl) then) =
      __$$RideVehicleInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String plate, String brand, String model, String color, int year});
}

/// @nodoc
class __$$RideVehicleInfoImplCopyWithImpl<$Res>
    extends _$RideVehicleInfoCopyWithImpl<$Res, _$RideVehicleInfoImpl>
    implements _$$RideVehicleInfoImplCopyWith<$Res> {
  __$$RideVehicleInfoImplCopyWithImpl(
      _$RideVehicleInfoImpl _value, $Res Function(_$RideVehicleInfoImpl) _then)
      : super(_value, _then);

  /// Create a copy of RideVehicleInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? plate = null,
    Object? brand = null,
    Object? model = null,
    Object? color = null,
    Object? year = null,
  }) {
    return _then(_$RideVehicleInfoImpl(
      plate: null == plate
          ? _value.plate
          : plate // ignore: cast_nullable_to_non_nullable
              as String,
      brand: null == brand
          ? _value.brand
          : brand // ignore: cast_nullable_to_non_nullable
              as String,
      model: null == model
          ? _value.model
          : model // ignore: cast_nullable_to_non_nullable
              as String,
      color: null == color
          ? _value.color
          : color // ignore: cast_nullable_to_non_nullable
              as String,
      year: null == year
          ? _value.year
          : year // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$RideVehicleInfoImpl implements _RideVehicleInfo {
  const _$RideVehicleInfoImpl(
      {required this.plate,
      required this.brand,
      required this.model,
      required this.color,
      required this.year});

  factory _$RideVehicleInfoImpl.fromJson(Map<String, dynamic> json) =>
      _$$RideVehicleInfoImplFromJson(json);

  @override
  final String plate;
  @override
  final String brand;
  @override
  final String model;
  @override
  final String color;
  @override
  final int year;

  @override
  String toString() {
    return 'RideVehicleInfo(plate: $plate, brand: $brand, model: $model, color: $color, year: $year)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RideVehicleInfoImpl &&
            (identical(other.plate, plate) || other.plate == plate) &&
            (identical(other.brand, brand) || other.brand == brand) &&
            (identical(other.model, model) || other.model == model) &&
            (identical(other.color, color) || other.color == color) &&
            (identical(other.year, year) || other.year == year));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, plate, brand, model, color, year);

  /// Create a copy of RideVehicleInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RideVehicleInfoImplCopyWith<_$RideVehicleInfoImpl> get copyWith =>
      __$$RideVehicleInfoImplCopyWithImpl<_$RideVehicleInfoImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$RideVehicleInfoImplToJson(
      this,
    );
  }
}

abstract class _RideVehicleInfo implements RideVehicleInfo {
  const factory _RideVehicleInfo(
      {required final String plate,
      required final String brand,
      required final String model,
      required final String color,
      required final int year}) = _$RideVehicleInfoImpl;

  factory _RideVehicleInfo.fromJson(Map<String, dynamic> json) =
      _$RideVehicleInfoImpl.fromJson;

  @override
  String get plate;
  @override
  String get brand;
  @override
  String get model;
  @override
  String get color;
  @override
  int get year;

  /// Create a copy of RideVehicleInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RideVehicleInfoImplCopyWith<_$RideVehicleInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

RoutePoint _$RoutePointFromJson(Map<String, dynamic> json) {
  return _RoutePoint.fromJson(json);
}

/// @nodoc
mixin _$RoutePoint {
  double get latitude => throw _privateConstructorUsedError;
  double get longitude => throw _privateConstructorUsedError;
  DateTime get timestamp => throw _privateConstructorUsedError;

  /// Serializes this RoutePoint to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RoutePoint
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RoutePointCopyWith<RoutePoint> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RoutePointCopyWith<$Res> {
  factory $RoutePointCopyWith(
          RoutePoint value, $Res Function(RoutePoint) then) =
      _$RoutePointCopyWithImpl<$Res, RoutePoint>;
  @useResult
  $Res call({double latitude, double longitude, DateTime timestamp});
}

/// @nodoc
class _$RoutePointCopyWithImpl<$Res, $Val extends RoutePoint>
    implements $RoutePointCopyWith<$Res> {
  _$RoutePointCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RoutePoint
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? latitude = null,
    Object? longitude = null,
    Object? timestamp = null,
  }) {
    return _then(_value.copyWith(
      latitude: null == latitude
          ? _value.latitude
          : latitude // ignore: cast_nullable_to_non_nullable
              as double,
      longitude: null == longitude
          ? _value.longitude
          : longitude // ignore: cast_nullable_to_non_nullable
              as double,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$RoutePointImplCopyWith<$Res>
    implements $RoutePointCopyWith<$Res> {
  factory _$$RoutePointImplCopyWith(
          _$RoutePointImpl value, $Res Function(_$RoutePointImpl) then) =
      __$$RoutePointImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({double latitude, double longitude, DateTime timestamp});
}

/// @nodoc
class __$$RoutePointImplCopyWithImpl<$Res>
    extends _$RoutePointCopyWithImpl<$Res, _$RoutePointImpl>
    implements _$$RoutePointImplCopyWith<$Res> {
  __$$RoutePointImplCopyWithImpl(
      _$RoutePointImpl _value, $Res Function(_$RoutePointImpl) _then)
      : super(_value, _then);

  /// Create a copy of RoutePoint
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? latitude = null,
    Object? longitude = null,
    Object? timestamp = null,
  }) {
    return _then(_$RoutePointImpl(
      latitude: null == latitude
          ? _value.latitude
          : latitude // ignore: cast_nullable_to_non_nullable
              as double,
      longitude: null == longitude
          ? _value.longitude
          : longitude // ignore: cast_nullable_to_non_nullable
              as double,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$RoutePointImpl implements _RoutePoint {
  const _$RoutePointImpl(
      {required this.latitude,
      required this.longitude,
      required this.timestamp});

  factory _$RoutePointImpl.fromJson(Map<String, dynamic> json) =>
      _$$RoutePointImplFromJson(json);

  @override
  final double latitude;
  @override
  final double longitude;
  @override
  final DateTime timestamp;

  @override
  String toString() {
    return 'RoutePoint(latitude: $latitude, longitude: $longitude, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RoutePointImpl &&
            (identical(other.latitude, latitude) ||
                other.latitude == latitude) &&
            (identical(other.longitude, longitude) ||
                other.longitude == longitude) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, latitude, longitude, timestamp);

  /// Create a copy of RoutePoint
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RoutePointImplCopyWith<_$RoutePointImpl> get copyWith =>
      __$$RoutePointImplCopyWithImpl<_$RoutePointImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$RoutePointImplToJson(
      this,
    );
  }
}

abstract class _RoutePoint implements RoutePoint {
  const factory _RoutePoint(
      {required final double latitude,
      required final double longitude,
      required final DateTime timestamp}) = _$RoutePointImpl;

  factory _RoutePoint.fromJson(Map<String, dynamic> json) =
      _$RoutePointImpl.fromJson;

  @override
  double get latitude;
  @override
  double get longitude;
  @override
  DateTime get timestamp;

  /// Create a copy of RoutePoint
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RoutePointImplCopyWith<_$RoutePointImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PassengerInfo _$PassengerInfoFromJson(Map<String, dynamic> json) {
  return _PassengerInfo.fromJson(json);
}

/// @nodoc
mixin _$PassengerInfo {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get phone => throw _privateConstructorUsedError;
  String? get photoUrl => throw _privateConstructorUsedError;
  double get rating => throw _privateConstructorUsedError;
  int get totalRides => throw _privateConstructorUsedError;

  /// Serializes this PassengerInfo to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PassengerInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PassengerInfoCopyWith<PassengerInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PassengerInfoCopyWith<$Res> {
  factory $PassengerInfoCopyWith(
          PassengerInfo value, $Res Function(PassengerInfo) then) =
      _$PassengerInfoCopyWithImpl<$Res, PassengerInfo>;
  @useResult
  $Res call(
      {String id,
      String name,
      String phone,
      String? photoUrl,
      double rating,
      int totalRides});
}

/// @nodoc
class _$PassengerInfoCopyWithImpl<$Res, $Val extends PassengerInfo>
    implements $PassengerInfoCopyWith<$Res> {
  _$PassengerInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PassengerInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? phone = null,
    Object? photoUrl = freezed,
    Object? rating = null,
    Object? totalRides = null,
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
      phone: null == phone
          ? _value.phone
          : phone // ignore: cast_nullable_to_non_nullable
              as String,
      photoUrl: freezed == photoUrl
          ? _value.photoUrl
          : photoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      rating: null == rating
          ? _value.rating
          : rating // ignore: cast_nullable_to_non_nullable
              as double,
      totalRides: null == totalRides
          ? _value.totalRides
          : totalRides // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PassengerInfoImplCopyWith<$Res>
    implements $PassengerInfoCopyWith<$Res> {
  factory _$$PassengerInfoImplCopyWith(
          _$PassengerInfoImpl value, $Res Function(_$PassengerInfoImpl) then) =
      __$$PassengerInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String phone,
      String? photoUrl,
      double rating,
      int totalRides});
}

/// @nodoc
class __$$PassengerInfoImplCopyWithImpl<$Res>
    extends _$PassengerInfoCopyWithImpl<$Res, _$PassengerInfoImpl>
    implements _$$PassengerInfoImplCopyWith<$Res> {
  __$$PassengerInfoImplCopyWithImpl(
      _$PassengerInfoImpl _value, $Res Function(_$PassengerInfoImpl) _then)
      : super(_value, _then);

  /// Create a copy of PassengerInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? phone = null,
    Object? photoUrl = freezed,
    Object? rating = null,
    Object? totalRides = null,
  }) {
    return _then(_$PassengerInfoImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      phone: null == phone
          ? _value.phone
          : phone // ignore: cast_nullable_to_non_nullable
              as String,
      photoUrl: freezed == photoUrl
          ? _value.photoUrl
          : photoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      rating: null == rating
          ? _value.rating
          : rating // ignore: cast_nullable_to_non_nullable
              as double,
      totalRides: null == totalRides
          ? _value.totalRides
          : totalRides // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PassengerInfoImpl implements _PassengerInfo {
  const _$PassengerInfoImpl(
      {required this.id,
      required this.name,
      required this.phone,
      this.photoUrl,
      required this.rating,
      required this.totalRides});

  factory _$PassengerInfoImpl.fromJson(Map<String, dynamic> json) =>
      _$$PassengerInfoImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String phone;
  @override
  final String? photoUrl;
  @override
  final double rating;
  @override
  final int totalRides;

  @override
  String toString() {
    return 'PassengerInfo(id: $id, name: $name, phone: $phone, photoUrl: $photoUrl, rating: $rating, totalRides: $totalRides)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PassengerInfoImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.phone, phone) || other.phone == phone) &&
            (identical(other.photoUrl, photoUrl) ||
                other.photoUrl == photoUrl) &&
            (identical(other.rating, rating) || other.rating == rating) &&
            (identical(other.totalRides, totalRides) ||
                other.totalRides == totalRides));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, name, phone, photoUrl, rating, totalRides);

  /// Create a copy of PassengerInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PassengerInfoImplCopyWith<_$PassengerInfoImpl> get copyWith =>
      __$$PassengerInfoImplCopyWithImpl<_$PassengerInfoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PassengerInfoImplToJson(
      this,
    );
  }
}

abstract class _PassengerInfo implements PassengerInfo {
  const factory _PassengerInfo(
      {required final String id,
      required final String name,
      required final String phone,
      final String? photoUrl,
      required final double rating,
      required final int totalRides}) = _$PassengerInfoImpl;

  factory _PassengerInfo.fromJson(Map<String, dynamic> json) =
      _$PassengerInfoImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get phone;
  @override
  String? get photoUrl;
  @override
  double get rating;
  @override
  int get totalRides;

  /// Create a copy of PassengerInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PassengerInfoImplCopyWith<_$PassengerInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
