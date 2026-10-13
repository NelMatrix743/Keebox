import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:keebox/features/authentication/state/authentication_controller.dart';
import 'package:keebox/features/onboarding/storage/onboarding_storage.dart';
import 'package:keebox/storage/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('onboarding is incomplete until completion is recorded', () async {
    final storage = OnboardingStorage(preferences: _Preferences());
    expect(await storage.isCompleted(), isFalse);
  });

  test(
    'completion survives recreating storage and preserves other settings',
    () async {
      final preferences = _Preferences();
      await preferences.setBool('notifications.enabled', false);
      await OnboardingStorage(preferences: preferences).markCompleted();
      expect(
        await OnboardingStorage(preferences: preferences).isCompleted(),
        isTrue,
      );
      expect(await preferences.getBool('notifications.enabled'), isFalse);
    },
  );

  test('logout preserves onboarding completion', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(_Preferences())],
    );
    addTearDown(container.dispose);
    final storage = container.read(onboardingStorageProvider);
    await storage.markCompleted();
    await container.read(authenticationControllerProvider.notifier).signOut();
    expect(await storage.isCompleted(), isTrue);
  });
}

class _Preferences implements SharedPreferencesAsync {
  final _values = <String, bool>{};

  @override
  Future<bool?> getBool(String key) async => _values[key];

  @override
  Future<void> setBool(String key, bool value) async => _values[key] = value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
