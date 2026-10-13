import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keebox/features/authentication/models/authenticated_user.dart';
import 'package:keebox/features/authentication/models/authentication_result.dart';
import 'package:keebox/features/authentication/models/authentication_session.dart';
import 'package:keebox/features/authentication/state/authentication_controller.dart';
import 'package:keebox/features/authentication/state/authentication_state.dart';
import 'package:keebox/features/authentication/storage/auth_session_storage.dart';
import 'package:keebox/network/api_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    container = ProviderContainer();
  });
  tearDown(() => container.dispose());

  test('completed backend authentication grants unlocked access', () async {
    await container
        .read(authenticationControllerProvider.notifier)
        .completeAuthentication(_result);
    final state = container.read(authenticationControllerProvider).requireValue;
    expect(state, isA<AuthenticatedUnlocked>());
    expect((state as AuthenticatedUnlocked).user.kbkey, 'permanent-key');
    expect(state.session.accessToken, 'access-token');
  });

  test('recreating authentication restores the session locked and retains its credentials', () async {
    await container
        .read(authenticationControllerProvider.notifier)
        .completeAuthentication(_result);
    container.invalidate(authenticationControllerProvider);
    final state = await container.read(authenticationControllerProvider.future);
    expect(state, isA<AuthenticatedLocked>());
    expect((state as AuthenticatedLocked).user.kbkey, 'permanent-key');
    expect(state.session.refreshToken, 'refresh-token');
    expect(container.read(apiSessionProvider).accessToken, 'access-token');
    expect(
      (await container.read(authenticationSessionStorageProvider).read())!
          .accessToken,
      'access-token',
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
