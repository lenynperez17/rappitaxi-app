// Log entry model for Rappi Team

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

class LogEntry {
  final LogLevel level;
  final String message;
  final String tag;
  final String? error;
  final String? stackTrace;
  final Map<String, dynamic>? additionalData;
  final DateTime timestamp;

  LogEntry({
    required this.level,
    required this.message,
    required this.tag,
    this.error,
    this.stackTrace,
    this.additionalData,
    required this.timestamp,
  });

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      level: LogLevel.values.firstWhere(
        (e) => e.toString() == 'LogLevel.${json['level']}',
        orElse: () => LogLevel.info,
      ),
      message: (json['message'] as String?) ?? '',
      tag: (json['tag'] as String?) ?? 'unknown',
      error: json['error'],
      stackTrace: json['stackTrace'],
      additionalData: json['additionalData'] as Map<String, dynamic>?,
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'level': level.toString().split('.').last,
      'message': message,
      'tag': tag,
      'error': error,
      'stackTrace': stackTrace,
      'additionalData': additionalData,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}