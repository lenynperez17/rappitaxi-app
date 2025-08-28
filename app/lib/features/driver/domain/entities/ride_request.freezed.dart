// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ride_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

RideRequest _$RideRequestFromJson(Map<String, dynamic> json) {
  return _RideRequest.fromJson(json);
}

/// @nodoc
mixin _$RideRequest {
  String get id => throw _privateConstructorUsedError;
  String get passengerId => throw _privateConstructorUsedError;
  String get passengerName => throw _privateConstructorUsedError;
  String get passengerPhone => throw _privateConstructorUsedError;
  String? get passengerPhoto => throw _privateConstructorUsedError;
  double get passengerRating => throw _privateConstructorUsedError;
  LocationModel get pickup => throw _privateConstructorUsedError;
  LocationModel get destination => throw _privateConstructorUsedError;
  double get estimatedFare => throw _privateConstructorUsedError;
  double get estimatedDistance => throw _privateConstructorUsedError; // en km
  int get estimatedDuration => throw _privateConstructorUsedError; // en minutos
  String get vehicleType => throw _privateConstructorUsedError;
  String get paymentMethod => throw _privateConstructorUsedError;
  DateTime get requestedAt => throw _privateConstructorUsedError;
  int get timeoutSeconds =>
      throw _privateConstructorUsedError; // tiempo para responder
  Map<String, dynamic>? get metadata => throw _privateConstructorUsedError;

  /// Serializes this RideRequest to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RideRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RideRequestCopyWith<RideRequest> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RideRequestCopyWith<$Res> {
  factory $RideRequestCopyWith(
          RideRequest value, $Res Function(RideRequest) then) =
      _$RideRequestCopyWithImpl<$Res, RideRequest>;
  @useResult
  $Res call(
      {String id,
      String passengerId,
      String passengerName,
      String passengerPhone,
      String? passengerPhoto,
      double passengerRating,
      LocationModel pickup,
      LocationModel destination,
      double estimatedFare,
      double estimatedDistance,
      int estimatedDuration,
      String vehicleType,
      String paymentMethod,
      DateTime requestedAt,
      int timeoutSeconds,
      Map<String, dynamic>? metadata});

  $LocationModelCopyWith<$Res> get pickup;
  $LocationModelCopyWith<$Res> get destination;
}

