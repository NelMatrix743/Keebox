import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keebox/features/authentication/models/authenticated_user.dart';
import 'package:keebox/features/authentication/models/authentication_result.dart';
import 'package:keebox/features/authentication/models/authentication_session.dart';
import 'package:keebox/features/authentication/models/login_response.dart';
import 'package:keebox/features/authentication/models/recovery_requests.dart';
import 'package:keebox/features/authentication/models/recovery_response.dart';
import 'package:keebox/features/authentication/models/recovery_type.dart';
import 'package:keebox/features/authentication/recovery_api.dart';
import 'package:keebox/features/authentication/state/authentication_controller.dart';
import 'package:keebox/features/authentication/state/authentication_state.dart';
import 'package:keebox/features/authentication/state/recovery_completion.dart';
import 'package:keebox/features/authentication/state/recovery_controller.dart';
import 'package:keebox/features/authentication/storage/auth_session_storage.dart';
import 'package:keebox/features/authentication/storage/user_storage.dart';
import 'package:keebox/features/pin/local_pin_policy.dart';
import 'package:keebox/features/pin/models/local_pin_verification.dart';
import 'package:keebox/features/pin/services/local_pin_hasher.dart';
import 'package:keebox/features/pin/services/local_pin_service.dart';
import 'package:keebox/features/pin/storage/local_pin_storage.dart';
import 'package:keebox/network/api_client.dart';
import 'package:keebox/network/api_session.dart';

const _result = AuthenticationResult(
  user: AuthenticatedUser(
    id: 'account-1',
    firstName: 'Ada',
    lastName: 'Lovelace',
    email: 'ada@example.com',
    kbkey: 'permanent-key',
  ),
  session: AuthenticationSession(
    userId: 'account-1',
    accessToken: 'old-access',
    refreshToken: 'old-refresh',
  ),
  message: 'Signed in.',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late _API api;
  late _SessionStorage storage;
  late RecoveryScope scope;
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    api = _API();
    storage = _SessionStorage();
    container = ProviderContainer(
      overrides: [
        recoveryApiProvider.overrideWithValue(api),
        authenticationSessionStorageProvider.overrideWithValue(storage),
        localPinHasherProvider.overrideWithValue(const _Hasher()),
      ],
    );
    scope = (identity: Object(), type: RecoveryType.pin);
    container.listen(recoveryControllerProvider(scope), (_, _) {});
    await container.read(authenticationControllerProvider.future);
    await container
        .read(authenticationControllerProvider.notifier)
        .completeAuthentication(_result, verifiedPin: '11111');
  });
  tearDown(() {
    container.dispose();
    api.client.close();
  });
  Future<void> complete(RecoveryType type) async {
    scope = (identity: Object(), type: type);
    container.listen(recoveryControllerProvider(scope), (_, _) {});
    final controller = container.read(
      recoveryControllerProvider(scope).notifier,
    );
    await controller.start('ada@example.com');
    await controller.verifyOtp('001234');
    if (type == RecoveryType.password) {
      await controller.completePassword('strong replacement password');
    } else {
      await controller.completePin('54321');
    }
  }

  for (final type in RecoveryType.values) {
    test(
      '$type completion clears session once while preserving cached user and local verifier',
      () async {
        final before =
            (await container.read(localPinStorageProvider).read('account-1'))!
                .toJson();
        await complete(type);
        await container.read(recoveryCompletionProvider(scope).future);
        await container.read(recoveryCompletionProvider(scope).future);
        expect(storage.clears, 1);
        expect(await storage.read(), isNull);
        expect(container.read(apiSessionProvider).accessToken, isNull);
        expect(
          container.read(authenticationControllerProvider).requireValue,
          isA<Unauthenticated>(),
        );
        expect(
          (await container
                  .read(authenticatedUserStorageProvider)
                  .read('account-1'))!
              .kbkey,
          'permanent-key',
        );
        expect(
          (await container.read(localPinStorageProvider).read('account-1'))!
              .toJson(),
          before,
        );
        container.invalidate(authenticationControllerProvider);
        expect(
          await container.read(authenticationControllerProvider.future),
          isA<Unauthenticated>(),
        );
      },
    );
  }

  test('cleanup refuses an uncompleted recovery without clearing an active session', () async {
    await expectLater(
      container.read(recoveryCompletionProvider(scope).future),
      throwsStateError,
    );
    expect(storage.clears, 0);
    expect(container.read(apiSessionProvider).accessToken, 'old-access');
  });

  test(
    'completion also discards an outstanding password-login PIN challenge',
    () async {
      await container
          .read(authenticationControllerProvider.notifier)
          .setLoginChallenge(
            LoginChallenge(
              loginChallengeId: 'pending-login',
              expiresAt: DateTime.now().add(const Duration(minutes: 5)),
              message: 'Enter PIN.',
            ),
          );
      await complete(RecoveryType.pin);
      await container.read(recoveryCompletionProvider(scope).future);
      expect(
        container.read(authenticationControllerProvider).requireValue,
        isA<Unauthenticated>(),
      );
    },
  );

  test('failed secure-storage cleanup can be retried without repeating the reset API', () async {
    await complete(RecoveryType.pin);
    storage.failures = 1;
    await expectLater(
      container.read(recoveryCompletionProvider(scope).future),
      throwsStateError,
    );
    expect(container.read(apiSessionProvider).accessToken, isNull);
    container.invalidate(recoveryCompletionProvider(scope));
    await container.read(recoveryCompletionProvider(scope).future);
    expect(storage.clears, 2);
    expect(await storage.read(), isNull);
    expect(api.completions, 1);
  });

  test(
    'the next backend-verified sign-in replaces the local PIN verifier',
    () async {
      await complete(RecoveryType.pin);
      await container.read(recoveryCompletionProvider(scope).future);
      await container
          .read(authenticationControllerProvider.notifier)
          .completeAuthentication(_result, verifiedPin: '54321');
      final local = container.read(localPinServiceProvider);
      expect(
        (await local.verify('account-1', '54321')).status,
        LocalPinStatus.matched,
      );
      expect(
        (await local.verify('account-1', '11111')).status,
        LocalPinStatus.incorrect,
      );
      expect(
        (await container
                .read(authenticatedUserStorageProvider)
                .read('account-1'))!
            .kbkey,
        'permanent-key',
      );
    },
  );
}

