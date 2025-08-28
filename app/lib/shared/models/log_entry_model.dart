// Log entry model for Rappi Taxi
import 'package:freezed_annotation/freezed_annotation.dart';

part 'log_entry_model.freezed.dart';
part 'log_entry_model.g.dart';

@freezed
class LogEntry with _$LogEntry {
  const factory LogEntry({
    required LogLevel level,
    required String message,
    required String tag,
    String? error,
    String? stackTrace,
    Map<String, dynamic>? additionalData,
    required DateTime timestamp,
  }) = _LogEntry;

  factory LogEntry.fromJson(Map<String, dynamic> json) =>
      _$LogEntryFromJson(json);
}

enum LogLevel {
  debug,
  info,
  warn,
  error,
}

// Extension for LogLevel to get string representation
extension LogLevelExtension on LogLevel {
  String get name {
    switch (this) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warn:
        return 'WARN';
      case LogLevel.error:
        return 'ERROR';
    }
  }
}