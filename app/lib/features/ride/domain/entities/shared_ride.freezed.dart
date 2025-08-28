// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'shared_ride.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

SharedRide _$SharedRideFromJson(Map<String, dynamic> json) {
  return _SharedRide.fromJson(json);
}

/// @nodoc
mixin _$SharedRide {
  String get id => throw _privateConstructorUsedError;
  String get driverId => throw _privateConstructorUsedError;
  List<SharedRidePassenger> get passengers =>
      throw _privateConstructorUsedError;
  SharedRideStatus get status => throw _privateConstructorUsedError;
  String get vehicleType => throw _privateConstructorUsedError;
  int get maxPassengers => throw _privateConstructorUsedError;
  double get totalDistance => throw _privateConstructorUsedError;
  double get currentDistance => throw _privateConstructorUsedError;
  List<RouteSegment> get routeSegments => throw _privateConstructorUsedError;
  DateTime get startTime => throw _privateConstructorUsedError;
  DateTime? get endTime => throw _privateConstructorUsedError;
  double get baseFare => throw _privateConstructorUsedError;
  Map<String, double> get passengerFares =>
      throw _privateConstructorUsedError; // passengerId -> fare
  double get sharedRideDiscount =>
      throw _privateConstructorUsedError; // 30% descuento por compartir
  bool get allowNewPassengers => throw _privateConstructorUsedError;
  int get maxDetourMinutes =>
      throw _privateConstructorUsedError; // Máximo desvío permitido
  String? get currentSegmentId => throw _privateConstructorUsedError;
  Map<String, dynamic>? get currentLocation =>
      throw _privateConstructorUsedError;

  /// Serializes this SharedRide to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SharedRide
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SharedRideCopyWith<SharedRide> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SharedRideCopyWith<$Res> {
  factory $SharedRideCopyWith(
          SharedRide value, $Res Function(SharedRide) then) =
      _$SharedRideCopyWithImpl<$Res, SharedRide>;
  @useResult
  $Res call(
      {String id,
      String driverId,
      List<SharedRidePassenger> passengers,
      SharedRideStatus status,
      String vehicleType,
      int maxPassengers,
      double totalDistance,
      double currentDistance,
      List<RouteSegment> routeSegments,
      DateTime startTime,
      DateTime? endTime,
      double baseFare,
      Map<String, double> passengerFares,
      double sharedRideDiscount,
      bool allowNewPassengers,
      int maxDetourMinutes,
      String? currentSegmentId,
      Map<String, dynamic>? currentLocation});
}

/// @nodoc
class _$SharedRideCopyWithImpl<$Res, $Val extends SharedRide>
    implements $SharedRideCopyWith<$Res> {
  _$SharedRideCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SharedRide
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? driverId = null,
    Object? passengers = null,
    Object? status = null,
    Object? vehicleType = null,
    Object? maxPassengers = null,
    Object? totalDistance = null,
    Object? currentDistance = null,
    Object? routeSegments = null,
    Object? startTime = null,
    Object? endTime = freezed,
    Object? baseFare = null,
    Object? passengerFares = null,
    Object? sharedRideDiscount = null,
    Object? allowNewPassengers = null,
    Object? maxDetourMinutes = null,
    Object? currentSegmentId = freezed,
    Object? currentLocation = freezed,
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
      passengers: null == passengers
          ? _value.passengers
          : passengers // ignore: cast_nullable_to_non_nullable
              as List<SharedRidePassenger>,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as SharedRideStatus,
      vehicleType: null == vehicleType
          ? _value.vehicleType
          : vehicleType // ignore: cast_nullable_to_non_nullable
              as String,
      maxPassengers: null == maxPassengers
          ? _value.maxPassengers
          : maxPassengers // ignore: cast_nullable_to_non_nullable
              as int,
      totalDistance: null == totalDistance
          ? _value.totalDistance
          : totalDistance // ignore: cast_nullable_to_non_nullable
              as double,
      currentDistance: null == currentDistance
          ? _value.currentDistance
          : currentDistance // ignore: cast_nullable_to_non_nullable
              as double,
      routeSegments: null == routeSegments
          ? _value.routeSegments
          : routeSegments // ignore: cast_nullable_to_non_nullable
              as List<RouteSegment>,
      startTime: null == startTime
          ? _value.startTime
          : startTime // ignore: cast_nullable_to_non_nullable
              as DateTime,
      endTime: freezed == endTime
          ? _value.endTime
          : endTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      baseFare: null == baseFare
          ? _value.baseFare
          : baseFare // ignore: cast_nullable_to_non_nullable
              as double,
      passengerFares: null == passengerFares
          ? _value.passengerFares
          : passengerFares // ignore: cast_nullable_to_non_nullable
              as Map<String, double>,
      sharedRideDiscount: null == sharedRideDiscount
          ? _value.sharedRideDiscount
          : sharedRideDiscount // ignore: cast_nullable_to_non_nullable
              as double,
      allowNewPassengers: null == allowNewPassengers
          ? _value.allowNewPassengers
          : allowNewPassengers // ignore: cast_nullable_to_non_nullable
              as bool,
      maxDetourMinutes: null == maxDetourMinutes
          ? _value.maxDetourMinutes
          : maxDetourMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      currentSegmentId: freezed == currentSegmentId
          ? _value.currentSegmentId
          : currentSegmentId // ignore: cast_nullable_to_non_nullable
              as String?,
      currentLocation: freezed == currentLocation
          ? _value.currentLocation
          : currentLocation // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SharedRideImplCopyWith<$Res>
    implements $SharedRideCopyWith<$Res> {
  factory _$$SharedRideImplCopyWith(
          _$SharedRideImpl value, $Res Function(_$SharedRideImpl) then) =
      __$$SharedRideImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String driverId,
      List<SharedRidePassenger> passengers,
      SharedRideStatus status,
      String vehicleType,
      int maxPassengers,
      double totalDistance,
      double currentDistance,
      List<RouteSegment> routeSegments,
      DateTime startTime,
      DateTime? endTime,
      double baseFare,
      Map<String, double> passengerFares,
      double sharedRideDiscount,
      bool allowNewPassengers,
      int maxDetourMinutes,
      String? currentSegmentId,
      Map<String, dynamic>? currentLocation});
}

/// @nodoc
class __$$SharedRideImplCopyWithImpl<$Res>
    extends _$SharedRideCopyWithImpl<$Res, _$SharedRideImpl>
    implements _$$SharedRideImplCopyWith<$Res> {
  __$$SharedRideImplCopyWithImpl(
      _$SharedRideImpl _value, $Res Function(_$SharedRideImpl) _then)
      : super(_value, _then);

  /// Create a copy of SharedRide
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? driverId = null,
    Object? passengers = null,
    Object? status = null,
    Object? vehicleType = null,
    Object? maxPassengers = null,
    Object? totalDistance = null,
    Object? currentDistance = null,
    Object? routeSegments = null,
    Object? startTime = null,
    Object? endTime = freezed,
    Object? baseFare = null,
    Object? passengerFares = null,
    Object? sharedRideDiscount = null,
    Object? allowNewPassengers = null,
    Object? maxDetourMinutes = null,
    Object? currentSegmentId = freezed,
    Object? currentLocation = freezed,
  }) {
    return _then(_$SharedRideImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      driverId: null == driverId
          ? _value.driverId
          : driverId // ignore: cast_nullable_to_non_nullable
              as String,
      passengers: null == passengers
          ? _value._passengers
          : passengers // ignore: cast_nullable_to_non_nullable
              as List<SharedRidePassenger>,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as SharedRideStatus,
      vehicleType: null == vehicleType
          ? _value.vehicleType
          : vehicleType // ignore: cast_nullable_to_non_nullable
              as String,
      maxPassengers: null == maxPassengers
          ? _value.maxPassengers
          : maxPassengers // ignore: cast_nullable_to_non_nullable
              as int,
      totalDistance: null == totalDistance
          ? _value.totalDistance
          : totalDistance // ignore: cast_nullable_to_non_nullable
              as double,
      currentDistance: null == currentDistance
          ? _value.currentDistance
          : currentDistance // ignore: cast_nullable_to_non_nullable
              as double,
      routeSegments: null == routeSegments
          ? _value._routeSegments
          : routeSegments // ignore: cast_nullable_to_non_nullable
              as List<RouteSegment>,
      startTime: null == startTime
          ? _value.startTime
          : startTime // ignore: cast_nullable_to_non_nullable
              as DateTime,
      endTime: freezed == endTime
          ? _value.endTime
          : endTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      baseFare: null == baseFare
          ? _value.baseFare
          : baseFare // ignore: cast_nullable_to_non_nullable
              as double,
      passengerFares: null == passengerFares
          ? _value._passengerFares
          : passengerFares // ignore: cast_nullable_to_non_nullable
              as Map<String, double>,
      sharedRideDiscount: null == sharedRideDiscount
          ? _value.sharedRideDiscount
          : sharedRideDiscount // ignore: cast_nullable_to_non_nullable
              as double,
      allowNewPassengers: null == allowNewPassengers
          ? _value.allowNewPassengers
          : allowNewPassengers // ignore: cast_nullable_to_non_nullable
              as bool,
      maxDetourMinutes: null == maxDetourMinutes
          ? _value.maxDetourMinutes
          : maxDetourMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      currentSegmentId: freezed == currentSegmentId
          ? _value.currentSegmentId
          : currentSegmentId // ignore: cast_nullable_to_non_nullable
              as String?,
      currentLocation: freezed == currentLocation
          ? _value._currentLocation
          : currentLocation // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SharedRideImpl implements _SharedRide {
  const _$SharedRideImpl(
      {required this.id,
      required this.driverId,
      required final List<SharedRidePassenger> passengers,
      required this.status,
      required this.vehicleType,
      required this.maxPassengers,
      required this.totalDistance,
      required this.currentDistance,
      required final List<RouteSegment> routeSegments,
      required this.startTime,
      this.endTime,
      required this.baseFare,
      required final Map<String, double> passengerFares,
      this.sharedRideDiscount = 0.7,
      this.allowNewPassengers = true,
      this.maxDetourMinutes = 15,
      this.currentSegmentId,
      final Map<String, dynamic>? currentLocation})
      : _passengers = passengers,
        _routeSegments = routeSegments,
        _passengerFares = passengerFares,
        _currentLocation = currentLocation;

  factory _$SharedRideImpl.fromJson(Map<String, dynamic> json) =>
      _$$SharedRideImplFromJson(json);

  @override
  final String id;
  @override
  final String driverId;
  final List<SharedRidePassenger> _passengers;
  @override
  List<SharedRidePassenger> get passengers {
    if (_passengers is EqualUnmodifiableListView) return _passengers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_passengers);
  }

  @override
  final SharedRideStatus status;
  @override
  final String vehicleType;
  @override
  final int maxPassengers;
  @override
  final double totalDistance;
  @override
  final double currentDistance;
  final List<RouteSegment> _routeSegments;
  @override
  List<RouteSegment> get routeSegments {
    if (_routeSegments is EqualUnmodifiableListView) return _routeSegments;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_routeSegments);
  }

  @override
  final DateTime startTime;
  @override
  final DateTime? endTime;
  @override
  final double baseFare;
  final Map<String, double> _passengerFares;
  @override
  Map<String, double> get passengerFares {
    if (_passengerFares is EqualUnmodifiableMapView) return _passengerFares;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_passengerFares);
  }

