import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:keebox/features/authentication/authentication_api.dart';
import 'package:keebox/features/authentication/models/authentication_result.dart';
import 'package:keebox/features/authentication/models/login_challenge.dart';
import 'package:keebox/features/authentication/state/authentication_state.dart';
import 'package:keebox/features/authentication/storage/auth_session_storage.dart';
import 'package:keebox/features/authentication/storage/user_storage.dart';
import 'package:keebox/network/api_session.dart';

final authenticationControllerProvider =
    AsyncNotifierProvider<AuthenticationController, AuthenticationState>(
      AuthenticationController.new,
    );

class AuthenticationController extends AsyncNotifier<AuthenticationState> {
  Future<void> _pending = Future<void>.value();

  @override
  Future<AuthenticationState> build() async {
    final sessionStorage = ref.read(authenticationSessionStorageProvider);
    final apiSession = ref.read(apiSessionProvider);
    ref.onDispose(apiSession.clear);
    final session = await sessionStorage.read();
    if (!ref.mounted || session == null) {
      return const Unauthenticated();
    }
    try {
      final user = await ref
          .read(authenticatedUserStorageProvider)
          .read(session.userId);
      if (!ref.mounted) {
        return const Unauthenticated();
      }
      if (user == null) {
        await sessionStorage.clear();
        return const Unauthenticated();
      }
      apiSession.set(
        session.accessToken,
        onInvalidSession: () => _invalidateSession(session.accessToken),
      );
      return Authenticated(user: user, session: session);
    } on FormatException {
      await sessionStorage.clear();
      return const Unauthenticated();
    }
  }

  Future<void> setLoginChallenge(LoginChallenge challenge) =>
      _serialize(() async {
        await future;
        if (!ref.mounted) {
          return;
        }
        await _clearSession();
        state = AsyncData(AwaitingPin(challenge));
      });

  Future<void> completeAuthentication(AuthenticationResult result) =>
      _serialize(() async {
        await future;
        if (!ref.mounted) {
          return;
        }
        if (result.user.id != result.session.userId) {
          throw StateError(
            'Authentication user and session must belong to the same account.',
          );
        }
        await ref.read(authenticatedUserStorageProvider).save(result.user);
        await ref
            .read(authenticationSessionStorageProvider)
            .save(result.session);
        if (!ref.mounted) {
          return;
        }
        ref
            .read(apiSessionProvider)
            .set(
              result.session.accessToken,
              onInvalidSession: () =>
                  _invalidateSession(result.session.accessToken),
            );
        state = AsyncData(
          Authenticated(user: result.user, session: result.session),
        );
      });

  Future<void> signOut() => _serialize(() async {
    await future;
    if (!ref.mounted) {
      return;
    }
    final current = state.asData?.value;
    try {
      if (current is Authenticated) {
        await ref
            .read(authenticationApiProvider)
            .logout(accessToken: current.session.accessToken);
      }
    } finally {
      await _clearSession();
    }
  });

  Future<void> clearSession() => _serialize(() async {
    await future;
    await _clearSession();
  });

  Future<void> _invalidateSession(String token) => _serialize(() async {
    await future;
    final current = state.asData?.value;
    if (current is Authenticated && current.session.accessToken == token) {
      await _clearSession();
    }
  });

  Future<void> _clearSession() async {
    if (!ref.mounted) {
      return;
    }
    ref.read(apiSessionProvider).clear();
    state = const AsyncData(Unauthenticated());
    await ref.read(authenticationSessionStorageProvider).clear();
  }

  Future<void> _serialize(Future<void> Function() action) {
    final operation = _pending.then((_) => action());
    _pending = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return operation;
  }
}
