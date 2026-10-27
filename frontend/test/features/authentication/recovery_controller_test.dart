import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/features/authentication/models/recovery_type.dart';
import 'package:keebox/features/authentication/models/recovery_response.dart';
import 'package:keebox/features/authentication/models/recovery_requests.dart';
import 'package:keebox/features/authentication/recovery_api.dart';
import 'package:keebox/features/authentication/state/recovery_controller.dart';
import 'package:keebox/features/authentication/state/recovery_state.dart';
import 'package:keebox/network/api_client.dart';
import 'package:keebox/network/api_exception.dart';

const resetId = '12345678-1234-1234-1234-123456789abc';

void main() {
  late ProviderContainer container;
  late _API api;
  late DateTime now;
  late RecoveryScope scope;
  setUp(() {
    now = DateTime.utc(2030);
    api = _API(() => now);
    container = ProviderContainer(
      overrides: [
        recoveryApiProvider.overrideWithValue(api),
        recoveryClockProvider.overrideWithValue(() => now),
      ],
    );
    scope = (identity: Object(), type: RecoveryType.password);
    container.listen(recoveryControllerProvider(scope), (_, _) {});
  });
  tearDown(() {
    container.dispose();
    api.client.close();
  });
  RecoveryController controller() =>
      container.read(recoveryControllerProvider(scope).notifier);
  RecoveryState state() => container.read(recoveryControllerProvider(scope));
  Future<void> verified() async {
    await controller().start(' ada@example.com ');
    await controller().verifyOtp('001234');
  }

  for (final type in RecoveryType.values) {
    test('$type progresses from email through OTP to completion', () async {
      scope = (identity: Object(), type: type);
      container.listen(recoveryControllerProvider(scope), (_, _) {});
      expect(state().stage, RecoveryStage.email);
      await verified();
      expect(state().stage, RecoveryStage.credential);
      expect(state().email, 'ada@example.com');
      expect(state().resetId, resetId);
      expect(
        state().verified!.completionExpiresAt,
        now.add(const Duration(minutes: 10)),
      );
      if (type == RecoveryType.password) {
        await controller().completePassword(' password ');
      } else {
        await controller().completePin('00123');
      }
      expect(state().stage, RecoveryStage.completed);
      expect(state().isSubmitting, isFalse);
      expect(api.calls, [
        'start:$type',
        'verify:001234',
        type == RecoveryType.password ? 'password: password ' : 'pin:00123',
      ]);
    });
  }
  test('resend enforces cooldown and replaces server timing without changing challenge ID', () async {
    await controller().start('ada@example.com');
    await controller().resendOtp();
    expect(api.calls, hasLength(1));
    now = now.add(const Duration(seconds: 60));
    await controller().resendOtp();
    expect(api.calls.last, 'resend');
    expect(
      state().challenge!.resendAvailableAt,
      now.add(const Duration(seconds: 60)),
    );
    expect(state().resetId, resetId);
  });
  test(
    'OTP expiry requires restart even after background time elapses',
    () async {
      await controller().start('ada@example.com');
      now = now.add(const Duration(minutes: 5));
      await controller().verifyOtp('123456');
      expect(state().stage, RecoveryStage.restartRequired);
      expect(api.calls, hasLength(1));
    },
  );
  test('completion expiry blocks submission at the exact deadline', () async {
    await verified();
    now = now.add(const Duration(minutes: 10));
    await controller().completePassword('password');
    expect(state().stage, RecoveryStage.restartRequired);
    expect(api.calls, hasLength(2));
  });
  test('wrong OTP preserves the challenge and permits correction', () async {
    await controller().start('ada@example.com');
    api.failure = const APIException(
      kind: APIErrorKind.api,
      code: 'invalid_otp',
      message: 'Incorrect code.',
      statusCode: 400,
    );
    await controller().verifyOtp('999999');
    expect(state().stage, RecoveryStage.otp);
    expect(state().errorMessage, 'Incorrect code.');
    api.failure = null;
    await controller().verifyOtp('001234');
    expect(state().stage, RecoveryStage.credential);
    expect(state().errorMessage, isNull);
  });
  for (final code in [
    'expired_otp',
    'locked_otp',
    'otp_resend_limit_reached',
    'invalid_reset_challenge',
    'consumed_otp',
    'expired_reset_challenge',
  ]) {
    test('$code requires restarting the flow', () async {
      await controller().start('ada@example.com');
      api.failure = APIException(
        kind: APIErrorKind.api,
        code: code,
        message: 'Restart recovery.',
      );
      await controller().verifyOtp('123456');
      expect(state().stage, RecoveryStage.restartRequired);
      expect(state().errorCode, code);
    });
  }
  test('backend field validation remains available without discarding the completion window', () async {
    await verified();
    api.failure = const APIException(
      kind: APIErrorKind.api,
      code: 'validation_error',
      message: 'Invalid data.',
      details: [
        {
          'location': ['body', 'new_password'],
          'message': 'Too common',
        },
      ],
      statusCode: 422,
    );
    await controller().completePassword('password');
    expect(state().stage, RecoveryStage.credential);
    expect(state().errorDetails, isA<List>());
    expect(state().isSubmitting, isFalse);
  });
  test('completion timeout is uncertain and cannot be automatically or accidentally resubmitted', () async {
    await verified();
    api.failure = const APIException(
      kind: APIErrorKind.timeout,
      message: 'Timeout',
    );
    await controller().completePassword('password');
    expect(state().stage, RecoveryStage.completionUncertain);
    expect(state().errorMessage, AppTexts.recoveryCompletionUncertain);
    await controller().completePassword('password');
    expect(api.calls, hasLength(3));
  });
  test('start network failure keeps email and allows explicit retry', () async {
    api.failure = const APIException(
      kind: APIErrorKind.connection,
      message: 'Offline',
    );
    await controller().start('ada@example.com');
    expect(state().stage, RecoveryStage.email);
    expect(state().email, 'ada@example.com');
    api.failure = null;
    await controller().start('ada@example.com');
    expect(state().stage, RecoveryStage.otp);
  });
  test(
    'duplicate verification and concurrent resend are ignored while busy',
    () async {
      await controller().start('ada@example.com');
      now = now.add(const Duration(seconds: 60));
      api.verifyGate = Completer<RecoveryVerified>();
      final pending = controller().verifyOtp('123456');
      expect(state().operation, RecoveryOperation.verify);
      await controller().verifyOtp('999999');
      await controller().resendOtp();
      expect(api.calls, hasLength(2));
      api.verifyGate!.complete(api.verified());
      await pending;
    },
  );
  test('restart cancels in-flight work and rejects its late result', () async {
    api.startGate = Completer<RecoveryChallenge>();
    final pending = controller().start('ada@example.com');
    final token = api.lastToken!;
    controller().restart();
    expect(token.isCancelled, isTrue);
    api.startGate!.complete(api.challenge());
    await pending;
    expect(state().stage, RecoveryStage.email);
    expect(state().resetId, isNull);
  });
  test('disposal cancels requests and late completion cannot change a fresh controller', () async {
    api.startGate = Completer<RecoveryChallenge>();
    final pending = controller().start('ada@example.com');
    final token = api.lastToken!;
    container.invalidate(recoveryControllerProvider(scope));
    api.startGate!.complete(api.challenge());
    await pending;
    expect(token.isCancelled, isTrue);
    expect(state().stage, RecoveryStage.email);
  });
  test('unexpected response challenge ID cannot advance recovery', () async {
    await controller().start('ada@example.com');
    api.wrongId = true;
    await controller().verifyOtp('123456');
    expect(state().stage, RecoveryStage.restartRequired);
  });
  test(
    'local format and wrong-stage submissions never reach the API',
    () async {
      await controller().verifyOtp('001234');
      await controller().completePassword('password');
      expect(api.calls, isEmpty);
      await controller().start('ada@example.com');
      await controller().verifyOtp('12345');
      expect(api.calls, hasLength(1));
      await controller().verifyOtp('001234');
      await controller().completePin('00123');
      await controller().completePassword('');
      expect(api.calls, hasLength(2));
    },
  );
}

