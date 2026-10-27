import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:keebox/app/app_texts.dart';
import 'package:keebox/features/authentication/models/recovery_type.dart';
import 'package:keebox/features/authentication/models/recovery_response.dart';
import 'package:keebox/features/authentication/models/recovery_requests.dart';
import 'package:keebox/features/authentication/recovery_api.dart';
import 'package:keebox/features/authentication/state/recovery_clock.dart';
import 'package:keebox/features/authentication/state/recovery_state.dart';
import 'package:keebox/network/api_exception.dart';

export 'package:keebox/features/authentication/state/recovery_clock.dart'
    show recoveryClockProvider;

typedef RecoveryScope = ({Object identity, RecoveryType type});

final recoveryControllerProvider = NotifierProvider.autoDispose
    .family<RecoveryController, RecoveryState, RecoveryScope>(
      (scope) => RecoveryController(scope.type),
    );

class RecoveryController extends Notifier<RecoveryState> {
  RecoveryController(this.type);
  final RecoveryType type;
  CancelToken? _request;

  @override
  RecoveryState build() {
    ref.onDispose(() => _request?.cancel());
    return RecoveryState(type: type);
  }

  void restart() {
    _request?.cancel();
    _request = null;
    state = RecoveryState(
      type: type,
      feedbackRevision: state.feedbackRevision + 1,
    );
  }

  DateTime get _now => ref.read(recoveryClockProvider)();

  bool get canResend =>
      state.stage == RecoveryStage.otp &&
      !state.isSubmitting &&
      state.challenge!.otpExpiresAt.isAfter(_now) &&
      !state.challenge!.resendAvailableAt.isAfter(_now);

  void checkDeadlines() {
    if (state.isSubmitting) return;
    if (state.stage == RecoveryStage.otp &&
        !state.challenge!.otpExpiresAt.isAfter(_now)) {
      _emit(
        stage: RecoveryStage.restartRequired,
        errorMessage: AppTexts.recoveryOtpExpired,
      );
    } else if (state.stage == RecoveryStage.credential &&
        !state.verified!.completionExpiresAt.isAfter(_now)) {
      _emit(
        stage: RecoveryStage.restartRequired,
        errorMessage: AppTexts.recoveryCompletionExpired,
      );
    }
  }

  bool _ready(RecoveryStage stage) {
    if (state.isSubmitting || state.stage != stage) return false;
    checkDeadlines();
    return state.stage == stage;
  }

  bool _validate(void Function() action, String message) {
    try {
      action();
      return true;
    } on FormatException {
      _emit(errorMessage: message);
      return false;
    }
  }

  void _requireId(String id) {
    if (id != state.resetId) {
      throw const FormatException('Recovery challenge mismatch.');
    }
  }

  void _emit({
    RecoveryStage? stage,
    String? email,
    RecoveryChallenge? challenge,
    RecoveryVerified? verified,
    RecoveryCompleted? completed,
    RecoveryOperation? operation,
    String? errorMessage,
    String? errorCode,
    Object? errorDetails,
  }) {
    state = RecoveryState(
      type: type,
      stage: stage ?? state.stage,
      email: email ?? state.email,
      challenge: challenge ?? state.challenge,
      verified: verified ?? state.verified,
      completed: completed ?? state.completed,
      operation: operation,
      errorMessage: errorMessage,
      errorCode: errorCode,
      errorDetails: errorDetails,
      feedbackRevision: state.feedbackRevision + 1,
    );
  }

