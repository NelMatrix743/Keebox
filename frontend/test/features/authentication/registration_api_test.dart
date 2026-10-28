import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keebox/features/authentication/models/authentication_result.dart';
import 'package:keebox/features/authentication/models/registration_requests.dart';
import 'package:keebox/features/authentication/models/registration_response.dart';
import 'package:keebox/features/authentication/registration_api.dart';
import 'package:keebox/network/api_client.dart';
import 'package:keebox/network/api_endpoints.dart';
import 'package:keebox/network/api_exception.dart';
import 'package:keebox/network/api_session.dart';

const _id = '12345678-1234-1234-1234-123456789abc';
typedef _Operation = ({
  String name,
  String Function() endpoint,
  Map<String, dynamic> payload,
  Future<Object> Function(RegistrationAPI, CancelToken?) invoke,
  Future<Object> Function(RegistrationAPI) invalid,
  Matcher result,
  List<(int, String)> failures,
});

void main() {
  late _Adapter adapter;
  late APIClient client;
  late APISession session;
  late RegistrationAPI api;
  setUp(() {
    adapter = _Adapter();
    session = APISession()
      ..set(
        'existing-access',
        onInvalidSession: () async =>
            fail('Public registration cannot invalidate a session'),
        onRefresh: () async {
          fail('Public registration cannot refresh a session');
        },
      );
    client = APIClient(
      dio: Dio()..httpClientAdapter = adapter,
      session: session,
    );
    api = RegistrationAPI(client: client);
  });
  tearDown(() => client.close());

  test('provider uses the shared API client', () {
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);
    expect(container.read(registrationApiProvider).client, same(client));
  });

  final operations = <_Operation>[
    (
      name: 'start',
      endpoint: () => APIEndpoints.register,
      payload: {
        'first_name': 'Ada',
        'last_name': 'Lovelace',
        'email': 'ada@example.com',
        'password': ' password ',
      },
      invoke: (api, token) => api.start(
        const RegistrationRequest(
          firstName: ' Ada ',
          lastName: ' Lovelace ',
          email: ' ada@example.com ',
          password: ' password ',
        ),
        cancelToken: token,
      ),
      invalid: (api) => api.start(
        const RegistrationRequest(
          firstName: '',
          lastName: 'L',
          email: 'ada@example.com',
          password: 'password',
        ),
      ),
      result: isA<RegistrationChallenge>().having(
        (r) => r.registrationId,
        'registration ID',
        _id,
      ),
      failures: [
        (409, 'registration_email_conflict'),
        (400, 'invalid_registration_data'),
        (409, 'invalid_registration_state'),
        (503, 'email_delivery_failed'),
      ],
    ),
    (
      name: 'verify OTP',
      endpoint: () => APIEndpoints.registerVerifyOtp,
      payload: {'registration_id': _id, 'otp_code': '001234'},
      invoke: (api, token) => api.verifyOtp(
        const RegistrationVerifyRequest(registrationId: _id, otpCode: '001234'),
        cancelToken: token,
      ),
      invalid: (api) => api.verifyOtp(
        const RegistrationVerifyRequest(registrationId: _id, otpCode: 'bad'),
      ),
      result: isA<RegistrationVerified>().having(
        (r) => r.registrationId,
        'registration ID',
        _id,
      ),
      failures: [
        (400, 'invalid_otp'),
        (410, 'expired_otp'),
        (423, 'locked_otp'),
        (409, 'consumed_otp'),
        (409, 'invalid_registration_state'),
      ],
    ),
    (
      name: 'resend OTP',
      endpoint: () => APIEndpoints.registerResendOtp,
      payload: {'registration_id': _id},
      invoke: (api, token) => api.resendOtp(
        const RegistrationResendRequest(registrationId: _id),
        cancelToken: token,
      ),
      invalid: (api) =>
          api.resendOtp(const RegistrationResendRequest(registrationId: 'bad')),
      result: isA<RegistrationOtpResent>()
          .having((r) => r.registrationId, 'registration ID', _id)
          .having((r) => r.resendsRemaining, 'remaining resends', 2),
      failures: [
        (429, 'otp_resend_cooldown'),
        (429, 'otp_resend_limit_reached'),
        (409, 'invalid_registration_state'),
        (503, 'email_delivery_failed'),
      ],
    ),
    (
      name: 'complete',
      endpoint: () => APIEndpoints.registerCreatePin,
      payload: {'registration_id': _id, 'pin': '00123'},
      invoke: (api, token) => api.complete(
        const RegistrationCompletionRequest(registrationId: _id, pin: '00123'),
        cancelToken: token,
      ),
      invalid: (api) => api.complete(
        const RegistrationCompletionRequest(registrationId: _id, pin: '1234'),
      ),
      result: isA<AuthenticationResult>()
          .having((r) => r.user.id, 'user ID', _id)
          .having((r) => r.user.kbkey, 'KBKey', 'permanent-key')
          .having((r) => r.session.accessToken, 'access token', 'new-access')
          .having(
            (r) => r.session.refreshToken,
            'refresh token',
            'new-refresh',
          ),
      failures: [(409, 'invalid_registration_state'), (500, 'internal_error')],
    ),
  ];
  for (final operation in operations) {
    group(operation.name, () {
      test(
        'uses the public POST contract and decodes the successful response',
        () async {
          expect(await operation.invoke(api, null), operation.result);
          final request = adapter.requests.single;
          expect(request.uri.toString(), operation.endpoint());
          expect(request.method, 'POST');
          expect(request.data, operation.payload);
          expect(
            request.headers.keys.map((key) => key.toLowerCase()),
            isNot(contains('authorization')),
          );
          expect(session.accessToken, 'existing-access');
        },
      );
      test('invalid input never reaches the network', () async {
        await expectLater(operation.invalid(api), throwsFormatException);
        expect(adapter.requests, isEmpty);
      });
      test('supports cancellation without replaying the request', () async {
        adapter.gate = Completer<void>();
        final token = CancelToken();
        final pending = expectLater(
          operation.invoke(api, token),
          throwsA(
            isA<APIException>().having(
              (e) => e.kind,
              'kind',
              APIErrorKind.cancelled,
            ),
          ),
        );
        await adapter.started.future;
        token.cancel();
        adapter.gate!.complete();
        await pending;
        expect(adapter.requests, hasLength(1));
      });
      test(
        'malformed successful data becomes an invalid response error',
        () async {
          adapter.malformed = true;
          await expectLater(
            operation.invoke(api, null),
            throwsA(
              isA<APIException>().having(
                (e) => e.kind,
                'kind',
                APIErrorKind.invalidResponse,
              ),
            ),
          );
          expect(adapter.requests, hasLength(1));
        },
      );
      for (final failure in [
        ...operation.failures,
        (422, 'validation_error'),
        (401, 'invalid_session'),
      ]) {
        test(
          'preserves ${failure.$2} without retrying or changing the session',
          () async {
            adapter.failure = failure;
            await expectLater(
              operation.invoke(api, null),
              throwsA(
                isA<APIException>()
                    .having((e) => e.kind, 'kind', APIErrorKind.api)
                    .having((e) => e.code, 'code', failure.$2)
                    .having((e) => e.statusCode, 'status', failure.$1)
                    .having((e) => e.message, 'message', 'Backend rejection')
                    .having((e) => e.details, 'details', {
                      'field': ['reason'],
                    }),
              ),
            );
            expect(adapter.requests, hasLength(1));
            expect(session.accessToken, 'existing-access');
          },
        );
      }
      for (final failure in [
        (DioExceptionType.connectionError, APIErrorKind.connection),
        (DioExceptionType.receiveTimeout, APIErrorKind.timeout),
      ]) {
        test('${failure.$2} is returned without an automatic retry', () async {
          adapter.transportFailure = failure.$1;
          await expectLater(
            operation.invoke(api, null),
            throwsA(
              isA<APIException>().having((e) => e.kind, 'kind', failure.$2),
            ),
          );
          expect(adapter.requests, hasLength(1));
        });
      }
    });
  }
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final started = Completer<void>();
  Completer<void>? gate;
  bool malformed = false;
  (int, String)? failure;
  DioExceptionType? transportFailure;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (!started.isCompleted) started.complete();
    if (gate != null) await gate!.future;
    if (transportFailure != null) {
      throw DioException(requestOptions: options, type: transportFailure!);
    }
    final completion = options.path.endsWith('/create-pin');
    final data = <String, dynamic>{
      'registration_id': _id,
      'status': completion
          ? 'completed'
          : options.path.endsWith('/verify-otp')
          ? 'otp_verified'
          : 'otp_pending',
      'message': 'Backend message',
      'expires_at': '2026-10-28T12:30:00Z',
      'otp_expires_at': '2026-10-28T12:05:00Z',
      'resend_available_at': '2026-10-28T12:01:00Z',
      if (options.path.endsWith('/resend-otp')) 'resends_remaining': 2,
      if (completion) ...{
        'user_id': _id,
        'first_name': 'Ada',
        'last_name': 'Lovelace',
        'email': 'ada@example.com',
        'kbkey': 'permanent-key',
        'access_token': 'new-access',
        'refresh_token': 'new-refresh',
      },
    };
    return ResponseBody.fromString(
      jsonEncode({
        'success': failure == null,
        'data': failure != null
            ? null
            : malformed
            ? {}
            : data,
        'error': failure == null
            ? null
            : {
                'code': failure!.$2,
                'message': 'Backend rejection',
                'details': {
                  'field': ['reason'],
                },
              },
        'meta': null,
      }),
      failure?.$1 ??
          (options.path.endsWith('/verify-otp') ||
                  options.path.endsWith('/resend-otp')
              ? 200
              : 201),
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