// passengerId -> fare
  @override
  @JsonKey()
  final double sharedRideDiscount;
// 30% descuento por compartir
  @override
  @JsonKey()
  final bool allowNewPassengers;
  @override
  @JsonKey()
  final int maxDetourMinutes;
// Máximo desvío permitido
  @override
  final String? currentSegmentId;
  final Map<String, dynamic>? _currentLocation;
  @override
  Map<String, dynamic>? get currentLocation {
    final value = _currentLocation;
    if (value == null) return null;
    if (_currentLocation is EqualUnmodifiableMapView) return _currentLocation;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  String toString() {
    return 'SharedRide(id: $id, driverId: $driverId, passengers: $passengers, status: $status, vehicleType: $vehicleType, maxPassengers: $maxPassengers, totalDistance: $totalDistance, currentDistance: $currentDistance, routeSegments: $routeSegments, startTime: $startTime, endTime: $endTime, baseFare: $baseFare, passengerFares: $passengerFares, sharedRideDiscount: $sharedRideDiscount, allowNewPassengers: $allowNewPassengers, maxDetourMinutes: $maxDetourMinutes, currentSegmentId: $currentSegmentId, currentLocation: $currentLocation)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SharedRideImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.driverId, driverId) ||
                other.driverId == driverId) &&
            const DeepCollectionEquality()
                .equals(other._passengers, _passengers) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.vehicleType, vehicleType) ||
                other.vehicleType == vehicleType) &&
            (identical(other.maxPassengers, maxPassengers) ||
                other.maxPassengers == maxPassengers) &&
            (identical(other.totalDistance, totalDistance) ||
                other.totalDistance == totalDistance) &&
            (identical(other.currentDistance, currentDistance) ||
                other.currentDistance == currentDistance) &&
            const DeepCollectionEquality()
                .equals(other._routeSegments, _routeSegments) &&
            (identical(other.startTime, startTime) ||
                other.startTime == startTime) &&
            (identical(other.endTime, endTime) || other.endTime == endTime) &&
            (identical(other.baseFare, baseFare) ||
                other.baseFare == baseFare) &&
            const DeepCollectionEquality()
                .equals(other._passengerFares, _passengerFares) &&
            (identical(other.sharedRideDiscount, sharedRideDiscount) ||
                other.sharedRideDiscount == sharedRideDiscount) &&
            (identical(other.allowNewPassengers, allowNewPassengers) ||
                other.allowNewPassengers == allowNewPassengers) &&
            (identical(other.maxDetourMinutes, maxDetourMinutes) ||
                other.maxDetourMinutes == maxDetourMinutes) &&
            (identical(other.currentSegmentId, currentSegmentId) ||
                other.currentSegmentId == currentSegmentId) &&
            const DeepCollectionEquality()
                .equals(other._currentLocation, _currentLocation));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      driverId,
      const DeepCollectionEquality().hash(_passengers),
      status,
      vehicleType,
      maxPassengers,
      totalDistance,
      currentDistance,
      const DeepCollectionEquality().hash(_routeSegments),
      startTime,
      endTime,
      baseFare,
      const DeepCollectionEquality().hash(_passengerFares),
      sharedRideDiscount,
      allowNewPassengers,
      maxDetourMinutes,
      currentSegmentId,
      const DeepCollectionEquality().hash(_currentLocation));

  /// Create a copy of SharedRide
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SharedRideImplCopyWith<_$SharedRideImpl> get copyWith =>
      __$$SharedRideImplCopyWithImpl<_$SharedRideImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SharedRideImplToJson(
      this,
    );
  }
}

abstract class _SharedRide implements SharedRide {
  const factory _SharedRide(
      {required final String id,
      required final String driverId,
      required final List<SharedRidePassenger> passengers,
      required final SharedRideStatus status,
      required final String vehicleType,
      required final int maxPassengers,
      required final double totalDistance,
      required final double currentDistance,
      required final List<RouteSegment> routeSegments,
      required final DateTime startTime,
      final DateTime? endTime,
      required final double baseFare,
      required final Map<String, double> passengerFares,
      final double sharedRideDiscount,
      final bool allowNewPassengers,
      final int maxDetourMinutes,
      final String? currentSegmentId,
      final Map<String, dynamic>? currentLocation}) = _$SharedRideImpl;

  factory _SharedRide.fromJson(Map<String, dynamic> json) =
      _$SharedRideImpl.fromJson;

  @override
  String get id;
  @override
  String get driverId;
  @override
  List<SharedRidePassenger> get passengers;
  @override
  SharedRideStatus get status;
  @override
  String get vehicleType;
  @override
  int get maxPassengers;
  @override
  double get totalDistance;
  @override
  double get currentDistance;
  @override
  List<RouteSegment> get routeSegments;
  @override
  DateTime get startTime;
  @override
  DateTime? get endTime;
  @override
  double get baseFare;
  @override
  Map<String, double> get passengerFares; // passengerId -> fare
  @override
  double get sharedRideDiscount; // 30% descuento por compartir
  @override
  bool get allowNewPassengers;
  @override
  int get maxDetourMinutes; // Máximo desvío permitido
  @override
  String? get currentSegmentId;
  @override
  Map<String, dynamic>? get currentLocation;

