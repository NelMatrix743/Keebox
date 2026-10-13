import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:keebox/app/app_texts.dart';
import 'package:keebox/features/authentication/authentication_api.dart';
import 'package:keebox/features/authentication/models/login_request.dart';
import 'package:keebox/features/authentication/state/authentication_controller.dart';
import 'package:keebox/features/authentication/state/login_state.dart';
import 'package:keebox/network/api_exception.dart';

final loginControllerProvider = NotifierProvider.autoDispose
    .family<LoginController, LoginState, Object>((_) => LoginController());

class LoginController extends Notifier<LoginState> {
  CancelToken? _request;

  @override
  LoginState build() {
    ref.onDispose(() => _request?.cancel());
    return const LoginState();
  }

  Future<void> submit(String email, String password) async {
    if (state.isSubmitting) return;
    final request = CancelToken();
    _request = request;
    state = const LoginState(isSubmitting: true);
    try {
      final challenge = await ref
          .read(authenticationApiProvider)
          .login(
            LoginRequest(email: email.trim(), password: password),
            cancelToken: request,
          );
      if (!ref.mounted || request.isCancelled) return;
      await ref
          .read(authenticationControllerProvider.notifier)
          .setLoginChallenge(challenge);
      if (!ref.mounted || request.isCancelled) return;
      state = LoginState(challenge: challenge);
    } on APIException catch (error) {
      if (!ref.mounted || request.isCancelled) return;
      state = LoginState(
        errorMessage: error.message.trim().isEmpty
            ? AppTexts.loginFailed
            : error.message,
      );
    } catch (_) {
      if (!ref.mounted || request.isCancelled) return;
      state = const LoginState(errorMessage: AppTexts.loginFailed);
    } finally {
      if (identical(_request, request)) _request = null;
    }
  }
}
