import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:keebox/features/authentication/authentication_api.dart';
import 'package:keebox/features/authentication/models/authentication_result.dart';
import 'package:keebox/features/authentication/models/login_challenge.dart';
import 'package:keebox/features/authentication/state/authentication_state.dart';
import 'package:keebox/features/authentication/storage/auth_session_storage.dart';
import 'package:keebox/features/authentication/storage/user_storage.dart';
import 'package:keebox/features/pin/models/local_pin_verification.dart';
import 'package:keebox/features/pin/services/local_pin_service.dart';
import 'package:keebox/features/pin/storage/local_pin_storage.dart';
import 'package:keebox/network/api_session.dart';

final authenticationControllerProvider =
    AsyncNotifierProvider<AuthenticationController, AuthenticationState>(
      AuthenticationController.new,
    );

class AuthenticationController extends AsyncNotifier<AuthenticationState> {
  Future<void> _pending = Future<void>.value();
  int _localVerificationRevision = 0;

  @override
  Future<AuthenticationState> build() async {
    final sessionStorage = ref.read(authenticationSessionStorageProvider);
    final apiSession = ref.read(apiSessionProvider);
    ref.onDispose(() {
      _localVerificationRevision++;
      apiSession.clear();
    });
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
      final localPin = await ref
          .read(localPinStorageProvider)
          .read(session.userId);
      if (!ref.mounted) return const Unauthenticated();
      if (localPin?.requiresReauthentication == true) {
        await sessionStorage.clear();
        return const Unauthenticated();
      }
      apiSession.set(
        session.accessToken,
        onInvalidSession: () => _invalidateSession(session.accessToken),
      );
      return AuthenticatedLocked(user: user, session: session);
    } on FormatException {
      await sessionStorage.clear();
      return const Unauthenticated();
    }
  }

  Future<void> setLoginChallenge(LoginChallenge challenge) =>
      _interruptLocalVerification(() async {
        await future;
        if (!ref.mounted) {
          return;
        }
        await _clearSession();
        state = AsyncData(AwaitingPin(challenge));
      });

  Future<void> completeAuthentication(
    AuthenticationResult result, {
    String? loginChallengeId,
    String? verifiedPin,
    bool Function()? isActive,
  }) => _interruptLocalVerification(() async {
    await future;
    bool canComplete() {
      if (!ref.mounted || (isActive != null && !isActive())) return false;
      if (loginChallengeId == null) return true;
      final current = state.asData?.value;
      return current is AwaitingPin &&
          current.challenge.loginChallengeId == loginChallengeId;
    }

    if (!canComplete()) return;
    if (result.user.id != result.session.userId) {
      throw StateError(
        'Authentication user and session must belong to the same account.',
      );
    }
    final sessionStorage = ref.read(authenticationSessionStorageProvider);
    if (verifiedPin != null) {
      final enrolled = await ref
          .read(localPinServiceProvider)
          .enrollVerifiedPin(
            result.user.id,
            verifiedPin,
            isActive: canComplete,
          );
      if (!enrolled || !canComplete()) return;
    }
    await ref.read(authenticatedUserStorageProvider).save(result.user);
    if (!canComplete()) return;
    await sessionStorage.save(result.session);
    if (!canComplete()) {
      await sessionStorage.clear();
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
      AuthenticatedUnlocked(user: result.user, session: result.session),
    );
  });

  Future<void> clearLoginChallenge(String challengeId) => _serialize(() async {
    await future;
    if (!ref.mounted) return;
    final current = state.asData?.value;
    if (current is AwaitingPin &&
        current.challenge.loginChallengeId == challengeId) {
      await _clearSession();
    }
  });

  void lock() {
    if (!ref.mounted) return;
    final current = state.asData?.value;
    if (current is! Authenticated) return;
    _localVerificationRevision++;
    state = AsyncData(
      AuthenticatedLocked(user: current.user, session: current.session),
    );
  }

  Future<LocalPinVerification> verifyLocalPin(
    String pin, {
    bool Function()? isActive,
  }) {
    final revision = _localVerificationRevision;
    return _serialize(() async {
      await future;
      if (!ref.mounted ||
          revision != _localVerificationRevision ||
          (isActive != null && !isActive())) {
        return const LocalPinVerification(LocalPinStatus.unavailable);
      }
      final current = state.asData?.value;
      if (current is! Authenticated) {
        return const LocalPinVerification(
          LocalPinStatus.requiresReauthentication,
        );
      }
      if (current is! AuthenticatedLocked) {
        return const LocalPinVerification(LocalPinStatus.unavailable);
      }
      final result = await ref
          .read(localPinServiceProvider)
          .verify(current.user.id, pin);
      if (!ref.mounted ||
          revision != _localVerificationRevision ||
          (isActive != null && !isActive()) ||
          !identical(state.asData?.value, current)) {
        return const LocalPinVerification(LocalPinStatus.unavailable);
      }
      if (result.status == LocalPinStatus.requiresReauthentication) {
        await _clearSession();
      } else if (result.status == LocalPinStatus.matched) {
        state = AsyncData(
          AuthenticatedUnlocked(user: current.user, session: current.session),
        );
      }
      return result;
    });
  }

  Future<void> signOut() => _interruptLocalVerification(() async {
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

  Future<void> clearSession() => _interruptLocalVerification(() async {
    await future;
    await _clearSession();
  });

  Future<void> _invalidateSession(String token) {
    final current = state.asData?.value;
    if (current is! Authenticated || current.session.accessToken != token) {
      return Future<void>.value();
    }
    return _interruptLocalVerification(() async {
      await future;
      final current = state.asData?.value;
      if (current is Authenticated && current.session.accessToken == token) {
        await _clearSession();
      }
    });
  }

  Future<void> _clearSession() async {
    if (!ref.mounted) {
      return;
    }
    _localVerificationRevision++;
    ref.read(apiSessionProvider).clear();
    state = const AsyncData(Unauthenticated());
    await ref.read(authenticationSessionStorageProvider).clear();
  }

  Future<T> _serialize<T>(Future<T> Function() action) {
    final operation = _pending.then((_) => action());
    _pending = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return operation;
  }

  Future<T> _interruptLocalVerification<T>(Future<T> Function() action) {
    _localVerificationRevision++;
    return _serialize(action);
  }
}