  /// Create a copy of SharedRide
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SharedRideImplCopyWith<_$SharedRideImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SharedRidePassenger _$SharedRidePassengerFromJson(Map<String, dynamic> json) {
  return _SharedRidePassenger.fromJson(json);
}

/// @nodoc
mixin _$SharedRidePassenger {
  String get passengerId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get photoUrl => throw _privateConstructorUsedError;
  double get rating => throw _privateConstructorUsedError;
  Map<String, dynamic> get pickupLocation => throw _privateConstructorUsedError;
  Map<String, dynamic> get dropoffLocation =>
      throw _privateConstructorUsedError;
  DateTime get requestTime => throw _privateConstructorUsedError;
  DateTime? get pickupTime => throw _privateConstructorUsedError;
  DateTime? get dropoffTime => throw _privateConstructorUsedError;
  PassengerStatus get status => throw _privateConstructorUsedError;
  double get fare => throw _privateConstructorUsedError;
  double get distance => throw _privateConstructorUsedError;
  int get seatCount => throw _privateConstructorUsedError;
  String? get phoneNumber => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;
  bool get isPriority => throw _privateConstructorUsedError;

  /// Serializes this SharedRidePassenger to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SharedRidePassenger
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SharedRidePassengerCopyWith<SharedRidePassenger> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SharedRidePassengerCopyWith<$Res> {
  factory $SharedRidePassengerCopyWith(
          SharedRidePassenger value, $Res Function(SharedRidePassenger) then) =
      _$SharedRidePassengerCopyWithImpl<$Res, SharedRidePassenger>;
  @useResult
  $Res call(
      {String passengerId,
      String name,
      String photoUrl,
      double rating,
      Map<String, dynamic> pickupLocation,
      Map<String, dynamic> dropoffLocation,
      DateTime requestTime,
      DateTime? pickupTime,
      DateTime? dropoffTime,
      PassengerStatus status,
      double fare,
      double distance,
      int seatCount,
      String? phoneNumber,
      String? notes,
      bool isPriority});
}

/// @nodoc
class _$SharedRidePassengerCopyWithImpl<$Res, $Val extends SharedRidePassenger>
    implements $SharedRidePassengerCopyWith<$Res> {
  _$SharedRidePassengerCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SharedRidePassenger
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? passengerId = null,
    Object? name = null,
    Object? photoUrl = null,
    Object? rating = null,
    Object? pickupLocation = null,
    Object? dropoffLocation = null,
    Object? requestTime = null,
    Object? pickupTime = freezed,
    Object? dropoffTime = freezed,
    Object? status = null,
    Object? fare = null,
    Object? distance = null,
    Object? seatCount = null,
    Object? phoneNumber = freezed,
    Object? notes = freezed,
    Object? isPriority = null,
  }) {
    return _then(_value.copyWith(
      passengerId: null == passengerId
          ? _value.passengerId
          : passengerId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      photoUrl: null == photoUrl
          ? _value.photoUrl
          : photoUrl // ignore: cast_nullable_to_non_nullable
              as String,
      rating: null == rating
          ? _value.rating
          : rating // ignore: cast_nullable_to_non_nullable
              as double,
      pickupLocation: null == pickupLocation
          ? _value.pickupLocation
          : pickupLocation // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      dropoffLocation: null == dropoffLocation
          ? _value.dropoffLocation
          : dropoffLocation // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      requestTime: null == requestTime
          ? _value.requestTime
          : requestTime // ignore: cast_nullable_to_non_nullable
              as DateTime,
      pickupTime: freezed == pickupTime
          ? _value.pickupTime
          : pickupTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      dropoffTime: freezed == dropoffTime
          ? _value.dropoffTime
          : dropoffTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as PassengerStatus,
      fare: null == fare
          ? _value.fare
          : fare // ignore: cast_nullable_to_non_nullable
              as double,
      distance: null == distance
          ? _value.distance
          : distance // ignore: cast_nullable_to_non_nullable
              as double,
      seatCount: null == seatCount
          ? _value.seatCount
          : seatCount // ignore: cast_nullable_to_non_nullable
              as int,
      phoneNumber: freezed == phoneNumber
          ? _value.phoneNumber
          : phoneNumber // ignore: cast_nullable_to_non_nullable
              as String?,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
      isPriority: null == isPriority
          ? _value.isPriority
          : isPriority // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SharedRidePassengerImplCopyWith<$Res>
    implements $SharedRidePassengerCopyWith<$Res> {
  factory _$$SharedRidePassengerImplCopyWith(_$SharedRidePassengerImpl value,
          $Res Function(_$SharedRidePassengerImpl) then) =
      __$$SharedRidePassengerImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String passengerId,
      String name,
      String photoUrl,
      double rating,
      Map<String, dynamic> pickupLocation,
      Map<String, dynamic> dropoffLocation,
      DateTime requestTime,
      DateTime? pickupTime,
      DateTime? dropoffTime,
      PassengerStatus status,
      double fare,
      double distance,
      int seatCount,
      String? phoneNumber,
      String? notes,
      bool isPriority});
}

/// @nodoc
class __$$SharedRidePassengerImplCopyWithImpl<$Res>
    extends _$SharedRidePassengerCopyWithImpl<$Res, _$SharedRidePassengerImpl>
    implements _$$SharedRidePassengerImplCopyWith<$Res> {
  __$$SharedRidePassengerImplCopyWithImpl(_$SharedRidePassengerImpl _value,
      $Res Function(_$SharedRidePassengerImpl) _then)
      : super(_value, _then);

  /// Create a copy of SharedRidePassenger
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? passengerId = null,
    Object? name = null,
    Object? photoUrl = null,
    Object? rating = null,
    Object? pickupLocation = null,
    Object? dropoffLocation = null,
    Object? requestTime = null,
    Object? pickupTime = freezed,
    Object? dropoffTime = freezed,
    Object? status = null,
    Object? fare = null,
    Object? distance = null,
    Object? seatCount = null,
    Object? phoneNumber = freezed,
    Object? notes = freezed,
    Object? isPriority = null,
  }) {
    return _then(_$SharedRidePassengerImpl(
      passengerId: null == passengerId
          ? _value.passengerId
          : passengerId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      photoUrl: null == photoUrl
          ? _value.photoUrl
          : photoUrl // ignore: cast_nullable_to_non_nullable
              as String,
      rating: null == rating
          ? _value.rating
          : rating // ignore: cast_nullable_to_non_nullable
              as double,
      pickupLocation: null == pickupLocation
          ? _value._pickupLocation
          : pickupLocation // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      dropoffLocation: null == dropoffLocation
          ? _value._dropoffLocation
          : dropoffLocation // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      requestTime: null == requestTime
          ? _value.requestTime
          : requestTime // ignore: cast_nullable_to_non_nullable
              as DateTime,
      pickupTime: freezed == pickupTime
          ? _value.pickupTime
          : pickupTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      dropoffTime: freezed == dropoffTime
          ? _value.dropoffTime
          : dropoffTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as PassengerStatus,
      fare: null == fare
          ? _value.fare
          : fare // ignore: cast_nullable_to_non_nullable
              as double,
      distance: null == distance
          ? _value.distance
          : distance // ignore: cast_nullable_to_non_nullable
              as double,
      seatCount: null == seatCount
          ? _value.seatCount
          : seatCount // ignore: cast_nullable_to_non_nullable
              as int,
      phoneNumber: freezed == phoneNumber
          ? _value.phoneNumber
          : phoneNumber // ignore: cast_nullable_to_non_nullable
              as String?,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
      isPriority: null == isPriority
          ? _value.isPriority
          : isPriority // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SharedRidePassengerImpl implements _SharedRidePassenger {
  const _$SharedRidePassengerImpl(
      {required this.passengerId,
      required this.name,
      required this.photoUrl,
      required this.rating,
      required final Map<String, dynamic> pickupLocation,
      required final Map<String, dynamic> dropoffLocation,
      required this.requestTime,
      this.pickupTime,
      this.dropoffTime,
      required this.status,
      required this.fare,
      required this.distance,
      required this.seatCount,
      this.phoneNumber,
      this.notes,
      this.isPriority = false})
      : _pickupLocation = pickupLocation,
        _dropoffLocation = dropoffLocation;

  factory _$SharedRidePassengerImpl.fromJson(Map<String, dynamic> json) =>
      _$$SharedRidePassengerImplFromJson(json);

  @override
  final String passengerId;
  @override
  final String name;
  @override
  final String photoUrl;
  @override
  final double rating;
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
  final DateTime requestTime;
  @override
  final DateTime? pickupTime;
  @override
  final DateTime? dropoffTime;
  @override
  final PassengerStatus status;
  @override
  final double fare;
  @override
  final double distance;
  @override
  final int seatCount;
  @override
  final String? phoneNumber;
  @override
  final String? notes;
  @override
  @JsonKey()
  final bool isPriority;

  @override
  String toString() {
    return 'SharedRidePassenger(passengerId: $passengerId, name: $name, photoUrl: $photoUrl, rating: $rating, pickupLocation: $pickupLocation, dropoffLocation: $dropoffLocation, requestTime: $requestTime, pickupTime: $pickupTime, dropoffTime: $dropoffTime, status: $status, fare: $fare, distance: $distance, seatCount: $seatCount, phoneNumber: $phoneNumber, notes: $notes, isPriority: $isPriority)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SharedRidePassengerImpl &&
            (identical(other.passengerId, passengerId) ||
                other.passengerId == passengerId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.photoUrl, photoUrl) ||
                other.photoUrl == photoUrl) &&
            (identical(other.rating, rating) || other.rating == rating) &&
            const DeepCollectionEquality()
                .equals(other._pickupLocation, _pickupLocation) &&
            const DeepCollectionEquality()
                .equals(other._dropoffLocation, _dropoffLocation) &&
            (identical(other.requestTime, requestTime) ||
                other.requestTime == requestTime) &&
            (identical(other.pickupTime, pickupTime) ||
                other.pickupTime == pickupTime) &&
            (identical(other.dropoffTime, dropoffTime) ||
                other.dropoffTime == dropoffTime) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.fare, fare) || other.fare == fare) &&
            (identical(other.distance, distance) ||
                other.distance == distance) &&
            (identical(other.seatCount, seatCount) ||
                other.seatCount == seatCount) &&
            (identical(other.phoneNumber, phoneNumber) ||
                other.phoneNumber == phoneNumber) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.isPriority, isPriority) ||
                other.isPriority == isPriority));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      passengerId,
      name,
      photoUrl,
      rating,
      const DeepCollectionEquality().hash(_pickupLocation),
      const DeepCollectionEquality().hash(_dropoffLocation),
      requestTime,
      pickupTime,
      dropoffTime,
      status,
      fare,
      distance,
      seatCount,
      phoneNumber,
      notes,
      isPriority);

  /// Create a copy of SharedRidePassenger
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SharedRidePassengerImplCopyWith<_$SharedRidePassengerImpl> get copyWith =>
      __$$SharedRidePassengerImplCopyWithImpl<_$SharedRidePassengerImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SharedRidePassengerImplToJson(
      this,
    );
  }
}