/// @nodoc
class _$RideRequestCopyWithImpl<$Res, $Val extends RideRequest>
    implements $RideRequestCopyWith<$Res> {
  _$RideRequestCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RideRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? passengerId = null,
    Object? passengerName = null,
    Object? passengerPhone = null,
    Object? passengerPhoto = freezed,
    Object? passengerRating = null,
    Object? pickup = null,
    Object? destination = null,
    Object? estimatedFare = null,
    Object? estimatedDistance = null,
    Object? estimatedDuration = null,
    Object? vehicleType = null,
    Object? paymentMethod = null,
    Object? requestedAt = null,
    Object? timeoutSeconds = null,
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
      passengerName: null == passengerName
          ? _value.passengerName
          : passengerName // ignore: cast_nullable_to_non_nullable
              as String,
      passengerPhone: null == passengerPhone
          ? _value.passengerPhone
          : passengerPhone // ignore: cast_nullable_to_non_nullable
              as String,
      passengerPhoto: freezed == passengerPhoto
          ? _value.passengerPhoto
          : passengerPhoto // ignore: cast_nullable_to_non_nullable
              as String?,
      passengerRating: null == passengerRating
          ? _value.passengerRating
          : passengerRating // ignore: cast_nullable_to_non_nullable
              as double,
      pickup: null == pickup
          ? _value.pickup
          : pickup // ignore: cast_nullable_to_non_nullable
              as LocationModel,
      destination: null == destination
          ? _value.destination
          : destination // ignore: cast_nullable_to_non_nullable
              as LocationModel,
      estimatedFare: null == estimatedFare
          ? _value.estimatedFare
          : estimatedFare // ignore: cast_nullable_to_non_nullable
              as double,
      estimatedDistance: null == estimatedDistance
          ? _value.estimatedDistance
          : estimatedDistance // ignore: cast_nullable_to_non_nullable
              as double,
      estimatedDuration: null == estimatedDuration
          ? _value.estimatedDuration
          : estimatedDuration // ignore: cast_nullable_to_non_nullable
              as int,
      vehicleType: null == vehicleType
          ? _value.vehicleType
          : vehicleType // ignore: cast_nullable_to_non_nullable
              as String,
      paymentMethod: null == paymentMethod
          ? _value.paymentMethod
          : paymentMethod // ignore: cast_nullable_to_non_nullable
              as String,
      requestedAt: null == requestedAt
          ? _value.requestedAt
          : requestedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      timeoutSeconds: null == timeoutSeconds
          ? _value.timeoutSeconds
          : timeoutSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      metadata: freezed == metadata
          ? _value.metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ) as $Val);
  }

  /// Create a copy of RideRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $LocationModelCopyWith<$Res> get pickup {
    return $LocationModelCopyWith<$Res>(_value.pickup, (value) {
      return _then(_value.copyWith(pickup: value) as $Val);
    });
  }

  /// Create a copy of RideRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $LocationModelCopyWith<$Res> get destination {
    return $LocationModelCopyWith<$Res>(_value.destination, (value) {
      return _then(_value.copyWith(destination: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$RideRequestImplCopyWith<$Res>
    implements $RideRequestCopyWith<$Res> {
  factory _$$RideRequestImplCopyWith(
          _$RideRequestImpl value, $Res Function(_$RideRequestImpl) then) =
      __$$RideRequestImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String passengerId,
      String passengerName,
      String passengerPhone,
      String? passengerPhoto,
      double passengerRating,
      LocationModel pickup,
      LocationModel destination,
      double estimatedFare,
      double estimatedDistance,
      int estimatedDuration,
      String vehicleType,
      String paymentMethod,
      DateTime requestedAt,
      int timeoutSeconds,
      Map<String, dynamic>? metadata});

  @override
  $LocationModelCopyWith<$Res> get pickup;
  @override
  $LocationModelCopyWith<$Res> get destination;
}

/// @nodoc
class __$$RideRequestImplCopyWithImpl<$Res>
    extends _$RideRequestCopyWithImpl<$Res, _$RideRequestImpl>
    implements _$$RideRequestImplCopyWith<$Res> {
  __$$RideRequestImplCopyWithImpl(
      _$RideRequestImpl _value, $Res Function(_$RideRequestImpl) _then)
      : super(_value, _then);

  /// Create a copy of RideRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? passengerId = null,
    Object? passengerName = null,
    Object? passengerPhone = null,
    Object? passengerPhoto = freezed,
    Object? passengerRating = null,
    Object? pickup = null,
    Object? destination = null,
    Object? estimatedFare = null,
    Object? estimatedDistance = null,
    Object? estimatedDuration = null,
    Object? vehicleType = null,
    Object? paymentMethod = null,
    Object? requestedAt = null,
    Object? timeoutSeconds = null,
    Object? metadata = freezed,
  }) {
    return _then(_$RideRequestImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      passengerId: null == passengerId
          ? _value.passengerId
          : passengerId // ignore: cast_nullable_to_non_nullable
              as String,
      passengerName: null == passengerName
          ? _value.passengerName
          : passengerName // ignore: cast_nullable_to_non_nullable
              as String,
      passengerPhone: null == passengerPhone
          ? _value.passengerPhone
          : passengerPhone // ignore: cast_nullable_to_non_nullable
              as String,
      passengerPhoto: freezed == passengerPhoto
          ? _value.passengerPhoto
          : passengerPhoto // ignore: cast_nullable_to_non_nullable
              as String?,
      passengerRating: null == passengerRating
          ? _value.passengerRating
          : passengerRating // ignore: cast_nullable_to_non_nullable
              as double,
      pickup: null == pickup
          ? _value.pickup
          : pickup // ignore: cast_nullable_to_non_nullable
              as LocationModel,
      destination: null == destination
          ? _value.destination
          : destination // ignore: cast_nullable_to_non_nullable
              as LocationModel,
      estimatedFare: null == estimatedFare
          ? _value.estimatedFare
          : estimatedFare // ignore: cast_nullable_to_non_nullable
              as double,
      estimatedDistance: null == estimatedDistance
          ? _value.estimatedDistance
          : estimatedDistance // ignore: cast_nullable_to_non_nullable
              as double,
      estimatedDuration: null == estimatedDuration
          ? _value.estimatedDuration
          : estimatedDuration // ignore: cast_nullable_to_non_nullable
              as int,
      vehicleType: null == vehicleType
          ? _value.vehicleType
          : vehicleType // ignore: cast_nullable_to_non_nullable
              as String,
      paymentMethod: null == paymentMethod
          ? _value.paymentMethod
          : paymentMethod // ignore: cast_nullable_to_non_nullable
              as String,
      requestedAt: null == requestedAt
          ? _value.requestedAt
          : requestedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      timeoutSeconds: null == timeoutSeconds
          ? _value.timeoutSeconds
          : timeoutSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      metadata: freezed == metadata
          ? _value._metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$RideRequestImpl implements _RideRequest {
  const _$RideRequestImpl(
      {required this.id,
      required this.passengerId,
      required this.passengerName,
      required this.passengerPhone,
      this.passengerPhoto,
      required this.passengerRating,
      required this.pickup,
      required this.destination,
      required this.estimatedFare,
      required this.estimatedDistance,
      required this.estimatedDuration,
      required this.vehicleType,
      required this.paymentMethod,
      required this.requestedAt,
      required this.timeoutSeconds,
      final Map<String, dynamic>? metadata})
      : _metadata = metadata;

  factory _$RideRequestImpl.fromJson(Map<String, dynamic> json) =>
      _$$RideRequestImplFromJson(json);

  @override
  final String id;
  @override
  final String passengerId;
  @override
  final String passengerName;
  @override
  final String passengerPhone;
  @override
  final String? passengerPhoto;
  @override
  final double passengerRating;
  @override
  final LocationModel pickup;
  @override
  final LocationModel destination;
  @override
  final double estimatedFare;
  @override
  final double estimatedDistance;
// en km
  @override
  final int estimatedDuration;
// en minutos
  @override
  final String vehicleType;
  @override
  final String paymentMethod;
  @override
  final DateTime requestedAt;
  @override
  final int timeoutSeconds;
// tiempo para responder
  final Map<String, dynamic>? _metadata;
// tiempo para responder
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
    return 'RideRequest(id: $id, passengerId: $passengerId, passengerName: $passengerName, passengerPhone: $passengerPhone, passengerPhoto: $passengerPhoto, passengerRating: $passengerRating, pickup: $pickup, destination: $destination, estimatedFare: $estimatedFare, estimatedDistance: $estimatedDistance, estimatedDuration: $estimatedDuration, vehicleType: $vehicleType, paymentMethod: $paymentMethod, requestedAt: $requestedAt, timeoutSeconds: $timeoutSeconds, metadata: $metadata)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RideRequestImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.passengerId, passengerId) ||
                other.passengerId == passengerId) &&
            (identical(other.passengerName, passengerName) ||
                other.passengerName == passengerName) &&
            (identical(other.passengerPhone, passengerPhone) ||
                other.passengerPhone == passengerPhone) &&
            (identical(other.passengerPhoto, passengerPhoto) ||
                other.passengerPhoto == passengerPhoto) &&
            (identical(other.passengerRating, passengerRating) ||
                other.passengerRating == passengerRating) &&
            (identical(other.pickup, pickup) || other.pickup == pickup) &&
            (identical(other.destination, destination) ||
                other.destination == destination) &&
            (identical(other.estimatedFare, estimatedFare) ||
                other.estimatedFare == estimatedFare) &&
            (identical(other.estimatedDistance, estimatedDistance) ||
                other.estimatedDistance == estimatedDistance) &&
            (identical(other.estimatedDuration, estimatedDuration) ||
                other.estimatedDuration == estimatedDuration) &&
            (identical(other.vehicleType, vehicleType) ||
                other.vehicleType == vehicleType) &&
            (identical(other.paymentMethod, paymentMethod) ||
                other.paymentMethod == paymentMethod) &&
            (identical(other.requestedAt, requestedAt) ||
                other.requestedAt == requestedAt) &&
            (identical(other.timeoutSeconds, timeoutSeconds) ||
                other.timeoutSeconds == timeoutSeconds) &&
            const DeepCollectionEquality().equals(other._metadata, _metadata));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      passengerId,
      passengerName,
      passengerPhone,
      passengerPhoto,
      passengerRating,
      pickup,
      destination,
      estimatedFare,
      estimatedDistance,
      estimatedDuration,
      vehicleType,
      paymentMethod,
      requestedAt,
      timeoutSeconds,
      const DeepCollectionEquality().hash(_metadata));

  /// Create a copy of RideRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RideRequestImplCopyWith<_$RideRequestImpl> get copyWith =>
      __$$RideRequestImplCopyWithImpl<_$RideRequestImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$RideRequestImplToJson(
      this,
    );
  }
}

