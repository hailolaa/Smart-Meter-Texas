class ApiEnvelope<T> {
  ApiEnvelope({
    required this.success,
    required this.provider,
    required this.operation,
    this.data,
    this.meta,
    this.error,
  });

  final bool success;
  final String provider;
  final String operation;
  final T? data;
  final Map<String, dynamic>? meta;
  final ApiErrorPayload? error;

  factory ApiEnvelope.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic raw)? parseData,
  ) {
    return ApiEnvelope<T>(
      success: json['success'] == true,
      provider: (json['provider'] ?? '').toString(),
      operation: (json['operation'] ?? '').toString(),
      data: parseData != null ? parseData(json['data']) : json['data'] as T?,
      meta: json['meta'] is Map<String, dynamic>
          ? json['meta'] as Map<String, dynamic>
          : null,
      error: json['error'] is Map<String, dynamic>
          ? ApiErrorPayload.fromJson(json['error'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ApiErrorPayload {
  ApiErrorPayload({
    required this.code,
    required this.message,
    this.details,
  });

  final String code;
  final String message;
  final dynamic details;

  factory ApiErrorPayload.fromJson(Map<String, dynamic> json) {
    return ApiErrorPayload(
      code: (json['code'] ?? '').toString(),
      message: (json['message'] ?? 'Unknown error').toString(),
      details: json['details'],
    );
  }
}