abstract class _SharedRidePassenger implements SharedRidePassenger {
  const factory _SharedRidePassenger(
      {required final String passengerId,
      required final String name,
      required final String photoUrl,
      required final double rating,
      required final Map<String, dynamic> pickupLocation,
      required final Map<String, dynamic> dropoffLocation,
      required final DateTime requestTime,
      final DateTime? pickupTime,
      final DateTime? dropoffTime,
      required final PassengerStatus status,
      required final double fare,
      required final double distance,
      required final int seatCount,
      final String? phoneNumber,
      final String? notes,
      final bool isPriority}) = _$SharedRidePassengerImpl;

  factory _SharedRidePassenger.fromJson(Map<String, dynamic> json) =
      _$SharedRidePassengerImpl.fromJson;

  @override
  String get passengerId;
  @override
  String get name;
  @override
  String get photoUrl;
  @override
  double get rating;
  @override
  Map<String, dynamic> get pickupLocation;
  @override
  Map<String, dynamic> get dropoffLocation;
  @override
  DateTime get requestTime;
  @override
  DateTime? get pickupTime;
  @override
  DateTime? get dropoffTime;
  @override
  PassengerStatus get status;
  @override
  double get fare;
  @override
  double get distance;
  @override
  int get seatCount;
  @override
  String? get phoneNumber;
  @override
  String? get notes;
  @override
  bool get isPriority;

  /// Create a copy of SharedRidePassenger
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SharedRidePassengerImplCopyWith<_$SharedRidePassengerImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

RouteSegment _$RouteSegmentFromJson(Map<String, dynamic> json) {
  return _RouteSegment.fromJson(json);
}

/// @nodoc
mixin _$RouteSegment {
  String get id => throw _privateConstructorUsedError;
  String get passengerId => throw _privateConstructorUsedError;
  SegmentType get type => throw _privateConstructorUsedError;
  Map<String, dynamic> get location => throw _privateConstructorUsedError;
  int get order => throw _privateConstructorUsedError;
  double get distanceFromPrevious => throw _privateConstructorUsedError;
  int get estimatedMinutesFromPrevious => throw _privateConstructorUsedError;
  DateTime? get actualArrivalTime => throw _privateConstructorUsedError;
  bool get isCompleted => throw _privateConstructorUsedError;

  /// Serializes this RouteSegment to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RouteSegment
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RouteSegmentCopyWith<RouteSegment> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RouteSegmentCopyWith<$Res> {
  factory $RouteSegmentCopyWith(
          RouteSegment value, $Res Function(RouteSegment) then) =
      _$RouteSegmentCopyWithImpl<$Res, RouteSegment>;
  @useResult
  $Res call(
      {String id,
      String passengerId,
      SegmentType type,
      Map<String, dynamic> location,
      int order,
      double distanceFromPrevious,
      int estimatedMinutesFromPrevious,
      DateTime? actualArrivalTime,
      bool isCompleted});
}

/// @nodoc
class _$RouteSegmentCopyWithImpl<$Res, $Val extends RouteSegment>
    implements $RouteSegmentCopyWith<$Res> {
  _$RouteSegmentCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RouteSegment
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? passengerId = null,
    Object? type = null,
    Object? location = null,
    Object? order = null,
    Object? distanceFromPrevious = null,
    Object? estimatedMinutesFromPrevious = null,
    Object? actualArrivalTime = freezed,
    Object? isCompleted = null,
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
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as SegmentType,
      location: null == location
          ? _value.location
          : location // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      order: null == order
          ? _value.order
          : order // ignore: cast_nullable_to_non_nullable
              as int,
      distanceFromPrevious: null == distanceFromPrevious
          ? _value.distanceFromPrevious
          : distanceFromPrevious // ignore: cast_nullable_to_non_nullable
              as double,
      estimatedMinutesFromPrevious: null == estimatedMinutesFromPrevious
          ? _value.estimatedMinutesFromPrevious
          : estimatedMinutesFromPrevious // ignore: cast_nullable_to_non_nullable
              as int,
      actualArrivalTime: freezed == actualArrivalTime
          ? _value.actualArrivalTime
          : actualArrivalTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      isCompleted: null == isCompleted
          ? _value.isCompleted
          : isCompleted // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$RouteSegmentImplCopyWith<$Res>
    implements $RouteSegmentCopyWith<$Res> {
  factory _$$RouteSegmentImplCopyWith(
          _$RouteSegmentImpl value, $Res Function(_$RouteSegmentImpl) then) =
      __$$RouteSegmentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String passengerId,
      SegmentType type,
      Map<String, dynamic> location,
      int order,
      double distanceFromPrevious,
      int estimatedMinutesFromPrevious,
      DateTime? actualArrivalTime,
      bool isCompleted});
}

/// @nodoc
class __$$RouteSegmentImplCopyWithImpl<$Res>
    extends _$RouteSegmentCopyWithImpl<$Res, _$RouteSegmentImpl>
    implements _$$RouteSegmentImplCopyWith<$Res> {
  __$$RouteSegmentImplCopyWithImpl(
      _$RouteSegmentImpl _value, $Res Function(_$RouteSegmentImpl) _then)
      : super(_value, _then);

  /// Create a copy of RouteSegment
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? passengerId = null,
    Object? type = null,
    Object? location = null,
    Object? order = null,
    Object? distanceFromPrevious = null,
    Object? estimatedMinutesFromPrevious = null,
    Object? actualArrivalTime = freezed,
    Object? isCompleted = null,
  }) {
    return _then(_$RouteSegmentImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      passengerId: null == passengerId
          ? _value.passengerId
          : passengerId // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as SegmentType,
      location: null == location
          ? _value._location
          : location // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      order: null == order
          ? _value.order
          : order // ignore: cast_nullable_to_non_nullable
              as int,
      distanceFromPrevious: null == distanceFromPrevious
          ? _value.distanceFromPrevious
          : distanceFromPrevious // ignore: cast_nullable_to_non_nullable
              as double,
      estimatedMinutesFromPrevious: null == estimatedMinutesFromPrevious
          ? _value.estimatedMinutesFromPrevious
          : estimatedMinutesFromPrevious // ignore: cast_nullable_to_non_nullable
              as int,
      actualArrivalTime: freezed == actualArrivalTime
          ? _value.actualArrivalTime
          : actualArrivalTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      isCompleted: null == isCompleted
          ? _value.isCompleted
          : isCompleted // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$RouteSegmentImpl implements _RouteSegment {
  const _$RouteSegmentImpl(
      {required this.id,
      required this.passengerId,
      required this.type,
      required final Map<String, dynamic> location,
      required this.order,
      required this.distanceFromPrevious,
      required this.estimatedMinutesFromPrevious,
      this.actualArrivalTime,
      this.isCompleted = false})
      : _location = location;

  factory _$RouteSegmentImpl.fromJson(Map<String, dynamic> json) =>
      _$$RouteSegmentImplFromJson(json);

  @override
  final String id;
  @override
  final String passengerId;
  @override
  final SegmentType type;
  final Map<String, dynamic> _location;
  @override
  Map<String, dynamic> get location {
    if (_location is EqualUnmodifiableMapView) return _location;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_location);
  }

  @override
  final int order;
  @override
  final double distanceFromPrevious;
  @override
  final int estimatedMinutesFromPrevious;
  @override
  final DateTime? actualArrivalTime;
  @override
  @JsonKey()
  final bool isCompleted;

  @override
  String toString() {
    return 'RouteSegment(id: $id, passengerId: $passengerId, type: $type, location: $location, order: $order, distanceFromPrevious: $distanceFromPrevious, estimatedMinutesFromPrevious: $estimatedMinutesFromPrevious, actualArrivalTime: $actualArrivalTime, isCompleted: $isCompleted)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RouteSegmentImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.passengerId, passengerId) ||
                other.passengerId == passengerId) &&
            (identical(other.type, type) || other.type == type) &&
            const DeepCollectionEquality().equals(other._location, _location) &&
            (identical(other.order, order) || other.order == order) &&
            (identical(other.distanceFromPrevious, distanceFromPrevious) ||
                other.distanceFromPrevious == distanceFromPrevious) &&
            (identical(other.estimatedMinutesFromPrevious,
                    estimatedMinutesFromPrevious) ||
                other.estimatedMinutesFromPrevious ==
                    estimatedMinutesFromPrevious) &&
            (identical(other.actualArrivalTime, actualArrivalTime) ||
                other.actualArrivalTime == actualArrivalTime) &&
            (identical(other.isCompleted, isCompleted) ||
                other.isCompleted == isCompleted));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      passengerId,
      type,
      const DeepCollectionEquality().hash(_location),
      order,
      distanceFromPrevious,
      estimatedMinutesFromPrevious,
      actualArrivalTime,
      isCompleted);

  /// Create a copy of RouteSegment
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RouteSegmentImplCopyWith<_$RouteSegmentImpl> get copyWith =>
      __$$RouteSegmentImplCopyWithImpl<_$RouteSegmentImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$RouteSegmentImplToJson(
      this,
    );
  }
}

