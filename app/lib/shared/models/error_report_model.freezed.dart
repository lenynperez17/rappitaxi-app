// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'error_report_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ErrorReport _$ErrorReportFromJson(Map<String, dynamic> json) {
  return _ErrorReport.fromJson(json);
}

/// @nodoc
mixin _$ErrorReport {
  ErrorType get type => throw _privateConstructorUsedError;
  String get error => throw _privateConstructorUsedError;
  String? get stackTrace => throw _privateConstructorUsedError;
  String? get context => throw _privateConstructorUsedError;
  String? get library => throw _privateConstructorUsedError;
  int? get statusCode => throw _privateConstructorUsedError;
  String? get errorCode => throw _privateConstructorUsedError;
  Map<String, dynamic>? get additionalData =>
      throw _privateConstructorUsedError;
  DateTime get timestamp => throw _privateConstructorUsedError;
  bool get isFatal => throw _privateConstructorUsedError;

  /// Serializes this ErrorReport to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ErrorReport
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ErrorReportCopyWith<ErrorReport> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ErrorReportCopyWith<$Res> {
  factory $ErrorReportCopyWith(
          ErrorReport value, $Res Function(ErrorReport) then) =
      _$ErrorReportCopyWithImpl<$Res, ErrorReport>;
  @useResult
  $Res call(
      {ErrorType type,
      String error,
      String? stackTrace,
      String? context,
      String? library,
      int? statusCode,
      String? errorCode,
      Map<String, dynamic>? additionalData,
      DateTime timestamp,
      bool isFatal});
}

/// @nodoc
class _$ErrorReportCopyWithImpl<$Res, $Val extends ErrorReport>
    implements $ErrorReportCopyWith<$Res> {
  _$ErrorReportCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ErrorReport
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? error = null,
    Object? stackTrace = freezed,
    Object? context = freezed,
    Object? library = freezed,
    Object? statusCode = freezed,
    Object? errorCode = freezed,
    Object? additionalData = freezed,
    Object? timestamp = null,
    Object? isFatal = null,
  }) {
    return _then(_value.copyWith(
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as ErrorType,
      error: null == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String,
      stackTrace: freezed == stackTrace
          ? _value.stackTrace
          : stackTrace // ignore: cast_nullable_to_non_nullable
              as String?,
      context: freezed == context
          ? _value.context
          : context // ignore: cast_nullable_to_non_nullable
              as String?,
      library: freezed == library
          ? _value.library
          : library // ignore: cast_nullable_to_non_nullable
              as String?,
      statusCode: freezed == statusCode
          ? _value.statusCode
          : statusCode // ignore: cast_nullable_to_non_nullable
              as int?,
      errorCode: freezed == errorCode
          ? _value.errorCode
          : errorCode // ignore: cast_nullable_to_non_nullable
              as String?,
      additionalData: freezed == additionalData
          ? _value.additionalData
          : additionalData // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      isFatal: null == isFatal
          ? _value.isFatal
          : isFatal // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ErrorReportImplCopyWith<$Res>
    implements $ErrorReportCopyWith<$Res> {
  factory _$$ErrorReportImplCopyWith(
          _$ErrorReportImpl value, $Res Function(_$ErrorReportImpl) then) =
      __$$ErrorReportImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {ErrorType type,
      String error,
      String? stackTrace,
      String? context,
      String? library,
      int? statusCode,
      String? errorCode,
      Map<String, dynamic>? additionalData,
      DateTime timestamp,
      bool isFatal});
}

/// @nodoc
class __$$ErrorReportImplCopyWithImpl<$Res>
    extends _$ErrorReportCopyWithImpl<$Res, _$ErrorReportImpl>
    implements _$$ErrorReportImplCopyWith<$Res> {
  __$$ErrorReportImplCopyWithImpl(
      _$ErrorReportImpl _value, $Res Function(_$ErrorReportImpl) _then)
      : super(_value, _then);

  /// Create a copy of ErrorReport
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? error = null,
    Object? stackTrace = freezed,
    Object? context = freezed,
    Object? library = freezed,
    Object? statusCode = freezed,
    Object? errorCode = freezed,
    Object? additionalData = freezed,
    Object? timestamp = null,
    Object? isFatal = null,
  }) {
    return _then(_$ErrorReportImpl(
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as ErrorType,
      error: null == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String,
      stackTrace: freezed == stackTrace
          ? _value.stackTrace
          : stackTrace // ignore: cast_nullable_to_non_nullable
              as String?,
      context: freezed == context
          ? _value.context
          : context // ignore: cast_nullable_to_non_nullable
              as String?,
      library: freezed == library
          ? _value.library
          : library // ignore: cast_nullable_to_non_nullable
              as String?,
      statusCode: freezed == statusCode
          ? _value.statusCode
          : statusCode // ignore: cast_nullable_to_non_nullable
              as int?,
      errorCode: freezed == errorCode
          ? _value.errorCode
          : errorCode // ignore: cast_nullable_to_non_nullable
              as String?,
      additionalData: freezed == additionalData
          ? _value._additionalData
          : additionalData // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      isFatal: null == isFatal
          ? _value.isFatal
          : isFatal // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ErrorReportImpl implements _ErrorReport {
  const _$ErrorReportImpl(
      {required this.type,
      required this.error,
      this.stackTrace,
      this.context,
      this.library,
      this.statusCode,
      this.errorCode,
      final Map<String, dynamic>? additionalData,
      required this.timestamp,
      required this.isFatal})
      : _additionalData = additionalData;

  factory _$ErrorReportImpl.fromJson(Map<String, dynamic> json) =>
      _$$ErrorReportImplFromJson(json);

  @override
  final ErrorType type;
  @override
  final String error;
  @override
  final String? stackTrace;
  @override
  final String? context;
  @override
  final String? library;
  @override
  final int? statusCode;
  @override
  final String? errorCode;
  final Map<String, dynamic>? _additionalData;
  @override
  Map<String, dynamic>? get additionalData {
    final value = _additionalData;
    if (value == null) return null;
    if (_additionalData is EqualUnmodifiableMapView) return _additionalData;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  final DateTime timestamp;
  @override
  final bool isFatal;

  @override
  String toString() {
    return 'ErrorReport(type: $type, error: $error, stackTrace: $stackTrace, context: $context, library: $library, statusCode: $statusCode, errorCode: $errorCode, additionalData: $additionalData, timestamp: $timestamp, isFatal: $isFatal)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ErrorReportImpl &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.error, error) || other.error == error) &&
            (identical(other.stackTrace, stackTrace) ||
                other.stackTrace == stackTrace) &&
            (identical(other.context, context) || other.context == context) &&
            (identical(other.library, library) || other.library == library) &&
            (identical(other.statusCode, statusCode) ||
                other.statusCode == statusCode) &&
            (identical(other.errorCode, errorCode) ||
                other.errorCode == errorCode) &&
            const DeepCollectionEquality()
                .equals(other._additionalData, _additionalData) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.isFatal, isFatal) || other.isFatal == isFatal));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      type,
      error,
      stackTrace,
      context,
      library,
      statusCode,
      errorCode,
      const DeepCollectionEquality().hash(_additionalData),
      timestamp,
      isFatal);

  /// Create a copy of ErrorReport
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ErrorReportImplCopyWith<_$ErrorReportImpl> get copyWith =>
      __$$ErrorReportImplCopyWithImpl<_$ErrorReportImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ErrorReportImplToJson(
      this,
    );
  }
}

abstract class _ErrorReport implements ErrorReport {
  const factory _ErrorReport(
      {required final ErrorType type,
      required final String error,
      final String? stackTrace,
      final String? context,
      final String? library,
      final int? statusCode,
      final String? errorCode,
      final Map<String, dynamic>? additionalData,
      required final DateTime timestamp,
      required final bool isFatal}) = _$ErrorReportImpl;

  factory _ErrorReport.fromJson(Map<String, dynamic> json) =
      _$ErrorReportImpl.fromJson;

  @override
  ErrorType get type;
  @override
  String get error;
  @override
  String? get stackTrace;
  @override
  String? get context;
  @override
  String? get library;
  @override
  int? get statusCode;
  @override
  String? get errorCode;
  @override
  Map<String, dynamic>? get additionalData;
  @override
  DateTime get timestamp;
  @override
  bool get isFatal;

  /// Create a copy of ErrorReport
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ErrorReportImplCopyWith<_$ErrorReportImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
