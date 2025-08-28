// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

UserModel _$UserModelFromJson(Map<String, dynamic> json) {
  return _UserModel.fromJson(json);
}

/// @nodoc
mixin _$UserModel {
  String get id => throw _privateConstructorUsedError;
  String get email => throw _privateConstructorUsedError;
  String get phone => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get photoUrl => throw _privateConstructorUsedError;
  String get role =>
      throw _privateConstructorUsedError; // passenger, driver, admin
  bool get isActive => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt =>
      throw _privateConstructorUsedError; // Role specific data
  PassengerData? get passengerData => throw _privateConstructorUsedError;
  DriverData? get driverData => throw _privateConstructorUsedError;
  AdminData? get adminData => throw _privateConstructorUsedError;

  /// Serializes this UserModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of UserModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UserModelCopyWith<UserModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserModelCopyWith<$Res> {
  factory $UserModelCopyWith(UserModel value, $Res Function(UserModel) then) =
      _$UserModelCopyWithImpl<$Res, UserModel>;
  @useResult
  $Res call(
      {String id,
      String email,
      String phone,
      String name,
      String? photoUrl,
      String role,
      bool isActive,
      DateTime? createdAt,
      DateTime? updatedAt,
      PassengerData? passengerData,
      DriverData? driverData,
      AdminData? adminData});

  $PassengerDataCopyWith<$Res>? get passengerData;
  $DriverDataCopyWith<$Res>? get driverData;
  $AdminDataCopyWith<$Res>? get adminData;
}

/// @nodoc
class _$UserModelCopyWithImpl<$Res, $Val extends UserModel>
    implements $UserModelCopyWith<$Res> {
  _$UserModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of UserModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? email = null,
    Object? phone = null,
    Object? name = null,
    Object? photoUrl = freezed,
    Object? role = null,
    Object? isActive = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? passengerData = freezed,
    Object? driverData = freezed,
    Object? adminData = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      email: null == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String,
      phone: null == phone
          ? _value.phone
          : phone // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      photoUrl: freezed == photoUrl
          ? _value.photoUrl
          : photoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      role: null == role
          ? _value.role
          : role // ignore: cast_nullable_to_non_nullable
              as String,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      passengerData: freezed == passengerData
          ? _value.passengerData
          : passengerData // ignore: cast_nullable_to_non_nullable
              as PassengerData?,
      driverData: freezed == driverData
          ? _value.driverData
          : driverData // ignore: cast_nullable_to_non_nullable
              as DriverData?,
      adminData: freezed == adminData
          ? _value.adminData
          : adminData // ignore: cast_nullable_to_non_nullable
              as AdminData?,
    ) as $Val);
  }

  /// Create a copy of UserModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PassengerDataCopyWith<$Res>? get passengerData {
    if (_value.passengerData == null) {
      return null;
    }

    return $PassengerDataCopyWith<$Res>(_value.passengerData!, (value) {
      return _then(_value.copyWith(passengerData: value) as $Val);
    });
  }

  /// Create a copy of UserModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $DriverDataCopyWith<$Res>? get driverData {
    if (_value.driverData == null) {
      return null;
    }

    return $DriverDataCopyWith<$Res>(_value.driverData!, (value) {
      return _then(_value.copyWith(driverData: value) as $Val);
    });
  }

  /// Create a copy of UserModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AdminDataCopyWith<$Res>? get adminData {
    if (_value.adminData == null) {
      return null;
    }

    return $AdminDataCopyWith<$Res>(_value.adminData!, (value) {
      return _then(_value.copyWith(adminData: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$UserModelImplCopyWith<$Res>
    implements $UserModelCopyWith<$Res> {
  factory _$$UserModelImplCopyWith(
          _$UserModelImpl value, $Res Function(_$UserModelImpl) then) =
      __$$UserModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String email,
      String phone,
      String name,
      String? photoUrl,
      String role,
      bool isActive,
      DateTime? createdAt,
      DateTime? updatedAt,
      PassengerData? passengerData,
      DriverData? driverData,
      AdminData? adminData});

  @override
  $PassengerDataCopyWith<$Res>? get passengerData;
  @override
  $DriverDataCopyWith<$Res>? get driverData;
  @override
  $AdminDataCopyWith<$Res>? get adminData;
}

/// @nodoc
class __$$UserModelImplCopyWithImpl<$Res>
    extends _$UserModelCopyWithImpl<$Res, _$UserModelImpl>
    implements _$$UserModelImplCopyWith<$Res> {
  __$$UserModelImplCopyWithImpl(
      _$UserModelImpl _value, $Res Function(_$UserModelImpl) _then)
      : super(_value, _then);

  /// Create a copy of UserModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? email = null,
    Object? phone = null,
    Object? name = null,
    Object? photoUrl = freezed,
    Object? role = null,
    Object? isActive = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
    Object? passengerData = freezed,
    Object? driverData = freezed,
    Object? adminData = freezed,
  }) {
    return _then(_$UserModelImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      email: null == email
          ? _value.email
          : email // ignore: cast_nullable_to_non_nullable
              as String,
      phone: null == phone
          ? _value.phone
          : phone // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      photoUrl: freezed == photoUrl
          ? _value.photoUrl
          : photoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      role: null == role
          ? _value.role
          : role // ignore: cast_nullable_to_non_nullable
              as String,
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      passengerData: freezed == passengerData
          ? _value.passengerData
          : passengerData // ignore: cast_nullable_to_non_nullable
              as PassengerData?,
      driverData: freezed == driverData
          ? _value.driverData
          : driverData // ignore: cast_nullable_to_non_nullable
              as DriverData?,
      adminData: freezed == adminData
          ? _value.adminData
          : adminData // ignore: cast_nullable_to_non_nullable
              as AdminData?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$UserModelImpl implements _UserModel {
  const _$UserModelImpl(
      {required this.id,
      required this.email,
      required this.phone,
      required this.name,
      this.photoUrl,
      this.role = 'passenger',
      this.isActive = true,
      this.createdAt,
      this.updatedAt,
      this.passengerData,
      this.driverData,
      this.adminData});

  factory _$UserModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$UserModelImplFromJson(json);

  @override
  final String id;
  @override
  final String email;
  @override
  final String phone;
  @override
  final String name;
  @override
  final String? photoUrl;
  @override
  @JsonKey()
  final String role;
// passenger, driver, admin
  @override
  @JsonKey()
  final bool isActive;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;
// Role specific data
  @override
  final PassengerData? passengerData;
  @override
  final DriverData? driverData;
  @override
  final AdminData? adminData;

  @override
  String toString() {
    return 'UserModel(id: $id, email: $email, phone: $phone, name: $name, photoUrl: $photoUrl, role: $role, isActive: $isActive, createdAt: $createdAt, updatedAt: $updatedAt, passengerData: $passengerData, driverData: $driverData, adminData: $adminData)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.phone, phone) || other.phone == phone) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.photoUrl, photoUrl) ||
                other.photoUrl == photoUrl) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.passengerData, passengerData) ||
                other.passengerData == passengerData) &&
            (identical(other.driverData, driverData) ||
                other.driverData == driverData) &&
            (identical(other.adminData, adminData) ||
                other.adminData == adminData));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      email,
      phone,
      name,
      photoUrl,
      role,
      isActive,
      createdAt,
      updatedAt,
      passengerData,
      driverData,
      adminData);

  /// Create a copy of UserModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UserModelImplCopyWith<_$UserModelImpl> get copyWith =>
      __$$UserModelImplCopyWithImpl<_$UserModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UserModelImplToJson(
      this,
    );
  }
}

abstract class _UserModel implements UserModel {
  const factory _UserModel(
      {required final String id,
      required final String email,
      required final String phone,
      required final String name,
      final String? photoUrl,
      final String role,
      final bool isActive,
      final DateTime? createdAt,
      final DateTime? updatedAt,
      final PassengerData? passengerData,
      final DriverData? driverData,
      final AdminData? adminData}) = _$UserModelImpl;

  factory _UserModel.fromJson(Map<String, dynamic> json) =
      _$UserModelImpl.fromJson;

  @override
  String get id;
  @override
  String get email;
  @override
  String get phone;
  @override
  String get name;
  @override
  String? get photoUrl;
  @override
  String get role; // passenger, driver, admin
  @override
  bool get isActive;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get updatedAt; // Role specific data
  @override
  PassengerData? get passengerData;
  @override
  DriverData? get driverData;
  @override
  AdminData? get adminData;

