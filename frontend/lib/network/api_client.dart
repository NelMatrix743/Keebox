import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:keebox/network/api_exception.dart';
import 'package:keebox/network/api_response.dart';
import 'package:keebox/network/api_session.dart';

final apiClientProvider = Provider<APIClient>((ref) {
  final client = APIClient(session: ref.watch(apiSessionProvider));
  ref.onDispose(client.close);
  return client;
});

class APIClient {
  APIClient({
    Dio? dio,
    this.session,
    Duration connectTimeout = const Duration(seconds: 20),
    Duration sendTimeout = const Duration(seconds: 30),
    Duration receiveTimeout = const Duration(seconds: 30),
  }) : _dio = dio ?? Dio() {
    _dio.options
      ..connectTimeout = connectTimeout
      ..sendTimeout = sendTimeout
      ..receiveTimeout = receiveTimeout
      ..contentType = Headers.jsonContentType;
    _dio.options.headers[Headers.acceptHeader] = Headers.jsonContentType;
  }

  final Dio _dio;
  final APISession? session;

  Future<APIResponse<T>> request<T>(
    String url, {
    required String method,
    required T Function(Object? data) decode,
    Object? data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
    bool authenticated = false,
  }) async {
    final token = authenticated ? session?.accessToken : null;
    if (authenticated && (token == null || token.isEmpty)) {
      throw const APIException(
        kind: APIErrorKind.api,
        code: 'authentication_required',
        message: 'Authentication is required.',
      );
    }
    final requestHeaders = <String, dynamic>{
      ...?headers,
      if (token != null) 'Authorization': 'Bearer $token',
    };
    Response<dynamic> response;
    try {
      response = await _dio.request<dynamic>(
        url,
        data: data,
        queryParameters: queryParameters,
        options: Options(
          method: method,
          headers: requestHeaders,
          followRedirects: !authenticated,
        ),
        cancelToken: cancelToken,
      );
    } on DioException catch (error) {
      final failure = _fromDio(error);
      await _handleInvalidSession(failure, token);
      throw failure;
    }
    final body = response.data;
    if (body is! Map<String, dynamic> || body['success'] is! bool) {
      throw _invalidResponse(response.statusCode);
    }
    if (body['success'] == false) {
      final failure =
          _backendError(body, response.statusCode) ??
          _invalidResponse(response.statusCode);
      await _handleInvalidSession(failure, token);
      throw failure;
    }
    if (!body.containsKey('data') || body['error'] != null) {
      throw _invalidResponse(response.statusCode);
    }
    try {
      return APIResponse<T>(
        data: decode(body['data']),
        statusCode: response.statusCode,
        meta: body['meta'],
      );
    } on FormatException {
      throw _invalidResponse(response.statusCode);
    } on TypeError {
      throw _invalidResponse(response.statusCode);
    }
  }

  Future<APIResponse<T>> get<T>(
    String url, {
    required T Function(Object? data) decode,
    Object? data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
    bool authenticated = false,
  }) => request<T>(
    url,
    method: 'GET',
    decode: decode,
    data: data,
    queryParameters: queryParameters,
    headers: headers,
    cancelToken: cancelToken,
    authenticated: authenticated,
  );

  Future<APIResponse<T>> post<T>(
    String url, {
    required T Function(Object? data) decode,
    Object? data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
    bool authenticated = false,
  }) => request<T>(
    url,
    method: 'POST',
    decode: decode,
    data: data,
    queryParameters: queryParameters,
    headers: headers,
    cancelToken: cancelToken,
    authenticated: authenticated,
  );

  Future<APIResponse<T>> put<T>(
    String url, {
    required T Function(Object? data) decode,
    Object? data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
    bool authenticated = false,
  }) => request<T>(
    url,
    method: 'PUT',
    decode: decode,
    data: data,
    queryParameters: queryParameters,
    headers: headers,
    cancelToken: cancelToken,
    authenticated: authenticated,
  );

  Future<APIResponse<T>> patch<T>(
    String url, {
    required T Function(Object? data) decode,
    Object? data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
    bool authenticated = false,
  }) => request<T>(
    url,
    method: 'PATCH',
    decode: decode,
    data: data,
    queryParameters: queryParameters,
    headers: headers,
    cancelToken: cancelToken,
    authenticated: authenticated,
  );

  Future<APIResponse<T>> delete<T>(
    String url, {
    required T Function(Object? data) decode,
    Object? data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
    bool authenticated = false,
  }) => request<T>(
    url,
    method: 'DELETE',
    decode: decode,
    data: data,
    queryParameters: queryParameters,
    headers: headers,
    cancelToken: cancelToken,
    authenticated: authenticated,
  );

  void close() => _dio.close(force: true);

  Future<void> _handleInvalidSession(
    APIException failure,
    String? token,
  ) async {
    if (token != null &&
        failure.statusCode == 401 &&
        (failure.code == 'invalid_session' ||
            failure.code == 'authentication_required')) {
      await session?.invalidate(token);
    }
  }

  static APIException _invalidResponse(int? status) => APIException(
    kind: APIErrorKind.invalidResponse,
    message: 'The server returned an unexpected response.',
    statusCode: status,
  );

  static APIException? _backendError(Object? body, int? status) {
    if (body is! Map<String, dynamic> || body['success'] != false) {
      return null;
    }
    final error = body['error'];
    if (error is! Map<String, dynamic> ||
        error['code'] is! String ||
        error['message'] is! String) {
      return null;
    }
    return APIException(
      kind: APIErrorKind.api,
      message: error['message'] as String,
      statusCode: status,
      code: error['code'] as String,
      details: error['details'],
    );
  }

  static APIException _fromDio(DioException error) {
    final status = error.response?.statusCode;
    if (error.type == DioExceptionType.badResponse) {
      return _backendError(error.response?.data, status) ??
          APIException(
            kind: APIErrorKind.http,
            message: 'The server could not complete the request.',
            statusCode: status,
          );
    }
    final kind = switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => APIErrorKind.timeout,
      DioExceptionType.connectionError ||
      DioExceptionType.badCertificate => APIErrorKind.connection,
      DioExceptionType.cancel => APIErrorKind.cancelled,
      _ => APIErrorKind.unknown,
    };
    final message = switch (kind) {
      APIErrorKind.timeout => 'The request timed out. Please try again.',
      APIErrorKind.connection => 'Unable to connect to the server.',
      APIErrorKind.cancelled => 'The request was cancelled.',
      _ => 'Unable to complete the request.',
    };
    return APIException(kind: kind, message: message, statusCode: status);
  }
}
