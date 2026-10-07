class APIResponse<T> {
  const APIResponse({required this.data, required this.statusCode, this.meta});

  final T data;
  final int? statusCode;
  final Object? meta;
}
