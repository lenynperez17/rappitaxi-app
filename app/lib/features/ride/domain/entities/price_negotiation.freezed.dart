// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'price_negotiation.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

PriceNegotiation _$PriceNegotiationFromJson(Map<String, dynamic> json) {
  return _PriceNegotiation.fromJson(json);
}

/// @nodoc
mixin _$PriceNegotiation {
  String get id => throw _privateConstructorUsedError;
  String get rideRequestId => throw _privateConstructorUsedError;
  String get passengerId => throw _privateConstructorUsedError;
  double get suggestedPrice => throw _privateConstructorUsedError;
  double? get passengerOffer => throw _privateConstructorUsedError;
  NegotiationType get negotiationType => throw _privateConstructorUsedError;
  NegotiationStatus get status => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get expiresAt => throw _privateConstructorUsedError;
  DateTime? get acceptedAt => throw _privateConstructorUsedError;
  DateTime? get rejectedAt => throw _privateConstructorUsedError;
  String? get acceptedOfferId => throw _privateConstructorUsedError;
  int? get maxOffers => throw _privateConstructorUsedError;
  List<String>? get allowedDriverIds => throw _privateConstructorUsedError;
  Map<String, dynamic>? get metadata => throw _privateConstructorUsedError;

  /// Serializes this PriceNegotiation to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PriceNegotiation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PriceNegotiationCopyWith<PriceNegotiation> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PriceNegotiationCopyWith<$Res> {
  factory $PriceNegotiationCopyWith(
          PriceNegotiation value, $Res Function(PriceNegotiation) then) =
      _$PriceNegotiationCopyWithImpl<$Res, PriceNegotiation>;
  @useResult
  $Res call(
      {String id,
      String rideRequestId,
      String passengerId,
      double suggestedPrice,
      double? passengerOffer,
      NegotiationType negotiationType,
      NegotiationStatus status,
      DateTime createdAt,
      DateTime expiresAt,
      DateTime? acceptedAt,
      DateTime? rejectedAt,
      String? acceptedOfferId,
      int? maxOffers,
      List<String>? allowedDriverIds,
      Map<String, dynamic>? metadata});
}

/// @nodoc
class _$PriceNegotiationCopyWithImpl<$Res, $Val extends PriceNegotiation>
    implements $PriceNegotiationCopyWith<$Res> {
  _$PriceNegotiationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PriceNegotiation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? rideRequestId = null,
    Object? passengerId = null,
    Object? suggestedPrice = null,
    Object? passengerOffer = freezed,
    Object? negotiationType = null,
    Object? status = null,
    Object? createdAt = null,
    Object? expiresAt = null,
    Object? acceptedAt = freezed,
    Object? rejectedAt = freezed,
    Object? acceptedOfferId = freezed,
    Object? maxOffers = freezed,
    Object? allowedDriverIds = freezed,
    Object? metadata = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      rideRequestId: null == rideRequestId
          ? _value.rideRequestId
          : rideRequestId // ignore: cast_nullable_to_non_nullable
              as String,
      passengerId: null == passengerId
          ? _value.passengerId
          : passengerId // ignore: cast_nullable_to_non_nullable
              as String,
      suggestedPrice: null == suggestedPrice
          ? _value.suggestedPrice
          : suggestedPrice // ignore: cast_nullable_to_non_nullable
              as double,
      passengerOffer: freezed == passengerOffer
          ? _value.passengerOffer
          : passengerOffer // ignore: cast_nullable_to_non_nullable
              as double?,
      negotiationType: null == negotiationType
          ? _value.negotiationType
          : negotiationType // ignore: cast_nullable_to_non_nullable
              as NegotiationType,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as NegotiationStatus,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      expiresAt: null == expiresAt
          ? _value.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      acceptedAt: freezed == acceptedAt
          ? _value.acceptedAt
          : acceptedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      rejectedAt: freezed == rejectedAt
          ? _value.rejectedAt
          : rejectedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      acceptedOfferId: freezed == acceptedOfferId
          ? _value.acceptedOfferId
          : acceptedOfferId // ignore: cast_nullable_to_non_nullable
              as String?,
      maxOffers: freezed == maxOffers
          ? _value.maxOffers
          : maxOffers // ignore: cast_nullable_to_non_nullable
              as int?,
      allowedDriverIds: freezed == allowedDriverIds
          ? _value.allowedDriverIds
          : allowedDriverIds // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      metadata: freezed == metadata
          ? _value.metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PriceNegotiationImplCopyWith<$Res>
    implements $PriceNegotiationCopyWith<$Res> {
  factory _$$PriceNegotiationImplCopyWith(_$PriceNegotiationImpl value,
          $Res Function(_$PriceNegotiationImpl) then) =
      __$$PriceNegotiationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String rideRequestId,
      String passengerId,
      double suggestedPrice,
      double? passengerOffer,
      NegotiationType negotiationType,
      NegotiationStatus status,
      DateTime createdAt,
      DateTime expiresAt,
      DateTime? acceptedAt,
      DateTime? rejectedAt,
      String? acceptedOfferId,
      int? maxOffers,
      List<String>? allowedDriverIds,
      Map<String, dynamic>? metadata});
}