  Future<void> _perform<T>(
    RecoveryOperation operation,
    Future<T> Function(CancelToken) request,
    void Function(T) accept,
  ) async {
    final token = CancelToken();
    _request = token;
    _emit(operation: operation);
    bool active() =>
        ref.mounted && identical(_request, token) && !token.isCancelled;
    try {
      final result = await request(token);
      if (active()) accept(result);
    } on APIException catch (error) {
      if (!active()) return;
      final uncertain =
          operation == RecoveryOperation.complete &&
          (error.kind != APIErrorKind.api || (error.statusCode ?? 0) >= 500);
      final terminal =
          const {
            'expired_otp',
            'locked_otp',
            'consumed_otp',
            'otp_resend_limit_reached',
            'invalid_reset_challenge',
            'expired_reset_challenge',
          }.contains(error.code) ||
          error.kind == APIErrorKind.invalidResponse;
      _emit(
        stage: uncertain
            ? RecoveryStage.completionUncertain
            : terminal
            ? RecoveryStage.restartRequired
            : null,
        errorMessage: uncertain
            ? AppTexts.recoveryCompletionUncertain
            : error.message.trim().isEmpty
            ? AppTexts.recoveryFailed
            : error.message,
        errorCode: error.code,
        errorDetails: error.details,
      );
    } catch (_) {
      if (!active()) return;
      _emit(
        stage: operation == RecoveryOperation.complete
            ? RecoveryStage.completionUncertain
            : RecoveryStage.restartRequired,
        errorMessage: operation == RecoveryOperation.complete
            ? AppTexts.recoveryCompletionUncertain
            : AppTexts.recoveryResponseInvalid,
      );
    } finally {
      if (identical(_request, token)) _request = null;
    }
  }

  Future<void> start(String email) async {
    if (!_ready(RecoveryStage.email)) return;
    final request = RecoveryStartRequest(email: email);
    if (!_validate(() {
      request.toJson();
    }, AppTexts.recoveryEmailRequired)) {
      return;
    }
    _emit(email: email.trim());
    await _perform(
      RecoveryOperation.start,
      (token) => ref
          .read(recoveryApiProvider)
          .start(type, request, cancelToken: token),
      (result) => _emit(stage: RecoveryStage.otp, challenge: result),
    );
  }

  Future<void> resendOtp() async {
    if (!_ready(RecoveryStage.otp)) return;
    if (!canResend) {
      _emit(errorMessage: AppTexts.recoveryResendUnavailable);
      return;
    }
    await _perform(
      RecoveryOperation.resend,
      (token) => ref
          .read(recoveryApiProvider)
          .resendOtp(
            RecoveryResendRequest(resetId: state.resetId!),
            cancelToken: token,
          ),
      (result) {
        _requireId(result.resetId);
        _emit(challenge: result);
      },
    );
  }

  Future<void> verifyOtp(String code) async {
    if (!_ready(RecoveryStage.otp)) return;
    final request = RecoveryVerifyRequest(
      resetId: state.resetId!,
      otpCode: code,
    );
    if (!_validate(() {
      request.toJson();
    }, AppTexts.recoveryOtpInvalid)) {
      return;
    }
    await _perform(
      RecoveryOperation.verify,
      (token) =>
          ref.read(recoveryApiProvider).verifyOtp(request, cancelToken: token),
      (result) {
        _requireId(result.resetId);
        _emit(stage: RecoveryStage.credential, verified: result);
      },
    );
  }

  Future<void> completePassword(String password) async {
    if (type != RecoveryType.password || !_ready(RecoveryStage.credential)) {
      return;
    }
    final request = PasswordResetRequest(
      resetId: state.resetId!,
      newPassword: password,
    );
    if (!_validate(() {
      request.toJson();
    }, AppTexts.recoveryPasswordRequired)) {
      return;
    }
    await _perform(
      RecoveryOperation.complete,
      (token) => ref
          .read(recoveryApiProvider)
          .completePassword(request, cancelToken: token),
      (result) {
        _requireId(result.resetId);
        _emit(stage: RecoveryStage.completed, completed: result);
      },
    );
  }

  Future<void> completePin(String pin) async {
    if (type != RecoveryType.pin || !_ready(RecoveryStage.credential)) return;
    final request = PinResetRequest(resetId: state.resetId!, newPin: pin);
    if (!_validate(() {
      request.toJson();
    }, AppTexts.recoveryPinInvalid)) {
      return;
    }
    await _perform(
      RecoveryOperation.complete,
      (token) => ref
          .read(recoveryApiProvider)
          .completePin(request, cancelToken: token),
      (result) {
        _requireId(result.resetId);
        _emit(stage: RecoveryStage.completed, completed: result);
      },
    );
  }
}
