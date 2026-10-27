import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keebox/features/authentication/models/authenticated_user.dart';
import 'package:keebox/features/authentication/models/authentication_result.dart';
import 'package:keebox/features/authentication/models/authentication_session.dart';
import 'package:keebox/features/authentication/models/login_response.dart';
import 'package:keebox/features/authentication/state/authentication_controller.dart';
import 'package:keebox/features/authentication/state/authentication_state.dart';
import 'package:keebox/features/authentication/storage/auth_session_storage.dart';
import 'package:keebox/features/pin/models/local_pin_record.dart';
import 'package:keebox/features/pin/services/local_pin_hasher.dart';
import 'package:keebox/features/pin/services/local_pin_service.dart';
import 'package:keebox/features/pin/storage/local_pin_storage.dart';
import 'package:keebox/network/api_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late _Hasher hasher;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    hasher = _Hasher();
    container = ProviderContainer(
      overrides: [localPinHasherProvider.overrideWithValue(hasher)],
    );
  });
  tearDown(() => container.dispose());

  test('verified PIN enrollment finishes before user and session become authenticated', () async {
    hasher.gate = Completer<void>();
    final operation = container
        .read(authenticationControllerProvider.notifier)
        .completeAuthentication(_result, verifiedPin: '01234');
    await Future<void>.delayed(Duration.zero);
    expect(container.read(apiSessionProvider).accessToken, isNull);
    expect(
      await container.read(authenticationSessionStorageProvider).read(),
      isNull,
    );
    hasher.gate!.complete();
    await operation;
    expect(
      container.read(authenticationControllerProvider).requireValue,
      isA<Authenticated>(),
    );
    expect(
      (await container.read(localPinStorageProvider).read('user-id'))!
          .failedAttempts,
      0,
    );
  });

  test(
    'cancelled enrollment cannot clear an existing retry restriction',
    () async {
      final service = container.read(localPinServiceProvider);
      await service.enrollVerifiedPin('user-id', '01234');
      for (var i = 0; i < 5; i++) {
        await service.verify('user-id', '99999');
      }
      final controller = container.read(
        authenticationControllerProvider.notifier,
      );
      await controller.setLoginChallenge(
        LoginChallenge(
          loginChallengeId: 'challenge',
          expiresAt: DateTime.utc(2030),
          message: 'Enter PIN.',
        ),
      );
      hasher.gate = Completer<void>();
      var active = true;
      final completion = controller.completeAuthentication(
        _result,
        loginChallengeId: 'challenge',
        verifiedPin: '54321',
        isActive: () => active,
      );
      await Future<void>.delayed(Duration.zero);
      active = false;
      hasher.gate!.complete();
      await completion;
      expect(
        (await container.read(localPinStorageProvider).read('user-id'))!
            .requiresReauthentication,
        isTrue,
      );
      expect(
        await container.read(authenticationSessionStorageProvider).read(),
        isNull,
      );
      expect(container.read(apiSessionProvider).accessToken, isNull);
    },
  );

  test(
    'enrollment storage failure cannot persist or publish a session',
    () async {
      container.dispose();
      container = ProviderContainer(
        overrides: [
          localPinHasherProvider.overrideWithValue(hasher),
          localPinStorageProvider.overrideWithValue(_FailingStorage()),
        ],
      );
      await expectLater(
        container
            .read(authenticationControllerProvider.notifier)
            .completeAuthentication(_result, verifiedPin: '01234'),
        throwsStateError,
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

class _Hasher extends LocalPinHasher {
  Completer<void>? gate;
  @override
  Future<List<int>> derive(String pin, List<int> salt) async {
    if (gate != null) await gate!.future;
    return List.generate(32, (index) => pin.codeUnitAt(index % pin.length));
  }
}

class _FailingStorage extends LocalPinStorage {
  _FailingStorage() : super(storage: const FlutterSecureStorage());
  @override
  Future<void> save(LocalPinRecord record) async =>
      throw StateError('Storage unavailable');
}