abstract class _RouteSegment implements RouteSegment {
  const factory _RouteSegment(
      {required final String id,
      required final String passengerId,
      required final SegmentType type,
      required final Map<String, dynamic> location,
      required final int order,
      required final double distanceFromPrevious,
      required final int estimatedMinutesFromPrevious,
      final DateTime? actualArrivalTime,
      final bool isCompleted}) = _$RouteSegmentImpl;

  factory _RouteSegment.fromJson(Map<String, dynamic> json) =
      _$RouteSegmentImpl.fromJson;

  @override
  String get id;
  @override
  String get passengerId;
  @override
  SegmentType get type;
  @override
  Map<String, dynamic> get location;
  @override
  int get order;
  @override
  double get distanceFromPrevious;
  @override
  int get estimatedMinutesFromPrevious;
  @override
  DateTime? get actualArrivalTime;
  @override
  bool get isCompleted;

  /// Create a copy of RouteSegment
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RouteSegmentImplCopyWith<_$RouteSegmentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SharedRideRequest _$SharedRideRequestFromJson(Map<String, dynamic> json) {
  return _SharedRideRequest.fromJson(json);
}

/// @nodoc
mixin _$SharedRideRequest {
  String get id => throw _privateConstructorUsedError;
  String get passengerId => throw _privateConstructorUsedError;
  Map<String, dynamic> get pickupLocation => throw _privateConstructorUsedError;
  Map<String, dynamic> get dropoffLocation =>
      throw _privateConstructorUsedError;
  DateTime get requestTime => throw _privateConstructorUsedError;
  int get passengerCount => throw _privateConstructorUsedError;
  SharedRideRequestStatus get status => throw _privateConstructorUsedError;
  String? get matchedRideId => throw _privateConstructorUsedError;
  double? get estimatedFare => throw _privateConstructorUsedError;
  double? get estimatedWaitTime => throw _privateConstructorUsedError;
  double? get estimatedTravelTime => throw _privateConstructorUsedError;
  int get maxWaitTimeSeconds =>
      throw _privateConstructorUsedError; // 5 minutos máximo de espera
  double get maxDetourKm => throw _privateConstructorUsedError;

  /// Serializes this SharedRideRequest to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SharedRideRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SharedRideRequestCopyWith<SharedRideRequest> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SharedRideRequestCopyWith<$Res> {
  factory $SharedRideRequestCopyWith(
          SharedRideRequest value, $Res Function(SharedRideRequest) then) =
      _$SharedRideRequestCopyWithImpl<$Res, SharedRideRequest>;
  @useResult
  $Res call(
      {String id,
      String passengerId,
      Map<String, dynamic> pickupLocation,
      Map<String, dynamic> dropoffLocation,
      DateTime requestTime,
      int passengerCount,
      SharedRideRequestStatus status,
      String? matchedRideId,
      double? estimatedFare,
      double? estimatedWaitTime,
      double? estimatedTravelTime,
      int maxWaitTimeSeconds,
      double maxDetourKm});
}

/// @nodoc
class _$SharedRideRequestCopyWithImpl<$Res, $Val extends SharedRideRequest>
    implements $SharedRideRequestCopyWith<$Res> {
  _$SharedRideRequestCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SharedRideRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? passengerId = null,
    Object? pickupLocation = null,
    Object? dropoffLocation = null,
    Object? requestTime = null,
    Object? passengerCount = null,
    Object? status = null,
    Object? matchedRideId = freezed,
    Object? estimatedFare = freezed,
    Object? estimatedWaitTime = freezed,
    Object? estimatedTravelTime = freezed,
    Object? maxWaitTimeSeconds = null,
    Object? maxDetourKm = null,
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
      pickupLocation: null == pickupLocation
          ? _value.pickupLocation
          : pickupLocation // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      dropoffLocation: null == dropoffLocation
          ? _value.dropoffLocation
          : dropoffLocation // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      requestTime: null == requestTime
          ? _value.requestTime
          : requestTime // ignore: cast_nullable_to_non_nullable
              as DateTime,
      passengerCount: null == passengerCount
          ? _value.passengerCount
          : passengerCount // ignore: cast_nullable_to_non_nullable
              as int,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as SharedRideRequestStatus,
      matchedRideId: freezed == matchedRideId
          ? _value.matchedRideId
          : matchedRideId // ignore: cast_nullable_to_non_nullable
              as String?,
      estimatedFare: freezed == estimatedFare
          ? _value.estimatedFare
          : estimatedFare // ignore: cast_nullable_to_non_nullable
              as double?,
      estimatedWaitTime: freezed == estimatedWaitTime
          ? _value.estimatedWaitTime
          : estimatedWaitTime // ignore: cast_nullable_to_non_nullable
              as double?,
      estimatedTravelTime: freezed == estimatedTravelTime
          ? _value.estimatedTravelTime
          : estimatedTravelTime // ignore: cast_nullable_to_non_nullable
              as double?,
      maxWaitTimeSeconds: null == maxWaitTimeSeconds
          ? _value.maxWaitTimeSeconds
          : maxWaitTimeSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      maxDetourKm: null == maxDetourKm
          ? _value.maxDetourKm
          : maxDetourKm // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SharedRideRequestImplCopyWith<$Res>
    implements $SharedRideRequestCopyWith<$Res> {
  factory _$$SharedRideRequestImplCopyWith(_$SharedRideRequestImpl value,
          $Res Function(_$SharedRideRequestImpl) then) =
      __$$SharedRideRequestImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String passengerId,
      Map<String, dynamic> pickupLocation,
      Map<String, dynamic> dropoffLocation,
      DateTime requestTime,
      int passengerCount,
      SharedRideRequestStatus status,
      String? matchedRideId,
      double? estimatedFare,
      double? estimatedWaitTime,
      double? estimatedTravelTime,
      int maxWaitTimeSeconds,
      double maxDetourKm});
}

/// @nodoc
class __$$SharedRideRequestImplCopyWithImpl<$Res>
    extends _$SharedRideRequestCopyWithImpl<$Res, _$SharedRideRequestImpl>
    implements _$$SharedRideRequestImplCopyWith<$Res> {
  __$$SharedRideRequestImplCopyWithImpl(_$SharedRideRequestImpl _value,
      $Res Function(_$SharedRideRequestImpl) _then)
      : super(_value, _then);

  /// Create a copy of SharedRideRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? passengerId = null,
    Object? pickupLocation = null,
    Object? dropoffLocation = null,
    Object? requestTime = null,
    Object? passengerCount = null,
    Object? status = null,
    Object? matchedRideId = freezed,
    Object? estimatedFare = freezed,
    Object? estimatedWaitTime = freezed,
    Object? estimatedTravelTime = freezed,
    Object? maxWaitTimeSeconds = null,
    Object? maxDetourKm = null,
  }) {
    return _then(_$SharedRideRequestImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      passengerId: null == passengerId
          ? _value.passengerId
          : passengerId // ignore: cast_nullable_to_non_nullable
              as String,
      pickupLocation: null == pickupLocation
          ? _value._pickupLocation
          : pickupLocation // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      dropoffLocation: null == dropoffLocation
          ? _value._dropoffLocation
          : dropoffLocation // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      requestTime: null == requestTime
          ? _value.requestTime
          : requestTime // ignore: cast_nullable_to_non_nullable
              as DateTime,
      passengerCount: null == passengerCount
          ? _value.passengerCount
          : passengerCount // ignore: cast_nullable_to_non_nullable
              as int,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as SharedRideRequestStatus,
      matchedRideId: freezed == matchedRideId
          ? _value.matchedRideId
          : matchedRideId // ignore: cast_nullable_to_non_nullable
              as String?,
      estimatedFare: freezed == estimatedFare
          ? _value.estimatedFare
          : estimatedFare // ignore: cast_nullable_to_non_nullable
              as double?,
      estimatedWaitTime: freezed == estimatedWaitTime
          ? _value.estimatedWaitTime
          : estimatedWaitTime // ignore: cast_nullable_to_non_nullable
              as double?,
      estimatedTravelTime: freezed == estimatedTravelTime
          ? _value.estimatedTravelTime
          : estimatedTravelTime // ignore: cast_nullable_to_non_nullable
              as double?,
      maxWaitTimeSeconds: null == maxWaitTimeSeconds
          ? _value.maxWaitTimeSeconds
          : maxWaitTimeSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      maxDetourKm: null == maxDetourKm
          ? _value.maxDetourKm
          : maxDetourKm // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SharedRideRequestImpl implements _SharedRideRequest {
  const _$SharedRideRequestImpl(
      {required this.id,
      required this.passengerId,
      required final Map<String, dynamic> pickupLocation,
      required final Map<String, dynamic> dropoffLocation,
      required this.requestTime,
      required this.passengerCount,
      this.status = SharedRideRequestStatus.pending,
      this.matchedRideId,
      this.estimatedFare,
      this.estimatedWaitTime,
      this.estimatedTravelTime,
      this.maxWaitTimeSeconds = 300,
      this.maxDetourKm = 0.5})
      : _pickupLocation = pickupLocation,
        _dropoffLocation = dropoffLocation;

  factory _$SharedRideRequestImpl.fromJson(Map<String, dynamic> json) =>
      _$$SharedRideRequestImplFromJson(json);

  @override
  final String id;
  @override
  final String passengerId;
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
  final DateTime requestTime;
  @override
  final int passengerCount;
  @override
  @JsonKey()
  final SharedRideRequestStatus status;
  @override
  final String? matchedRideId;
  @override
  final double? estimatedFare;
  @override
  final double? estimatedWaitTime;
  @override
  final double? estimatedTravelTime;
  @override
  @JsonKey()
  final int maxWaitTimeSeconds;
// 5 minutos máximo de espera
  @override
  @JsonKey()
  final double maxDetourKm;

  @override
  String toString() {
    return 'SharedRideRequest(id: $id, passengerId: $passengerId, pickupLocation: $pickupLocation, dropoffLocation: $dropoffLocation, requestTime: $requestTime, passengerCount: $passengerCount, status: $status, matchedRideId: $matchedRideId, estimatedFare: $estimatedFare, estimatedWaitTime: $estimatedWaitTime, estimatedTravelTime: $estimatedTravelTime, maxWaitTimeSeconds: $maxWaitTimeSeconds, maxDetourKm: $maxDetourKm)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SharedRideRequestImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.passengerId, passengerId) ||
                other.passengerId == passengerId) &&
            const DeepCollectionEquality()
                .equals(other._pickupLocation, _pickupLocation) &&
            const DeepCollectionEquality()
                .equals(other._dropoffLocation, _dropoffLocation) &&
            (identical(other.requestTime, requestTime) ||
                other.requestTime == requestTime) &&
            (identical(other.passengerCount, passengerCount) ||
                other.passengerCount == passengerCount) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.matchedRideId, matchedRideId) ||
                other.matchedRideId == matchedRideId) &&
            (identical(other.estimatedFare, estimatedFare) ||
                other.estimatedFare == estimatedFare) &&
            (identical(other.estimatedWaitTime, estimatedWaitTime) ||
                other.estimatedWaitTime == estimatedWaitTime) &&
            (identical(other.estimatedTravelTime, estimatedTravelTime) ||
                other.estimatedTravelTime == estimatedTravelTime) &&
            (identical(other.maxWaitTimeSeconds, maxWaitTimeSeconds) ||
                other.maxWaitTimeSeconds == maxWaitTimeSeconds) &&
            (identical(other.maxDetourKm, maxDetourKm) ||
                other.maxDetourKm == maxDetourKm));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      passengerId,
      const DeepCollectionEquality().hash(_pickupLocation),
      const DeepCollectionEquality().hash(_dropoffLocation),
      requestTime,
      passengerCount,
      status,
      matchedRideId,
      estimatedFare,
      estimatedWaitTime,
      estimatedTravelTime,
      maxWaitTimeSeconds,
      maxDetourKm);

  /// Create a copy of SharedRideRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SharedRideRequestImplCopyWith<_$SharedRideRequestImpl> get copyWith =>
      __$$SharedRideRequestImplCopyWithImpl<_$SharedRideRequestImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SharedRideRequestImplToJson(
      this,
    );
  }
}

