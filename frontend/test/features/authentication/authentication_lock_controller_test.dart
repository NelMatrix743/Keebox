import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keebox/features/authentication/authentication_api.dart';
import 'package:keebox/features/authentication/models/authenticated_user.dart';
import 'package:keebox/features/authentication/models/authentication_result.dart';
import 'package:keebox/features/authentication/models/authentication_session.dart';
import 'package:keebox/features/authentication/models/login_challenge.dart';
import 'package:keebox/features/authentication/models/logout_response.dart';
import 'package:keebox/features/authentication/state/authentication_controller.dart';
import 'package:keebox/features/authentication/state/authentication_state.dart';
import 'package:keebox/features/authentication/storage/auth_session_storage.dart';
import 'package:keebox/features/authentication/storage/user_storage.dart';
import 'package:keebox/features/pin/models/local_pin_verification.dart';
import 'package:keebox/features/pin/services/local_pin_hasher.dart';
import 'package:keebox/features/pin/storage/local_pin_storage.dart';
import 'package:keebox/network/api_client.dart';
import 'package:keebox/network/api_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late _Hasher hasher;
  late _API api;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    hasher = _Hasher();
    api = _API();
    container = ProviderContainer(
      overrides: [
        localPinHasherProvider.overrideWithValue(hasher),
        authenticationApiProvider.overrideWithValue(api),
      ],
    );
  });
  tearDown(() {
    container.dispose();
    api.client.close();
  });

  test(
    'locking retains the exact user, tokens, KBKey, and local retry state',
    () async {
      final controller = container.read(
        authenticationControllerProvider.notifier,
      );
      await controller.completeAuthentication(_result, verifiedPin: '01234');
      final before =
          container.read(authenticationControllerProvider).requireValue
              as AuthenticatedUnlocked;
      controller.lock();
      final locked =
          container.read(authenticationControllerProvider).requireValue
              as AuthenticatedLocked;
      expect(identical(locked.user, before.user), isTrue);
      expect(identical(locked.session, before.session), isTrue);
      expect(container.read(apiSessionProvider).accessToken, 'access-token');
      expect(
        (await container
                .read(authenticatedUserStorageProvider)
                .read('user-id'))!
            .kbkey,
        'permanent-key',
      );
      expect(
        (await container.read(authenticationSessionStorageProvider).read())!
            .refreshToken,
        'refresh-token',
      );
      expect(
        (await container.read(localPinStorageProvider).read('user-id'))!
            .failedAttempts,
        0,
      );
    },
  );

  test(
    'incorrect PIN stays locked and correct PIN grants unlocked access',
    () async {
      final controller = container.read(
        authenticationControllerProvider.notifier,
      );
      await controller.completeAuthentication(_result, verifiedPin: '01234');
      controller.lock();
      expect(
        (await controller.verifyLocalPin('99999')).status,
        LocalPinStatus.incorrect,
      );
      expect(
        container.read(authenticationControllerProvider).requireValue,
        isA<AuthenticatedLocked>(),
      );
      expect(
        (await controller.verifyLocalPin('01234')).status,
        LocalPinStatus.matched,
      );
      expect(
        container.read(authenticationControllerProvider).requireValue,
        isA<AuthenticatedUnlocked>(),
      );
    },
  );

  test('local verification requires a locked session and ignores queued duplicate unlocks', () async {
    final controller = container.read(
      authenticationControllerProvider.notifier,
    );
    await controller.completeAuthentication(_result, verifiedPin: '01234');
    final calls = hasher.calls;
    expect(
      (await controller.verifyLocalPin('99999')).status,
      LocalPinStatus.unavailable,
    );
    expect(hasher.calls, calls);
    controller.lock();
    final first = controller.verifyLocalPin('01234');
    final second = controller.verifyLocalPin('01234');
    expect((await first).status, LocalPinStatus.matched);
    expect((await second).status, LocalPinStatus.unavailable);
    expect(hasher.calls, calls + 1);
  });

  test(
    'locking has no effect before backend authentication is complete',
    () async {
      final controller = container.read(
        authenticationControllerProvider.notifier,
      );
      await container.read(authenticationControllerProvider.future);
      controller.lock();
      expect(
        container.read(authenticationControllerProvider).requireValue,
        isA<Unauthenticated>(),
      );
      await controller.setLoginChallenge(_challenge);
      controller.lock();
      expect(
        container.read(authenticationControllerProvider).requireValue,
        isA<AwaitingPin>(),
      );
    },
  );

  test(
    'logout from a locked session revokes its token and clears the session',
    () async {
      final controller = container.read(
        authenticationControllerProvider.notifier,
      );
      await controller.completeAuthentication(_result, verifiedPin: '01234');
      controller.lock();
      await controller.signOut();
      expect(api.logoutToken, 'access-token');
      expect(
        container.read(authenticationControllerProvider).requireValue,
        isA<Unauthenticated>(),
      );
      expect(
        await container.read(authenticationSessionStorageProvider).read(),
        isNull,
      );
    },
  );

  for (final action in [
    'relock',
    'logout',
    'clear session',
    'new challenge',
    'account change',
    'invalidate session',
    'restore session',
  ]) {
    test(
      'a late PIN match cannot unlock the previous session after $action',
      () async {
        final controller = container.read(
          authenticationControllerProvider.notifier,
        );
        await controller.completeAuthentication(_result, verifiedPin: '01234');
        controller.lock();
        final unlockedUsers = <String>[];
        container.listen(authenticationControllerProvider, (_, next) {
          final state = next.asData?.value;
          if (state is AuthenticatedUnlocked) unlockedUsers.add(state.user.id);
        });
        hasher.pause();
        final verification = controller.verifyLocalPin('01234');
        await hasher.started!.future;
        Future<void>? pending;
        switch (action) {
          case 'relock':
            controller.lock();
          case 'logout':
            pending = controller.signOut();
          case 'clear session':
            pending = controller.clearSession();
          case 'new challenge':
            pending = controller.setLoginChallenge(_challenge);
          case 'account change':
            pending = controller.completeAuthentication(_otherResult);
          case 'invalidate session':
            pending = container
                .read(apiSessionProvider)
                .invalidate('access-token');
          case 'restore session':
            container.invalidate(authenticationControllerProvider);
            pending = container
                .read(authenticationControllerProvider.future)
                .then((_) {});
        }
        hasher.gate!.complete();
        expect((await verification).status, LocalPinStatus.unavailable);
        await pending;
        expect(unlockedUsers, isNot(contains('user-id')));
        final state = container
            .read(authenticationControllerProvider)
            .requireValue;
        switch (action) {
          case 'relock' || 'restore session':
            expect(state, isA<AuthenticatedLocked>());
          case 'new challenge':
            expect(state, isA<AwaitingPin>());
          case 'account change':
            expect((state as AuthenticatedUnlocked).user.id, 'other-user');
          default:
            expect(state, isA<Unauthenticated>());
        }
      },
    );
  }
}