/// @nodoc
class __$$PriceNegotiationImplCopyWithImpl<$Res>
    extends _$PriceNegotiationCopyWithImpl<$Res, _$PriceNegotiationImpl>
    implements _$$PriceNegotiationImplCopyWith<$Res> {
  __$$PriceNegotiationImplCopyWithImpl(_$PriceNegotiationImpl _value,
      $Res Function(_$PriceNegotiationImpl) _then)
      : super(_value, _then);

  /// Create a copy of PriceNegotiation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? rideRequestId = null,
    Object? passengerId = null,
    Object? suggestedPrice = null,
    Object? passengerOffer = freezed,
    Object? negotiationType = null,
    Object? status = null,
    Object? createdAt = null,
    Object? expiresAt = null,
    Object? acceptedAt = freezed,
    Object? rejectedAt = freezed,
    Object? acceptedOfferId = freezed,
    Object? maxOffers = freezed,
    Object? allowedDriverIds = freezed,
    Object? metadata = freezed,
  }) {
    return _then(_$PriceNegotiationImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      rideRequestId: null == rideRequestId
          ? _value.rideRequestId
          : rideRequestId // ignore: cast_nullable_to_non_nullable
              as String,
      passengerId: null == passengerId
          ? _value.passengerId
          : passengerId // ignore: cast_nullable_to_non_nullable
              as String,
      suggestedPrice: null == suggestedPrice
          ? _value.suggestedPrice
          : suggestedPrice // ignore: cast_nullable_to_non_nullable
              as double,
      passengerOffer: freezed == passengerOffer
          ? _value.passengerOffer
          : passengerOffer // ignore: cast_nullable_to_non_nullable
              as double?,
      negotiationType: null == negotiationType
          ? _value.negotiationType
          : negotiationType // ignore: cast_nullable_to_non_nullable
              as NegotiationType,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as NegotiationStatus,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      expiresAt: null == expiresAt
          ? _value.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      acceptedAt: freezed == acceptedAt
          ? _value.acceptedAt
          : acceptedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      rejectedAt: freezed == rejectedAt
          ? _value.rejectedAt
          : rejectedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      acceptedOfferId: freezed == acceptedOfferId
          ? _value.acceptedOfferId
          : acceptedOfferId // ignore: cast_nullable_to_non_nullable
              as String?,
      maxOffers: freezed == maxOffers
          ? _value.maxOffers
          : maxOffers // ignore: cast_nullable_to_non_nullable
              as int?,
      allowedDriverIds: freezed == allowedDriverIds
          ? _value._allowedDriverIds
          : allowedDriverIds // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      metadata: freezed == metadata
          ? _value._metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PriceNegotiationImpl implements _PriceNegotiation {
  const _$PriceNegotiationImpl(
      {required this.id,
      required this.rideRequestId,
      required this.passengerId,
      required this.suggestedPrice,
      required this.passengerOffer,
      required this.negotiationType,
      required this.status,
      required this.createdAt,
      required this.expiresAt,
      this.acceptedAt,
      this.rejectedAt,
      this.acceptedOfferId,
      this.maxOffers,
      final List<String>? allowedDriverIds,
      final Map<String, dynamic>? metadata})
      : _allowedDriverIds = allowedDriverIds,
        _metadata = metadata;

  factory _$PriceNegotiationImpl.fromJson(Map<String, dynamic> json) =>
      _$$PriceNegotiationImplFromJson(json);

  @override
  final String id;
  @override
  final String rideRequestId;
  @override
  final String passengerId;
  @override
  final double suggestedPrice;
  @override
  final double? passengerOffer;
  @override
  final NegotiationType negotiationType;
  @override
  final NegotiationStatus status;
  @override
  final DateTime createdAt;
  @override
  final DateTime expiresAt;
  @override
  final DateTime? acceptedAt;
  @override
  final DateTime? rejectedAt;
  @override
  final String? acceptedOfferId;
  @override
  final int? maxOffers;
  final List<String>? _allowedDriverIds;
  @override
  List<String>? get allowedDriverIds {
    final value = _allowedDriverIds;
    if (value == null) return null;
    if (_allowedDriverIds is EqualUnmodifiableListView)
      return _allowedDriverIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
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
    return 'PriceNegotiation(id: $id, rideRequestId: $rideRequestId, passengerId: $passengerId, suggestedPrice: $suggestedPrice, passengerOffer: $passengerOffer, negotiationType: $negotiationType, status: $status, createdAt: $createdAt, expiresAt: $expiresAt, acceptedAt: $acceptedAt, rejectedAt: $rejectedAt, acceptedOfferId: $acceptedOfferId, maxOffers: $maxOffers, allowedDriverIds: $allowedDriverIds, metadata: $metadata)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PriceNegotiationImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.rideRequestId, rideRequestId) ||
                other.rideRequestId == rideRequestId) &&
            (identical(other.passengerId, passengerId) ||
                other.passengerId == passengerId) &&
            (identical(other.suggestedPrice, suggestedPrice) ||
                other.suggestedPrice == suggestedPrice) &&
            (identical(other.passengerOffer, passengerOffer) ||
                other.passengerOffer == passengerOffer) &&
            (identical(other.negotiationType, negotiationType) ||
                other.negotiationType == negotiationType) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt) &&
            (identical(other.acceptedAt, acceptedAt) ||
                other.acceptedAt == acceptedAt) &&
            (identical(other.rejectedAt, rejectedAt) ||
                other.rejectedAt == rejectedAt) &&
            (identical(other.acceptedOfferId, acceptedOfferId) ||
                other.acceptedOfferId == acceptedOfferId) &&
            (identical(other.maxOffers, maxOffers) ||
                other.maxOffers == maxOffers) &&
            const DeepCollectionEquality()
                .equals(other._allowedDriverIds, _allowedDriverIds) &&
            const DeepCollectionEquality().equals(other._metadata, _metadata));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      rideRequestId,
      passengerId,
      suggestedPrice,
      passengerOffer,
      negotiationType,
      status,
      createdAt,
      expiresAt,
      acceptedAt,
      rejectedAt,
      acceptedOfferId,
      maxOffers,
      const DeepCollectionEquality().hash(_allowedDriverIds),
      const DeepCollectionEquality().hash(_metadata));

  /// Create a copy of PriceNegotiation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PriceNegotiationImplCopyWith<_$PriceNegotiationImpl> get copyWith =>
      __$$PriceNegotiationImplCopyWithImpl<_$PriceNegotiationImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PriceNegotiationImplToJson(
      this,
    );
  }
}

abstract class _PriceNegotiation implements PriceNegotiation {
  const factory _PriceNegotiation(
      {required final String id,
      required final String rideRequestId,
      required final String passengerId,
      required final double suggestedPrice,
      required final double? passengerOffer,
      required final NegotiationType negotiationType,
      required final NegotiationStatus status,
      required final DateTime createdAt,
      required final DateTime expiresAt,
      final DateTime? acceptedAt,
      final DateTime? rejectedAt,
      final String? acceptedOfferId,
      final int? maxOffers,
      final List<String>? allowedDriverIds,
      final Map<String, dynamic>? metadata}) = _$PriceNegotiationImpl;

  factory _PriceNegotiation.fromJson(Map<String, dynamic> json) =
      _$PriceNegotiationImpl.fromJson;

  @override
  String get id;
  @override
  String get rideRequestId;
  @override
  String get passengerId;
  @override
  double get suggestedPrice;
  @override
  double? get passengerOffer;
  @override
  NegotiationType get negotiationType;
  @override
  NegotiationStatus get status;
  @override
  DateTime get createdAt;
  @override
  DateTime get expiresAt;
  @override
  DateTime? get acceptedAt;
  @override
  DateTime? get rejectedAt;
  @override
  String? get acceptedOfferId;
  @override
  int? get maxOffers;
  @override
  List<String>? get allowedDriverIds;
  @override
  Map<String, dynamic>? get metadata;

