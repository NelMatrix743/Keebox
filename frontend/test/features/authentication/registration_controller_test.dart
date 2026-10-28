import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/features/authentication/models/authenticated_user.dart';
import 'package:keebox/features/authentication/models/authentication_result.dart';
import 'package:keebox/features/authentication/models/authentication_session.dart';
import 'package:keebox/features/authentication/models/registration_requests.dart';
import 'package:keebox/features/authentication/models/registration_response.dart';
import 'package:keebox/features/authentication/registration_api.dart';
import 'package:keebox/features/authentication/state/registration_clock.dart';
import 'package:keebox/features/authentication/state/registration_controller.dart';
import 'package:keebox/features/authentication/state/registration_state.dart';
import 'package:keebox/network/api_client.dart';
import 'package:keebox/network/api_exception.dart';
import 'package:keebox/network/api_session.dart';

const _id = '12345678-1234-1234-1234-123456789abc';
const _request = RegistrationRequest(
  firstName: ' Ada ',
  lastName: ' Lovelace ',
  email: ' ada@example.com ',
  password: ' password ',
);

void main() {
  late ProviderContainer container;
  late _API api;
  late DateTime now;
  late Object scope;
  setUp(() {
    now = DateTime.utc(2030);
    api = _API(() => now);
    container = ProviderContainer(
      overrides: [
        registrationApiProvider.overrideWithValue(api),
        registrationClockProvider.overrideWithValue(() => now),
      ],
    );
    scope = Object();
    container.listen(registrationControllerProvider(scope), (_, _) {});
  });
  tearDown(() {
    container.dispose();
    api.client.close();
  });
  RegistrationController controller() =>
      container.read(registrationControllerProvider(scope).notifier);
  RegistrationState state() =>
      container.read(registrationControllerProvider(scope));
  Future<void> verified() async {
    await controller().start(_request);
    await controller().verifyOtp('001234');
  }

  test(
    'form to OTP to PIN to account completion without establishing a session',
    () async {
      expect(state().stage, RegistrationStage.form);
      await controller().start(_request);
      expect(state().stage, RegistrationStage.otp);
      expect(state().email, 'ada@example.com');
      expect(state().firstName, 'Ada');
      expect(state().lastName, 'Lovelace');
      expect(state().registrationId, _id);
      await controller().verifyOtp('001234');
      expect(state().stage, RegistrationStage.pin);
      await controller().complete('00123');
      expect(state().stage, RegistrationStage.completed);
      expect(state().completed!.user.kbkey, 'permanent-key');
      expect(state().completed!.session.accessToken, 'access');
      expect(container.read(apiSessionProvider).accessToken, isNull);
      expect(api.calls, ['start', 'verify:001234', 'complete:00123']);
      expect(state().isSubmitting, isFalse);
      await controller().complete('00123');
      expect(api.calls, hasLength(3));
    },
  );
  test('independent scopes cannot share registration challenges', () async {
    await controller().start(_request);
    final other = container.listen(
      registrationControllerProvider(Object()),
      (_, _) {},
    );
    expect(other.read().stage, RegistrationStage.form);
    expect(other.read().registrationId, isNull);
    other.close();
  });
  test(
    'local validation and wrong-stage actions never reach the API',
    () async {
      await controller().verifyOtp('001234');
      await controller().resendOtp();
      await controller().complete('00123');
      await controller().start(
        const RegistrationRequest(
          firstName: '',
          lastName: 'L',
          email: 'a@b.com',
          password: 'password',
        ),
      );
      expect(state().errorMessage, AppTexts.registrationDetailsInvalid);
      expect(api.calls, isEmpty);
      await controller().start(_request);
      await controller().verifyOtp('12345');
      expect(state().errorMessage, AppTexts.registrationOtpInvalid);
      expect(api.calls, hasLength(1));
      await controller().verifyOtp('001234');
      await controller().complete('1234');
      expect(state().errorMessage, AppTexts.registrationPinInvalid);
      expect(api.calls, hasLength(2));
    },
  );
  test(
    'resend enforces cooldown and preserves the original registration deadline',
    () async {
      await controller().start(_request);
      final expiresAt = state().challenge!.expiresAt;
      await controller().resendOtp();
      expect(api.calls, hasLength(1));
      now = now.add(const Duration(seconds: 60));
      expect(controller().canResend, isTrue);
      await controller().resendOtp();
      expect(state().challenge!.expiresAt, expiresAt);
      expect(
        state().challenge!.otpExpiresAt,
        now.add(const Duration(minutes: 5)),
      );
      expect(
        state().challenge!.resendAvailableAt,
        now.add(const Duration(seconds: 60)),
      );
      expect(state().resendsRemaining, 2);
      expect(state().otpRevision, 1);
      expect(controller().canResend, isFalse);
    },
  );
  test('OTP expiry blocks verification but allows replacement while registration is active', () async {
    await controller().start(_request);
    now = now.add(const Duration(minutes: 5));
    await controller().verifyOtp('001234');
    expect(state().stage, RegistrationStage.otp);
    expect(controller().canVerify, isFalse);
    expect(controller().canResend, isTrue);
    expect(api.calls, hasLength(1));
    await controller().resendOtp();
    expect(controller().canVerify, isTrue);
    expect(state().errorMessage, isNull);
  });
  test('last resend still permits verification, but expired final OTP requires restart', () async {
    await controller().start(_request);
    now = now.add(const Duration(seconds: 60));
    api.remaining = 0;
    await controller().resendOtp();
    expect(controller().canResend, isFalse);
    expect(controller().canVerify, isTrue);
    await controller().resendOtp();
    expect(state().stage, RegistrationStage.otp);
    expect(api.calls, hasLength(2));
    now = now.add(const Duration(minutes: 5));
    controller().checkDeadlines();
    expect(state().stage, RegistrationStage.restartRequired);
  });
  test('zero remaining resends still allows the latest OTP to advance to PIN setup', () async {
    await controller().start(_request);
    now = now.add(const Duration(seconds: 60));
    api.remaining = 0;
    await controller().resendOtp();
    await controller().verifyOtp('001234');
    expect(state().stage, RegistrationStage.pin);
    expect(api.calls.last, 'verify:001234');
  });
  test('empty backend feedback uses the centralized fallback', () async {
    api.failure = const APIException(
      kind: APIErrorKind.api,
      message: ' ',
      statusCode: 400,
    );
    await controller().start(_request);
    expect(state().errorMessage, AppTexts.registrationFailed);
  });
  test('deadline checks do not override an in-flight response accepted by the backend', () async {
    await verified();
    api.gate = Completer<void>();
    final pending = controller().complete('00123');
    now = state().challenge!.expiresAt;
    controller().checkDeadlines();
    expect(state().operation, RegistrationOperation.complete);
    api.gate!.complete();
    await pending;
    expect(state().stage, RegistrationStage.completed);
  });
  for (final stage in ['otp', 'pin']) {
    test('registration expires at the exact deadline during $stage', () async {
      if (stage == 'pin') {
        await verified();
      } else {
        await controller().start(_request);
      }
      now = state().challenge!.expiresAt;
      controller().checkDeadlines();
      expect(state().stage, RegistrationStage.restartRequired);
      expect(state().errorMessage, AppTexts.registrationExpired);
      await controller().complete('00123');
      await controller().resendOtp();
      expect(api.calls, hasLength(stage == 'pin' ? 2 : 1));
    });
  }
  test('OTP deadline stops applying once email is verified', () async {
    await verified();
    now = now.add(const Duration(minutes: 5));
    controller().checkDeadlines();
    expect(state().stage, RegistrationStage.pin);
    await controller().complete('00123');
    expect(state().stage, RegistrationStage.completed);
  });
  test('incorrect OTP and backend field errors preserve the active stage and allow correction', () async {
    await controller().start(_request);
    api.failure = const APIException(
      kind: APIErrorKind.api,
      code: 'invalid_otp',
      message: 'Incorrect.',
      statusCode: 400,
      details: {
        'otp_code': ['Incorrect'],
      },
    );
    await controller().verifyOtp('999999');
    expect(state().stage, RegistrationStage.otp);
    expect(state().errorCode, 'invalid_otp');
    expect(state().errorDetails, {
      'otp_code': ['Incorrect'],
    });
    final revision = state().feedbackRevision;
    await controller().verifyOtp('999999');
    expect(state().feedbackRevision, greaterThan(revision));
    api.failure = null;
    await controller().verifyOtp('001234');
    expect(state().errorMessage, isNull);
    api.failure = const APIException(
      kind: APIErrorKind.api,
      code: 'validation_error',
      message: 'Invalid PIN.',
      statusCode: 422,
    );
    await controller().complete('00123');
    expect(state().stage, RegistrationStage.pin);
    api.failure = null;
    await controller().complete('00123');
    expect(state().stage, RegistrationStage.completed);
  });
  for (final code in ['expired_otp', 'locked_otp']) {
    test('$code disables the current OTP and still permits resend', () async {
      await controller().start(_request);
      now = now.add(const Duration(seconds: 60));
      api.failure = APIException(
        kind: APIErrorKind.api,
        code: code,
        message: 'Replace the code.',
        statusCode: 400,
      );
      await controller().verifyOtp('001234');
      expect(state().stage, RegistrationStage.otp);
      expect(controller().canVerify, isFalse);
      expect(controller().canResend, isTrue);
      api.failure = null;
      await controller().resendOtp();
      expect(controller().canVerify, isTrue);
    });
  }
  for (final code in [
    'invalid_registration_state',
    'otp_resend_limit_reached',
    'consumed_otp',
  ]) {
    test('$code requires restarting registration', () async {
      await controller().start(_request);
      api.failure = APIException(
        kind: APIErrorKind.api,
        code: code,
        message: 'Restart.',
        statusCode: 409,
      );
      await controller().verifyOtp('001234');
      expect(state().stage, RegistrationStage.restartRequired);
      expect(state().errorCode, code);
    });
  }
  for (final code in ['otp_resend_cooldown', 'email_delivery_failed']) {
    test(
      '$code preserves the last known OTP timing and resend allowance',
      () async {
        await controller().start(_request);
        now = now.add(const Duration(seconds: 60));
        final before = state().challenge;
        api.failure = APIException(
          kind: APIErrorKind.api,
          code: code,
          message: 'Retry later.',
          statusCode: 429,
        );
        await controller().resendOtp();
        expect(state().stage, RegistrationStage.otp);
        expect(state().challenge, same(before));
        expect(state().resendsRemaining, isNull);
      },
    );
  }
  test('email conflict and network failure retain identity details for a manual retry', () async {
    for (final failure in [
      const APIException(kind: APIErrorKind.connection, message: 'Offline'),
      const APIException(
        kind: APIErrorKind.api,
        code: 'registration_email_conflict',
        message: 'Already exists.',
        statusCode: 409,
      ),
    ]) {
      api.failure = failure;
      await controller().start(_request);
      expect(state().stage, RegistrationStage.form);
      expect(state().email, 'ada@example.com');
    }
    api.failure = null;
    await controller().start(_request);
    expect(state().stage, RegistrationStage.otp);
    expect(api.calls, hasLength(3));
  });
  for (final failure in [
    const APIException(kind: APIErrorKind.timeout, message: 'Timeout'),
    const APIException(kind: APIErrorKind.connection, message: 'Offline'),
    const APIException(
      kind: APIErrorKind.invalidResponse,
      message: 'Bad response',
    ),
    const APIException(
      kind: APIErrorKind.api,
      statusCode: 500,
      message: 'Internal error',
    ),
  ]) {
    test(
      'completion failure ${failure.kind}/${failure.statusCode} blocks resubmission',
      () async {
        await verified();
        api.failure = failure;
        await controller().complete('00123');
        expect(state().stage, RegistrationStage.completionUncertain);
        expect(state().errorMessage, AppTexts.registrationCompletionUncertain);
        expect(state().completed, isNull);
        await controller().complete('00123');
        expect(api.calls, hasLength(3));
      },
    );
  }
  test(
    'unexpected exception is safe and does not expose exception details',
    () async {
      api.unexpected = true;
      await controller().start(_request);
      expect(state().errorMessage, AppTexts.registrationResponseInvalid);
      expect(state().stage, RegistrationStage.restartRequired);
    },
  );
  for (final operation in RegistrationOperation.values) {
    test('$operation ignores duplicate and concurrent submissions', () async {
      if (operation == RegistrationOperation.complete) {
        await verified();
      } else if (operation != RegistrationOperation.start) {
        await controller().start(_request);
        now = now.add(const Duration(seconds: 60));
      }
      api.gate = Completer<void>();
      final pending = switch (operation) {
        RegistrationOperation.start => controller().start(_request),
        RegistrationOperation.resend => controller().resendOtp(),
        RegistrationOperation.verify => controller().verifyOtp('001234'),
        RegistrationOperation.complete => controller().complete('00123'),
      };
      expect(state().operation, operation);
      final count = api.calls.length;
      await controller().start(_request);
      await controller().verifyOtp('001234');
      await controller().resendOtp();
      await controller().complete('00123');
      expect(api.calls, hasLength(count));
      api.gate!.complete();
      await pending;
      expect(state().isSubmitting, isFalse);
    });
  }
  test('restart cancels a request and ignores a late result without clobbering a new flow', () async {
    api.gate = Completer<void>();
    final pending = controller().start(_request);
    final token = api.lastToken!;
    final gate = api.gate!;
    controller().restart();
    expect(token.isCancelled, isTrue);
    expect(state().email, isEmpty);
    api.gate = null;
    await controller().start(_request);
    final activeChallenge = state().challenge;
    gate.complete();
    await pending;
    expect(state().challenge, same(activeChallenge));
    expect(state().stage, RegistrationStage.otp);
  });
  test(
    'disposal cancels pending completion and ignores late credentials',
    () async {
      await verified();
      api.gate = Completer<void>();
      final pending = controller().complete('00123');
      final token = api.lastToken!;
      container.invalidate(registrationControllerProvider(scope));
      api.gate!.complete();
      await pending;
      expect(token.isCancelled, isTrue);
      expect(state().stage, RegistrationStage.form);
      expect(state().completed, isNull);
    },
  );
  for (final operation in ['verify', 'resend']) {
    test(
      'mismatched $operation response cannot advance the challenge',
      () async {
        await controller().start(_request);
        api.wrongId = true;
        now = now.add(const Duration(seconds: 60));
        if (operation == 'verify') {
          await controller().verifyOtp('001234');
        } else {
          await controller().resendOtp();
        }
        expect(state().stage, RegistrationStage.restartRequired);
      },
    );
  }
}

