import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keebox/network/api_client.dart';
import 'package:keebox/network/api_exception.dart';

void main() {
  late Dio dio;
  late _Adapter adapter;
  late APIClient client;

  setUp(() {
    adapter = _Adapter();
    dio = Dio()..httpClientAdapter = adapter;
    client = APIClient(dio: dio);
  });
  tearDown(() => client.close());

  test(
    'sends JSON payload, query and headers and decodes envelope data',
    () async {
      adapter.body = {
        'success': true,
        'data': {'status': 'password_verified'},
        'error': null,
        'meta': {'page': 1},
      };
      final response = await client.post<String>(
        'https://example.com/api/auth/login',
        data: {'email': 'user@example.com', 'password': ' secret '},
        queryParameters: {'source': 'mobile'},
        headers: {'X-Request-ID': 'request-1'},
        decode: (data) => (data as Map<String, dynamic>)['status'] as String,
      );
      expect(response.data, 'password_verified');
      expect(response.statusCode, 200);
      expect(response.meta, {'page': 1});
      expect(adapter.request!.method, 'POST');
      expect(adapter.request!.data['password'], ' secret ');
      expect(adapter.request!.queryParameters, {'source': 'mobile'});
      expect(adapter.request!.headers['X-Request-ID'], 'request-1');
      expect(adapter.request!.contentType, Headers.jsonContentType);
    },
  );

  test('HTTP helpers dispatch their corresponding methods', () async {
    final url = 'https://example.com/api/items';
    await client.get<void>(url, decode: (_) {});
    expect(adapter.request!.method, 'GET');
    await client.put<void>(url, decode: (_) {});
    expect(adapter.request!.method, 'PUT');
    await client.patch<void>(url, decode: (_) {});
    expect(adapter.request!.method, 'PATCH');
    await client.delete<void>(url, decode: (_) {});
    expect(adapter.request!.method, 'DELETE');
  });

  test(
    'preserves backend error status, code, message and details without retry',
    () async {
      adapter.status = 401;
      adapter.body = {
        'success': false,
        'data': null,
        'error': {
          'code': 'invalid_login_credentials',
          'message': 'Invalid credentials.',
          'details': {'field': 'email'},
        },
        'meta': null,
      };
      await expectLater(
        client.post<void>('https://example.com/api/auth/login', decode: (_) {}),
        throwsA(
          isA<APIException>()
              .having((e) => e.kind, 'kind', APIErrorKind.api)
              .having((e) => e.statusCode, 'status', 401)
              .having((e) => e.code, 'code', 'invalid_login_credentials')
              .having((e) => e.message, 'message', 'Invalid credentials.')
              .having((e) => e.details, 'details', {'field': 'email'}),
        ),
      );
      expect(adapter.calls, 1);
    },
  );

  test('rejects malformed success responses', () async {
    adapter.body = {'unexpected': true};
    await expectLater(
      client.get<void>('https://example.com/api/items', decode: (_) {}),
      throwsA(
        isA<APIException>().having(
          (e) => e.kind,
          'kind',
          APIErrorKind.invalidResponse,
        ),
      ),
    );
  });

  test('normalizes non-JSON HTTP errors', () async {
    adapter.status = 502;
    adapter.body = 'Bad gateway';
    await expectLater(
      client.get<void>('https://example.com/api/items', decode: (_) {}),
      throwsA(
        isA<APIException>()
            .having((e) => e.kind, 'kind', APIErrorKind.http)
            .having((e) => e.statusCode, 'status', 502),
      ),
    );
  });

  for (final entry in {
    DioExceptionType.connectionTimeout: APIErrorKind.timeout,
    DioExceptionType.receiveTimeout: APIErrorKind.timeout,
    DioExceptionType.connectionError: APIErrorKind.connection,
    DioExceptionType.cancel: APIErrorKind.cancelled,
  }.entries) {
    test('normalizes ${entry.key.name}', () async {
      adapter.failure = entry.key;
      await expectLater(
        client.get<void>('https://example.com/api/items', decode: (_) {}),
        throwsA(isA<APIException>().having((e) => e.kind, 'kind', entry.value)),
      );
    });
  }
}

class _Adapter implements HttpClientAdapter {
  Object body = {'success': true, 'data': null, 'error': null, 'meta': null};
  int status = 200;
  int calls = 0;
  RequestOptions? request;
  DioExceptionType? failure;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    request = options;
    if (failure != null) {
      throw DioException(requestOptions: options, type: failure!);
    }
    return ResponseBody.fromString(
      body is String ? body as String : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [
          body is String ? 'text/plain' : Headers.jsonContentType,
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