  /// Create a copy of PriceNegotiation
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PriceNegotiationImplCopyWith<_$PriceNegotiationImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

DriverOffer _$DriverOfferFromJson(Map<String, dynamic> json) {
  return _DriverOffer.fromJson(json);
}

/// @nodoc
mixin _$DriverOffer {
  String get id => throw _privateConstructorUsedError;
  String get negotiationId => throw _privateConstructorUsedError;
  String get driverId => throw _privateConstructorUsedError;
  String get driverName => throw _privateConstructorUsedError;
  String? get driverPhoto => throw _privateConstructorUsedError;
  double get driverRating => throw _privateConstructorUsedError;
  int get totalTrips => throw _privateConstructorUsedError;
  String get vehicleModel => throw _privateConstructorUsedError;
  String get vehiclePlate => throw _privateConstructorUsedError;
  double get offeredPrice => throw _privateConstructorUsedError;
  double get estimatedDistance => throw _privateConstructorUsedError;
  int get estimatedArrivalMinutes => throw _privateConstructorUsedError;
  OfferStatus get status => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime? get expiresAt => throw _privateConstructorUsedError;
  DateTime? get acceptedAt => throw _privateConstructorUsedError;
  DateTime? get rejectedAt => throw _privateConstructorUsedError;
  String? get message => throw _privateConstructorUsedError;
  bool? get isCounterOffer => throw _privateConstructorUsedError;
  String? get originalOfferId => throw _privateConstructorUsedError;
  Map<String, dynamic>? get driverMetadata =>
      throw _privateConstructorUsedError;

  /// Serializes this DriverOffer to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DriverOffer
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DriverOfferCopyWith<DriverOffer> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DriverOfferCopyWith<$Res> {
  factory $DriverOfferCopyWith(
          DriverOffer value, $Res Function(DriverOffer) then) =
      _$DriverOfferCopyWithImpl<$Res, DriverOffer>;
  @useResult
  $Res call(
      {String id,
      String negotiationId,
      String driverId,
      String driverName,
      String? driverPhoto,
      double driverRating,
      int totalTrips,
      String vehicleModel,
      String vehiclePlate,
      double offeredPrice,
      double estimatedDistance,
      int estimatedArrivalMinutes,
      OfferStatus status,
      DateTime createdAt,
      DateTime? expiresAt,
      DateTime? acceptedAt,
      DateTime? rejectedAt,
      String? message,
      bool? isCounterOffer,
      String? originalOfferId,
      Map<String, dynamic>? driverMetadata});
}

/// @nodoc
class _$DriverOfferCopyWithImpl<$Res, $Val extends DriverOffer>
    implements $DriverOfferCopyWith<$Res> {
  _$DriverOfferCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DriverOffer
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? negotiationId = null,
    Object? driverId = null,
    Object? driverName = null,
    Object? driverPhoto = freezed,
    Object? driverRating = null,
    Object? totalTrips = null,
    Object? vehicleModel = null,
    Object? vehiclePlate = null,
    Object? offeredPrice = null,
    Object? estimatedDistance = null,
    Object? estimatedArrivalMinutes = null,
    Object? status = null,
    Object? createdAt = null,
    Object? expiresAt = freezed,
    Object? acceptedAt = freezed,
    Object? rejectedAt = freezed,
    Object? message = freezed,
    Object? isCounterOffer = freezed,
    Object? originalOfferId = freezed,
    Object? driverMetadata = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      negotiationId: null == negotiationId
          ? _value.negotiationId
          : negotiationId // ignore: cast_nullable_to_non_nullable
              as String,
      driverId: null == driverId
          ? _value.driverId
          : driverId // ignore: cast_nullable_to_non_nullable
              as String,
      driverName: null == driverName
          ? _value.driverName
          : driverName // ignore: cast_nullable_to_non_nullable
              as String,
      driverPhoto: freezed == driverPhoto
          ? _value.driverPhoto
          : driverPhoto // ignore: cast_nullable_to_non_nullable
              as String?,
      driverRating: null == driverRating
          ? _value.driverRating
          : driverRating // ignore: cast_nullable_to_non_nullable
              as double,
      totalTrips: null == totalTrips
          ? _value.totalTrips
          : totalTrips // ignore: cast_nullable_to_non_nullable
              as int,
      vehicleModel: null == vehicleModel
          ? _value.vehicleModel
          : vehicleModel // ignore: cast_nullable_to_non_nullable
              as String,
      vehiclePlate: null == vehiclePlate
          ? _value.vehiclePlate
          : vehiclePlate // ignore: cast_nullable_to_non_nullable
              as String,
      offeredPrice: null == offeredPrice
          ? _value.offeredPrice
          : offeredPrice // ignore: cast_nullable_to_non_nullable
              as double,
      estimatedDistance: null == estimatedDistance
          ? _value.estimatedDistance
          : estimatedDistance // ignore: cast_nullable_to_non_nullable
              as double,
      estimatedArrivalMinutes: null == estimatedArrivalMinutes
          ? _value.estimatedArrivalMinutes
          : estimatedArrivalMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as OfferStatus,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      expiresAt: freezed == expiresAt
          ? _value.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      acceptedAt: freezed == acceptedAt
          ? _value.acceptedAt
          : acceptedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      rejectedAt: freezed == rejectedAt
          ? _value.rejectedAt
          : rejectedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      message: freezed == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
      isCounterOffer: freezed == isCounterOffer
          ? _value.isCounterOffer
          : isCounterOffer // ignore: cast_nullable_to_non_nullable
              as bool?,
      originalOfferId: freezed == originalOfferId
          ? _value.originalOfferId
          : originalOfferId // ignore: cast_nullable_to_non_nullable
              as String?,
      driverMetadata: freezed == driverMetadata
          ? _value.driverMetadata
          : driverMetadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DriverOfferImplCopyWith<$Res>
    implements $DriverOfferCopyWith<$Res> {
  factory _$$DriverOfferImplCopyWith(
          _$DriverOfferImpl value, $Res Function(_$DriverOfferImpl) then) =
      __$$DriverOfferImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String negotiationId,
      String driverId,
      String driverName,
      String? driverPhoto,
      double driverRating,
      int totalTrips,
      String vehicleModel,
      String vehiclePlate,
      double offeredPrice,
      double estimatedDistance,
      int estimatedArrivalMinutes,
      OfferStatus status,
      DateTime createdAt,
      DateTime? expiresAt,
      DateTime? acceptedAt,
      DateTime? rejectedAt,
      String? message,
      bool? isCounterOffer,
      String? originalOfferId,
      Map<String, dynamic>? driverMetadata});
}

/// @nodoc
class __$$DriverOfferImplCopyWithImpl<$Res>
    extends _$DriverOfferCopyWithImpl<$Res, _$DriverOfferImpl>
    implements _$$DriverOfferImplCopyWith<$Res> {
  __$$DriverOfferImplCopyWithImpl(
      _$DriverOfferImpl _value, $Res Function(_$DriverOfferImpl) _then)
      : super(_value, _then);

  /// Create a copy of DriverOffer
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? negotiationId = null,
    Object? driverId = null,
    Object? driverName = null,
    Object? driverPhoto = freezed,
    Object? driverRating = null,
    Object? totalTrips = null,
    Object? vehicleModel = null,
    Object? vehiclePlate = null,
    Object? offeredPrice = null,
    Object? estimatedDistance = null,
    Object? estimatedArrivalMinutes = null,
    Object? status = null,
    Object? createdAt = null,
    Object? expiresAt = freezed,
    Object? acceptedAt = freezed,
    Object? rejectedAt = freezed,
    Object? message = freezed,
    Object? isCounterOffer = freezed,
    Object? originalOfferId = freezed,
    Object? driverMetadata = freezed,
  }) {
    return _then(_$DriverOfferImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      negotiationId: null == negotiationId
          ? _value.negotiationId
          : negotiationId // ignore: cast_nullable_to_non_nullable
              as String,
      driverId: null == driverId
          ? _value.driverId
          : driverId // ignore: cast_nullable_to_non_nullable
              as String,
      driverName: null == driverName
          ? _value.driverName
          : driverName // ignore: cast_nullable_to_non_nullable
              as String,
      driverPhoto: freezed == driverPhoto
          ? _value.driverPhoto
          : driverPhoto // ignore: cast_nullable_to_non_nullable
              as String?,
      driverRating: null == driverRating
          ? _value.driverRating
          : driverRating // ignore: cast_nullable_to_non_nullable
              as double,
      totalTrips: null == totalTrips
          ? _value.totalTrips
          : totalTrips // ignore: cast_nullable_to_non_nullable
              as int,
      vehicleModel: null == vehicleModel
          ? _value.vehicleModel
          : vehicleModel // ignore: cast_nullable_to_non_nullable
              as String,
      vehiclePlate: null == vehiclePlate
          ? _value.vehiclePlate
          : vehiclePlate // ignore: cast_nullable_to_non_nullable
              as String,
      offeredPrice: null == offeredPrice
          ? _value.offeredPrice
          : offeredPrice // ignore: cast_nullable_to_non_nullable
              as double,
      estimatedDistance: null == estimatedDistance
          ? _value.estimatedDistance
          : estimatedDistance // ignore: cast_nullable_to_non_nullable
              as double,
      estimatedArrivalMinutes: null == estimatedArrivalMinutes
          ? _value.estimatedArrivalMinutes
          : estimatedArrivalMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as OfferStatus,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      expiresAt: freezed == expiresAt
          ? _value.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      acceptedAt: freezed == acceptedAt
          ? _value.acceptedAt
          : acceptedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      rejectedAt: freezed == rejectedAt
          ? _value.rejectedAt
          : rejectedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      message: freezed == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
      isCounterOffer: freezed == isCounterOffer
          ? _value.isCounterOffer
          : isCounterOffer // ignore: cast_nullable_to_non_nullable
              as bool?,
      originalOfferId: freezed == originalOfferId
          ? _value.originalOfferId
          : originalOfferId // ignore: cast_nullable_to_non_nullable
              as String?,
      driverMetadata: freezed == driverMetadata
          ? _value._driverMetadata
          : driverMetadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$DriverOfferImpl implements _DriverOffer {
  const _$DriverOfferImpl(
      {required this.id,
      required this.negotiationId,
      required this.driverId,
      required this.driverName,
      required this.driverPhoto,
      required this.driverRating,
      required this.totalTrips,
      required this.vehicleModel,
      required this.vehiclePlate,
      required this.offeredPrice,
      required this.estimatedDistance,
      required this.estimatedArrivalMinutes,
      required this.status,
      required this.createdAt,
      this.expiresAt,
      this.acceptedAt,
      this.rejectedAt,
      this.message,
      this.isCounterOffer,
      this.originalOfferId,
      final Map<String, dynamic>? driverMetadata})
      : _driverMetadata = driverMetadata;

  factory _$DriverOfferImpl.fromJson(Map<String, dynamic> json) =>
      _$$DriverOfferImplFromJson(json);

  @override
  final String id;
  @override
  final String negotiationId;
  @override
  final String driverId;
  @override
  final String driverName;
  @override
  final String? driverPhoto;
  @override
  final double driverRating;
  @override
  final int totalTrips;
  @override
  final String vehicleModel;
  @override
  final String vehiclePlate;
  @override
  final double offeredPrice;
  @override
  final double estimatedDistance;
  @override
  final int estimatedArrivalMinutes;
  @override
  final OfferStatus status;
  @override
  final DateTime createdAt;
  @override
  final DateTime? expiresAt;
  @override
  final DateTime? acceptedAt;
  @override
  final DateTime? rejectedAt;
  @override
  final String? message;
  @override
  final bool? isCounterOffer;
  @override
  final String? originalOfferId;
  final Map<String, dynamic>? _driverMetadata;
  @override
  Map<String, dynamic>? get driverMetadata {
    final value = _driverMetadata;
    if (value == null) return null;
    if (_driverMetadata is EqualUnmodifiableMapView) return _driverMetadata;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  String toString() {
    return 'DriverOffer(id: $id, negotiationId: $negotiationId, driverId: $driverId, driverName: $driverName, driverPhoto: $driverPhoto, driverRating: $driverRating, totalTrips: $totalTrips, vehicleModel: $vehicleModel, vehiclePlate: $vehiclePlate, offeredPrice: $offeredPrice, estimatedDistance: $estimatedDistance, estimatedArrivalMinutes: $estimatedArrivalMinutes, status: $status, createdAt: $createdAt, expiresAt: $expiresAt, acceptedAt: $acceptedAt, rejectedAt: $rejectedAt, message: $message, isCounterOffer: $isCounterOffer, originalOfferId: $originalOfferId, driverMetadata: $driverMetadata)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DriverOfferImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.negotiationId, negotiationId) ||
                other.negotiationId == negotiationId) &&
            (identical(other.driverId, driverId) ||
                other.driverId == driverId) &&
            (identical(other.driverName, driverName) ||
                other.driverName == driverName) &&
            (identical(other.driverPhoto, driverPhoto) ||
                other.driverPhoto == driverPhoto) &&
            (identical(other.driverRating, driverRating) ||
                other.driverRating == driverRating) &&
            (identical(other.totalTrips, totalTrips) ||
                other.totalTrips == totalTrips) &&
            (identical(other.vehicleModel, vehicleModel) ||
                other.vehicleModel == vehicleModel) &&
            (identical(other.vehiclePlate, vehiclePlate) ||
                other.vehiclePlate == vehiclePlate) &&
            (identical(other.offeredPrice, offeredPrice) ||
                other.offeredPrice == offeredPrice) &&
            (identical(other.estimatedDistance, estimatedDistance) ||
                other.estimatedDistance == estimatedDistance) &&
            (identical(
                    other.estimatedArrivalMinutes, estimatedArrivalMinutes) ||
                other.estimatedArrivalMinutes == estimatedArrivalMinutes) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt) &&
            (identical(other.acceptedAt, acceptedAt) ||
                other.acceptedAt == acceptedAt) &&
            (identical(other.rejectedAt, rejectedAt) ||
                other.rejectedAt == rejectedAt) &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.isCounterOffer, isCounterOffer) ||
                other.isCounterOffer == isCounterOffer) &&
            (identical(other.originalOfferId, originalOfferId) ||
                other.originalOfferId == originalOfferId) &&
            const DeepCollectionEquality()
                .equals(other._driverMetadata, _driverMetadata));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        negotiationId,
        driverId,
        driverName,
        driverPhoto,
        driverRating,
        totalTrips,
        vehicleModel,
        vehiclePlate,
        offeredPrice,
        estimatedDistance,
        estimatedArrivalMinutes,
        status,
        createdAt,
        expiresAt,
        acceptedAt,
        rejectedAt,
        message,
        isCounterOffer,
        originalOfferId,
        const DeepCollectionEquality().hash(_driverMetadata)
      ]);

  /// Create a copy of DriverOffer
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DriverOfferImplCopyWith<_$DriverOfferImpl> get copyWith =>
      __$$DriverOfferImplCopyWithImpl<_$DriverOfferImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$DriverOfferImplToJson(
      this,
    );
  }
}

