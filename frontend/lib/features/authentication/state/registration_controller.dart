import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/features/authentication/models/authentication_result.dart';
import 'package:keebox/features/authentication/models/registration_requests.dart';
import 'package:keebox/features/authentication/models/registration_response.dart';
import 'package:keebox/features/authentication/registration_api.dart';
import 'package:keebox/features/authentication/state/registration_clock.dart';
import 'package:keebox/features/authentication/state/registration_state.dart';
import 'package:keebox/network/api_exception.dart';

final registrationControllerProvider = NotifierProvider.autoDispose
    .family<RegistrationController, RegistrationState, Object>(
      (scope) => RegistrationController(),
    );

class RegistrationController extends Notifier<RegistrationState> {
  CancelToken? _request;

  @override
  RegistrationState build() {
    ref.onDispose(() => _request?.cancel());
    return const RegistrationState();
  }

  DateTime get _now => ref.read(registrationClockProvider)();

  bool get canVerify =>
      state.stage == RegistrationStage.otp &&
      !state.isSubmitting &&
      !state.otpUnavailable &&
      state.challenge!.expiresAt.isAfter(_now) &&
      state.challenge!.otpExpiresAt.isAfter(_now);

  bool get canResend =>
      state.stage == RegistrationStage.otp &&
      !state.isSubmitting &&
      state.resendsRemaining != 0 &&
      state.challenge!.expiresAt.isAfter(_now) &&
      !state.challenge!.resendAvailableAt.isAfter(_now);

  void restart() {
    _request?.cancel();
    _request = null;
    state = RegistrationState(feedbackRevision: state.feedbackRevision + 1);
  }

  void checkDeadlines() {
    if (state.isSubmitting ||
        !const {
          RegistrationStage.otp,
          RegistrationStage.pin,
        }.contains(state.stage)) {
      return;
    }
    if (!state.challenge!.expiresAt.isAfter(_now)) {
      _emit(
        stage: RegistrationStage.restartRequired,
        errorMessage: AppTexts.registrationExpired,
      );
    } else if (state.stage == RegistrationStage.otp) {
      final unavailable =
          state.otpUnavailable || !state.challenge!.otpExpiresAt.isAfter(_now);
      if (unavailable && state.resendsRemaining == 0) {
        _emit(
          stage: RegistrationStage.restartRequired,
          errorMessage: AppTexts.registrationResendsExhausted,
        );
      } else if (unavailable && !state.otpUnavailable) {
        _emit(
          otpUnavailable: true,
          errorMessage: AppTexts.registrationOtpExpired,
        );
      }
    }
  }

  bool _ready(RegistrationStage stage) {
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
    if (id != state.registrationId) {
      throw const FormatException('Registration challenge mismatch.');
    }
  }

  void _emit({
    RegistrationStage? stage,
    String? firstName,
    String? lastName,
    String? email,
    RegistrationChallenge? challenge,
    RegistrationVerified? verified,
    AuthenticationResult? completed,
    int? resendsRemaining,
    bool? otpUnavailable,
    int? otpRevision,
    RegistrationOperation? operation,
    String? errorMessage,
    String? errorCode,
    Object? errorDetails,
  }) {
    state = RegistrationState(
      stage: stage ?? state.stage,
      firstName: firstName ?? state.firstName,
      lastName: lastName ?? state.lastName,
      email: email ?? state.email,
      challenge: challenge ?? state.challenge,
      verified: verified ?? state.verified,
      completed: completed ?? state.completed,
      resendsRemaining: resendsRemaining ?? state.resendsRemaining,
      otpUnavailable: otpUnavailable ?? state.otpUnavailable,
      otpRevision: otpRevision ?? state.otpRevision,
      operation: operation,
      errorMessage: errorMessage,
      errorCode: errorCode,
      errorDetails: errorDetails,
      feedbackRevision: state.feedbackRevision + 1,
    );
  }