  /// Create a copy of UserModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UserModelImplCopyWith<_$UserModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PassengerData _$PassengerDataFromJson(Map<String, dynamic> json) {
  return _PassengerData.fromJson(json);
}

/// @nodoc
mixin _$PassengerData {
  List<FavoriteLocation> get favoriteLocations =>
      throw _privateConstructorUsedError;
  List<PaymentMethod> get paymentMethods => throw _privateConstructorUsedError;
  double get rating => throw _privateConstructorUsedError;
  int get totalRides => throw _privateConstructorUsedError;
  double get totalSpent => throw _privateConstructorUsedError;

  /// Serializes this PassengerData to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PassengerData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PassengerDataCopyWith<PassengerData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PassengerDataCopyWith<$Res> {
  factory $PassengerDataCopyWith(
          PassengerData value, $Res Function(PassengerData) then) =
      _$PassengerDataCopyWithImpl<$Res, PassengerData>;
  @useResult
  $Res call(
      {List<FavoriteLocation> favoriteLocations,
      List<PaymentMethod> paymentMethods,
      double rating,
      int totalRides,
      double totalSpent});
}

/// @nodoc
class _$PassengerDataCopyWithImpl<$Res, $Val extends PassengerData>
    implements $PassengerDataCopyWith<$Res> {
  _$PassengerDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PassengerData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? favoriteLocations = null,
    Object? paymentMethods = null,
    Object? rating = null,
    Object? totalRides = null,
    Object? totalSpent = null,
  }) {
    return _then(_value.copyWith(
      favoriteLocations: null == favoriteLocations
          ? _value.favoriteLocations
          : favoriteLocations // ignore: cast_nullable_to_non_nullable
              as List<FavoriteLocation>,
      paymentMethods: null == paymentMethods
          ? _value.paymentMethods
          : paymentMethods // ignore: cast_nullable_to_non_nullable
              as List<PaymentMethod>,
      rating: null == rating
          ? _value.rating
          : rating // ignore: cast_nullable_to_non_nullable
              as double,
      totalRides: null == totalRides
          ? _value.totalRides
          : totalRides // ignore: cast_nullable_to_non_nullable
              as int,
      totalSpent: null == totalSpent
          ? _value.totalSpent
          : totalSpent // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PassengerDataImplCopyWith<$Res>
    implements $PassengerDataCopyWith<$Res> {
  factory _$$PassengerDataImplCopyWith(
          _$PassengerDataImpl value, $Res Function(_$PassengerDataImpl) then) =
      __$$PassengerDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {List<FavoriteLocation> favoriteLocations,
      List<PaymentMethod> paymentMethods,
      double rating,
      int totalRides,
      double totalSpent});
}

/// @nodoc
class __$$PassengerDataImplCopyWithImpl<$Res>
    extends _$PassengerDataCopyWithImpl<$Res, _$PassengerDataImpl>
    implements _$$PassengerDataImplCopyWith<$Res> {
  __$$PassengerDataImplCopyWithImpl(
      _$PassengerDataImpl _value, $Res Function(_$PassengerDataImpl) _then)
      : super(_value, _then);

  /// Create a copy of PassengerData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? favoriteLocations = null,
    Object? paymentMethods = null,
    Object? rating = null,
    Object? totalRides = null,
    Object? totalSpent = null,
  }) {
    return _then(_$PassengerDataImpl(
      favoriteLocations: null == favoriteLocations
          ? _value._favoriteLocations
          : favoriteLocations // ignore: cast_nullable_to_non_nullable
              as List<FavoriteLocation>,
      paymentMethods: null == paymentMethods
          ? _value._paymentMethods
          : paymentMethods // ignore: cast_nullable_to_non_nullable
              as List<PaymentMethod>,
      rating: null == rating
          ? _value.rating
          : rating // ignore: cast_nullable_to_non_nullable
              as double,
      totalRides: null == totalRides
          ? _value.totalRides
          : totalRides // ignore: cast_nullable_to_non_nullable
              as int,
      totalSpent: null == totalSpent
          ? _value.totalSpent
          : totalSpent // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PassengerDataImpl implements _PassengerData {
  const _$PassengerDataImpl(
      {final List<FavoriteLocation> favoriteLocations = const [],
      final List<PaymentMethod> paymentMethods = const [],
      this.rating = 5.0,
      this.totalRides = 0,
      this.totalSpent = 0.0})
      : _favoriteLocations = favoriteLocations,
        _paymentMethods = paymentMethods;

  factory _$PassengerDataImpl.fromJson(Map<String, dynamic> json) =>
      _$$PassengerDataImplFromJson(json);

  final List<FavoriteLocation> _favoriteLocations;
  @override
  @JsonKey()
  List<FavoriteLocation> get favoriteLocations {
    if (_favoriteLocations is EqualUnmodifiableListView)
      return _favoriteLocations;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_favoriteLocations);
  }

  final List<PaymentMethod> _paymentMethods;
  @override
  @JsonKey()
  List<PaymentMethod> get paymentMethods {
    if (_paymentMethods is EqualUnmodifiableListView) return _paymentMethods;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_paymentMethods);
  }

  @override
  @JsonKey()
  final double rating;
  @override
  @JsonKey()
  final int totalRides;
  @override
  @JsonKey()
  final double totalSpent;

  @override
  String toString() {
    return 'PassengerData(favoriteLocations: $favoriteLocations, paymentMethods: $paymentMethods, rating: $rating, totalRides: $totalRides, totalSpent: $totalSpent)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PassengerDataImpl &&
            const DeepCollectionEquality()
                .equals(other._favoriteLocations, _favoriteLocations) &&
            const DeepCollectionEquality()
                .equals(other._paymentMethods, _paymentMethods) &&
            (identical(other.rating, rating) || other.rating == rating) &&
            (identical(other.totalRides, totalRides) ||
                other.totalRides == totalRides) &&
            (identical(other.totalSpent, totalSpent) ||
                other.totalSpent == totalSpent));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_favoriteLocations),
      const DeepCollectionEquality().hash(_paymentMethods),
      rating,
      totalRides,
      totalSpent);

  /// Create a copy of PassengerData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PassengerDataImplCopyWith<_$PassengerDataImpl> get copyWith =>
      __$$PassengerDataImplCopyWithImpl<_$PassengerDataImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PassengerDataImplToJson(
      this,
    );
  }
}

abstract class _PassengerData implements PassengerData {
  const factory _PassengerData(
      {final List<FavoriteLocation> favoriteLocations,
      final List<PaymentMethod> paymentMethods,
      final double rating,
      final int totalRides,
      final double totalSpent}) = _$PassengerDataImpl;

  factory _PassengerData.fromJson(Map<String, dynamic> json) =
      _$PassengerDataImpl.fromJson;

  @override
  List<FavoriteLocation> get favoriteLocations;
  @override
  List<PaymentMethod> get paymentMethods;
  @override
  double get rating;
  @override
  int get totalRides;
  @override
  double get totalSpent;

  /// Create a copy of PassengerData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PassengerDataImplCopyWith<_$PassengerDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

FavoriteLocation _$FavoriteLocationFromJson(Map<String, dynamic> json) {
  return _FavoriteLocation.fromJson(json);
}

/// @nodoc
mixin _$FavoriteLocation {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get address => throw _privateConstructorUsedError;
  double get latitude => throw _privateConstructorUsedError;
  double get longitude => throw _privateConstructorUsedError;
  String? get placeId => throw _privateConstructorUsedError;
  String get type => throw _privateConstructorUsedError;

  /// Serializes this FavoriteLocation to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FavoriteLocation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FavoriteLocationCopyWith<FavoriteLocation> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FavoriteLocationCopyWith<$Res> {
  factory $FavoriteLocationCopyWith(
          FavoriteLocation value, $Res Function(FavoriteLocation) then) =
      _$FavoriteLocationCopyWithImpl<$Res, FavoriteLocation>;
  @useResult
  $Res call(
      {String id,
      String name,
      String address,
      double latitude,
      double longitude,
      String? placeId,
      String type});
}

/// @nodoc
class _$FavoriteLocationCopyWithImpl<$Res, $Val extends FavoriteLocation>
    implements $FavoriteLocationCopyWith<$Res> {
  _$FavoriteLocationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FavoriteLocation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? address = null,
    Object? latitude = null,
    Object? longitude = null,
    Object? placeId = freezed,
    Object? type = null,
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
      address: null == address
          ? _value.address
          : address // ignore: cast_nullable_to_non_nullable
              as String,
      latitude: null == latitude
          ? _value.latitude
          : latitude // ignore: cast_nullable_to_non_nullable
              as double,
      longitude: null == longitude
          ? _value.longitude
          : longitude // ignore: cast_nullable_to_non_nullable
              as double,
      placeId: freezed == placeId
          ? _value.placeId
          : placeId // ignore: cast_nullable_to_non_nullable
              as String?,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$FavoriteLocationImplCopyWith<$Res>
    implements $FavoriteLocationCopyWith<$Res> {
  factory _$$FavoriteLocationImplCopyWith(_$FavoriteLocationImpl value,
          $Res Function(_$FavoriteLocationImpl) then) =
      __$$FavoriteLocationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String address,
      double latitude,
      double longitude,
      String? placeId,
      String type});
}

