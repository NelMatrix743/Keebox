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
import 'package:keebox/network/api_client.dart';
import 'package:keebox/network/api_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late _AuthenticationAPI api;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    api = _AuthenticationAPI();
    container = ProviderContainer(
      overrides: [authenticationApiProvider.overrideWithValue(api)],
    );
  });
  tearDown(() {
    container.dispose();
    api.client.close();
  });

  test('starts unauthenticated without stored credentials', () async {
    expect(
      await container.read(authenticationControllerProvider.future),
      isA<Unauthenticated>(),
    );
  });

  test(
    'restores independently stored user and session with the access token',
    () async {
      await container.read(authenticatedUserStorageProvider).save(_result.user);
      await container
          .read(authenticationSessionStorageProvider)
          .save(_result.session);
      final restored = await container.read(
        authenticationControllerProvider.future,
      ) as Authenticated;
      expect(restored.user.kbkey, 'permanent-key');
      expect(restored.session.accessToken, 'access-token');
      expect(container.read(apiSessionProvider).accessToken, 'access-token');
    },
  );

  test('discards credentials when their user data is missing', () async {
    await container
        .read(authenticationSessionStorageProvider)
        .save(_result.session);
    expect(
      await container.read(authenticationControllerProvider.future),
      isA<Unauthenticated>(),
    );
    expect(
      await container.read(authenticationSessionStorageProvider).read(),
      isNull,
    );
  });

  test(
    'password verification enters PIN state without authenticating',
    () async {
      final controller = container.read(
        authenticationControllerProvider.notifier,
      );
      await controller.setLoginChallenge(
        LoginChallenge(
          loginChallengeId: 'challenge-id',
          expiresAt: DateTime.utc(2026, 10, 7, 12),
          message: 'Enter PIN.',
        ),
      );
      final pending =
          container.read(authenticationControllerProvider).requireValue
              as AwaitingPin;
      expect(pending.challenge.loginChallengeId, 'challenge-id');
      expect(container.read(apiSessionProvider).accessToken, isNull);
      expect(
        await container.read(authenticationSessionStorageProvider).read(),
        isNull,
      );
    },
  );

  test('completed authentication persists both groups and exposes authenticated state', () async {
    await container
        .read(authenticationControllerProvider.notifier)
        .completeAuthentication(_result);
    expect(
      container.read(authenticationControllerProvider).requireValue,
      isA<Authenticated>(),
    );
    expect(
      (await container.read(authenticatedUserStorageProvider).read('user-id'))!
          .kbkey,
      'permanent-key',
    );
    expect(
      (await container.read(authenticationSessionStorageProvider).read())!
          .refreshToken,
      'refresh-token',
    );
    expect(container.read(apiSessionProvider).accessToken, 'access-token');
  });

  test('invalid session clears authentication and retains user key', () async {
    await container
        .read(authenticationControllerProvider.notifier)
        .completeAuthentication(_result);
    await container.read(apiSessionProvider).invalidate('access-token');
    expect(
      container.read(authenticationControllerProvider).requireValue,
      isA<Unauthenticated>(),
    );
    expect(
      await container.read(authenticationSessionStorageProvider).read(),
      isNull,
    );
    expect(
      (await container.read(authenticatedUserStorageProvider).read('user-id'))!
          .kbkey,
      'permanent-key',
    );
  });

  test(
    'logout uses current token and clears local session even if server fails',
    () async {
      final controller = container.read(
        authenticationControllerProvider.notifier,
      );
      await controller.completeAuthentication(_result);
      api.failLogout = true;
      await expectLater(controller.signOut(), throwsStateError);
      expect(api.logoutToken, 'access-token');
      expect(
        container.read(authenticationControllerProvider).requireValue,
        isA<Unauthenticated>(),
      );
      expect(container.read(apiSessionProvider).accessToken, isNull);
      expect(
        await container.read(authenticationSessionStorageProvider).read(),
        isNull,
      );
    },
  );
}

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

class _AuthenticationAPI extends AuthenticationAPI {
  _AuthenticationAPI() : super(client: APIClient());
  bool failLogout = false;
  String? logoutToken;

  @override
  Future<LogoutResponse> logout({
    required String accessToken,
    CancelToken? cancelToken,
  }) async {
    logoutToken = accessToken;
    if (failLogout) {
      throw StateError('Server unavailable.');
    }
    return const LogoutResponse(message: 'Logged out.');
  }
}
