// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'error_report_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ErrorReportImpl _$$ErrorReportImplFromJson(Map<String, dynamic> json) =>
    _$ErrorReportImpl(
      type: $enumDecode(_$ErrorTypeEnumMap, json['type']),
      error: json['error'] as String,
      stackTrace: json['stackTrace'] as String?,
      context: json['context'] as String?,
      library: json['library'] as String?,
      statusCode: (json['statusCode'] as num?)?.toInt(),
      errorCode: json['errorCode'] as String?,
      additionalData: json['additionalData'] as Map<String, dynamic>?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isFatal: json['isFatal'] as bool,
    );

Map<String, dynamic> _$$ErrorReportImplToJson(_$ErrorReportImpl instance) =>
    <String, dynamic>{
      'type': _$ErrorTypeEnumMap[instance.type]!,
      'error': instance.error,
      'stackTrace': instance.stackTrace,
      'context': instance.context,
      'library': instance.library,
      'statusCode': instance.statusCode,
      'errorCode': instance.errorCode,
      'additionalData': instance.additionalData,
      'timestamp': instance.timestamp.toIso8601String(),
      'isFatal': instance.isFatal,
    };

const _$ErrorTypeEnumMap = {
  ErrorType.flutter: 'flutter',
  ErrorType.platform: 'platform',
  ErrorType.api: 'api',
  ErrorType.business: 'business',
  ErrorType.manual: 'manual',
};