/// @nodoc
class __$$FavoriteLocationImplCopyWithImpl<$Res>
    extends _$FavoriteLocationCopyWithImpl<$Res, _$FavoriteLocationImpl>
    implements _$$FavoriteLocationImplCopyWith<$Res> {
  __$$FavoriteLocationImplCopyWithImpl(_$FavoriteLocationImpl _value,
      $Res Function(_$FavoriteLocationImpl) _then)
      : super(_value, _then);

  /// Create a copy of FavoriteLocation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? address = null,
    Object? latitude = null,
    Object? longitude = null,
    Object? placeId = freezed,
    Object? type = null,
  }) {
    return _then(_$FavoriteLocationImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      address: null == address
          ? _value.address
          : address // ignore: cast_nullable_to_non_nullable
              as String,
      latitude: null == latitude
          ? _value.latitude
          : latitude // ignore: cast_nullable_to_non_nullable
              as double,
      longitude: null == longitude
          ? _value.longitude
          : longitude // ignore: cast_nullable_to_non_nullable
              as double,
      placeId: freezed == placeId
          ? _value.placeId
          : placeId // ignore: cast_nullable_to_non_nullable
              as String?,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$FavoriteLocationImpl implements _FavoriteLocation {
  const _$FavoriteLocationImpl(
      {required this.id,
      required this.name,
      required this.address,
      required this.latitude,
      required this.longitude,
      this.placeId,
      this.type = 'home'});

  factory _$FavoriteLocationImpl.fromJson(Map<String, dynamic> json) =>
      _$$FavoriteLocationImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String address;
  @override
  final double latitude;
  @override
  final double longitude;
  @override
  final String? placeId;
  @override
  @JsonKey()
  final String type;

  @override
  String toString() {
    return 'FavoriteLocation(id: $id, name: $name, address: $address, latitude: $latitude, longitude: $longitude, placeId: $placeId, type: $type)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FavoriteLocationImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.address, address) || other.address == address) &&
            (identical(other.latitude, latitude) ||
                other.latitude == latitude) &&
            (identical(other.longitude, longitude) ||
                other.longitude == longitude) &&
            (identical(other.placeId, placeId) || other.placeId == placeId) &&
            (identical(other.type, type) || other.type == type));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, name, address, latitude, longitude, placeId, type);

  /// Create a copy of FavoriteLocation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FavoriteLocationImplCopyWith<_$FavoriteLocationImpl> get copyWith =>
      __$$FavoriteLocationImplCopyWithImpl<_$FavoriteLocationImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FavoriteLocationImplToJson(
      this,
    );
  }
}

abstract class _FavoriteLocation implements FavoriteLocation {
  const factory _FavoriteLocation(
      {required final String id,
      required final String name,
      required final String address,
      required final double latitude,
      required final double longitude,
      final String? placeId,
      final String type}) = _$FavoriteLocationImpl;

  factory _FavoriteLocation.fromJson(Map<String, dynamic> json) =
      _$FavoriteLocationImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get address;
  @override
  double get latitude;
  @override
  double get longitude;
  @override
  String? get placeId;
  @override
  String get type;

  /// Create a copy of FavoriteLocation
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FavoriteLocationImplCopyWith<_$FavoriteLocationImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PaymentMethod _$PaymentMethodFromJson(Map<String, dynamic> json) {
  return _PaymentMethod.fromJson(json);
}

/// @nodoc
mixin _$PaymentMethod {
  String get id => throw _privateConstructorUsedError;
  String get type =>
      throw _privateConstructorUsedError; // cash, card, mercadopago, yape
  bool get isDefault => throw _privateConstructorUsedError;
  String? get cardLast4 => throw _privateConstructorUsedError;
  String? get cardBrand => throw _privateConstructorUsedError;
  String? get externalId =>
      throw _privateConstructorUsedError; // ID de Mercado Pago, etc
  Map<String, dynamic>? get metadata => throw _privateConstructorUsedError;

  /// Serializes this PaymentMethod to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PaymentMethod
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PaymentMethodCopyWith<PaymentMethod> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PaymentMethodCopyWith<$Res> {
  factory $PaymentMethodCopyWith(
          PaymentMethod value, $Res Function(PaymentMethod) then) =
      _$PaymentMethodCopyWithImpl<$Res, PaymentMethod>;
  @useResult
  $Res call(
      {String id,
      String type,
      bool isDefault,
      String? cardLast4,
      String? cardBrand,
      String? externalId,
      Map<String, dynamic>? metadata});
}

/// @nodoc
class _$PaymentMethodCopyWithImpl<$Res, $Val extends PaymentMethod>
    implements $PaymentMethodCopyWith<$Res> {
  _$PaymentMethodCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PaymentMethod
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? isDefault = null,
    Object? cardLast4 = freezed,
    Object? cardBrand = freezed,
    Object? externalId = freezed,
    Object? metadata = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      isDefault: null == isDefault
          ? _value.isDefault
          : isDefault // ignore: cast_nullable_to_non_nullable
              as bool,
      cardLast4: freezed == cardLast4
          ? _value.cardLast4
          : cardLast4 // ignore: cast_nullable_to_non_nullable
              as String?,
      cardBrand: freezed == cardBrand
          ? _value.cardBrand
          : cardBrand // ignore: cast_nullable_to_non_nullable
              as String?,
      externalId: freezed == externalId
          ? _value.externalId
          : externalId // ignore: cast_nullable_to_non_nullable
              as String?,
      metadata: freezed == metadata
          ? _value.metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PaymentMethodImplCopyWith<$Res>
    implements $PaymentMethodCopyWith<$Res> {
  factory _$$PaymentMethodImplCopyWith(
          _$PaymentMethodImpl value, $Res Function(_$PaymentMethodImpl) then) =
      __$$PaymentMethodImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String type,
      bool isDefault,
      String? cardLast4,
      String? cardBrand,
      String? externalId,
      Map<String, dynamic>? metadata});
}

/// @nodoc
class __$$PaymentMethodImplCopyWithImpl<$Res>
    extends _$PaymentMethodCopyWithImpl<$Res, _$PaymentMethodImpl>
    implements _$$PaymentMethodImplCopyWith<$Res> {
  __$$PaymentMethodImplCopyWithImpl(
      _$PaymentMethodImpl _value, $Res Function(_$PaymentMethodImpl) _then)
      : super(_value, _then);

  /// Create a copy of PaymentMethod
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? isDefault = null,
    Object? cardLast4 = freezed,
    Object? cardBrand = freezed,
    Object? externalId = freezed,
    Object? metadata = freezed,
  }) {
    return _then(_$PaymentMethodImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      isDefault: null == isDefault
          ? _value.isDefault
          : isDefault // ignore: cast_nullable_to_non_nullable
              as bool,
      cardLast4: freezed == cardLast4
          ? _value.cardLast4
          : cardLast4 // ignore: cast_nullable_to_non_nullable
              as String?,
      cardBrand: freezed == cardBrand
          ? _value.cardBrand
          : cardBrand // ignore: cast_nullable_to_non_nullable
              as String?,
      externalId: freezed == externalId
          ? _value.externalId
          : externalId // ignore: cast_nullable_to_non_nullable
              as String?,
      metadata: freezed == metadata
          ? _value._metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PaymentMethodImpl implements _PaymentMethod {
  const _$PaymentMethodImpl(
      {required this.id,
      required this.type,
      this.isDefault = true,
      this.cardLast4,
      this.cardBrand,
      this.externalId,
      final Map<String, dynamic>? metadata})
      : _metadata = metadata;

  factory _$PaymentMethodImpl.fromJson(Map<String, dynamic> json) =>
      _$$PaymentMethodImplFromJson(json);

  @override
  final String id;
  @override
  final String type;
// cash, card, mercadopago, yape
  @override
  @JsonKey()
  final bool isDefault;
  @override
  final String? cardLast4;
  @override
  final String? cardBrand;
  @override
  final String? externalId;
// ID de Mercado Pago, etc
  final Map<String, dynamic>? _metadata;
// ID de Mercado Pago, etc
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
    return 'PaymentMethod(id: $id, type: $type, isDefault: $isDefault, cardLast4: $cardLast4, cardBrand: $cardBrand, externalId: $externalId, metadata: $metadata)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PaymentMethodImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.isDefault, isDefault) ||
                other.isDefault == isDefault) &&
            (identical(other.cardLast4, cardLast4) ||
                other.cardLast4 == cardLast4) &&
            (identical(other.cardBrand, cardBrand) ||
                other.cardBrand == cardBrand) &&
            (identical(other.externalId, externalId) ||
                other.externalId == externalId) &&
            const DeepCollectionEquality().equals(other._metadata, _metadata));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, type, isDefault, cardLast4,
      cardBrand, externalId, const DeepCollectionEquality().hash(_metadata));

  /// Create a copy of PaymentMethod
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PaymentMethodImplCopyWith<_$PaymentMethodImpl> get copyWith =>
      __$$PaymentMethodImplCopyWithImpl<_$PaymentMethodImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PaymentMethodImplToJson(
      this,
    );
  }
}

