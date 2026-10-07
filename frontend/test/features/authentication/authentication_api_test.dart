import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keebox/features/authentication/authentication_api.dart';
import 'package:keebox/features/authentication/models/login_pin_request.dart';
import 'package:keebox/features/authentication/models/login_request.dart';
import 'package:keebox/network/api_client.dart';
import 'package:keebox/network/api_endpoints.dart';
import 'package:keebox/network/api_exception.dart';

void main() {
  late _AuthAdapter adapter;
  late APIClient client;
  late AuthenticationAPI api;

  setUp(() {
    adapter = _AuthAdapter();
    client = APIClient(dio: Dio()..httpClientAdapter = adapter);
    api = AuthenticationAPI(client: client);
  });
  tearDown(() => client.close());

  test(
    'password verification, PIN verification and logout use backend contract',
    () async {
      final challenge = await api.login(
        const LoginRequest(email: ' user@example.com ', password: ' secret '),
      );
      expect(challenge.loginChallengeId, 'challenge-id');
      expect(adapter.requests.last.uri.toString(), APIEndpoints.login);
      expect(adapter.requests.last.method, 'POST');
      expect(adapter.requests.last.data, {
        'email': 'user@example.com',
        'password': ' secret ',
      });
      expect(adapter.requests.last.headers['Authorization'], isNull);

      final session = await api.verifyPin(
        LoginPinRequest(
          loginChallengeId: challenge.loginChallengeId,
          pin: '0012',
        ),
      );
      expect(session.user.email, 'user@example.com');
      expect(session.accessToken, 'access-token');
      expect(session.refreshToken, 'refresh-token');
      expect(session.user.kbkey, 'key');
      expect(adapter.requests.last.uri.toString(), APIEndpoints.loginVerifyPin);
      expect(adapter.requests.last.data, {
        'login_challenge_id': 'challenge-id',
        'pin': '0012',
      });
      expect(adapter.requests.last.headers['Authorization'], isNull);

      final result = await api.logout(accessToken: session.accessToken);
      expect(result.message, 'Logged out successfully.');
      expect(adapter.requests.last.uri.toString(), APIEndpoints.logout);
      expect(
        adapter.requests.last.headers['Authorization'],
        'Bearer access-token',
      );
      expect(adapter.requests.last.data, isNull);
      expect(adapter.requests.length, 3);
    },
  );

  test(
    'logout authorization does not leak into a subsequent public login',
    () async {
      await api.logout(accessToken: 'access-token');
      await api.login(
        const LoginRequest(email: 'user@example.com', password: 'secret'),
      );
      expect(adapter.requests.last.headers['Authorization'], isNull);
    },
  );

  test(
    'backend authentication errors propagate with their code and status',
    () async {
      adapter.errorCode = 'invalid_login_pin';
      adapter.statusCode = 400;
      await expectLater(
        api.verifyPin(
          const LoginPinRequest(loginChallengeId: 'challenge-id', pin: '0000'),
        ),
        throwsA(
          isA<APIException>()
              .having((e) => e.code, 'code', 'invalid_login_pin')
              .having((e) => e.statusCode, 'status', 400),
        ),
      );
      expect(adapter.requests.length, 1);
    },
  );

  test(
    'malformed session response is normalized as an invalid response',
    () async {
      adapter.malformedSession = true;
      await expectLater(
        api.verifyPin(
          const LoginPinRequest(loginChallengeId: 'challenge-id', pin: '0012'),
        ),
        throwsA(
          isA<APIException>().having(
            (e) => e.kind,
            'kind',
            APIErrorKind.invalidResponse,
          ),
        ),
      );
    },
  );
}

class _AuthAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  String? errorCode;
  int statusCode = 200;
  bool malformedSession = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final data = switch (options.uri.path) {
      '/api/auth/login' => {
        'login_challenge_id': 'challenge-id',
        'status': 'password_verified',
        'expires_at': '2026-10-07T12:00:00Z',
        'message': 'Enter your lock PIN.',
      },
      '/api/auth/login/verify-pin' => {
        'user_id': 'user-id',
        'first_name': 'Ada',
        'last_name': 'Lovelace',
        'email': 'user@example.com',
        'access_token': 'access-token',
        'refresh_token': 'refresh-token',
        if (!malformedSession) 'kbkey': 'key',
        'status': 'completed',
        'message': 'Login completed successfully.',
      },
      '/api/auth/logout' => {
        'status': 'logged_out',
        'message': 'Logged out successfully.',
      },
      _ => throw StateError('Unexpected authentication route.'),
    };
    return ResponseBody.fromString(
      jsonEncode({
        'success': errorCode == null,
        'data': errorCode == null ? data : null,
        'error': errorCode == null
            ? null
            : {
                'code': errorCode,
                'message': 'Authentication failed.',
                'details': null,
              },
        'meta': null,
      }),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
