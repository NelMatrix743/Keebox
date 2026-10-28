import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:keebox/main.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/storage/shared_preferences.dart';
import 'package:keebox/features/onboarding/storage/onboarding_storage.dart';

void main() {
  testWidgets(
    'onboarding opens sign in and registration with back navigation',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(_Preferences()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const KeeboxApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        await container.read(onboardingStorageProvider).isCompleted(),
        isFalse,
      );
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome Back!'), findsOneWidget);
      expect(
        await container.read(onboardingStorageProvider).isCompleted(),
        isTrue,
      );
      await tester.ensureVisible(find.text('Forgot your password?'));
      await tester.tap(find.text('Forgot your password?'));
      await tester.pumpAndSettle();
      expect(find.text('Enter your email'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Register'));
      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();
      expect(find.text(AppTexts.registrationIdentityTitle), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();
      expect(find.text(AppTexts.registrationIdentityTitle), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Get Started'), findsOneWidget);
    },
  );
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