abstract class _DriverOffer implements DriverOffer {
  const factory _DriverOffer(
      {required final String id,
      required final String negotiationId,
      required final String driverId,
      required final String driverName,
      required final String? driverPhoto,
      required final double driverRating,
      required final int totalTrips,
      required final String vehicleModel,
      required final String vehiclePlate,
      required final double offeredPrice,
      required final double estimatedDistance,
      required final int estimatedArrivalMinutes,
      required final OfferStatus status,
      required final DateTime createdAt,
      final DateTime? expiresAt,
      final DateTime? acceptedAt,
      final DateTime? rejectedAt,
      final String? message,
      final bool? isCounterOffer,
      final String? originalOfferId,
      final Map<String, dynamic>? driverMetadata}) = _$DriverOfferImpl;

  factory _DriverOffer.fromJson(Map<String, dynamic> json) =
      _$DriverOfferImpl.fromJson;

  @override
  String get id;
  @override
  String get negotiationId;
  @override
  String get driverId;
  @override
  String get driverName;
  @override
  String? get driverPhoto;
  @override
  double get driverRating;
  @override
  int get totalTrips;
  @override
  String get vehicleModel;
  @override
  String get vehiclePlate;
  @override
  double get offeredPrice;
  @override
  double get estimatedDistance;
  @override
  int get estimatedArrivalMinutes;
  @override
  OfferStatus get status;
  @override
  DateTime get createdAt;
  @override
  DateTime? get expiresAt;
  @override
  DateTime? get acceptedAt;
  @override
  DateTime? get rejectedAt;
  @override
  String? get message;
  @override
  bool? get isCounterOffer;
  @override
  String? get originalOfferId;
  @override
  Map<String, dynamic>? get driverMetadata;

