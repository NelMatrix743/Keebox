import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:keebox/features/authentication/authentication_api.dart';
import 'package:keebox/features/authentication/models/login_request.dart';
import 'package:keebox/features/authentication/state/authentication_controller.dart';

final loginControllerProvider =
    NotifierProvider.autoDispose<LoginController, AsyncValue<void>>(
      LoginController.new,
    );

class LoginController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> submit(LoginRequest request) async {
    if (state.isLoading) {
      return;
    }
    state = const AsyncLoading();
    final cancelToken = CancelToken();
    ref.onDispose(() => cancelToken.cancel());
    try {
      await ref.read(authenticationControllerProvider.future);
      if (!ref.mounted) {
        return;
      }
      final challenge = await ref
          .read(authenticationApiProvider)
          .login(request, cancelToken: cancelToken);
      if (!ref.mounted) {
        return;
      }
      await ref
          .read(authenticationControllerProvider.notifier)
          .setLoginChallenge(challenge);
      if (ref.mounted) {
        state = const AsyncData(null);
      }
    } catch (error, stackTrace) {
      if (ref.mounted) {
        state = AsyncError(error, stackTrace);
      }
    }
  }
}
