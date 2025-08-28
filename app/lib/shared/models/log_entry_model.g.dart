// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'log_entry_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$LogEntryImpl _$$LogEntryImplFromJson(Map<String, dynamic> json) =>
    _$LogEntryImpl(
      level: $enumDecode(_$LogLevelEnumMap, json['level']),
      message: json['message'] as String,
      tag: json['tag'] as String,
      error: json['error'] as String?,
      stackTrace: json['stackTrace'] as String?,
      additionalData: json['additionalData'] as Map<String, dynamic>?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );

Map<String, dynamic> _$$LogEntryImplToJson(_$LogEntryImpl instance) =>
    <String, dynamic>{
      'level': _$LogLevelEnumMap[instance.level]!,
      'message': instance.message,
      'tag': instance.tag,
      'error': instance.error,
      'stackTrace': instance.stackTrace,
      'additionalData': instance.additionalData,
      'timestamp': instance.timestamp.toIso8601String(),
    };

const _$LogLevelEnumMap = {
  LogLevel.debug: 'debug',
  LogLevel.info: 'info',
  LogLevel.warn: 'warn',
  LogLevel.error: 'error',
};