class _SessionStorage extends AuthenticationSessionStorage {
  _SessionStorage() : super(storage: const FlutterSecureStorage());
  int clears = 0;
  int failures = 0;
  @override
  Future<void> clear() async {
    clears++;
    if (failures > 0) {
      failures--;
      throw StateError('Storage unavailable');
    }
    await super.clear();
  }
}

class _Hasher extends LocalPinHasher {
  const _Hasher();
  @override
  List<int> newSalt() => List.filled(LocalPinPolicy.saltLength, 1);
  @override
  Future<List<int>> derive(String pin, List<int> salt) async => List.filled(
    LocalPinPolicy.verifierLength,
    pin.codeUnits.fold<int>(0, (sum, byte) => sum + byte) % 256,
  );
}

class _API extends RecoveryAPI {
  _API() : super(client: APIClient());
  int completions = 0;
  static const id = '12345678-1234-1234-1234-123456789abc';
  @override
  Future<RecoveryChallenge> start(
    RecoveryType type,
    RecoveryStartRequest request, {
    CancelToken? cancelToken,
  }) async => RecoveryChallenge(
    resetId: id,
    otpExpiresAt: DateTime.now().add(const Duration(minutes: 5)),
    resendAvailableAt: DateTime.now(),
    message: 'Code sent.',
  );
  @override
  Future<RecoveryVerified> verifyOtp(
    RecoveryVerifyRequest request, {
    CancelToken? cancelToken,
  }) async => RecoveryVerified(
    resetId: id,
    completionExpiresAt: DateTime.now().add(const Duration(minutes: 10)),
    message: 'Verified.',
  );
  @override
  Future<RecoveryCompleted> completePassword(
    PasswordResetRequest request, {
    CancelToken? cancelToken,
  }) async {
    completions++;
    return const RecoveryCompleted(resetId: id, message: 'Reset completed.');
  }

  @override
  Future<RecoveryCompleted> completePin(
    PinResetRequest request, {
    CancelToken? cancelToken,
  }) async {
    completions++;
    return const RecoveryCompleted(resetId: id, message: 'Reset completed.');
  }
}
