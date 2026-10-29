import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:keebox/main.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/app/router/app_router.dart';
import 'package:keebox/app/router/app_routes.dart';
import 'package:keebox/app/startup/startup_coordinator.dart';
import 'package:keebox/features/onboarding/screens/onboarding_screen.dart';
import 'package:keebox/storage/shared_preferences.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  for (final action in [AppTexts.signIn, AppTexts.getStarted]) {
    final destination = action == AppTexts.signIn
        ? AppRoutes.signIn
        : AppRoutes.register;
    testWidgets(
      '$action saves completion and replaces onboarding with $destination',
      (tester) async {
        final preferences = _Preferences();
        final container = await _launch(tester, preferences);
        expect(preferences.completed, isFalse);
        await _welcome(tester);
        expect(preferences.completed, isFalse);
        await tester.tap(find.text(action));
        await tester.pumpAndSettle();
        expect(preferences.completed, isTrue);
        expect(_path(container), destination);
        expect(container.read(appRouterProvider).canPop(), isFalse);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(_path(container), destination);
        expect(find.byType(OnboardingScreen), findsNothing);
      },
    );

    testWidgets(
      '$action waits for persistence and stays retryable on failure',
      (tester) async {
        final preferences = _Preferences()..failSave = true;
        final container = await _launch(tester, preferences);
        await _welcome(tester);
        preferences.writeGate = Completer<void>();
        await tester.tap(find.text(action));
        await tester.pump();
        expect(_path(container), AppRoutes.root);
        expect(preferences.completed, isFalse);
        expect(
          tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
          isNull,
        );
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        preferences.writeGate!.complete();
        await tester.pumpAndSettle();
        expect(_path(container), AppRoutes.root);
        expect(preferences.completed, isFalse);
        expect(
          find.text(AppTexts.onboardingWelcomeTitle).hitTestable(),
          findsOneWidget,
        );
        expect(
          tester.widget<SnackBar>(find.byType(SnackBar)).backgroundColor,
          Colors.red,
        );
        preferences.failSave = false;
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        await tester.tap(find.text(action));
        await tester.pumpAndSettle();
        expect(_path(container), destination);
        expect(container.read(appRouterProvider).canPop(), isFalse);
        expect(preferences.completed, isTrue);
        expect(preferences.writes, 2);
      },
    );
  }

  testWidgets(
    'fresh startup repeats unfinished onboarding and skips completed onboarding',
    (tester) async {
      final preferences = _Preferences();
      await _launch(tester, preferences);
      await _welcome(tester);
      expect(preferences.writes, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      final unfinished = await _launch(tester, preferences);
      expect(_path(unfinished), AppRoutes.root);
      expect(
        find.text(AppTexts.onboardingNotesTitle).hitTestable(),
        findsOneWidget,
      );
      await _welcome(tester);
      await tester.tap(find.text(AppTexts.getStarted));
      await tester.pumpAndSettle();
      expect(preferences.writes, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      final completed = await _launch(tester, preferences);
      expect(_path(completed), AppRoutes.signIn);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(preferences.writes, 1);
    },
  );

  testWidgets(
    'login recovery and registration retain their own back navigation',
    (tester) async {
      final container = await _launch(tester, _Preferences());
      await _welcome(tester);
      await tester.tap(find.text(AppTexts.signIn));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Forgot your password?'));
      await tester.tap(find.text('Forgot your password?'));
      await tester.pumpAndSettle();
      expect(find.text('Enter your email'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(_path(container), AppRoutes.signIn);
      await tester.ensureVisible(find.text('Register'));
      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();
      expect(find.text(AppTexts.registrationIdentityTitle), findsOneWidget);
      expect(find.byTooltip(AppTexts.back), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_path(container), AppRoutes.signIn);
      expect(container.read(appRouterProvider).canPop(), isFalse);
    },
  );
}

Future<ProviderContainer> _launch(
  WidgetTester tester,
  _Preferences preferences,
) async {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      initialRouteProvider.overrideWith(
        (ref) => ref.watch(startupCoordinatorProvider).requireValue,
      ),
    ],
  );
  addTearDown(container.dispose);
  await container.read(startupCoordinatorProvider.future);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const KeeboxApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _welcome(WidgetTester tester) async {
  await tester.tap(find.text(AppTexts.onboardingSkip));
  await tester.pumpAndSettle();
}

String _path(ProviderContainer container) =>
    container.read(appRouterProvider).routeInformationProvider.value.uri.path;

class _Preferences implements SharedPreferencesAsync {
  final _values = <String, Object?>{};
  bool get completed => _values['completed'] == true;
  bool get failSave => _values['failSave'] == true;
  set failSave(bool value) => _values['failSave'] = value;
  int get writes => _values['writes'] as int? ?? 0;
  Completer<void>? get writeGate => _values['gate'] as Completer<void>?;
  set writeGate(Completer<void>? value) => _values['gate'] = value;
  @override
  Future<bool?> getBool(String key) async => completed;
  @override
  Future<void> setBool(String key, bool value) async {
    _values['writes'] = writes + 1;
    if (writeGate != null) await writeGate!.future;
    if (failSave) throw StateError('Preference write failed');
    _values['completed'] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