class _API extends RecoveryAPI {
  _API(this.now) : super(client: APIClient());
  final DateTime Function() now;
  final calls = <String>[];
  APIException? failure;
  bool wrongId = false;
  CancelToken? lastToken;
  Completer<RecoveryChallenge>? startGate;
  Completer<RecoveryVerified>? verifyGate;
  RecoveryChallenge challenge() => RecoveryChallenge(
    resetId: resetId,
    otpExpiresAt: now().add(const Duration(minutes: 5)),
    resendAvailableAt: now().add(const Duration(seconds: 60)),
    message: 'Generic response',
  );
  RecoveryVerified verified() => RecoveryVerified(
    resetId: wrongId ? 'other' : resetId,
    completionExpiresAt: now().add(const Duration(minutes: 10)),
    message: 'Verified',
  );
  void check(CancelToken? token, String call) {
    lastToken = token;
    calls.add(call);
    if (failure != null) throw failure!;
  }

  @override
  Future<RecoveryChallenge> start(
    RecoveryType type,
    RecoveryStartRequest request, {
    CancelToken? cancelToken,
  }) async {
    check(cancelToken, 'start:$type');
    return startGate == null ? challenge() : await startGate!.future;
  }

  @override
  Future<RecoveryChallenge> resendOtp(
    RecoveryResendRequest request, {
    CancelToken? cancelToken,
  }) async {
    check(cancelToken, 'resend');
    return challenge();
  }

  @override
  Future<RecoveryVerified> verifyOtp(
    RecoveryVerifyRequest request, {
    CancelToken? cancelToken,
  }) async {
    check(cancelToken, 'verify:${request.otpCode}');
    return verifyGate == null ? verified() : await verifyGate!.future;
  }

  @override
  Future<RecoveryCompleted> completePassword(
    PasswordResetRequest request, {
    CancelToken? cancelToken,
  }) async {
    check(cancelToken, 'password:${request.newPassword}');
    return RecoveryCompleted(resetId: resetId, message: 'Done');
  }

  @override
  Future<RecoveryCompleted> completePin(
    PinResetRequest request, {
    CancelToken? cancelToken,
  }) async {
    check(cancelToken, 'pin:${request.newPin}');
    return RecoveryCompleted(resetId: resetId, message: 'Done');
  }
}
