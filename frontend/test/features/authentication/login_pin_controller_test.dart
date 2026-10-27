import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/features/authentication/authentication_api.dart';
import 'package:keebox/features/authentication/models/authenticated_user.dart';
import 'package:keebox/features/authentication/models/authentication_result.dart';
import 'package:keebox/features/authentication/models/authentication_session.dart';
import 'package:keebox/features/authentication/models/login_response.dart';
import 'package:keebox/features/authentication/models/login_requests.dart';
import 'package:keebox/features/authentication/state/authentication_controller.dart';
import 'package:keebox/features/authentication/state/authentication_state.dart';
import 'package:keebox/features/authentication/state/login_pin_controller.dart';
import 'package:keebox/features/authentication/storage/auth_session_storage.dart';
import 'package:keebox/features/authentication/storage/user_storage.dart';
import 'package:keebox/network/api_client.dart';
import 'package:keebox/network/api_exception.dart';
import 'package:keebox/network/api_session.dart';
import 'package:keebox/features/pin/services/local_pin_hasher.dart';
import 'package:keebox/features/pin/services/local_pin_service.dart';
import 'package:keebox/features/pin/storage/local_pin_storage.dart';
import 'package:keebox/features/pin/models/local_pin_verification.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late _API api;
  final identity = Object();
  final provider = loginPinControllerProvider(identity);

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    api = _API();
    container = ProviderContainer(
      overrides: [
        authenticationApiProvider.overrideWithValue(api),
        localPinHasherProvider.overrideWithValue(_Hasher()),
      ],
    );
    container.listen(provider, (_, _) {});
    await container
        .read(authenticationControllerProvider.notifier)
        .setLoginChallenge(
          LoginChallenge(
            loginChallengeId: 'challenge',
            expiresAt: DateTime.utc(2030),
            message: 'Enter PIN.',
          ),
        );
  });
  tearDown(() {
    container.dispose();
    api.client.close();
  });

  test(
    'a lock requested at backend completion prevents login navigation success',
    () async {
      container.listen(authenticationControllerProvider, (_, next) {
        if (next.asData?.value is AuthenticatedUnlocked) {
          container.read(authenticationControllerProvider.notifier).lock();
        }
      });
      final operation = container.read(provider.notifier).submit('01234');
      api.response.complete(_result);
      await operation;
      expect(
        container.read(authenticationControllerProvider).requireValue,
        isA<AuthenticatedLocked>(),
      );
      expect(container.read(provider).isAuthenticated, isFalse);
      expect(container.read(provider).isSubmitting, isFalse);
    },
  );

  test('submits once with leading zero and persists user and tokens before success', () async {
    final controller = container.read(provider.notifier);
    final operation = controller.submit('01234');
    await controller.submit('99999');
    expect(api.requests.single.toJson(), {
      'login_challenge_id': 'challenge',
      'pin': '01234',
    });
    expect(container.read(provider).isSubmitting, isTrue);
    expect(container.read(apiSessionProvider).accessToken, isNull);
    api.response.complete(_result);
    await operation;
    expect(container.read(provider).isAuthenticated, isTrue);
    expect(
      container.read(authenticationControllerProvider).requireValue,
      isA<AuthenticatedUnlocked>(),
    );
    expect(
      (await container.read(authenticatedUserStorageProvider).read('user'))!
          .kbkey,
      'key',
    );
    expect(
      (await container.read(authenticationSessionStorageProvider).read())!
          .refreshToken,
      'refresh',
    );
    expect(container.read(apiSessionProvider).accessToken, 'access');
    expect(
      (await container.read(localPinServiceProvider).verify('user', '01234'))
          .status,
      LocalPinStatus.matched,
    );
  });

  test(
    'invalid PIN permits an explicit retry without authenticating',
    () async {
      final local = container.read(localPinServiceProvider);
      await local.enrollVerifiedPin('user', '01234');
      for (var i = 0; i < 5; i++) {
        await local.verify('user', '99999');
      }
      final operation = container.read(provider.notifier).submit('11111');
      api.response.completeError(
        const APIException(
          kind: APIErrorKind.api,
          code: 'invalid_login_pin',
          message: 'Incorrect PIN.',
          statusCode: 400,
        ),
      );
      await operation;
      expect(container.read(provider).errorMessage, 'Incorrect PIN.');
      expect(container.read(provider).requiresLogin, isFalse);
      expect(
        (await container.read(localPinStorageProvider).read('user'))!
            .requiresReauthentication,
        isTrue,
      );
      expect(
        container.read(authenticationControllerProvider).requireValue,
        isA<AwaitingPin>(),
      );
      expect(
        await container.read(authenticationSessionStorageProvider).read(),
        isNull,
      );
      api.response = Completer();
      final retry = container.read(provider.notifier).submit('01234');
      api.response.complete(_result);
      await retry;
      expect(api.requests, hasLength(2));
      expect(container.read(provider).isAuthenticated, isTrue);
      expect(
        (await container.read(localPinStorageProvider).read('user'))!
            .requiresReauthentication,
        isFalse,
      );
    },
  );

  for (final code in [
    'invalid_login_challenge',
    'expired_login_challenge',
    'login_account_locked',
    'login_pin_attempt_limit',
  ]) {
    test('$code clears the challenge and requires password login', () async {
      final operation = container.read(provider.notifier).submit('11111');
      api.response.completeError(
        APIException(
          kind: APIErrorKind.api,
          code: code,
          message: 'Start again.',
          statusCode: 423,
        ),
      );
      await operation;
      expect(container.read(provider).requiresLogin, isTrue);
      expect(container.read(provider).errorMessage, 'Start again.');
      expect(
        container.read(authenticationControllerProvider).requireValue,
        isA<Unauthenticated>(),
      );
      expect(container.read(apiSessionProvider).accessToken, isNull);
    });
  }

  test('network failure is not retried automatically', () async {
    final operation = container.read(provider.notifier).submit('11111');
    api.response.completeError(
      const APIException(
        kind: APIErrorKind.connection,
        message: 'Unable to connect to the server.',
      ),
    );
    await operation;
    expect(api.requests, hasLength(1));
    expect(container.read(provider).requiresLogin, isFalse);
    expect(container.read(provider).isSubmitting, isFalse);
  });

  test('expired challenge is rejected before sending a PIN', () async {
    await container
        .read(authenticationControllerProvider.notifier)
        .setLoginChallenge(
          LoginChallenge(
            loginChallengeId: 'expired',
            expiresAt: DateTime.utc(2000),
            message: 'Enter PIN.',
          ),
        );
    await container.read(provider.notifier).submit('12345');
    expect(api.requests, isEmpty);
    expect(container.read(provider).requiresLogin, isTrue);
    expect(
      container.read(provider).errorMessage,
      AppTexts.loginChallengeExpired,
    );
  });

  test(
    'replaced challenge cancels the request and ignores its late response',
    () async {
      final operation = container.read(provider.notifier).submit('11111');
      await container
          .read(authenticationControllerProvider.notifier)
          .setLoginChallenge(
            LoginChallenge(
              loginChallengeId: 'new',
              expiresAt: DateTime.utc(2030),
              message: 'Enter PIN.',
            ),
          );
      expect(api.token!.isCancelled, isTrue);
      api.response.complete(_result);
      await operation;
      expect(container.read(apiSessionProvider).accessToken, isNull);
      expect(
        await container.read(authenticationSessionStorageProvider).read(),
        isNull,
      );
      expect(
        (container.read(authenticationControllerProvider).requireValue
                as AwaitingPin)
            .challenge
            .loginChallengeId,
        'new',
      );
    },
  );

  test(
    'disposed screen cancels verification without persisting a late result',
    () async {
      final operation = container.read(provider.notifier).submit('11111');
      container.invalidate(provider);
      expect(api.token!.isCancelled, isTrue);
      api.response.complete(_result);
      await operation;
      expect(container.read(apiSessionProvider).accessToken, isNull);
      expect(
        await container.read(authenticationSessionStorageProvider).read(),
        isNull,
      );
    },
  );

  test(
    'storage failure requires a new login and never exposes a token',
    () async {
      container.dispose();
      container = ProviderContainer(
        overrides: [
          authenticationApiProvider.overrideWithValue(api),
          localPinHasherProvider.overrideWithValue(_Hasher()),
          authenticatedUserStorageProvider.overrideWithValue(
            _FailingUserStorage(),
          ),
        ],
      );
      container.listen(provider, (_, _) {});
      await container
          .read(authenticationControllerProvider.notifier)
          .setLoginChallenge(
            LoginChallenge(
              loginChallengeId: 'challenge',
              expiresAt: DateTime.utc(2030),
              message: 'Enter PIN.',
            ),
          );
      final operation = container.read(provider.notifier).submit('01234');
      api.response.complete(_result);
      await operation;
      expect(container.read(provider).requiresLogin, isTrue);
      expect(
        container.read(provider).errorMessage,
        AppTexts.loginSessionSaveFailed,
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
    id: 'user',
    firstName: 'Ada',
    lastName: 'Lovelace',
    email: 'ada@example.com',
    kbkey: 'key',
  ),
  session: AuthenticationSession(
    userId: 'user',
    accessToken: 'access',
    refreshToken: 'refresh',
  ),
  message: 'Completed.',
);

class _API extends AuthenticationAPI {
  _API() : super(client: APIClient());
  Completer<AuthenticationResult> response = Completer();
  final requests = <LoginPinRequest>[];
  CancelToken? token;
  @override
  Future<AuthenticationResult> verifyPin(
    LoginPinRequest request, {
    CancelToken? cancelToken,
  }) {
    requests.add(request);
    token = cancelToken;
    return response.future;
  }
}

class _FailingUserStorage extends AuthenticatedUserStorage {
  _FailingUserStorage() : super(storage: const FlutterSecureStorage());
  @override
  Future<void> save(AuthenticatedUser user) async =>
      throw StateError('Storage unavailable');
}

class _Hasher extends LocalPinHasher {
  @override
  Future<List<int>> derive(String pin, List<int> salt) async =>
      List.generate(32, (index) => pin.codeUnitAt(index % pin.length));
}