abstract class _SharedRideRequest implements SharedRideRequest {
  const factory _SharedRideRequest(
      {required final String id,
      required final String passengerId,
      required final Map<String, dynamic> pickupLocation,
      required final Map<String, dynamic> dropoffLocation,
      required final DateTime requestTime,
      required final int passengerCount,
      final SharedRideRequestStatus status,
      final String? matchedRideId,
      final double? estimatedFare,
      final double? estimatedWaitTime,
      final double? estimatedTravelTime,
      final int maxWaitTimeSeconds,
      final double maxDetourKm}) = _$SharedRideRequestImpl;

  factory _SharedRideRequest.fromJson(Map<String, dynamic> json) =
      _$SharedRideRequestImpl.fromJson;

  @override
  String get id;
  @override
  String get passengerId;
  @override
  Map<String, dynamic> get pickupLocation;
  @override
  Map<String, dynamic> get dropoffLocation;
  @override
  DateTime get requestTime;
  @override
  int get passengerCount;
  @override
  SharedRideRequestStatus get status;
  @override
  String? get matchedRideId;
  @override
  double? get estimatedFare;
  @override
  double? get estimatedWaitTime;
  @override
  double? get estimatedTravelTime;
  @override
  int get maxWaitTimeSeconds; // 5 minutos máximo de espera
  @override
  double get maxDetourKm;

  /// Create a copy of SharedRideRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SharedRideRequestImplCopyWith<_$SharedRideRequestImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SharedRideConfig _$SharedRideConfigFromJson(Map<String, dynamic> json) {
  return _SharedRideConfig.fromJson(json);
}

/// @nodoc
mixin _$SharedRideConfig {
  bool get enableSharedRides => throw _privateConstructorUsedError;
  int get maxPassengersPerRide => throw _privateConstructorUsedError;
  double get discountPercent =>
      throw _privateConstructorUsedError; // 30% descuento
  double get driverBonusPercent =>
      throw _privateConstructorUsedError; // 80% de tarifa total para conductor
  int get maxDetourMinutes => throw _privateConstructorUsedError;
  double get maxDetourKm => throw _privateConstructorUsedError;
  int get matchingWindowSeconds =>
      throw _privateConstructorUsedError; // Ventana para emparejar pasajeros
  bool get allowDynamicRouting =>
      throw _privateConstructorUsedError; // Reoptimizar ruta con nuevos pasajeros
  bool get showOtherPassengers =>
      throw _privateConstructorUsedError; // Mostrar info de otros pasajeros
  bool get allowPassengerChat =>
      throw _privateConstructorUsedError; // Chat entre pasajeros
  bool get requireRatingAbove =>
      throw _privateConstructorUsedError; // Requerir rating mínimo
  double get minimumRating => throw _privateConstructorUsedError;
  int get maxMatchingAttempts => throw _privateConstructorUsedError;

  /// Serializes this SharedRideConfig to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SharedRideConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SharedRideConfigCopyWith<SharedRideConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SharedRideConfigCopyWith<$Res> {
  factory $SharedRideConfigCopyWith(
          SharedRideConfig value, $Res Function(SharedRideConfig) then) =
      _$SharedRideConfigCopyWithImpl<$Res, SharedRideConfig>;
  @useResult
  $Res call(
      {bool enableSharedRides,
      int maxPassengersPerRide,
      double discountPercent,
      double driverBonusPercent,
      int maxDetourMinutes,
      double maxDetourKm,
      int matchingWindowSeconds,
      bool allowDynamicRouting,
      bool showOtherPassengers,
      bool allowPassengerChat,
      bool requireRatingAbove,
      double minimumRating,
      int maxMatchingAttempts});
}

