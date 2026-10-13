import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keebox/app/app_texts.dart';
import 'package:keebox/app/theme/app_theme.dart';
import 'package:keebox/features/onboarding/screens/onboarding_screen.dart';
import 'package:keebox/features/onboarding/storage/onboarding_storage.dart';

void main() {
  for (final action in ['Sign In', 'Get Started']) {
    testWidgets(
      '$action waits for saving before navigating and blocks duplicate taps',
      (tester) async {
        final storage = _Storage()..gate = Completer<void>();
        var signIns = 0;
        var registrations = 0;
        await _pump(
          tester,
          storage,
          onSignIn: () => signIns++,
          onGetStarted: () => registrations++,
        );
        expect(storage.writes, 0);
        expect(storage.completed, isFalse);
        await tester.tap(find.text(action));
        await tester.pump();
        expect(storage.writes, 1);
        expect(signIns + registrations, 0);
        expect(
          tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
          isNull,
        );
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        storage.gate!.complete();
        await tester.pumpAndSettle();
        expect(storage.completed, isTrue);
        expect(signIns, action == 'Sign In' ? 1 : 0);
        expect(registrations, action == 'Get Started' ? 1 : 0);
      },
    );
  }

  testWidgets(
    'save failure stays on onboarding with a red bottom error and permits retry',
    (tester) async {
      final storage = _Storage()..failSave = true;
      var navigations = 0;
      await _pump(tester, storage, onSignIn: () => navigations++);
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();
      expect(navigations, 0);
      expect(storage.completed, isFalse);
      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.backgroundColor, Colors.red);
      expect(snackBar.behavior, SnackBarBehavior.fixed);
      expect(
        tester
            .widget<Text>(find.text(AppTexts.onboardingSaveFailed))
            .style!
            .color,
        Colors.white,
      );
      storage.failSave = false;
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();
      expect(navigations, 1);
      expect(storage.completed, isTrue);
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets('leaving onboarding while saving prevents late navigation', (
    tester,
  ) async {
    final storage = _Storage()..gate = Completer<void>();
    var navigations = 0;
    await _pump(tester, storage, onSignIn: () => navigations++);
    await tester.tap(find.text('Sign In'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    storage.gate!.complete();
    await tester.pumpAndSettle();
    expect(navigations, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('buttons wait for the initial preference read', (tester) async {
    final storage = _Storage()..readGate = Completer<bool>();
    await _pump(tester, storage);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    storage.readGate!.complete(false);
    await tester.pumpAndSettle();
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNotNull,
    );
  });
}

Future<void> _pump(
  WidgetTester tester,
  _Storage storage, {
  VoidCallback? onSignIn,
  VoidCallback? onGetStarted,
}) async {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [onboardingStorageProvider.overrideWithValue(storage)],
      child: ScreenUtilInit(
        designSize: const Size(402, 874),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) => MaterialApp(
          theme: AppTheme.light,
          home: OnboardingScreen(
            onSignIn: onSignIn ?? () {},
            onGetStarted: onGetStarted ?? () {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _Storage implements OnboardingStorage {
  bool completed = false;
  bool failSave = false;
  int writes = 0;
  Completer<void>? gate;
  Completer<bool>? readGate;

  @override
  Future<bool> isCompleted() async =>
      readGate == null ? completed : readGate!.future;

  @override
  Future<void> markCompleted() async {
    writes++;
    if (gate != null) await gate!.future;
    if (failSave) throw StateError('Write failed');
    completed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
