enum ApiErrorType {
  network,
  timeout,
  cancelled,
  unauthorized,
  forbidden,
  notFound,
  conflict,
  validation,
  server,
  unknown,
}

class ApiException implements Exception {
  const ApiException({
    required this.type,
    required this.message,
    this.statusCode,
    this.fieldErrors = const {},
  });

  final ApiErrorType type;
  final String message;
  final int? statusCode;
  final Map<String, String> fieldErrors;

  bool get isUnauthorized => type == ApiErrorType.unauthorized;

  @override
  String toString() => 'ApiException($type, $statusCode): $message';
}

String describeError(Object error) {
  if (error is ApiException) return error.message;
  return 'Terjadi kesalahan yang tidak terduga. Silakan coba lagi.';
}
