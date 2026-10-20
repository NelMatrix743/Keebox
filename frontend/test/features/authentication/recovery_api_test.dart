import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keebox/features/authentication/recovery_api.dart';
import 'package:keebox/features/authentication/models/recovery_challenge.dart';
import 'package:keebox/features/authentication/models/recovery_verified.dart';
import 'package:keebox/features/authentication/models/recovery_completed.dart';
import 'package:keebox/features/authentication/models/recovery_type.dart';
import 'package:keebox/features/authentication/models/recovery_start_request.dart';
import 'package:keebox/features/authentication/models/recovery_resend_request.dart';
import 'package:keebox/features/authentication/models/recovery_verify_request.dart';
import 'package:keebox/features/authentication/models/password_reset_request.dart';
import 'package:keebox/features/authentication/models/pin_reset_request.dart';
import 'package:keebox/network/api_client.dart';
import 'package:keebox/network/api_endpoints.dart';
import 'package:keebox/network/api_exception.dart';
import 'package:keebox/network/api_session.dart';

const resetId = '12345678-1234-1234-1234-123456789abc';

void main() {
  late _Adapter adapter;
  late APIClient client;
  late RecoveryAPI api;
  late APISession session;
  setUp(() {
    adapter = _Adapter();
    session = APISession()
      ..set(
        'existing-access',
        onInvalidSession: () async {
          fail('Recovery must not invalidate a session');
        },
      );
    client = APIClient(
      dio: Dio()..httpClientAdapter = adapter,
      session: session,
    );
    api = RecoveryAPI(client: client);
  });
  tearDown(() => client.close());

  final cases =
      <
        (
          String,
          String Function(),
          Map<String, dynamic>,
          Future<Object> Function(RecoveryAPI, CancelToken?),
        )
      >[
        (
          'password initiation',
          () => APIEndpoints.resetPassword,
          {'email': 'ada@example.com'},
          (api, token) => api.start(
            RecoveryType.password,
            const RecoveryStartRequest(email: ' ada@example.com '),
            cancelToken: token,
          ),
        ),
        (
          'PIN initiation',
          () => APIEndpoints.resetPin,
          {'email': 'ada@example.com'},
          (api, token) => api.start(
            RecoveryType.pin,
            const RecoveryStartRequest(email: 'ada@example.com'),
            cancelToken: token,
          ),
        ),
        (
          'OTP resend',
          () => APIEndpoints.resetResendOtp,
          {'reset_id': resetId},
          (api, token) => api.resendOtp(
            const RecoveryResendRequest(resetId: resetId),
            cancelToken: token,
          ),
        ),
        (
          'OTP verification',
          () => APIEndpoints.resetVerifyOtp,
          {'reset_id': resetId, 'otp_code': '001234'},
          (api, token) => api.verifyOtp(
            const RecoveryVerifyRequest(resetId: resetId, otpCode: '001234'),
            cancelToken: token,
          ),
        ),
        (
          'password completion',
          () => APIEndpoints.resetPasswordComplete,
          {'reset_id': resetId, 'new_password': ' password '},
          (api, token) => api.completePassword(
            const PasswordResetRequest(
              resetId: resetId,
              newPassword: ' password ',
            ),
            cancelToken: token,
          ),
        ),
        (
          'PIN completion',
          () => APIEndpoints.resetPinComplete,
          {'reset_id': resetId, 'new_pin': '00123'},
          (api, token) => api.completePin(
            const PinResetRequest(resetId: resetId, newPin: '00123'),
            cancelToken: token,
          ),
        ),
      ];
  for (final operation in cases) {
    test(
      '${operation.$1} uses the public POST contract and typed decoding',
      () async {
        final result = await operation.$4(api, null);
        if (operation.$1.contains('completion')) {
          expect(
            result,
            isA<RecoveryCompleted>().having(
              (value) => value.resetId,
              'reset ID',
              resetId,
            ),
          );
        } else if (operation.$1 == 'OTP verification') {
          expect(
            result,
            isA<RecoveryVerified>().having(
              (value) => value.resetId,
              'reset ID',
              resetId,
            ),
          );
        } else {
          expect(
            result,
            isA<RecoveryChallenge>().having(
              (value) => value.resetId,
              'reset ID',
              resetId,
            ),
          );
        }
        final request = adapter.requests.single;
        expect(request.uri.toString(), operation.$2());
        expect(request.method, 'POST');
        expect(request.data, operation.$3);
        expect(request.headers['Authorization'], isNull);
        expect(session.accessToken, 'existing-access');
      },
    );
    test('${operation.$1} supports request cancellation', () async {
      adapter.gate = Completer<void>();
      final token = CancelToken();
      final pending = expectLater(
        operation.$4(api, token),
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
    test('${operation.$1} rejects malformed successful payloads', () async {
      adapter.malformed = true;
      await expectLater(
        operation.$4(api, null),
        throwsA(
          isA<APIException>().having(
            (e) => e.kind,
            'kind',
            APIErrorKind.invalidResponse,
          ),
        ),
      );
      expect(adapter.requests, hasLength(1));
    });
  }
  for (final failure in [
    (400, 'invalid_otp'),
    (410, 'expired_otp'),
    (423, 'locked_otp'),
    (429, 'otp_resend_cooldown'),
    (429, 'otp_resend_limit_reached'),
    (409, 'invalid_reset_challenge'),
    (410, 'expired_reset_challenge'),
    (400, 'invalid_password'),
    (422, 'validation_error'),
    (401, 'invalid_session'),
  ]) {
    test(
      'preserves backend error ${failure.$2} without retries or token refresh',
      () async {
        adapter.failure = failure;
        await expectLater(
          api.completePassword(
            const PasswordResetRequest(
              resetId: resetId,
              newPassword: 'password',
            ),
          ),
          throwsA(
            isA<APIException>()
                .having((e) => e.code, 'code', failure.$2)
                .having((e) => e.statusCode, 'status', failure.$1)
                .having((e) => e.details, 'details', {'field': 'reason'}),
          ),
        );
        expect(adapter.requests, hasLength(1));
        expect(session.accessToken, 'existing-access');
      },
    );
  }
  test('invalid credential formats never reach the network', () async {
    await expectLater(
      api.verifyOtp(
        const RecoveryVerifyRequest(resetId: resetId, otpCode: 'bad'),
      ),
      throwsFormatException,
    );
    await expectLater(
      api.completePin(const PinResetRequest(resetId: resetId, newPin: '1234')),
      throwsFormatException,
    );
    expect(adapter.requests, isEmpty);
  });
  test(
    'a connection failure is returned without replaying completion',
    () async {
      adapter.offline = true;
      await expectLater(
        api.completePin(
          const PinResetRequest(resetId: resetId, newPin: '00123'),
        ),
        throwsA(
          isA<APIException>().having(
            (e) => e.kind,
            'kind',
            APIErrorKind.connection,
          ),
        ),
      );
      expect(adapter.requests, hasLength(1));
    },
  );
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final started = Completer<void>();
  Completer<void>? gate;
  bool malformed = false;
  bool offline = false;
  (int, String)? failure;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (!started.isCompleted) started.complete();
    if (gate != null) await gate!.future;
    if (offline) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'Offline',
      );
    }
    final verification = options.path.endsWith('/verify-otp');
    final completion = options.path.endsWith('/complete');
    final data = <String, dynamic>{
      'reset_id': resetId,
      'message': 'Backend message',
      'status': completion
          ? 'completed'
          : verification
          ? 'otp_verified'
          : 'otp_pending',
      if (verification) 'completion_expires_at': '2026-10-18T12:10:00Z',
      if (!verification && !completion) ...{
        'otp_expires_at': '2026-10-18T12:05:00Z',
        'resend_available_at': '2026-10-18T12:01:00Z',
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
                'message': 'Rejected',
                'details': {'field': 'reason'},
              },
        'meta': null,
      }),
      failure?.$1 ?? 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