final _challenge = LoginChallenge(
  loginChallengeId: 'challenge',
  expiresAt: DateTime.utc(2030),
  message: 'Enter PIN.',
);
const _result = AuthenticationResult(
  user: AuthenticatedUser(
    id: 'user-id',
    firstName: 'Ada',
    lastName: 'Lovelace',
    email: 'ada@example.com',
    kbkey: 'permanent-key',
  ),
  session: AuthenticationSession(
    userId: 'user-id',
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
  ),
  message: 'Completed.',
);
const _otherResult = AuthenticationResult(
  user: AuthenticatedUser(
    id: 'other-user',
    firstName: 'Other',
    lastName: 'User',
    email: 'other@example.com',
    kbkey: 'other-key',
  ),
  session: AuthenticationSession(
    userId: 'other-user',
    accessToken: 'other-token',
    refreshToken: 'other-refresh',
  ),
  message: 'Completed.',
);

class _Hasher extends LocalPinHasher {
  int calls = 0;
  Completer<void>? gate;
  Completer<void>? started;
  void pause() {
    gate = Completer<void>();
    started = Completer<void>();
  }

  @override
  Future<List<int>> derive(String pin, List<int> salt) async {
    calls++;
    if (gate != null) {
      if (!started!.isCompleted) started!.complete();
      await gate!.future;
    }
    return List.generate(32, (index) => pin.codeUnitAt(index % pin.length));
  }
}

class _API extends AuthenticationAPI {
  _API() : super(client: APIClient());
  String? logoutToken;
  @override
  Future<LogoutResponse> logout({
    required String accessToken,
    CancelToken? cancelToken,
  }) async {
    logoutToken = accessToken;
    return const LogoutResponse(message: 'Logged out.');
  }
}
