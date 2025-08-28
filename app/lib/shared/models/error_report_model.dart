// Error report model for Rappi Taxi
import 'package:freezed_annotation/freezed_annotation.dart';

part 'error_report_model.freezed.dart';
part 'error_report_model.g.dart';

@freezed
class ErrorReport with _$ErrorReport {
  const factory ErrorReport({
    required ErrorType type,
    required String error,
    String? stackTrace,
    String? context,
    String? library,
    int? statusCode,
    String? errorCode,
    Map<String, dynamic>? additionalData,
    required DateTime timestamp,
    required bool isFatal,
  }) = _ErrorReport;

  factory ErrorReport.fromJson(Map<String, dynamic> json) =>
      _$ErrorReportFromJson(json);
}

// Error severity levels
enum ErrorSeverity {
  info,
  warning,
  error,
  critical,
}

// Error types for categorization
enum ErrorType {
  flutter,
  platform,
  api,
  business,
  manual,
}