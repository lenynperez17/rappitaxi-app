// Error report model for Rappi Team

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

class ErrorReport {
  final ErrorType type;
  final String error;
  final String? stackTrace;
  final String? context;
  final String? library;
  final int? statusCode;
  final String? errorCode;
  final Map<String, dynamic>? additionalData;
  final DateTime timestamp;
  final bool isFatal;

  ErrorReport({
    required this.type,
    required this.error,
    this.stackTrace,
    this.context,
    this.library,
    this.statusCode,
    this.errorCode,
    this.additionalData,
    required this.timestamp,
    required this.isFatal,
  });

  factory ErrorReport.fromJson(Map<String, dynamic> json) {
    return ErrorReport(
      type: ErrorType.values.firstWhere(
        (e) => e.toString() == 'ErrorType.${json['type']}',
        orElse: () => ErrorType.manual,
      ),
      error: (json['error'] as String?) ?? 'Error desconocido',
      stackTrace: json['stackTrace'],
      context: json['context'],
      library: json['library'],
      statusCode: json['statusCode'],
      errorCode: json['errorCode'],
      additionalData: json['additionalData'] as Map<String, dynamic>?,
      timestamp: DateTime.parse(json['timestamp']),
      isFatal: (json['isFatal'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.toString().split('.').last,
      'error': error,
      'stackTrace': stackTrace,
      'context': context,
      'library': library,
      'statusCode': statusCode,
      'errorCode': errorCode,
      'additionalData': additionalData,
      'timestamp': timestamp.toIso8601String(),
      'isFatal': isFatal,
    };
  }
}