/// @nodoc
class _$SharedRideConfigCopyWithImpl<$Res, $Val extends SharedRideConfig>
    implements $SharedRideConfigCopyWith<$Res> {
  _$SharedRideConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SharedRideConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? enableSharedRides = null,
    Object? maxPassengersPerRide = null,
    Object? discountPercent = null,
    Object? driverBonusPercent = null,
    Object? maxDetourMinutes = null,
    Object? maxDetourKm = null,
    Object? matchingWindowSeconds = null,
    Object? allowDynamicRouting = null,
    Object? showOtherPassengers = null,
    Object? allowPassengerChat = null,
    Object? requireRatingAbove = null,
    Object? minimumRating = null,
    Object? maxMatchingAttempts = null,
  }) {
    return _then(_value.copyWith(
      enableSharedRides: null == enableSharedRides
          ? _value.enableSharedRides
          : enableSharedRides // ignore: cast_nullable_to_non_nullable
              as bool,
      maxPassengersPerRide: null == maxPassengersPerRide
          ? _value.maxPassengersPerRide
          : maxPassengersPerRide // ignore: cast_nullable_to_non_nullable
              as int,
      discountPercent: null == discountPercent
          ? _value.discountPercent
          : discountPercent // ignore: cast_nullable_to_non_nullable
              as double,
      driverBonusPercent: null == driverBonusPercent
          ? _value.driverBonusPercent
          : driverBonusPercent // ignore: cast_nullable_to_non_nullable
              as double,
      maxDetourMinutes: null == maxDetourMinutes
          ? _value.maxDetourMinutes
          : maxDetourMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      maxDetourKm: null == maxDetourKm
          ? _value.maxDetourKm
          : maxDetourKm // ignore: cast_nullable_to_non_nullable
              as double,
      matchingWindowSeconds: null == matchingWindowSeconds
          ? _value.matchingWindowSeconds
          : matchingWindowSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      allowDynamicRouting: null == allowDynamicRouting
          ? _value.allowDynamicRouting
          : allowDynamicRouting // ignore: cast_nullable_to_non_nullable
              as bool,
      showOtherPassengers: null == showOtherPassengers
          ? _value.showOtherPassengers
          : showOtherPassengers // ignore: cast_nullable_to_non_nullable
              as bool,
      allowPassengerChat: null == allowPassengerChat
          ? _value.allowPassengerChat
          : allowPassengerChat // ignore: cast_nullable_to_non_nullable
              as bool,
      requireRatingAbove: null == requireRatingAbove
          ? _value.requireRatingAbove
          : requireRatingAbove // ignore: cast_nullable_to_non_nullable
              as bool,
      minimumRating: null == minimumRating
          ? _value.minimumRating
          : minimumRating // ignore: cast_nullable_to_non_nullable
              as double,
      maxMatchingAttempts: null == maxMatchingAttempts
          ? _value.maxMatchingAttempts
          : maxMatchingAttempts // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SharedRideConfigImplCopyWith<$Res>
    implements $SharedRideConfigCopyWith<$Res> {
  factory _$$SharedRideConfigImplCopyWith(_$SharedRideConfigImpl value,
          $Res Function(_$SharedRideConfigImpl) then) =
      __$$SharedRideConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool enableSharedRides,
      int maxPassengersPerRide,
      double discountPercent,
      double driverBonusPercent,
      int maxDetourMinutes,
      double maxDetourKm,
      int matchingWindowSeconds,
      bool allowDynamicRouting,
      bool showOtherPassengers,
      bool allowPassengerChat,
      bool requireRatingAbove,
      double minimumRating,
      int maxMatchingAttempts});
}

/// @nodoc
class __$$SharedRideConfigImplCopyWithImpl<$Res>
    extends _$SharedRideConfigCopyWithImpl<$Res, _$SharedRideConfigImpl>
    implements _$$SharedRideConfigImplCopyWith<$Res> {
  __$$SharedRideConfigImplCopyWithImpl(_$SharedRideConfigImpl _value,
      $Res Function(_$SharedRideConfigImpl) _then)
      : super(_value, _then);

  /// Create a copy of SharedRideConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? enableSharedRides = null,
    Object? maxPassengersPerRide = null,
    Object? discountPercent = null,
    Object? driverBonusPercent = null,
    Object? maxDetourMinutes = null,
    Object? maxDetourKm = null,
    Object? matchingWindowSeconds = null,
    Object? allowDynamicRouting = null,
    Object? showOtherPassengers = null,
    Object? allowPassengerChat = null,
    Object? requireRatingAbove = null,
    Object? minimumRating = null,
    Object? maxMatchingAttempts = null,
  }) {
    return _then(_$SharedRideConfigImpl(
      enableSharedRides: null == enableSharedRides
          ? _value.enableSharedRides
          : enableSharedRides // ignore: cast_nullable_to_non_nullable
              as bool,
      maxPassengersPerRide: null == maxPassengersPerRide
          ? _value.maxPassengersPerRide
          : maxPassengersPerRide // ignore: cast_nullable_to_non_nullable
              as int,
      discountPercent: null == discountPercent
          ? _value.discountPercent
          : discountPercent // ignore: cast_nullable_to_non_nullable
              as double,
      driverBonusPercent: null == driverBonusPercent
          ? _value.driverBonusPercent
          : driverBonusPercent // ignore: cast_nullable_to_non_nullable
              as double,
      maxDetourMinutes: null == maxDetourMinutes
          ? _value.maxDetourMinutes
          : maxDetourMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      maxDetourKm: null == maxDetourKm
          ? _value.maxDetourKm
          : maxDetourKm // ignore: cast_nullable_to_non_nullable
              as double,
      matchingWindowSeconds: null == matchingWindowSeconds
          ? _value.matchingWindowSeconds
          : matchingWindowSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      allowDynamicRouting: null == allowDynamicRouting
          ? _value.allowDynamicRouting
          : allowDynamicRouting // ignore: cast_nullable_to_non_nullable
              as bool,
      showOtherPassengers: null == showOtherPassengers
          ? _value.showOtherPassengers
          : showOtherPassengers // ignore: cast_nullable_to_non_nullable
              as bool,
      allowPassengerChat: null == allowPassengerChat
          ? _value.allowPassengerChat
          : allowPassengerChat // ignore: cast_nullable_to_non_nullable
              as bool,
      requireRatingAbove: null == requireRatingAbove
          ? _value.requireRatingAbove
          : requireRatingAbove // ignore: cast_nullable_to_non_nullable
              as bool,
      minimumRating: null == minimumRating
          ? _value.minimumRating
          : minimumRating // ignore: cast_nullable_to_non_nullable
              as double,
      maxMatchingAttempts: null == maxMatchingAttempts
          ? _value.maxMatchingAttempts
          : maxMatchingAttempts // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SharedRideConfigImpl implements _SharedRideConfig {
  const _$SharedRideConfigImpl(
      {this.enableSharedRides = true,
      this.maxPassengersPerRide = 4,
      this.discountPercent = 0.3,
      this.driverBonusPercent = 0.8,
      this.maxDetourMinutes = 15,
      this.maxDetourKm = 2.0,
      this.matchingWindowSeconds = 300,
      this.allowDynamicRouting = true,
      this.showOtherPassengers = true,
      this.allowPassengerChat = false,
      this.requireRatingAbove = true,
      this.minimumRating = 4.0,
      this.maxMatchingAttempts = 10});

  factory _$SharedRideConfigImpl.fromJson(Map<String, dynamic> json) =>
      _$$SharedRideConfigImplFromJson(json);

  @override
  @JsonKey()
  final bool enableSharedRides;
  @override
  @JsonKey()
  final int maxPassengersPerRide;
  @override
  @JsonKey()
  final double discountPercent;
// 30% descuento
  @override
  @JsonKey()
  final double driverBonusPercent;
// 80% de tarifa total para conductor
  @override
  @JsonKey()
  final int maxDetourMinutes;
  @override
  @JsonKey()
  final double maxDetourKm;
  @override
  @JsonKey()
  final int matchingWindowSeconds;
// Ventana para emparejar pasajeros
  @override
  @JsonKey()
  final bool allowDynamicRouting;
// Reoptimizar ruta con nuevos pasajeros
  @override
  @JsonKey()
  final bool showOtherPassengers;
// Mostrar info de otros pasajeros
  @override
  @JsonKey()
  final bool allowPassengerChat;
// Chat entre pasajeros
  @override
  @JsonKey()
  final bool requireRatingAbove;
// Requerir rating mínimo
  @override
  @JsonKey()
  final double minimumRating;
  @override
  @JsonKey()
  final int maxMatchingAttempts;

  @override
  String toString() {
    return 'SharedRideConfig(enableSharedRides: $enableSharedRides, maxPassengersPerRide: $maxPassengersPerRide, discountPercent: $discountPercent, driverBonusPercent: $driverBonusPercent, maxDetourMinutes: $maxDetourMinutes, maxDetourKm: $maxDetourKm, matchingWindowSeconds: $matchingWindowSeconds, allowDynamicRouting: $allowDynamicRouting, showOtherPassengers: $showOtherPassengers, allowPassengerChat: $allowPassengerChat, requireRatingAbove: $requireRatingAbove, minimumRating: $minimumRating, maxMatchingAttempts: $maxMatchingAttempts)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SharedRideConfigImpl &&
            (identical(other.enableSharedRides, enableSharedRides) ||
                other.enableSharedRides == enableSharedRides) &&
            (identical(other.maxPassengersPerRide, maxPassengersPerRide) ||
                other.maxPassengersPerRide == maxPassengersPerRide) &&
            (identical(other.discountPercent, discountPercent) ||
                other.discountPercent == discountPercent) &&
            (identical(other.driverBonusPercent, driverBonusPercent) ||
                other.driverBonusPercent == driverBonusPercent) &&
            (identical(other.maxDetourMinutes, maxDetourMinutes) ||
                other.maxDetourMinutes == maxDetourMinutes) &&
            (identical(other.maxDetourKm, maxDetourKm) ||
                other.maxDetourKm == maxDetourKm) &&
            (identical(other.matchingWindowSeconds, matchingWindowSeconds) ||
                other.matchingWindowSeconds == matchingWindowSeconds) &&
            (identical(other.allowDynamicRouting, allowDynamicRouting) ||
                other.allowDynamicRouting == allowDynamicRouting) &&
            (identical(other.showOtherPassengers, showOtherPassengers) ||
                other.showOtherPassengers == showOtherPassengers) &&
            (identical(other.allowPassengerChat, allowPassengerChat) ||
                other.allowPassengerChat == allowPassengerChat) &&
            (identical(other.requireRatingAbove, requireRatingAbove) ||
                other.requireRatingAbove == requireRatingAbove) &&
            (identical(other.minimumRating, minimumRating) ||
                other.minimumRating == minimumRating) &&
            (identical(other.maxMatchingAttempts, maxMatchingAttempts) ||
                other.maxMatchingAttempts == maxMatchingAttempts));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      enableSharedRides,
      maxPassengersPerRide,
      discountPercent,
      driverBonusPercent,
      maxDetourMinutes,
      maxDetourKm,
      matchingWindowSeconds,
      allowDynamicRouting,
      showOtherPassengers,
      allowPassengerChat,
      requireRatingAbove,
      minimumRating,
      maxMatchingAttempts);

  /// Create a copy of SharedRideConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SharedRideConfigImplCopyWith<_$SharedRideConfigImpl> get copyWith =>
      __$$SharedRideConfigImplCopyWithImpl<_$SharedRideConfigImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SharedRideConfigImplToJson(
      this,
    );
  }
}