  /// Create a copy of DriverOffer
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DriverOfferImplCopyWith<_$DriverOfferImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

NegotiationConfig _$NegotiationConfigFromJson(Map<String, dynamic> json) {
  return _NegotiationConfig.fromJson(json);
}

/// @nodoc
mixin _$NegotiationConfig {
  int get defaultTimeoutSeconds => throw _privateConstructorUsedError;
  int get maxOffersPerNegotiation => throw _privateConstructorUsedError;
  int get maxCounterOffersPerDriver => throw _privateConstructorUsedError;
  double get minPriceReductionPercentage => throw _privateConstructorUsedError;
  double get maxPriceIncreaseMultiplier => throw _privateConstructorUsedError;
  int get extensionTimeSeconds => throw _privateConstructorUsedError;
  int get maxExtensions => throw _privateConstructorUsedError;
  int get offerExpirationMinutes => throw _privateConstructorUsedError;
  bool get allowCounterOffers => throw _privateConstructorUsedError;
  bool get allowExtensions => throw _privateConstructorUsedError;
  bool get requireDriverApproval => throw _privateConstructorUsedError;
  List<String>? get blacklistedDriverIds => throw _privateConstructorUsedError;
  Map<String, dynamic>? get rules => throw _privateConstructorUsedError;

  /// Serializes this NegotiationConfig to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of NegotiationConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NegotiationConfigCopyWith<NegotiationConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NegotiationConfigCopyWith<$Res> {
  factory $NegotiationConfigCopyWith(
          NegotiationConfig value, $Res Function(NegotiationConfig) then) =
      _$NegotiationConfigCopyWithImpl<$Res, NegotiationConfig>;
  @useResult
  $Res call(
      {int defaultTimeoutSeconds,
      int maxOffersPerNegotiation,
      int maxCounterOffersPerDriver,
      double minPriceReductionPercentage,
      double maxPriceIncreaseMultiplier,
      int extensionTimeSeconds,
      int maxExtensions,
      int offerExpirationMinutes,
      bool allowCounterOffers,
      bool allowExtensions,
      bool requireDriverApproval,
      List<String>? blacklistedDriverIds,
      Map<String, dynamic>? rules});
}

/// @nodoc
class _$NegotiationConfigCopyWithImpl<$Res, $Val extends NegotiationConfig>
    implements $NegotiationConfigCopyWith<$Res> {
  _$NegotiationConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NegotiationConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? defaultTimeoutSeconds = null,
    Object? maxOffersPerNegotiation = null,
    Object? maxCounterOffersPerDriver = null,
    Object? minPriceReductionPercentage = null,
    Object? maxPriceIncreaseMultiplier = null,
    Object? extensionTimeSeconds = null,
    Object? maxExtensions = null,
    Object? offerExpirationMinutes = null,
    Object? allowCounterOffers = null,
    Object? allowExtensions = null,
    Object? requireDriverApproval = null,
    Object? blacklistedDriverIds = freezed,
    Object? rules = freezed,
  }) {
    return _then(_value.copyWith(
      defaultTimeoutSeconds: null == defaultTimeoutSeconds
          ? _value.defaultTimeoutSeconds
          : defaultTimeoutSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      maxOffersPerNegotiation: null == maxOffersPerNegotiation
          ? _value.maxOffersPerNegotiation
          : maxOffersPerNegotiation // ignore: cast_nullable_to_non_nullable
              as int,
      maxCounterOffersPerDriver: null == maxCounterOffersPerDriver
          ? _value.maxCounterOffersPerDriver
          : maxCounterOffersPerDriver // ignore: cast_nullable_to_non_nullable
              as int,
      minPriceReductionPercentage: null == minPriceReductionPercentage
          ? _value.minPriceReductionPercentage
          : minPriceReductionPercentage // ignore: cast_nullable_to_non_nullable
              as double,
      maxPriceIncreaseMultiplier: null == maxPriceIncreaseMultiplier
          ? _value.maxPriceIncreaseMultiplier
          : maxPriceIncreaseMultiplier // ignore: cast_nullable_to_non_nullable
              as double,
      extensionTimeSeconds: null == extensionTimeSeconds
          ? _value.extensionTimeSeconds
          : extensionTimeSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      maxExtensions: null == maxExtensions
          ? _value.maxExtensions
          : maxExtensions // ignore: cast_nullable_to_non_nullable
              as int,
      offerExpirationMinutes: null == offerExpirationMinutes
          ? _value.offerExpirationMinutes
          : offerExpirationMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      allowCounterOffers: null == allowCounterOffers
          ? _value.allowCounterOffers
          : allowCounterOffers // ignore: cast_nullable_to_non_nullable
              as bool,
      allowExtensions: null == allowExtensions
          ? _value.allowExtensions
          : allowExtensions // ignore: cast_nullable_to_non_nullable
              as bool,
      requireDriverApproval: null == requireDriverApproval
          ? _value.requireDriverApproval
          : requireDriverApproval // ignore: cast_nullable_to_non_nullable
              as bool,
      blacklistedDriverIds: freezed == blacklistedDriverIds
          ? _value.blacklistedDriverIds
          : blacklistedDriverIds // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      rules: freezed == rules
          ? _value.rules
          : rules // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$NegotiationConfigImplCopyWith<$Res>
    implements $NegotiationConfigCopyWith<$Res> {
  factory _$$NegotiationConfigImplCopyWith(_$NegotiationConfigImpl value,
          $Res Function(_$NegotiationConfigImpl) then) =
      __$$NegotiationConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int defaultTimeoutSeconds,
      int maxOffersPerNegotiation,
      int maxCounterOffersPerDriver,
      double minPriceReductionPercentage,
      double maxPriceIncreaseMultiplier,
      int extensionTimeSeconds,
      int maxExtensions,
      int offerExpirationMinutes,
      bool allowCounterOffers,
      bool allowExtensions,
      bool requireDriverApproval,
      List<String>? blacklistedDriverIds,
      Map<String, dynamic>? rules});
}

/// @nodoc
class __$$NegotiationConfigImplCopyWithImpl<$Res>
    extends _$NegotiationConfigCopyWithImpl<$Res, _$NegotiationConfigImpl>
    implements _$$NegotiationConfigImplCopyWith<$Res> {
  __$$NegotiationConfigImplCopyWithImpl(_$NegotiationConfigImpl _value,
      $Res Function(_$NegotiationConfigImpl) _then)
      : super(_value, _then);

  /// Create a copy of NegotiationConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? defaultTimeoutSeconds = null,
    Object? maxOffersPerNegotiation = null,
    Object? maxCounterOffersPerDriver = null,
    Object? minPriceReductionPercentage = null,
    Object? maxPriceIncreaseMultiplier = null,
    Object? extensionTimeSeconds = null,
    Object? maxExtensions = null,
    Object? offerExpirationMinutes = null,
    Object? allowCounterOffers = null,
    Object? allowExtensions = null,
    Object? requireDriverApproval = null,
    Object? blacklistedDriverIds = freezed,
    Object? rules = freezed,
  }) {
    return _then(_$NegotiationConfigImpl(
      defaultTimeoutSeconds: null == defaultTimeoutSeconds
          ? _value.defaultTimeoutSeconds
          : defaultTimeoutSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      maxOffersPerNegotiation: null == maxOffersPerNegotiation
          ? _value.maxOffersPerNegotiation
          : maxOffersPerNegotiation // ignore: cast_nullable_to_non_nullable
              as int,
      maxCounterOffersPerDriver: null == maxCounterOffersPerDriver
          ? _value.maxCounterOffersPerDriver
          : maxCounterOffersPerDriver // ignore: cast_nullable_to_non_nullable
              as int,
      minPriceReductionPercentage: null == minPriceReductionPercentage
          ? _value.minPriceReductionPercentage
          : minPriceReductionPercentage // ignore: cast_nullable_to_non_nullable
              as double,
      maxPriceIncreaseMultiplier: null == maxPriceIncreaseMultiplier
          ? _value.maxPriceIncreaseMultiplier
          : maxPriceIncreaseMultiplier // ignore: cast_nullable_to_non_nullable
              as double,
      extensionTimeSeconds: null == extensionTimeSeconds
          ? _value.extensionTimeSeconds
          : extensionTimeSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      maxExtensions: null == maxExtensions
          ? _value.maxExtensions
          : maxExtensions // ignore: cast_nullable_to_non_nullable
              as int,
      offerExpirationMinutes: null == offerExpirationMinutes
          ? _value.offerExpirationMinutes
          : offerExpirationMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      allowCounterOffers: null == allowCounterOffers
          ? _value.allowCounterOffers
          : allowCounterOffers // ignore: cast_nullable_to_non_nullable
              as bool,
      allowExtensions: null == allowExtensions
          ? _value.allowExtensions
          : allowExtensions // ignore: cast_nullable_to_non_nullable
              as bool,
      requireDriverApproval: null == requireDriverApproval
          ? _value.requireDriverApproval
          : requireDriverApproval // ignore: cast_nullable_to_non_nullable
              as bool,
      blacklistedDriverIds: freezed == blacklistedDriverIds
          ? _value._blacklistedDriverIds
          : blacklistedDriverIds // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      rules: freezed == rules
          ? _value._rules
          : rules // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$NegotiationConfigImpl implements _NegotiationConfig {
  const _$NegotiationConfigImpl(
      {this.defaultTimeoutSeconds = 300,
      this.maxOffersPerNegotiation = 5,
      this.maxCounterOffersPerDriver = 3,
      this.minPriceReductionPercentage = 0.1,
      this.maxPriceIncreaseMultiplier = 2.0,
      this.extensionTimeSeconds = 120,
      this.maxExtensions = 3,
      this.offerExpirationMinutes = 30,
      this.allowCounterOffers = true,
      this.allowExtensions = true,
      this.requireDriverApproval = false,
      final List<String>? blacklistedDriverIds,
      final Map<String, dynamic>? rules})
      : _blacklistedDriverIds = blacklistedDriverIds,
        _rules = rules;

  factory _$NegotiationConfigImpl.fromJson(Map<String, dynamic> json) =>
      _$$NegotiationConfigImplFromJson(json);

  @override
  @JsonKey()
  final int defaultTimeoutSeconds;
  @override
  @JsonKey()
  final int maxOffersPerNegotiation;
  @override
  @JsonKey()
  final int maxCounterOffersPerDriver;
  @override
  @JsonKey()
  final double minPriceReductionPercentage;
  @override
  @JsonKey()
  final double maxPriceIncreaseMultiplier;
  @override
  @JsonKey()
  final int extensionTimeSeconds;
  @override
  @JsonKey()
  final int maxExtensions;
  @override
  @JsonKey()
  final int offerExpirationMinutes;
  @override
  @JsonKey()
  final bool allowCounterOffers;
  @override
  @JsonKey()
  final bool allowExtensions;
  @override
  @JsonKey()
  final bool requireDriverApproval;
  final List<String>? _blacklistedDriverIds;
  @override
  List<String>? get blacklistedDriverIds {
    final value = _blacklistedDriverIds;
    if (value == null) return null;
    if (_blacklistedDriverIds is EqualUnmodifiableListView)
      return _blacklistedDriverIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  final Map<String, dynamic>? _rules;
  @override
  Map<String, dynamic>? get rules {
    final value = _rules;
    if (value == null) return null;
    if (_rules is EqualUnmodifiableMapView) return _rules;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  String toString() {
    return 'NegotiationConfig(defaultTimeoutSeconds: $defaultTimeoutSeconds, maxOffersPerNegotiation: $maxOffersPerNegotiation, maxCounterOffersPerDriver: $maxCounterOffersPerDriver, minPriceReductionPercentage: $minPriceReductionPercentage, maxPriceIncreaseMultiplier: $maxPriceIncreaseMultiplier, extensionTimeSeconds: $extensionTimeSeconds, maxExtensions: $maxExtensions, offerExpirationMinutes: $offerExpirationMinutes, allowCounterOffers: $allowCounterOffers, allowExtensions: $allowExtensions, requireDriverApproval: $requireDriverApproval, blacklistedDriverIds: $blacklistedDriverIds, rules: $rules)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NegotiationConfigImpl &&
            (identical(other.defaultTimeoutSeconds, defaultTimeoutSeconds) ||
                other.defaultTimeoutSeconds == defaultTimeoutSeconds) &&
            (identical(other.maxOffersPerNegotiation, maxOffersPerNegotiation) ||
                other.maxOffersPerNegotiation == maxOffersPerNegotiation) &&
            (identical(other.maxCounterOffersPerDriver,
                    maxCounterOffersPerDriver) ||
                other.maxCounterOffersPerDriver == maxCounterOffersPerDriver) &&
            (identical(other.minPriceReductionPercentage,
                    minPriceReductionPercentage) ||
                other.minPriceReductionPercentage ==
                    minPriceReductionPercentage) &&
            (identical(other.maxPriceIncreaseMultiplier,
                    maxPriceIncreaseMultiplier) ||
                other.maxPriceIncreaseMultiplier ==
                    maxPriceIncreaseMultiplier) &&
            (identical(other.extensionTimeSeconds, extensionTimeSeconds) ||
                other.extensionTimeSeconds == extensionTimeSeconds) &&
            (identical(other.maxExtensions, maxExtensions) ||
                other.maxExtensions == maxExtensions) &&
            (identical(other.offerExpirationMinutes, offerExpirationMinutes) ||
                other.offerExpirationMinutes == offerExpirationMinutes) &&
            (identical(other.allowCounterOffers, allowCounterOffers) ||
                other.allowCounterOffers == allowCounterOffers) &&
            (identical(other.allowExtensions, allowExtensions) ||
                other.allowExtensions == allowExtensions) &&
            (identical(other.requireDriverApproval, requireDriverApproval) ||
                other.requireDriverApproval == requireDriverApproval) &&
            const DeepCollectionEquality()
                .equals(other._blacklistedDriverIds, _blacklistedDriverIds) &&
            const DeepCollectionEquality().equals(other._rules, _rules));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      defaultTimeoutSeconds,
      maxOffersPerNegotiation,
      maxCounterOffersPerDriver,
      minPriceReductionPercentage,
      maxPriceIncreaseMultiplier,
      extensionTimeSeconds,
      maxExtensions,
      offerExpirationMinutes,
      allowCounterOffers,
      allowExtensions,
      requireDriverApproval,
      const DeepCollectionEquality().hash(_blacklistedDriverIds),
      const DeepCollectionEquality().hash(_rules));

  /// Create a copy of NegotiationConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NegotiationConfigImplCopyWith<_$NegotiationConfigImpl> get copyWith =>
      __$$NegotiationConfigImplCopyWithImpl<_$NegotiationConfigImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$NegotiationConfigImplToJson(
      this,
    );
  }
}

abstract class _NegotiationConfig implements NegotiationConfig {
  const factory _NegotiationConfig(
      {final int defaultTimeoutSeconds,
      final int maxOffersPerNegotiation,
      final int maxCounterOffersPerDriver,
      final double minPriceReductionPercentage,
      final double maxPriceIncreaseMultiplier,
      final int extensionTimeSeconds,
      final int maxExtensions,
      final int offerExpirationMinutes,
      final bool allowCounterOffers,
      final bool allowExtensions,
      final bool requireDriverApproval,
      final List<String>? blacklistedDriverIds,
      final Map<String, dynamic>? rules}) = _$NegotiationConfigImpl;

  factory _NegotiationConfig.fromJson(Map<String, dynamic> json) =
      _$NegotiationConfigImpl.fromJson;

  @override
  int get defaultTimeoutSeconds;
  @override
  int get maxOffersPerNegotiation;
  @override
  int get maxCounterOffersPerDriver;
  @override
  double get minPriceReductionPercentage;
  @override
  double get maxPriceIncreaseMultiplier;
  @override
  int get extensionTimeSeconds;
  @override
  int get maxExtensions;
  @override
  int get offerExpirationMinutes;
  @override
  bool get allowCounterOffers;
  @override
  bool get allowExtensions;
  @override
  bool get requireDriverApproval;
  @override
  List<String>? get blacklistedDriverIds;
  @override
  Map<String, dynamic>? get rules;

  /// Create a copy of NegotiationConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NegotiationConfigImplCopyWith<_$NegotiationConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

NegotiationMetrics _$NegotiationMetricsFromJson(Map<String, dynamic> json) {
  return _NegotiationMetrics.fromJson(json);
}

/// @nodoc
mixin _$NegotiationMetrics {
  String get negotiationId => throw _privateConstructorUsedError;
  int get totalOffers => throw _privateConstructorUsedError;
  double get averageOffer => throw _privateConstructorUsedError;
  double get lowestOffer => throw _privateConstructorUsedError;
  double get highestOffer => throw _privateConstructorUsedError;
  int get totalDriversParticipated => throw _privateConstructorUsedError;
  Duration get averageResponseTime => throw _privateConstructorUsedError;
  Duration get totalNegotiationTime => throw _privateConstructorUsedError;
  bool get wasSuccessful => throw _privateConstructorUsedError;
  bool get wasExtended => throw _privateConstructorUsedError;
  int get extensionsUsed => throw _privateConstructorUsedError;
  Map<String, dynamic>? get additionalMetrics =>
      throw _privateConstructorUsedError;

  /// Serializes this NegotiationMetrics to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of NegotiationMetrics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NegotiationMetricsCopyWith<NegotiationMetrics> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NegotiationMetricsCopyWith<$Res> {
  factory $NegotiationMetricsCopyWith(
          NegotiationMetrics value, $Res Function(NegotiationMetrics) then) =
      _$NegotiationMetricsCopyWithImpl<$Res, NegotiationMetrics>;
  @useResult
  $Res call(
      {String negotiationId,
      int totalOffers,
      double averageOffer,
      double lowestOffer,
      double highestOffer,
      int totalDriversParticipated,
      Duration averageResponseTime,
      Duration totalNegotiationTime,
      bool wasSuccessful,
      bool wasExtended,
      int extensionsUsed,
      Map<String, dynamic>? additionalMetrics});
}

/// @nodoc
class _$NegotiationMetricsCopyWithImpl<$Res, $Val extends NegotiationMetrics>
    implements $NegotiationMetricsCopyWith<$Res> {
  _$NegotiationMetricsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NegotiationMetrics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? negotiationId = null,
    Object? totalOffers = null,
    Object? averageOffer = null,
    Object? lowestOffer = null,
    Object? highestOffer = null,
    Object? totalDriversParticipated = null,
    Object? averageResponseTime = null,
    Object? totalNegotiationTime = null,
    Object? wasSuccessful = null,
    Object? wasExtended = null,
    Object? extensionsUsed = null,
    Object? additionalMetrics = freezed,
  }) {
    return _then(_value.copyWith(
      negotiationId: null == negotiationId
          ? _value.negotiationId
          : negotiationId // ignore: cast_nullable_to_non_nullable
              as String,
      totalOffers: null == totalOffers
          ? _value.totalOffers
          : totalOffers // ignore: cast_nullable_to_non_nullable
              as int,
      averageOffer: null == averageOffer
          ? _value.averageOffer
          : averageOffer // ignore: cast_nullable_to_non_nullable
              as double,
      lowestOffer: null == lowestOffer
          ? _value.lowestOffer
          : lowestOffer // ignore: cast_nullable_to_non_nullable
              as double,
      highestOffer: null == highestOffer
          ? _value.highestOffer
          : highestOffer // ignore: cast_nullable_to_non_nullable
              as double,
      totalDriversParticipated: null == totalDriversParticipated
          ? _value.totalDriversParticipated
          : totalDriversParticipated // ignore: cast_nullable_to_non_nullable
              as int,
      averageResponseTime: null == averageResponseTime
          ? _value.averageResponseTime
          : averageResponseTime // ignore: cast_nullable_to_non_nullable
              as Duration,
      totalNegotiationTime: null == totalNegotiationTime
          ? _value.totalNegotiationTime
          : totalNegotiationTime // ignore: cast_nullable_to_non_nullable
              as Duration,
      wasSuccessful: null == wasSuccessful
          ? _value.wasSuccessful
          : wasSuccessful // ignore: cast_nullable_to_non_nullable
              as bool,
      wasExtended: null == wasExtended
          ? _value.wasExtended
          : wasExtended // ignore: cast_nullable_to_non_nullable
              as bool,
      extensionsUsed: null == extensionsUsed
          ? _value.extensionsUsed
          : extensionsUsed // ignore: cast_nullable_to_non_nullable
              as int,
      additionalMetrics: freezed == additionalMetrics
          ? _value.additionalMetrics
          : additionalMetrics // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$NegotiationMetricsImplCopyWith<$Res>
    implements $NegotiationMetricsCopyWith<$Res> {
  factory _$$NegotiationMetricsImplCopyWith(_$NegotiationMetricsImpl value,
          $Res Function(_$NegotiationMetricsImpl) then) =
      __$$NegotiationMetricsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String negotiationId,
      int totalOffers,
      double averageOffer,
      double lowestOffer,
      double highestOffer,
      int totalDriversParticipated,
      Duration averageResponseTime,
      Duration totalNegotiationTime,
      bool wasSuccessful,
      bool wasExtended,
      int extensionsUsed,
      Map<String, dynamic>? additionalMetrics});
}

/// @nodoc
class __$$NegotiationMetricsImplCopyWithImpl<$Res>
    extends _$NegotiationMetricsCopyWithImpl<$Res, _$NegotiationMetricsImpl>
    implements _$$NegotiationMetricsImplCopyWith<$Res> {
  __$$NegotiationMetricsImplCopyWithImpl(_$NegotiationMetricsImpl _value,
      $Res Function(_$NegotiationMetricsImpl) _then)
      : super(_value, _then);

  /// Create a copy of NegotiationMetrics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? negotiationId = null,
    Object? totalOffers = null,
    Object? averageOffer = null,
    Object? lowestOffer = null,
    Object? highestOffer = null,
    Object? totalDriversParticipated = null,
    Object? averageResponseTime = null,
    Object? totalNegotiationTime = null,
    Object? wasSuccessful = null,
    Object? wasExtended = null,
    Object? extensionsUsed = null,
    Object? additionalMetrics = freezed,
  }) {
    return _then(_$NegotiationMetricsImpl(
      negotiationId: null == negotiationId
          ? _value.negotiationId
          : negotiationId // ignore: cast_nullable_to_non_nullable
              as String,
      totalOffers: null == totalOffers
          ? _value.totalOffers
          : totalOffers // ignore: cast_nullable_to_non_nullable
              as int,
      averageOffer: null == averageOffer
          ? _value.averageOffer
          : averageOffer // ignore: cast_nullable_to_non_nullable
              as double,
      lowestOffer: null == lowestOffer
          ? _value.lowestOffer
          : lowestOffer // ignore: cast_nullable_to_non_nullable
              as double,
      highestOffer: null == highestOffer
          ? _value.highestOffer
          : highestOffer // ignore: cast_nullable_to_non_nullable
              as double,
      totalDriversParticipated: null == totalDriversParticipated
          ? _value.totalDriversParticipated
          : totalDriversParticipated // ignore: cast_nullable_to_non_nullable
              as int,
      averageResponseTime: null == averageResponseTime
          ? _value.averageResponseTime
          : averageResponseTime // ignore: cast_nullable_to_non_nullable
              as Duration,
      totalNegotiationTime: null == totalNegotiationTime
          ? _value.totalNegotiationTime
          : totalNegotiationTime // ignore: cast_nullable_to_non_nullable
              as Duration,
      wasSuccessful: null == wasSuccessful
          ? _value.wasSuccessful
          : wasSuccessful // ignore: cast_nullable_to_non_nullable
              as bool,
      wasExtended: null == wasExtended
          ? _value.wasExtended
          : wasExtended // ignore: cast_nullable_to_non_nullable
              as bool,
      extensionsUsed: null == extensionsUsed
          ? _value.extensionsUsed
          : extensionsUsed // ignore: cast_nullable_to_non_nullable
              as int,
      additionalMetrics: freezed == additionalMetrics
          ? _value._additionalMetrics
          : additionalMetrics // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$NegotiationMetricsImpl implements _NegotiationMetrics {
  const _$NegotiationMetricsImpl(
      {required this.negotiationId,
      required this.totalOffers,
      required this.averageOffer,
      required this.lowestOffer,
      required this.highestOffer,
      required this.totalDriversParticipated,
      required this.averageResponseTime,
      required this.totalNegotiationTime,
      required this.wasSuccessful,
      required this.wasExtended,
      required this.extensionsUsed,
      final Map<String, dynamic>? additionalMetrics})
      : _additionalMetrics = additionalMetrics;

  factory _$NegotiationMetricsImpl.fromJson(Map<String, dynamic> json) =>
      _$$NegotiationMetricsImplFromJson(json);

  @override
  final String negotiationId;
  @override
  final int totalOffers;
  @override
  final double averageOffer;
  @override
  final double lowestOffer;
  @override
  final double highestOffer;
  @override
  final int totalDriversParticipated;
  @override
  final Duration averageResponseTime;
  @override
  final Duration totalNegotiationTime;
  @override
  final bool wasSuccessful;
  @override
  final bool wasExtended;
  @override
  final int extensionsUsed;
  final Map<String, dynamic>? _additionalMetrics;
  @override
  Map<String, dynamic>? get additionalMetrics {
    final value = _additionalMetrics;
    if (value == null) return null;
    if (_additionalMetrics is EqualUnmodifiableMapView)
      return _additionalMetrics;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  String toString() {
    return 'NegotiationMetrics(negotiationId: $negotiationId, totalOffers: $totalOffers, averageOffer: $averageOffer, lowestOffer: $lowestOffer, highestOffer: $highestOffer, totalDriversParticipated: $totalDriversParticipated, averageResponseTime: $averageResponseTime, totalNegotiationTime: $totalNegotiationTime, wasSuccessful: $wasSuccessful, wasExtended: $wasExtended, extensionsUsed: $extensionsUsed, additionalMetrics: $additionalMetrics)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NegotiationMetricsImpl &&
            (identical(other.negotiationId, negotiationId) ||
                other.negotiationId == negotiationId) &&
            (identical(other.totalOffers, totalOffers) ||
                other.totalOffers == totalOffers) &&
            (identical(other.averageOffer, averageOffer) ||
                other.averageOffer == averageOffer) &&
            (identical(other.lowestOffer, lowestOffer) ||
                other.lowestOffer == lowestOffer) &&
            (identical(other.highestOffer, highestOffer) ||
                other.highestOffer == highestOffer) &&
            (identical(
                    other.totalDriversParticipated, totalDriversParticipated) ||
                other.totalDriversParticipated == totalDriversParticipated) &&
            (identical(other.averageResponseTime, averageResponseTime) ||
                other.averageResponseTime == averageResponseTime) &&
            (identical(other.totalNegotiationTime, totalNegotiationTime) ||
                other.totalNegotiationTime == totalNegotiationTime) &&
            (identical(other.wasSuccessful, wasSuccessful) ||
                other.wasSuccessful == wasSuccessful) &&
            (identical(other.wasExtended, wasExtended) ||
                other.wasExtended == wasExtended) &&
            (identical(other.extensionsUsed, extensionsUsed) ||
                other.extensionsUsed == extensionsUsed) &&
            const DeepCollectionEquality()
                .equals(other._additionalMetrics, _additionalMetrics));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      negotiationId,
      totalOffers,
      averageOffer,
      lowestOffer,
      highestOffer,
      totalDriversParticipated,
      averageResponseTime,
      totalNegotiationTime,
      wasSuccessful,
      wasExtended,
      extensionsUsed,
      const DeepCollectionEquality().hash(_additionalMetrics));

  /// Create a copy of NegotiationMetrics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NegotiationMetricsImplCopyWith<_$NegotiationMetricsImpl> get copyWith =>
      __$$NegotiationMetricsImplCopyWithImpl<_$NegotiationMetricsImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$NegotiationMetricsImplToJson(
      this,
    );
  }
}

abstract class _NegotiationMetrics implements NegotiationMetrics {
  const factory _NegotiationMetrics(
          {required final String negotiationId,
          required final int totalOffers,
          required final double averageOffer,
          required final double lowestOffer,
          required final double highestOffer,
          required final int totalDriversParticipated,
          required final Duration averageResponseTime,
          required final Duration totalNegotiationTime,
          required final bool wasSuccessful,
          required final bool wasExtended,
          required final int extensionsUsed,
          final Map<String, dynamic>? additionalMetrics}) =
      _$NegotiationMetricsImpl;

  factory _NegotiationMetrics.fromJson(Map<String, dynamic> json) =
      _$NegotiationMetricsImpl.fromJson;

  @override
  String get negotiationId;
  @override
  int get totalOffers;
  @override
  double get averageOffer;
  @override
  double get lowestOffer;
  @override
  double get highestOffer;
  @override
  int get totalDriversParticipated;
  @override
  Duration get averageResponseTime;
  @override
  Duration get totalNegotiationTime;
  @override
  bool get wasSuccessful;
  @override
  bool get wasExtended;
  @override
  int get extensionsUsed;
  @override
  Map<String, dynamic>? get additionalMetrics;

  /// Create a copy of NegotiationMetrics
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NegotiationMetricsImplCopyWith<_$NegotiationMetricsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