class _API extends RegistrationAPI {
  _API(this.now) : super(client: APIClient());
  final DateTime Function() now;
  final calls = <String>[];
  APIException? failure;
  bool unexpected = false;
  bool wrongId = false;
  int remaining = 2;
  CancelToken? lastToken;
  Completer<void>? gate;
  String get id => wrongId ? 'other' : _id;
  Future<void> check(CancelToken? token, String call) async {
    lastToken = token;
    calls.add(call);
    if (unexpected) throw StateError('secret internal details');
    if (failure != null) throw failure!;
    final pending = gate;
    if (pending != null) await pending.future;
  }

  @override
  Future<RegistrationChallenge> start(
    RegistrationRequest request, {
    CancelToken? cancelToken,
  }) async {
    await check(cancelToken, 'start');
    return RegistrationChallenge(
      registrationId: id,
      expiresAt: now().add(const Duration(minutes: 30)),
      otpExpiresAt: now().add(const Duration(minutes: 5)),
      resendAvailableAt: now().add(const Duration(seconds: 60)),
      message: 'Check email.',
    );
  }

  @override
  Future<RegistrationVerified> verifyOtp(
    RegistrationVerifyRequest request, {
    CancelToken? cancelToken,
  }) async {
    await check(cancelToken, 'verify:${request.otpCode}');
    return RegistrationVerified(registrationId: id, message: 'Create PIN.');
  }

  @override
  Future<RegistrationOtpResent> resendOtp(
    RegistrationResendRequest request, {
    CancelToken? cancelToken,
  }) async {
    await check(cancelToken, 'resend');
    return RegistrationOtpResent(
      registrationId: id,
      otpExpiresAt: now().add(const Duration(minutes: 5)),
      resendAvailableAt: now().add(const Duration(seconds: 60)),
      resendsRemaining: remaining,
      message: 'New code sent.',
    );
  }

  @override
  Future<AuthenticationResult> complete(
    RegistrationCompletionRequest request, {
    CancelToken? cancelToken,
  }) async {
    await check(cancelToken, 'complete:${request.pin}');
    return const AuthenticationResult(
      user: AuthenticatedUser(
        id: 'user-1',
        firstName: 'Ada',
        lastName: 'Lovelace',
        email: 'ada@example.com',
        kbkey: 'permanent-key',
      ),
      session: AuthenticationSession(
        userId: 'user-1',
        accessToken: 'access',
        refreshToken: 'refresh',
      ),
      message: 'Registered.',
    );
  }
}