abstract class _PaymentMethod implements PaymentMethod {
  const factory _PaymentMethod(
      {required final String id,
      required final String type,
      final bool isDefault,
      final String? cardLast4,
      final String? cardBrand,
      final String? externalId,
      final Map<String, dynamic>? metadata}) = _$PaymentMethodImpl;

  factory _PaymentMethod.fromJson(Map<String, dynamic> json) =
      _$PaymentMethodImpl.fromJson;

  @override
  String get id;
  @override
  String get type; // cash, card, mercadopago, yape
  @override
  bool get isDefault;
  @override
  String? get cardLast4;
  @override
  String? get cardBrand;
  @override
  String? get externalId; // ID de Mercado Pago, etc
  @override
  Map<String, dynamic>? get metadata;

  /// Create a copy of PaymentMethod
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PaymentMethodImplCopyWith<_$PaymentMethodImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

DriverData _$DriverDataFromJson(Map<String, dynamic> json) {
  return _DriverData.fromJson(json);
}

/// @nodoc
mixin _$DriverData {
  String get licenseNumber => throw _privateConstructorUsedError;
  String get licenseExpiry => throw _privateConstructorUsedError;
  VehicleInfo get vehicleInfo => throw _privateConstructorUsedError;
  double get rating => throw _privateConstructorUsedError;
  int get totalRides => throw _privateConstructorUsedError;
  double get totalEarnings => throw _privateConstructorUsedError;
  double get acceptanceRate => throw _privateConstructorUsedError;
  double get cancellationRate => throw _privateConstructorUsedError;
  String get status =>
      throw _privateConstructorUsedError; // offline, online, busy, in_ride
  bool get isVerified => throw _privateConstructorUsedError;
  bool get isAvailable => throw _privateConstructorUsedError;
  Map<String, DocumentInfo>? get documents =>
      throw _privateConstructorUsedError; // license, soat, criminal_record, etc
  List<String>? get workingZones => throw _privateConstructorUsedError;
  Map<String, dynamic>? get preferences => throw _privateConstructorUsedError;

  /// Serializes this DriverData to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DriverData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DriverDataCopyWith<DriverData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DriverDataCopyWith<$Res> {
  factory $DriverDataCopyWith(
          DriverData value, $Res Function(DriverData) then) =
      _$DriverDataCopyWithImpl<$Res, DriverData>;
  @useResult
  $Res call(
      {String licenseNumber,
      String licenseExpiry,
      VehicleInfo vehicleInfo,
      double rating,
      int totalRides,
      double totalEarnings,
      double acceptanceRate,
      double cancellationRate,
      String status,
      bool isVerified,
      bool isAvailable,
      Map<String, DocumentInfo>? documents,
      List<String>? workingZones,
      Map<String, dynamic>? preferences});

  $VehicleInfoCopyWith<$Res> get vehicleInfo;
}

/// @nodoc
class _$DriverDataCopyWithImpl<$Res, $Val extends DriverData>
    implements $DriverDataCopyWith<$Res> {
  _$DriverDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DriverData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? licenseNumber = null,
    Object? licenseExpiry = null,
    Object? vehicleInfo = null,
    Object? rating = null,
    Object? totalRides = null,
    Object? totalEarnings = null,
    Object? acceptanceRate = null,
    Object? cancellationRate = null,
    Object? status = null,
    Object? isVerified = null,
    Object? isAvailable = null,
    Object? documents = freezed,
    Object? workingZones = freezed,
    Object? preferences = freezed,
  }) {
    return _then(_value.copyWith(
      licenseNumber: null == licenseNumber
          ? _value.licenseNumber
          : licenseNumber // ignore: cast_nullable_to_non_nullable
              as String,
      licenseExpiry: null == licenseExpiry
          ? _value.licenseExpiry
          : licenseExpiry // ignore: cast_nullable_to_non_nullable
              as String,
      vehicleInfo: null == vehicleInfo
          ? _value.vehicleInfo
          : vehicleInfo // ignore: cast_nullable_to_non_nullable
              as VehicleInfo,
      rating: null == rating
          ? _value.rating
          : rating // ignore: cast_nullable_to_non_nullable
              as double,
      totalRides: null == totalRides
          ? _value.totalRides
          : totalRides // ignore: cast_nullable_to_non_nullable
              as int,
      totalEarnings: null == totalEarnings
          ? _value.totalEarnings
          : totalEarnings // ignore: cast_nullable_to_non_nullable
              as double,
      acceptanceRate: null == acceptanceRate
          ? _value.acceptanceRate
          : acceptanceRate // ignore: cast_nullable_to_non_nullable
              as double,
      cancellationRate: null == cancellationRate
          ? _value.cancellationRate
          : cancellationRate // ignore: cast_nullable_to_non_nullable
              as double,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      isVerified: null == isVerified
          ? _value.isVerified
          : isVerified // ignore: cast_nullable_to_non_nullable
              as bool,
      isAvailable: null == isAvailable
          ? _value.isAvailable
          : isAvailable // ignore: cast_nullable_to_non_nullable
              as bool,
      documents: freezed == documents
          ? _value.documents
          : documents // ignore: cast_nullable_to_non_nullable
              as Map<String, DocumentInfo>?,
      workingZones: freezed == workingZones
          ? _value.workingZones
          : workingZones // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      preferences: freezed == preferences
          ? _value.preferences
          : preferences // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ) as $Val);
  }

  /// Create a copy of DriverData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $VehicleInfoCopyWith<$Res> get vehicleInfo {
    return $VehicleInfoCopyWith<$Res>(_value.vehicleInfo, (value) {
      return _then(_value.copyWith(vehicleInfo: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$DriverDataImplCopyWith<$Res>
    implements $DriverDataCopyWith<$Res> {
  factory _$$DriverDataImplCopyWith(
          _$DriverDataImpl value, $Res Function(_$DriverDataImpl) then) =
      __$$DriverDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String licenseNumber,
      String licenseExpiry,
      VehicleInfo vehicleInfo,
      double rating,
      int totalRides,
      double totalEarnings,
      double acceptanceRate,
      double cancellationRate,
      String status,
      bool isVerified,
      bool isAvailable,
      Map<String, DocumentInfo>? documents,
      List<String>? workingZones,
      Map<String, dynamic>? preferences});

  @override
  $VehicleInfoCopyWith<$Res> get vehicleInfo;
}

/// @nodoc
class __$$DriverDataImplCopyWithImpl<$Res>
    extends _$DriverDataCopyWithImpl<$Res, _$DriverDataImpl>
    implements _$$DriverDataImplCopyWith<$Res> {
  __$$DriverDataImplCopyWithImpl(
      _$DriverDataImpl _value, $Res Function(_$DriverDataImpl) _then)
      : super(_value, _then);

  /// Create a copy of DriverData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? licenseNumber = null,
    Object? licenseExpiry = null,
    Object? vehicleInfo = null,
    Object? rating = null,
    Object? totalRides = null,
    Object? totalEarnings = null,
    Object? acceptanceRate = null,
    Object? cancellationRate = null,
    Object? status = null,
    Object? isVerified = null,
    Object? isAvailable = null,
    Object? documents = freezed,
    Object? workingZones = freezed,
    Object? preferences = freezed,
  }) {
    return _then(_$DriverDataImpl(
      licenseNumber: null == licenseNumber
          ? _value.licenseNumber
          : licenseNumber // ignore: cast_nullable_to_non_nullable
              as String,
      licenseExpiry: null == licenseExpiry
          ? _value.licenseExpiry
          : licenseExpiry // ignore: cast_nullable_to_non_nullable
              as String,
      vehicleInfo: null == vehicleInfo
          ? _value.vehicleInfo
          : vehicleInfo // ignore: cast_nullable_to_non_nullable
              as VehicleInfo,
      rating: null == rating
          ? _value.rating
          : rating // ignore: cast_nullable_to_non_nullable
              as double,
      totalRides: null == totalRides
          ? _value.totalRides
          : totalRides // ignore: cast_nullable_to_non_nullable
              as int,
      totalEarnings: null == totalEarnings
          ? _value.totalEarnings
          : totalEarnings // ignore: cast_nullable_to_non_nullable
              as double,
      acceptanceRate: null == acceptanceRate
          ? _value.acceptanceRate
          : acceptanceRate // ignore: cast_nullable_to_non_nullable
              as double,
      cancellationRate: null == cancellationRate
          ? _value.cancellationRate
          : cancellationRate // ignore: cast_nullable_to_non_nullable
              as double,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      isVerified: null == isVerified
          ? _value.isVerified
          : isVerified // ignore: cast_nullable_to_non_nullable
              as bool,
      isAvailable: null == isAvailable
          ? _value.isAvailable
          : isAvailable // ignore: cast_nullable_to_non_nullable
              as bool,
      documents: freezed == documents
          ? _value._documents
          : documents // ignore: cast_nullable_to_non_nullable
              as Map<String, DocumentInfo>?,
      workingZones: freezed == workingZones
          ? _value._workingZones
          : workingZones // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      preferences: freezed == preferences
          ? _value._preferences
          : preferences // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$DriverDataImpl implements _DriverData {
  const _$DriverDataImpl(
      {required this.licenseNumber,
      required this.licenseExpiry,
      required this.vehicleInfo,
      this.rating = 5.0,
      this.totalRides = 0,
      this.totalEarnings = 0.0,
      this.acceptanceRate = 95.0,
      this.cancellationRate = 5.0,
      this.status = 'offline',
      this.isVerified = false,
      this.isAvailable = true,
      final Map<String, DocumentInfo>? documents,
      final List<String>? workingZones,
      final Map<String, dynamic>? preferences})
      : _documents = documents,
        _workingZones = workingZones,
        _preferences = preferences;

  factory _$DriverDataImpl.fromJson(Map<String, dynamic> json) =>
      _$$DriverDataImplFromJson(json);

  @override
  final String licenseNumber;
  @override
  final String licenseExpiry;
  @override
  final VehicleInfo vehicleInfo;
  @override
  @JsonKey()
  final double rating;
  @override
  @JsonKey()
  final int totalRides;
  @override
  @JsonKey()
  final double totalEarnings;
  @override
  @JsonKey()
  final double acceptanceRate;
  @override
  @JsonKey()
  final double cancellationRate;
  @override
  @JsonKey()
  final String status;
// offline, online, busy, in_ride
  @override
  @JsonKey()
  final bool isVerified;
  @override
  @JsonKey()
  final bool isAvailable;
  final Map<String, DocumentInfo>? _documents;
  @override
  Map<String, DocumentInfo>? get documents {
    final value = _documents;
    if (value == null) return null;
    if (_documents is EqualUnmodifiableMapView) return _documents;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

// license, soat, criminal_record, etc
  final List<String>? _workingZones;
// license, soat, criminal_record, etc
  @override
  List<String>? get workingZones {
    final value = _workingZones;
    if (value == null) return null;
    if (_workingZones is EqualUnmodifiableListView) return _workingZones;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  final Map<String, dynamic>? _preferences;
  @override
  Map<String, dynamic>? get preferences {
    final value = _preferences;
    if (value == null) return null;
    if (_preferences is EqualUnmodifiableMapView) return _preferences;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  String toString() {
    return 'DriverData(licenseNumber: $licenseNumber, licenseExpiry: $licenseExpiry, vehicleInfo: $vehicleInfo, rating: $rating, totalRides: $totalRides, totalEarnings: $totalEarnings, acceptanceRate: $acceptanceRate, cancellationRate: $cancellationRate, status: $status, isVerified: $isVerified, isAvailable: $isAvailable, documents: $documents, workingZones: $workingZones, preferences: $preferences)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DriverDataImpl &&
            (identical(other.licenseNumber, licenseNumber) ||
                other.licenseNumber == licenseNumber) &&
            (identical(other.licenseExpiry, licenseExpiry) ||
                other.licenseExpiry == licenseExpiry) &&
            (identical(other.vehicleInfo, vehicleInfo) ||
                other.vehicleInfo == vehicleInfo) &&
            (identical(other.rating, rating) || other.rating == rating) &&
            (identical(other.totalRides, totalRides) ||
                other.totalRides == totalRides) &&
            (identical(other.totalEarnings, totalEarnings) ||
                other.totalEarnings == totalEarnings) &&
            (identical(other.acceptanceRate, acceptanceRate) ||
                other.acceptanceRate == acceptanceRate) &&
            (identical(other.cancellationRate, cancellationRate) ||
                other.cancellationRate == cancellationRate) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.isVerified, isVerified) ||
                other.isVerified == isVerified) &&
            (identical(other.isAvailable, isAvailable) ||
                other.isAvailable == isAvailable) &&
            const DeepCollectionEquality()
                .equals(other._documents, _documents) &&
            const DeepCollectionEquality()
                .equals(other._workingZones, _workingZones) &&
            const DeepCollectionEquality()
                .equals(other._preferences, _preferences));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      licenseNumber,
      licenseExpiry,
      vehicleInfo,
      rating,
      totalRides,
      totalEarnings,
      acceptanceRate,
      cancellationRate,
      status,
      isVerified,
      isAvailable,
      const DeepCollectionEquality().hash(_documents),
      const DeepCollectionEquality().hash(_workingZones),
      const DeepCollectionEquality().hash(_preferences));

  /// Create a copy of DriverData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DriverDataImplCopyWith<_$DriverDataImpl> get copyWith =>
      __$$DriverDataImplCopyWithImpl<_$DriverDataImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$DriverDataImplToJson(
      this,
    );
  }
}

abstract class _DriverData implements DriverData {
  const factory _DriverData(
      {required final String licenseNumber,
      required final String licenseExpiry,
      required final VehicleInfo vehicleInfo,
      final double rating,
      final int totalRides,
      final double totalEarnings,
      final double acceptanceRate,
      final double cancellationRate,
      final String status,
      final bool isVerified,
      final bool isAvailable,
      final Map<String, DocumentInfo>? documents,
      final List<String>? workingZones,
      final Map<String, dynamic>? preferences}) = _$DriverDataImpl;

  factory _DriverData.fromJson(Map<String, dynamic> json) =
      _$DriverDataImpl.fromJson;

  @override
  String get licenseNumber;
  @override
  String get licenseExpiry;
  @override
  VehicleInfo get vehicleInfo;
  @override
  double get rating;
  @override
  int get totalRides;
  @override
  double get totalEarnings;
  @override
  double get acceptanceRate;
  @override
  double get cancellationRate;
  @override
  String get status; // offline, online, busy, in_ride
  @override
  bool get isVerified;
  @override
  bool get isAvailable;
  @override
  Map<String, DocumentInfo>?
      get documents; // license, soat, criminal_record, etc
  @override
  List<String>? get workingZones;
  @override
  Map<String, dynamic>? get preferences;

  /// Create a copy of DriverData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DriverDataImplCopyWith<_$DriverDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AdminData _$AdminDataFromJson(Map<String, dynamic> json) {
  return _AdminData.fromJson(json);
}

/// @nodoc
mixin _$AdminData {
  String get employeeId => throw _privateConstructorUsedError;
  String get department => throw _privateConstructorUsedError;
  List<String> get permissions => throw _privateConstructorUsedError;
  bool get canManageDrivers => throw _privateConstructorUsedError;
  bool get canManagePassengers => throw _privateConstructorUsedError;
  bool get canViewReports => throw _privateConstructorUsedError;
  bool get canManagePromotions => throw _privateConstructorUsedError;
  bool get canManageAdmins => throw _privateConstructorUsedError;
  bool get isSuperAdmin => throw _privateConstructorUsedError;
  DateTime? get lastLogin => throw _privateConstructorUsedError;
  Map<String, dynamic>? get metadata => throw _privateConstructorUsedError;

  /// Serializes this AdminData to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AdminData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AdminDataCopyWith<AdminData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AdminDataCopyWith<$Res> {
  factory $AdminDataCopyWith(AdminData value, $Res Function(AdminData) then) =
      _$AdminDataCopyWithImpl<$Res, AdminData>;
  @useResult
  $Res call(
      {String employeeId,
      String department,
      List<String> permissions,
      bool canManageDrivers,
      bool canManagePassengers,
      bool canViewReports,
      bool canManagePromotions,
      bool canManageAdmins,
      bool isSuperAdmin,
      DateTime? lastLogin,
      Map<String, dynamic>? metadata});
}

/// @nodoc
class _$AdminDataCopyWithImpl<$Res, $Val extends AdminData>
    implements $AdminDataCopyWith<$Res> {
  _$AdminDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AdminData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? employeeId = null,
    Object? department = null,
    Object? permissions = null,
    Object? canManageDrivers = null,
    Object? canManagePassengers = null,
    Object? canViewReports = null,
    Object? canManagePromotions = null,
    Object? canManageAdmins = null,
    Object? isSuperAdmin = null,
    Object? lastLogin = freezed,
    Object? metadata = freezed,
  }) {
    return _then(_value.copyWith(
      employeeId: null == employeeId
          ? _value.employeeId
          : employeeId // ignore: cast_nullable_to_non_nullable
              as String,
      department: null == department
          ? _value.department
          : department // ignore: cast_nullable_to_non_nullable
              as String,
      permissions: null == permissions
          ? _value.permissions
          : permissions // ignore: cast_nullable_to_non_nullable
              as List<String>,
      canManageDrivers: null == canManageDrivers
          ? _value.canManageDrivers
          : canManageDrivers // ignore: cast_nullable_to_non_nullable
              as bool,
      canManagePassengers: null == canManagePassengers
          ? _value.canManagePassengers
          : canManagePassengers // ignore: cast_nullable_to_non_nullable
              as bool,
      canViewReports: null == canViewReports
          ? _value.canViewReports
          : canViewReports // ignore: cast_nullable_to_non_nullable
              as bool,
      canManagePromotions: null == canManagePromotions
          ? _value.canManagePromotions
          : canManagePromotions // ignore: cast_nullable_to_non_nullable
              as bool,
      canManageAdmins: null == canManageAdmins
          ? _value.canManageAdmins
          : canManageAdmins // ignore: cast_nullable_to_non_nullable
              as bool,
      isSuperAdmin: null == isSuperAdmin
          ? _value.isSuperAdmin
          : isSuperAdmin // ignore: cast_nullable_to_non_nullable
              as bool,
      lastLogin: freezed == lastLogin
          ? _value.lastLogin
          : lastLogin // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      metadata: freezed == metadata
          ? _value.metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AdminDataImplCopyWith<$Res>
    implements $AdminDataCopyWith<$Res> {
  factory _$$AdminDataImplCopyWith(
          _$AdminDataImpl value, $Res Function(_$AdminDataImpl) then) =
      __$$AdminDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String employeeId,
      String department,
      List<String> permissions,
      bool canManageDrivers,
      bool canManagePassengers,
      bool canViewReports,
      bool canManagePromotions,
      bool canManageAdmins,
      bool isSuperAdmin,
      DateTime? lastLogin,
      Map<String, dynamic>? metadata});
}

/// @nodoc
class __$$AdminDataImplCopyWithImpl<$Res>
    extends _$AdminDataCopyWithImpl<$Res, _$AdminDataImpl>
    implements _$$AdminDataImplCopyWith<$Res> {
  __$$AdminDataImplCopyWithImpl(
      _$AdminDataImpl _value, $Res Function(_$AdminDataImpl) _then)
      : super(_value, _then);

  /// Create a copy of AdminData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? employeeId = null,
    Object? department = null,
    Object? permissions = null,
    Object? canManageDrivers = null,
    Object? canManagePassengers = null,
    Object? canViewReports = null,
    Object? canManagePromotions = null,
    Object? canManageAdmins = null,
    Object? isSuperAdmin = null,
    Object? lastLogin = freezed,
    Object? metadata = freezed,
  }) {
    return _then(_$AdminDataImpl(
      employeeId: null == employeeId
          ? _value.employeeId
          : employeeId // ignore: cast_nullable_to_non_nullable
              as String,
      department: null == department
          ? _value.department
          : department // ignore: cast_nullable_to_non_nullable
              as String,
      permissions: null == permissions
          ? _value._permissions
          : permissions // ignore: cast_nullable_to_non_nullable
              as List<String>,
      canManageDrivers: null == canManageDrivers
          ? _value.canManageDrivers
          : canManageDrivers // ignore: cast_nullable_to_non_nullable
              as bool,
      canManagePassengers: null == canManagePassengers
          ? _value.canManagePassengers
          : canManagePassengers // ignore: cast_nullable_to_non_nullable
              as bool,
      canViewReports: null == canViewReports
          ? _value.canViewReports
          : canViewReports // ignore: cast_nullable_to_non_nullable
              as bool,
      canManagePromotions: null == canManagePromotions
          ? _value.canManagePromotions
          : canManagePromotions // ignore: cast_nullable_to_non_nullable
              as bool,
      canManageAdmins: null == canManageAdmins
          ? _value.canManageAdmins
          : canManageAdmins // ignore: cast_nullable_to_non_nullable
              as bool,
      isSuperAdmin: null == isSuperAdmin
          ? _value.isSuperAdmin
          : isSuperAdmin // ignore: cast_nullable_to_non_nullable
              as bool,
      lastLogin: freezed == lastLogin
          ? _value.lastLogin
          : lastLogin // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      metadata: freezed == metadata
          ? _value._metadata
          : metadata // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AdminDataImpl implements _AdminData {
  const _$AdminDataImpl(
      {required this.employeeId,
      required this.department,
      final List<String> permissions = const [],
      this.canManageDrivers = true,
      this.canManagePassengers = true,
      this.canViewReports = true,
      this.canManagePromotions = true,
      this.canManageAdmins = false,
      this.isSuperAdmin = false,
      this.lastLogin,
      final Map<String, dynamic>? metadata})
      : _permissions = permissions,
        _metadata = metadata;

  factory _$AdminDataImpl.fromJson(Map<String, dynamic> json) =>
      _$$AdminDataImplFromJson(json);

  @override
  final String employeeId;
  @override
  final String department;
  final List<String> _permissions;
  @override
  @JsonKey()
  List<String> get permissions {
    if (_permissions is EqualUnmodifiableListView) return _permissions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_permissions);
  }

  @override
  @JsonKey()
  final bool canManageDrivers;
  @override
  @JsonKey()
  final bool canManagePassengers;
  @override
  @JsonKey()
  final bool canViewReports;
  @override
  @JsonKey()
  final bool canManagePromotions;
  @override
  @JsonKey()
  final bool canManageAdmins;
  @override
  @JsonKey()
  final bool isSuperAdmin;
  @override
  final DateTime? lastLogin;
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
    return 'AdminData(employeeId: $employeeId, department: $department, permissions: $permissions, canManageDrivers: $canManageDrivers, canManagePassengers: $canManagePassengers, canViewReports: $canViewReports, canManagePromotions: $canManagePromotions, canManageAdmins: $canManageAdmins, isSuperAdmin: $isSuperAdmin, lastLogin: $lastLogin, metadata: $metadata)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AdminDataImpl &&
            (identical(other.employeeId, employeeId) ||
                other.employeeId == employeeId) &&
            (identical(other.department, department) ||
                other.department == department) &&
            const DeepCollectionEquality()
                .equals(other._permissions, _permissions) &&
            (identical(other.canManageDrivers, canManageDrivers) ||
                other.canManageDrivers == canManageDrivers) &&
            (identical(other.canManagePassengers, canManagePassengers) ||
                other.canManagePassengers == canManagePassengers) &&
            (identical(other.canViewReports, canViewReports) ||
                other.canViewReports == canViewReports) &&
            (identical(other.canManagePromotions, canManagePromotions) ||
                other.canManagePromotions == canManagePromotions) &&
            (identical(other.canManageAdmins, canManageAdmins) ||
                other.canManageAdmins == canManageAdmins) &&
            (identical(other.isSuperAdmin, isSuperAdmin) ||
                other.isSuperAdmin == isSuperAdmin) &&
            (identical(other.lastLogin, lastLogin) ||
                other.lastLogin == lastLogin) &&
            const DeepCollectionEquality().equals(other._metadata, _metadata));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      employeeId,
      department,
      const DeepCollectionEquality().hash(_permissions),
      canManageDrivers,
      canManagePassengers,
      canViewReports,
      canManagePromotions,
      canManageAdmins,
      isSuperAdmin,
      lastLogin,
      const DeepCollectionEquality().hash(_metadata));

  /// Create a copy of AdminData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AdminDataImplCopyWith<_$AdminDataImpl> get copyWith =>
      __$$AdminDataImplCopyWithImpl<_$AdminDataImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AdminDataImplToJson(
      this,
    );
  }
}

abstract class _AdminData implements AdminData {
  const factory _AdminData(
      {required final String employeeId,
      required final String department,
      final List<String> permissions,
      final bool canManageDrivers,
      final bool canManagePassengers,
      final bool canViewReports,
      final bool canManagePromotions,
      final bool canManageAdmins,
      final bool isSuperAdmin,
      final DateTime? lastLogin,
      final Map<String, dynamic>? metadata}) = _$AdminDataImpl;

  factory _AdminData.fromJson(Map<String, dynamic> json) =
      _$AdminDataImpl.fromJson;

  @override
  String get employeeId;
  @override
  String get department;
  @override
  List<String> get permissions;
  @override
  bool get canManageDrivers;
  @override
  bool get canManagePassengers;
  @override
  bool get canViewReports;
  @override
  bool get canManagePromotions;
  @override
  bool get canManageAdmins;
  @override
  bool get isSuperAdmin;
  @override
  DateTime? get lastLogin;
  @override
  Map<String, dynamic>? get metadata;

  /// Create a copy of AdminData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AdminDataImplCopyWith<_$AdminDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

VehicleInfo _$VehicleInfoFromJson(Map<String, dynamic> json) {
  return _VehicleInfo.fromJson(json);
}

/// @nodoc
mixin _$VehicleInfo {
  String get plate => throw _privateConstructorUsedError;
  String get brand => throw _privateConstructorUsedError;
  String get model => throw _privateConstructorUsedError;
  String get color => throw _privateConstructorUsedError;
  int get year => throw _privateConstructorUsedError;
  String get type =>
      throw _privateConstructorUsedError; // economy, standard, premium
  String? get soatNumber => throw _privateConstructorUsedError;
  String? get soatExpiry => throw _privateConstructorUsedError;
  List<String>? get photos => throw _privateConstructorUsedError;
  Map<String, dynamic>? get maintenance => throw _privateConstructorUsedError;

  /// Serializes this VehicleInfo to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of VehicleInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $VehicleInfoCopyWith<VehicleInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VehicleInfoCopyWith<$Res> {
  factory $VehicleInfoCopyWith(
          VehicleInfo value, $Res Function(VehicleInfo) then) =
      _$VehicleInfoCopyWithImpl<$Res, VehicleInfo>;
  @useResult
  $Res call(
      {String plate,
      String brand,
      String model,
      String color,
      int year,
      String type,
      String? soatNumber,
      String? soatExpiry,
      List<String>? photos,
      Map<String, dynamic>? maintenance});
}

/// @nodoc
class _$VehicleInfoCopyWithImpl<$Res, $Val extends VehicleInfo>
    implements $VehicleInfoCopyWith<$Res> {
  _$VehicleInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of VehicleInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? plate = null,
    Object? brand = null,
    Object? model = null,
    Object? color = null,
    Object? year = null,
    Object? type = null,
    Object? soatNumber = freezed,
    Object? soatExpiry = freezed,
    Object? photos = freezed,
    Object? maintenance = freezed,
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
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      soatNumber: freezed == soatNumber
          ? _value.soatNumber
          : soatNumber // ignore: cast_nullable_to_non_nullable
              as String?,
      soatExpiry: freezed == soatExpiry
          ? _value.soatExpiry
          : soatExpiry // ignore: cast_nullable_to_non_nullable
              as String?,
      photos: freezed == photos
          ? _value.photos
          : photos // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      maintenance: freezed == maintenance
          ? _value.maintenance
          : maintenance // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$VehicleInfoImplCopyWith<$Res>
    implements $VehicleInfoCopyWith<$Res> {
  factory _$$VehicleInfoImplCopyWith(
          _$VehicleInfoImpl value, $Res Function(_$VehicleInfoImpl) then) =
      __$$VehicleInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String plate,
      String brand,
      String model,
      String color,
      int year,
      String type,
      String? soatNumber,
      String? soatExpiry,
      List<String>? photos,
      Map<String, dynamic>? maintenance});
}

/// @nodoc
class __$$VehicleInfoImplCopyWithImpl<$Res>
    extends _$VehicleInfoCopyWithImpl<$Res, _$VehicleInfoImpl>
    implements _$$VehicleInfoImplCopyWith<$Res> {
  __$$VehicleInfoImplCopyWithImpl(
      _$VehicleInfoImpl _value, $Res Function(_$VehicleInfoImpl) _then)
      : super(_value, _then);

  /// Create a copy of VehicleInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? plate = null,
    Object? brand = null,
    Object? model = null,
    Object? color = null,
    Object? year = null,
    Object? type = null,
    Object? soatNumber = freezed,
    Object? soatExpiry = freezed,
    Object? photos = freezed,
    Object? maintenance = freezed,
  }) {
    return _then(_$VehicleInfoImpl(
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
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      soatNumber: freezed == soatNumber
          ? _value.soatNumber
          : soatNumber // ignore: cast_nullable_to_non_nullable
              as String?,
      soatExpiry: freezed == soatExpiry
          ? _value.soatExpiry
          : soatExpiry // ignore: cast_nullable_to_non_nullable
              as String?,
      photos: freezed == photos
          ? _value._photos
          : photos // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      maintenance: freezed == maintenance
          ? _value._maintenance
          : maintenance // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$VehicleInfoImpl implements _VehicleInfo {
  const _$VehicleInfoImpl(
      {required this.plate,
      required this.brand,
      required this.model,
      required this.color,
      required this.year,
      required this.type,
      this.soatNumber,
      this.soatExpiry,
      final List<String>? photos,
      final Map<String, dynamic>? maintenance})
      : _photos = photos,
        _maintenance = maintenance;

  factory _$VehicleInfoImpl.fromJson(Map<String, dynamic> json) =>
      _$$VehicleInfoImplFromJson(json);

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
  final String type;
// economy, standard, premium
  @override
  final String? soatNumber;
  @override
  final String? soatExpiry;
  final List<String>? _photos;
  @override
  List<String>? get photos {
    final value = _photos;
    if (value == null) return null;
    if (_photos is EqualUnmodifiableListView) return _photos;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  final Map<String, dynamic>? _maintenance;
  @override
  Map<String, dynamic>? get maintenance {
    final value = _maintenance;
    if (value == null) return null;
    if (_maintenance is EqualUnmodifiableMapView) return _maintenance;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  String toString() {
    return 'VehicleInfo(plate: $plate, brand: $brand, model: $model, color: $color, year: $year, type: $type, soatNumber: $soatNumber, soatExpiry: $soatExpiry, photos: $photos, maintenance: $maintenance)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VehicleInfoImpl &&
            (identical(other.plate, plate) || other.plate == plate) &&
            (identical(other.brand, brand) || other.brand == brand) &&
            (identical(other.model, model) || other.model == model) &&
            (identical(other.color, color) || other.color == color) &&
            (identical(other.year, year) || other.year == year) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.soatNumber, soatNumber) ||
                other.soatNumber == soatNumber) &&
            (identical(other.soatExpiry, soatExpiry) ||
                other.soatExpiry == soatExpiry) &&
            const DeepCollectionEquality().equals(other._photos, _photos) &&
            const DeepCollectionEquality()
                .equals(other._maintenance, _maintenance));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      plate,
      brand,
      model,
      color,
      year,
      type,
      soatNumber,
      soatExpiry,
      const DeepCollectionEquality().hash(_photos),
      const DeepCollectionEquality().hash(_maintenance));

  /// Create a copy of VehicleInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$VehicleInfoImplCopyWith<_$VehicleInfoImpl> get copyWith =>
      __$$VehicleInfoImplCopyWithImpl<_$VehicleInfoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$VehicleInfoImplToJson(
      this,
    );
  }
}

