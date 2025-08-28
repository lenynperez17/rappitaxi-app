class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final int statusCode;
  final Map<String, dynamic>? metadata;

  const ApiResponse({
    required this.success,
    required this.message,
    this.data,
    required this.statusCode,
    this.metadata,
  });

  factory ApiResponse.success({
    required T data,
    String message = 'Success',
    int statusCode = 200,
    Map<String, dynamic>? metadata,
  }) {
    return ApiResponse<T>(
      success: true,
      message: message,
      data: data,
      statusCode: statusCode,
      metadata: metadata,
    );
  }

  factory ApiResponse.error({
    required String message,
    int statusCode = 400,
    T? data,
    Map<String, dynamic>? metadata,
  }) {
    return ApiResponse<T>(
      success: false,
      message: message,
      data: data,
      statusCode: statusCode,
      metadata: metadata,
    );
  }

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? dataMapper,
  ) {
    return ApiResponse<T>(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: dataMapper != null && json['data'] != null 
          ? dataMapper(json['data']) 
          : json['data'],
      statusCode: json['statusCode'] ?? 200,
      metadata: json['metadata'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'data': data,
      'statusCode': statusCode,
      'metadata': metadata,
    };
  }

  @override
  String toString() {
    return 'ApiResponse(success: $success, message: $message, statusCode: $statusCode)';
  }
}