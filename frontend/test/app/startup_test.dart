import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:keebox/app/startup/startup_coordinator.dart';
import 'package:keebox/app/router/app_routes.dart';
import 'package:keebox/storage/shared_preferences.dart';
import 'package:keebox/features/authentication/models/authenticated_user.dart';
import 'package:keebox/features/authentication/models/authentication_result.dart';
import 'package:keebox/features/authentication/models/authentication_session.dart';
import 'package:keebox/features/authentication/state/authentication_controller.dart';
import 'package:keebox/features/authentication/state/authentication_state.dart';
import 'package:keebox/features/pin/models/local_pin_record.dart';
import 'package:keebox/features/pin/storage/local_pin_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final hasPin in [false, true]) {
    test(
      'restored session requires usable local credentials hasPin=$hasPin',
      () async {
        FlutterSecureStorage.setMockInitialValues({});
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(_Preferences(true)),
          ],
        );
        addTearDown(container.dispose);
        await container
            .read(authenticationControllerProvider.notifier)
            .completeAuthentication(
              const AuthenticationResult(
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
                message: 'Done',
              ),
            );
        if (hasPin) {
          await container
              .read(localPinStorageProvider)
              .save(
                LocalPinRecord(
                  userId: 'user',
                  salt: List.filled(16, 0),
                  verifier: List.filled(32, 0),
                ),
              );
        }
        container.invalidate(authenticationControllerProvider);
        expect(
          await container.read(startupCoordinatorProvider.future),
          hasPin ? AppRoutes.homeLock : AppRoutes.signIn,
        );
        expect(
          container.read(authenticationControllerProvider).requireValue,
          hasPin ? isA<AuthenticatedLocked>() : isA<Unauthenticated>(),
        );
      },
    );
  }
  for (final completed in [false, true]) {
    test(
      'startup selects the correct unauthenticated route completed=$completed',
      () async {
        FlutterSecureStorage.setMockInitialValues({});
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(
              _Preferences(completed),
            ),
          ],
        );
        addTearDown(container.dispose);
        expect(
          await container.read(startupCoordinatorProvider.future),
          completed ? AppRoutes.signIn : AppRoutes.root,
        );
      },
    );
  }
  test('storage errors remain retryable', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final preferences = _Preferences(false)..fail = true;
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);
    await expectLater(
      container.read(startupCoordinatorProvider.future),
      throwsStateError,
    );
    preferences.fail = false;
    container.invalidate(startupCoordinatorProvider);
    expect(
      await container.read(startupCoordinatorProvider.future),
      AppRoutes.root,
    );
  });
}

class _Preferences implements SharedPreferencesAsync {
  _Preferences(this.completed);
  final bool completed;
  final _failure = [false];
  bool get fail => _failure[0];
  set fail(bool value) => _failure[0] = value;
  @override
  Future<bool?> getBool(String key) async {
    if (fail) throw StateError('Unavailable');
    return completed;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
