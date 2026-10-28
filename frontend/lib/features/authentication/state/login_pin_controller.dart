import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:keebox/app/app_texts.dart';
import 'package:keebox/features/authentication/authentication_api.dart';
import 'package:keebox/features/authentication/models/login_requests.dart';
import 'package:keebox/features/authentication/state/authentication_controller.dart';
import 'package:keebox/features/authentication/state/authentication_state.dart';
import 'package:keebox/features/authentication/state/login_pin_state.dart';
import 'package:keebox/network/api_exception.dart';

final loginPinControllerProvider = NotifierProvider.autoDispose
    .family<LoginPinController, LoginPinState, Object>(
      (_) => LoginPinController(),
    );

class LoginPinController extends Notifier<LoginPinState> {
  CancelToken? _request;
  String? _challengeId;
  bool _completing = false;

  @override
  LoginPinState build() {
    ref.onDispose(() => _request?.cancel());
    ref.listen(authenticationControllerProvider, (_, next) {
      final current = next.asData?.value;
      if (_request == null || _completing && current is AuthenticatedUnlocked) {
        return;
      }
      if (current is! AwaitingPin ||
          current.challenge.loginChallengeId != _challengeId) {
        _request?.cancel();
        state = const LoginPinState();
      }
    });
    return const LoginPinState();
  }

  Future<void> submit(String pin) async {
    if (state.isSubmitting ||
        state.isAuthenticated ||
        state.requiresLogin ||
        !RegExp(r'^[0-9]{5}$').hasMatch(pin)) {
      return;
    }
    final current = ref.read(authenticationControllerProvider).asData?.value;
    if (current is! AwaitingPin) {
      state = const LoginPinState(
        requiresLogin: true,
        errorMessage: AppTexts.loginChallengeExpired,
      );
      return;
    }
    final challenge = current.challenge;
    _challengeId = challenge.loginChallengeId;
    if (!challenge.expiresAt.isAfter(DateTime.now())) {
      await _restartLogin(
        challenge.loginChallengeId,
        AppTexts.loginChallengeExpired,
      );
      return;
    }
    final request = CancelToken();
    _request = request;
    state = const LoginPinState(isSubmitting: true);
    try {
      final result = await ref
          .read(authenticationApiProvider)
          .verifyPin(
            LoginPinRequest(
              loginChallengeId: challenge.loginChallengeId,
              pin: pin,
            ),
            cancelToken: request,
          );
      if (!_isActive(request, challenge.loginChallengeId)) return;
      _completing = true;
      try {
        await ref
            .read(authenticationControllerProvider.notifier)
            .completeAuthentication(
              result,
              loginChallengeId: challenge.loginChallengeId,
              verifiedPin: pin,
              isActive: () => _isActive(request, challenge.loginChallengeId),
            );
      } catch (_) {
        if (!ref.mounted || request.isCancelled) return;
        await _restartLogin(
          challenge.loginChallengeId,
          AppTexts.loginSessionSaveFailed,
        );
        return;
      } finally {
        _completing = false;
      }
      if (!ref.mounted || request.isCancelled) return;
      final authenticated = ref
          .read(authenticationControllerProvider)
          .asData
          ?.value;
      if (authenticated is AuthenticatedUnlocked &&
          authenticated.session.accessToken == result.session.accessToken) {
        state = const LoginPinState(isAuthenticated: true);
      }
    } on APIException catch (error) {
      if (!_isActive(request, challenge.loginChallengeId)) return;
      final message = error.message.trim().isEmpty
          ? AppTexts.pinVerificationFailed
          : error.message;
      if (const {
            'invalid_login_challenge',
            'expired_login_challenge',
            'login_account_locked',
            'login_pin_attempt_limit',
          }.contains(error.code) ||
          error.kind == APIErrorKind.invalidResponse) {
        await _restartLogin(challenge.loginChallengeId, message);
      } else {
        state = LoginPinState(errorMessage: message);
      }
    } catch (_) {
      if (!_isActive(request, challenge.loginChallengeId)) return;
      state = const LoginPinState(errorMessage: AppTexts.pinVerificationFailed);
    } finally {
      if (identical(_request, request)) _request = null;
    }
  }

  bool _isActive(CancelToken request, String challengeId) {
    if (!ref.mounted || request.isCancelled) return false;
    final current = ref.read(authenticationControllerProvider).asData?.value;
    return current is AwaitingPin &&
        current.challenge.loginChallengeId == challengeId;
  }

  Future<void> _restartLogin(String challengeId, String message) async {
    await ref
        .read(authenticationControllerProvider.notifier)
        .clearLoginChallenge(challengeId);
    if (!ref.mounted) return;
    state = LoginPinState(requiresLogin: true, errorMessage: message);
  }
}
