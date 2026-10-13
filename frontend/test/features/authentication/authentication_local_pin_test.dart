import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keebox/features/authentication/models/authenticated_user.dart';
import 'package:keebox/features/authentication/models/authentication_result.dart';
import 'package:keebox/features/authentication/models/authentication_session.dart';
import 'package:keebox/features/authentication/state/authentication_controller.dart';
import 'package:keebox/features/authentication/state/authentication_state.dart';
import 'package:keebox/features/authentication/storage/auth_session_storage.dart';
import 'package:keebox/features/authentication/storage/user_storage.dart';
import 'package:keebox/features/pin/models/local_pin_verification.dart';
import 'package:keebox/features/pin/services/local_pin_hasher.dart';
import 'package:keebox/features/pin/storage/local_pin_storage.dart';
import 'package:keebox/network/api_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    container = ProviderContainer(
      overrides: [localPinHasherProvider.overrideWithValue(_Hasher())],
    );
  });
  tearDown(() => container.dispose());

  test(
    'fifth local failure clears tokens and retains the user KBKey',
    () async {
      final controller = container.read(
        authenticationControllerProvider.notifier,
      );
      await controller.completeAuthentication(_result, verifiedPin: '01234');
      for (var i = 0; i < 4; i++) {
        expect(
          (await controller.verifyLocalPin('99999')).status,
          LocalPinStatus.incorrect,
        );
        expect(
          container.read(authenticationControllerProvider).requireValue,
          isA<Authenticated>(),
        );
      }
      expect(
        (await controller.verifyLocalPin('99999')).status,
        LocalPinStatus.requiresReauthentication,
      );
      expect(
        container.read(authenticationControllerProvider).requireValue,
        isA<Unauthenticated>(),
      );
      expect(container.read(apiSessionProvider).accessToken, isNull);
      expect(
        await container.read(authenticationSessionStorageProvider).read(),
        isNull,
      );
      expect(
        (await container
                .read(authenticatedUserStorageProvider)
                .read('user-id'))!
            .kbkey,
        'permanent-key',
      );
      expect(
        (await container.read(localPinStorageProvider).read('user-id'))!
            .requiresReauthentication,
        isTrue,
      );
      expect(
        (await controller.verifyLocalPin('01234')).status,
        LocalPinStatus.requiresReauthentication,
      );
    },
  );

  test(
    'restoration cannot reuse tokens when a persisted local restriction exists',
    () async {
      final controller = container.read(
        authenticationControllerProvider.notifier,
      );
      await controller.completeAuthentication(_result, verifiedPin: '01234');
      for (var i = 0; i < 5; i++) {
        await controller.verifyLocalPin('99999');
      }
      await container
          .read(authenticationSessionStorageProvider)
          .save(_result.session);
      container.invalidate(authenticationControllerProvider);
      expect(
        await container.read(authenticationControllerProvider.future),
        isA<Unauthenticated>(),
      );
      expect(
        await container.read(authenticationSessionStorageProvider).read(),
        isNull,
      );
      expect(container.read(apiSessionProvider).accessToken, isNull);
    },
  );

  test(
    'local success resets failures and does not replace the KBKey',
    () async {
      final controller = container.read(
        authenticationControllerProvider.notifier,
      );
      await controller.completeAuthentication(_result, verifiedPin: '01234');
      await controller.verifyLocalPin('99999');
      expect(
        (await controller.verifyLocalPin('01234')).status,
        LocalPinStatus.matched,
      );
      expect(
        (await container.read(localPinStorageProvider).read('user-id'))!
            .failedAttempts,
        0,
      );
      expect(
        (await container
                .read(authenticatedUserStorageProvider)
                .read('user-id'))!
            .kbkey,
        'permanent-key',
      );
    },
  );

  test('legacy session without local credentials requires backend login on local verification', () async {
    final controller = container.read(
      authenticationControllerProvider.notifier,
    );
    await controller.completeAuthentication(_result);
    expect(
      (await controller.verifyLocalPin('01234')).status,
      LocalPinStatus.requiresReauthentication,
    );
    expect(
      container.read(authenticationControllerProvider).requireValue,
      isA<Unauthenticated>(),
    );
  });

  test('corrupt local credentials cannot restore a saved session', () async {
    final controller = container.read(
      authenticationControllerProvider.notifier,
    );
    await controller.completeAuthentication(_result, verifiedPin: '01234');
    await const FlutterSecureStorage().write(
      key: 'keebox.pin.local.v1.user-id',
      value: '{corrupt',
    );
    container.invalidate(authenticationControllerProvider);
    expect(
      await container.read(authenticationControllerProvider.future),
      isA<Unauthenticated>(),
    );
    expect(container.read(apiSessionProvider).accessToken, isNull);
    expect(
      await container.read(authenticationSessionStorageProvider).read(),
      isNull,
    );
  });
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
  @override
  Future<List<int>> derive(String pin, List<int> salt) async =>
      List.generate(32, (index) => pin.codeUnitAt(index % pin.length));
}
