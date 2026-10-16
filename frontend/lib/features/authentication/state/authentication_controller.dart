import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:keebox/features/authentication/authentication_api.dart';
import 'package:keebox/features/authentication/models/authentication_result.dart';
import 'package:keebox/features/authentication/models/authenticated_user.dart';
import 'package:keebox/features/authentication/models/authentication_session.dart';
import 'package:keebox/network/api_exception.dart';
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
  int _sessionRevision = 0;
  bool _applicationActive = true;
  bool _profileFetchPending = false;

  @override
  Future<AuthenticationState> build() async {
    final sessionStorage = ref.read(authenticationSessionStorageProvider);
    final apiSession = ref.read(apiSessionProvider);
    ref.onDispose(() {
      _sessionRevision++;
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
        onRefresh: () => _refreshSession(session),
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
          onRefresh: () => _refreshSession(result.session),
        );
    _profileFetchPending = true;
    state = AsyncData(
      _applicationActive
          ? AuthenticatedUnlocked(user: result.user, session: result.session)
          : AuthenticatedLocked(user: result.user, session: result.session),
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

  void setApplicationActive(bool active) {
    _applicationActive = active;
    if (!active) lock();
  }

  Future<bool> fetchProfileAfterLogin() async {
    if (!_profileFetchPending) return false;
    _profileFetchPending = false;
    return refreshCurrentUser();
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

  Future<String?> _refreshSession(AuthenticationSession expected) async {
    final revision = _sessionRevision;
    try {
      final response = await ref
          .read(authenticationApiProvider)
          .refresh(expected.refreshToken);
      return await _serialize(() async {
        if (!ref.mounted || revision != _sessionRevision) return null;
        final current = state.asData?.value;
        if (current is! Authenticated ||
            !identical(current.session, expected)) {
          return null;
        }
        final updated = AuthenticationSession(
          userId: expected.userId,
          accessToken: response.accessToken,
          refreshToken: expected.refreshToken,
        );
        await ref.read(authenticationSessionStorageProvider).save(updated);
        if (!ref.mounted || revision != _sessionRevision) return null;
        final latest = state.asData?.value;
        if (latest is! Authenticated || !identical(latest.session, expected)) {
          return null;
        }
        ref
            .read(apiSessionProvider)
            .set(
              updated.accessToken,
              previousToken: expected.accessToken,
              onInvalidSession: () => _invalidateSession(updated.accessToken),
              onRefresh: () => _refreshSession(updated),
            );
        state = AsyncData(
          latest is AuthenticatedLocked
              ? AuthenticatedLocked(user: latest.user, session: updated)
              : AuthenticatedUnlocked(user: latest.user, session: updated),
        );
        return updated.accessToken;
      });
    } on APIException catch (error) {
      if (ref.mounted &&
          error.statusCode == 401 &&
          error.code == 'invalid_refresh_token') {
        await _invalidateSession(expected.accessToken);
      }
      rethrow;
    }
  }

  /// Explicitly fetches and caches profile details after login or a profile edit.
  /// Session restoration and startup do not invoke this operation.
  Future<bool> refreshCurrentUser() async {
    await future;
    if (!ref.mounted) return false;
    final expected = state.asData?.value;
    if (expected is! Authenticated) return false;
    final revision = _sessionRevision;
    final profile = await ref
        .read(authenticationApiProvider)
        .fetchCurrentUser();
    return _serialize(() async {
      if (!ref.mounted || revision != _sessionRevision) return false;
      final current = state.asData?.value;
      if (current is! Authenticated ||
          current.user.id != expected.user.id ||
          current.session.refreshToken != expected.session.refreshToken) {
        return false;
      }
      if (profile.id != current.user.id) {
        await _clearSession();
        throw const APIException(
          kind: APIErrorKind.invalidResponse,
          message: 'The server returned an unexpected response.',
        );
      }
      final updated = AuthenticatedUser(
        id: current.user.id,
        firstName: profile.firstName,
        lastName: profile.lastName,
        email: profile.email,
        kbkey: current.user.kbkey,
      );
      await ref.read(authenticatedUserStorageProvider).save(updated);
      if (!ref.mounted || revision != _sessionRevision) return false;
      final latest = state.asData?.value;
      if (latest is! Authenticated) return false;
      state = AsyncData(
        latest is AuthenticatedLocked
            ? AuthenticatedLocked(user: updated, session: latest.session)
            : AuthenticatedUnlocked(user: updated, session: latest.session),
      );
      return true;
    });
  }

  Future<void> signOut() => _interruptLocalVerification(() async {
    await future;
    if (!ref.mounted) {
      return;
    }
    final current = state.asData?.value;
    await _clearSession();
    try {
      if (current is Authenticated) {
        final api = ref.read(authenticationApiProvider);
        try {
          await api.logout(accessToken: current.session.accessToken);
        } on APIException catch (error) {
          if (error.statusCode != 401) rethrow;
          final renewed = await api.refresh(current.session.refreshToken);
          await api.logout(accessToken: renewed.accessToken);
        }
      }
    } finally {
      _profileFetchPending = false;
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
    _sessionRevision++;
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
    _sessionRevision++;
    _localVerificationRevision++;
    return _serialize(action);
  }
}