abstract class _RideRequest implements RideRequest {
  const factory _RideRequest(
      {required final String id,
      required final String passengerId,
      required final String passengerName,
      required final String passengerPhone,
      final String? passengerPhoto,
      required final double passengerRating,
      required final LocationModel pickup,
      required final LocationModel destination,
      required final double estimatedFare,
      required final double estimatedDistance,
      required final int estimatedDuration,
      required final String vehicleType,
      required final String paymentMethod,
      required final DateTime requestedAt,
      required final int timeoutSeconds,
      final Map<String, dynamic>? metadata}) = _$RideRequestImpl;

  factory _RideRequest.fromJson(Map<String, dynamic> json) =
      _$RideRequestImpl.fromJson;

  @override
  String get id;
  @override
  String get passengerId;
  @override
  String get passengerName;
  @override
  String get passengerPhone;
  @override
  String? get passengerPhoto;
  @override
  double get passengerRating;
  @override
  LocationModel get pickup;
  @override
  LocationModel get destination;
  @override
  double get estimatedFare;
  @override
  double get estimatedDistance; // en km
  @override
  int get estimatedDuration; // en minutos
  @override
  String get vehicleType;
  @override
  String get paymentMethod;
  @override
  DateTime get requestedAt;
  @override
  int get timeoutSeconds; // tiempo para responder
  @override
  Map<String, dynamic>? get metadata;

  /// Create a copy of RideRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RideRequestImplCopyWith<_$RideRequestImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