abstract class _SharedRideConfig implements SharedRideConfig {
  const factory _SharedRideConfig(
      {final bool enableSharedRides,
      final int maxPassengersPerRide,
      final double discountPercent,
      final double driverBonusPercent,
      final int maxDetourMinutes,
      final double maxDetourKm,
      final int matchingWindowSeconds,
      final bool allowDynamicRouting,
      final bool showOtherPassengers,
      final bool allowPassengerChat,
      final bool requireRatingAbove,
      final double minimumRating,
      final int maxMatchingAttempts}) = _$SharedRideConfigImpl;

  factory _SharedRideConfig.fromJson(Map<String, dynamic> json) =
      _$SharedRideConfigImpl.fromJson;

  @override
  bool get enableSharedRides;
  @override
  int get maxPassengersPerRide;
  @override
  double get discountPercent; // 30% descuento
  @override
  double get driverBonusPercent; // 80% de tarifa total para conductor
  @override
  int get maxDetourMinutes;
  @override
  double get maxDetourKm;
  @override
  int get matchingWindowSeconds; // Ventana para emparejar pasajeros
  @override
  bool get allowDynamicRouting; // Reoptimizar ruta con nuevos pasajeros
  @override
  bool get showOtherPassengers; // Mostrar info de otros pasajeros
  @override
  bool get allowPassengerChat; // Chat entre pasajeros
  @override
  bool get requireRatingAbove; // Requerir rating mínimo
  @override
  double get minimumRating;
  @override
  int get maxMatchingAttempts;

  /// Create a copy of SharedRideConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SharedRideConfigImplCopyWith<_$SharedRideConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

RideMatchingCriteria _$RideMatchingCriteriaFromJson(Map<String, dynamic> json) {
  return _RideMatchingCriteria.fromJson(json);
}

/// @nodoc
mixin _$RideMatchingCriteria {
  double get maxDetourPercent =>
      throw _privateConstructorUsedError; // % máximo de desvío
  double get maxWaitTime =>
      throw _privateConstructorUsedError; // Minutos máximos de espera
  double get compatibilityScore =>
      throw _privateConstructorUsedError; // Score mínimo de compatibilidad
  bool get sameDirection =>
      throw _privateConstructorUsedError; // Misma dirección general
  double get overlapPercent => throw _privateConstructorUsedError;

  /// Serializes this RideMatchingCriteria to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RideMatchingCriteria
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RideMatchingCriteriaCopyWith<RideMatchingCriteria> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RideMatchingCriteriaCopyWith<$Res> {
  factory $RideMatchingCriteriaCopyWith(RideMatchingCriteria value,
          $Res Function(RideMatchingCriteria) then) =
      _$RideMatchingCriteriaCopyWithImpl<$Res, RideMatchingCriteria>;
  @useResult
  $Res call(
      {double maxDetourPercent,
      double maxWaitTime,
      double compatibilityScore,
      bool sameDirection,
      double overlapPercent});
}

/// @nodoc
class _$RideMatchingCriteriaCopyWithImpl<$Res,
        $Val extends RideMatchingCriteria>
    implements $RideMatchingCriteriaCopyWith<$Res> {
  _$RideMatchingCriteriaCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RideMatchingCriteria
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? maxDetourPercent = null,
    Object? maxWaitTime = null,
    Object? compatibilityScore = null,
    Object? sameDirection = null,
    Object? overlapPercent = null,
  }) {
    return _then(_value.copyWith(
      maxDetourPercent: null == maxDetourPercent
          ? _value.maxDetourPercent
          : maxDetourPercent // ignore: cast_nullable_to_non_nullable
              as double,
      maxWaitTime: null == maxWaitTime
          ? _value.maxWaitTime
          : maxWaitTime // ignore: cast_nullable_to_non_nullable
              as double,
      compatibilityScore: null == compatibilityScore
          ? _value.compatibilityScore
          : compatibilityScore // ignore: cast_nullable_to_non_nullable
              as double,
      sameDirection: null == sameDirection
          ? _value.sameDirection
          : sameDirection // ignore: cast_nullable_to_non_nullable
              as bool,
      overlapPercent: null == overlapPercent
          ? _value.overlapPercent
          : overlapPercent // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$RideMatchingCriteriaImplCopyWith<$Res>
    implements $RideMatchingCriteriaCopyWith<$Res> {
  factory _$$RideMatchingCriteriaImplCopyWith(_$RideMatchingCriteriaImpl value,
          $Res Function(_$RideMatchingCriteriaImpl) then) =
      __$$RideMatchingCriteriaImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {double maxDetourPercent,
      double maxWaitTime,
      double compatibilityScore,
      bool sameDirection,
      double overlapPercent});
}

/// @nodoc
class __$$RideMatchingCriteriaImplCopyWithImpl<$Res>
    extends _$RideMatchingCriteriaCopyWithImpl<$Res, _$RideMatchingCriteriaImpl>
    implements _$$RideMatchingCriteriaImplCopyWith<$Res> {
  __$$RideMatchingCriteriaImplCopyWithImpl(_$RideMatchingCriteriaImpl _value,
      $Res Function(_$RideMatchingCriteriaImpl) _then)
      : super(_value, _then);

  /// Create a copy of RideMatchingCriteria
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? maxDetourPercent = null,
    Object? maxWaitTime = null,
    Object? compatibilityScore = null,
    Object? sameDirection = null,
    Object? overlapPercent = null,
  }) {
    return _then(_$RideMatchingCriteriaImpl(
      maxDetourPercent: null == maxDetourPercent
          ? _value.maxDetourPercent
          : maxDetourPercent // ignore: cast_nullable_to_non_nullable
              as double,
      maxWaitTime: null == maxWaitTime
          ? _value.maxWaitTime
          : maxWaitTime // ignore: cast_nullable_to_non_nullable
              as double,
      compatibilityScore: null == compatibilityScore
          ? _value.compatibilityScore
          : compatibilityScore // ignore: cast_nullable_to_non_nullable
              as double,
      sameDirection: null == sameDirection
          ? _value.sameDirection
          : sameDirection // ignore: cast_nullable_to_non_nullable
              as bool,
      overlapPercent: null == overlapPercent
          ? _value.overlapPercent
          : overlapPercent // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$RideMatchingCriteriaImpl implements _RideMatchingCriteria {
  const _$RideMatchingCriteriaImpl(
      {required this.maxDetourPercent,
      required this.maxWaitTime,
      required this.compatibilityScore,
      required this.sameDirection,
      required this.overlapPercent});

  factory _$RideMatchingCriteriaImpl.fromJson(Map<String, dynamic> json) =>
      _$$RideMatchingCriteriaImplFromJson(json);

  @override
  final double maxDetourPercent;
// % máximo de desvío
  @override
  final double maxWaitTime;
// Minutos máximos de espera
  @override
  final double compatibilityScore;
// Score mínimo de compatibilidad
  @override
  final bool sameDirection;
// Misma dirección general
  @override
  final double overlapPercent;

  @override
  String toString() {
    return 'RideMatchingCriteria(maxDetourPercent: $maxDetourPercent, maxWaitTime: $maxWaitTime, compatibilityScore: $compatibilityScore, sameDirection: $sameDirection, overlapPercent: $overlapPercent)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RideMatchingCriteriaImpl &&
            (identical(other.maxDetourPercent, maxDetourPercent) ||
                other.maxDetourPercent == maxDetourPercent) &&
            (identical(other.maxWaitTime, maxWaitTime) ||
                other.maxWaitTime == maxWaitTime) &&
            (identical(other.compatibilityScore, compatibilityScore) ||
                other.compatibilityScore == compatibilityScore) &&
            (identical(other.sameDirection, sameDirection) ||
                other.sameDirection == sameDirection) &&
            (identical(other.overlapPercent, overlapPercent) ||
                other.overlapPercent == overlapPercent));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, maxDetourPercent, maxWaitTime,
      compatibilityScore, sameDirection, overlapPercent);

  /// Create a copy of RideMatchingCriteria
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RideMatchingCriteriaImplCopyWith<_$RideMatchingCriteriaImpl>
      get copyWith =>
          __$$RideMatchingCriteriaImplCopyWithImpl<_$RideMatchingCriteriaImpl>(
              this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$RideMatchingCriteriaImplToJson(
      this,
    );
  }
}

abstract class _RideMatchingCriteria implements RideMatchingCriteria {
  const factory _RideMatchingCriteria(
      {required final double maxDetourPercent,
      required final double maxWaitTime,
      required final double compatibilityScore,
      required final bool sameDirection,
      required final double overlapPercent}) = _$RideMatchingCriteriaImpl;

  factory _RideMatchingCriteria.fromJson(Map<String, dynamic> json) =
      _$RideMatchingCriteriaImpl.fromJson;

  @override
  double get maxDetourPercent; // % máximo de desvío
  @override
  double get maxWaitTime; // Minutos máximos de espera
  @override
  double get compatibilityScore; // Score mínimo de compatibilidad
  @override
  bool get sameDirection; // Misma dirección general
  @override
  double get overlapPercent;

  /// Create a copy of RideMatchingCriteria
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RideMatchingCriteriaImplCopyWith<_$RideMatchingCriteriaImpl>
      get copyWith => throw _privateConstructorUsedError;
}