  Future<void> _perform<T>(
    RegistrationOperation operation,
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
          operation == RegistrationOperation.complete &&
          (error.kind != APIErrorKind.api || (error.statusCode ?? 0) >= 500);
      final terminal =
          const {
            'invalid_registration_state',
            'otp_resend_limit_reached',
            'consumed_otp',
          }.contains(error.code) ||
          error.kind == APIErrorKind.invalidResponse;
      final otpUnavailable =
          operation == RegistrationOperation.verify &&
          const {'expired_otp', 'locked_otp'}.contains(error.code);
      _emit(
        stage: uncertain
            ? RegistrationStage.completionUncertain
            : terminal || (otpUnavailable && state.resendsRemaining == 0)
            ? RegistrationStage.restartRequired
            : null,
        otpUnavailable: otpUnavailable ? true : null,
        errorMessage: uncertain
            ? AppTexts.registrationCompletionUncertain
            : error.message.trim().isEmpty
            ? AppTexts.registrationFailed
            : error.message,
        errorCode: error.code,
        errorDetails: error.details,
      );
    } catch (_) {
      if (!active()) return;
      final completing = operation == RegistrationOperation.complete;
      _emit(
        stage: completing
            ? RegistrationStage.completionUncertain
            : RegistrationStage.restartRequired,
        errorMessage: completing
            ? AppTexts.registrationCompletionUncertain
            : AppTexts.registrationResponseInvalid,
      );
    } finally {
      if (identical(_request, token)) _request = null;
    }
  }

  Future<void> start(RegistrationRequest request) async {
    if (!_ready(RegistrationStage.form)) return;
    if (!_validate(() {
      request.toJson();
    }, AppTexts.registrationDetailsInvalid)) {
      return;
    }
    _emit(
      firstName: request.firstName.trim(),
      lastName: request.lastName.trim(),
      email: request.email.trim(),
    );
    await _perform(
      RegistrationOperation.start,
      (token) =>
          ref.read(registrationApiProvider).start(request, cancelToken: token),
      (result) => _emit(stage: RegistrationStage.otp, challenge: result),
    );
  }

  Future<void> verifyOtp(String code) async {
    if (!_ready(RegistrationStage.otp) || !canVerify) return;
    final request = RegistrationVerifyRequest(
      registrationId: state.registrationId!,
      otpCode: code,
    );
    if (!_validate(() {
      request.toJson();
    }, AppTexts.registrationOtpInvalid)) {
      return;
    }
    await _perform(
      RegistrationOperation.verify,
      (token) => ref
          .read(registrationApiProvider)
          .verifyOtp(request, cancelToken: token),
      (result) {
        _requireId(result.registrationId);
        _emit(stage: RegistrationStage.pin, verified: result);
      },
    );
  }

  Future<void> resendOtp() async {
    if (!_ready(RegistrationStage.otp)) return;
    if (!canResend) {
      _emit(
        errorMessage: state.resendsRemaining == 0
            ? AppTexts.registrationResendsExhausted
            : AppTexts.registrationResendUnavailable,
      );
      return;
    }
    await _perform(
      RegistrationOperation.resend,
      (token) => ref
          .read(registrationApiProvider)
          .resendOtp(
            RegistrationResendRequest(registrationId: state.registrationId!),
            cancelToken: token,
          ),
      (result) {
        _requireId(result.registrationId);
        _emit(
          challenge: RegistrationChallenge(
            registrationId: result.registrationId,
            expiresAt: state.challenge!.expiresAt,
            otpExpiresAt: result.otpExpiresAt,
            resendAvailableAt: result.resendAvailableAt,
            message: result.message,
          ),
          resendsRemaining: result.resendsRemaining,
          otpUnavailable: false,
          otpRevision: state.otpRevision + 1,
        );
      },
    );
  }

  Future<void> complete(String pin) async {
    if (!_ready(RegistrationStage.pin)) return;
    final request = RegistrationCompletionRequest(
      registrationId: state.registrationId!,
      pin: pin,
    );
    if (!_validate(() {
      request.toJson();
    }, AppTexts.registrationPinInvalid)) {
      return;
    }
    await _perform(
      RegistrationOperation.complete,
      (token) => ref
          .read(registrationApiProvider)
          .complete(request, cancelToken: token),
      (result) => _emit(stage: RegistrationStage.completed, completed: result),
    );
  }
}
