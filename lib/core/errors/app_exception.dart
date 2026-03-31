class AppException implements Exception {
  AppException({
    required this.code,
    required this.message,
    this.statusCode,
    this.details,
  });

  final String code;
  final String message;
  final int? statusCode;
  final dynamic details;

  @override
  String toString() => message;
}