enum APIErrorKind {
  api,
  http,
  timeout,
  connection,
  cancelled,
  invalidResponse,
  unknown,
}

class APIException implements Exception {
  const APIException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.code,
    this.details,
  });

  final APIErrorKind kind;
  final String message;
  final int? statusCode;
  final String? code;
  final Object? details;

  @override
  String toString() =>
      'APIException(${kind.name}, status: $statusCode, code: $code)';
}