abstract class _VehicleInfo implements VehicleInfo {
  const factory _VehicleInfo(
      {required final String plate,
      required final String brand,
      required final String model,
      required final String color,
      required final int year,
      required final String type,
      final String? soatNumber,
      final String? soatExpiry,
      final List<String>? photos,
      final Map<String, dynamic>? maintenance}) = _$VehicleInfoImpl;

  factory _VehicleInfo.fromJson(Map<String, dynamic> json) =
      _$VehicleInfoImpl.fromJson;

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
  @override
  String get type; // economy, standard, premium
  @override
  String? get soatNumber;
  @override
  String? get soatExpiry;
  @override
  List<String>? get photos;
  @override
  Map<String, dynamic>? get maintenance;

  /// Create a copy of VehicleInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$VehicleInfoImplCopyWith<_$VehicleInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

DocumentInfo _$DocumentInfoFromJson(Map<String, dynamic> json) {
  return _DocumentInfo.fromJson(json);
}

/// @nodoc
mixin _$DocumentInfo {
  String get type => throw _privateConstructorUsedError;
  String get number => throw _privateConstructorUsedError;
  String get fileUrl => throw _privateConstructorUsedError;
  DateTime get uploadedAt => throw _privateConstructorUsedError;
  DateTime? get expiryDate => throw _privateConstructorUsedError;
  String get status =>
      throw _privateConstructorUsedError; // pending, approved, rejected
  String? get rejectionReason => throw _privateConstructorUsedError;

  /// Serializes this DocumentInfo to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DocumentInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DocumentInfoCopyWith<DocumentInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DocumentInfoCopyWith<$Res> {
  factory $DocumentInfoCopyWith(
          DocumentInfo value, $Res Function(DocumentInfo) then) =
      _$DocumentInfoCopyWithImpl<$Res, DocumentInfo>;
  @useResult
  $Res call(
      {String type,
      String number,
      String fileUrl,
      DateTime uploadedAt,
      DateTime? expiryDate,
      String status,
      String? rejectionReason});
}

/// @nodoc
class _$DocumentInfoCopyWithImpl<$Res, $Val extends DocumentInfo>
    implements $DocumentInfoCopyWith<$Res> {
  _$DocumentInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DocumentInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? number = null,
    Object? fileUrl = null,
    Object? uploadedAt = null,
    Object? expiryDate = freezed,
    Object? status = null,
    Object? rejectionReason = freezed,
  }) {
    return _then(_value.copyWith(
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      number: null == number
          ? _value.number
          : number // ignore: cast_nullable_to_non_nullable
              as String,
      fileUrl: null == fileUrl
          ? _value.fileUrl
          : fileUrl // ignore: cast_nullable_to_non_nullable
              as String,
      uploadedAt: null == uploadedAt
          ? _value.uploadedAt
          : uploadedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      expiryDate: freezed == expiryDate
          ? _value.expiryDate
          : expiryDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      rejectionReason: freezed == rejectionReason
          ? _value.rejectionReason
          : rejectionReason // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DocumentInfoImplCopyWith<$Res>
    implements $DocumentInfoCopyWith<$Res> {
  factory _$$DocumentInfoImplCopyWith(
          _$DocumentInfoImpl value, $Res Function(_$DocumentInfoImpl) then) =
      __$$DocumentInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String type,
      String number,
      String fileUrl,
      DateTime uploadedAt,
      DateTime? expiryDate,
      String status,
      String? rejectionReason});
}

/// @nodoc
class __$$DocumentInfoImplCopyWithImpl<$Res>
    extends _$DocumentInfoCopyWithImpl<$Res, _$DocumentInfoImpl>
    implements _$$DocumentInfoImplCopyWith<$Res> {
  __$$DocumentInfoImplCopyWithImpl(
      _$DocumentInfoImpl _value, $Res Function(_$DocumentInfoImpl) _then)
      : super(_value, _then);

  /// Create a copy of DocumentInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? number = null,
    Object? fileUrl = null,
    Object? uploadedAt = null,
    Object? expiryDate = freezed,
    Object? status = null,
    Object? rejectionReason = freezed,
  }) {
    return _then(_$DocumentInfoImpl(
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      number: null == number
          ? _value.number
          : number // ignore: cast_nullable_to_non_nullable
              as String,
      fileUrl: null == fileUrl
          ? _value.fileUrl
          : fileUrl // ignore: cast_nullable_to_non_nullable
              as String,
      uploadedAt: null == uploadedAt
          ? _value.uploadedAt
          : uploadedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      expiryDate: freezed == expiryDate
          ? _value.expiryDate
          : expiryDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      rejectionReason: freezed == rejectionReason
          ? _value.rejectionReason
          : rejectionReason // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$DocumentInfoImpl implements _DocumentInfo {
  const _$DocumentInfoImpl(
      {required this.type,
      required this.number,
      required this.fileUrl,
      required this.uploadedAt,
      this.expiryDate,
      this.status = 'pending',
      this.rejectionReason});

  factory _$DocumentInfoImpl.fromJson(Map<String, dynamic> json) =>
      _$$DocumentInfoImplFromJson(json);

  @override
  final String type;
  @override
  final String number;
  @override
  final String fileUrl;
  @override
  final DateTime uploadedAt;
  @override
  final DateTime? expiryDate;
  @override
  @JsonKey()
  final String status;
// pending, approved, rejected
  @override
  final String? rejectionReason;

  @override
  String toString() {
    return 'DocumentInfo(type: $type, number: $number, fileUrl: $fileUrl, uploadedAt: $uploadedAt, expiryDate: $expiryDate, status: $status, rejectionReason: $rejectionReason)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DocumentInfoImpl &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.number, number) || other.number == number) &&
            (identical(other.fileUrl, fileUrl) || other.fileUrl == fileUrl) &&
            (identical(other.uploadedAt, uploadedAt) ||
                other.uploadedAt == uploadedAt) &&
            (identical(other.expiryDate, expiryDate) ||
                other.expiryDate == expiryDate) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.rejectionReason, rejectionReason) ||
                other.rejectionReason == rejectionReason));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, type, number, fileUrl,
      uploadedAt, expiryDate, status, rejectionReason);

  /// Create a copy of DocumentInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DocumentInfoImplCopyWith<_$DocumentInfoImpl> get copyWith =>
      __$$DocumentInfoImplCopyWithImpl<_$DocumentInfoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$DocumentInfoImplToJson(
      this,
    );
  }
}

abstract class _DocumentInfo implements DocumentInfo {
  const factory _DocumentInfo(
      {required final String type,
      required final String number,
      required final String fileUrl,
      required final DateTime uploadedAt,
      final DateTime? expiryDate,
      final String status,
      final String? rejectionReason}) = _$DocumentInfoImpl;

  factory _DocumentInfo.fromJson(Map<String, dynamic> json) =
      _$DocumentInfoImpl.fromJson;

  @override
  String get type;
  @override
  String get number;
  @override
  String get fileUrl;
  @override
  DateTime get uploadedAt;
  @override
  DateTime? get expiryDate;
  @override
  String get status; // pending, approved, rejected
  @override
  String? get rejectionReason;

  /// Create a copy of DocumentInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DocumentInfoImplCopyWith<_$DocumentInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
