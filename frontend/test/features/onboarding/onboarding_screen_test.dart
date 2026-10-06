import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:keebox/app/theme/app_theme.dart';
import 'package:keebox/features/onboarding/onboarding_screen.dart';

void main() {
  testWidgets('bottom action keeps spacing above Android navigation controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _buildApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.only(top: 24, bottom: 26),
            viewPadding: const EdgeInsets.only(top: 24, bottom: 26),
          ),
          child: child!,
        ),
        home: OnboardingScreen(onSignIn: () {}, onGetStarted: () {}),
      ),
    );
    final buttonBottom = tester.getBottomLeft(find.byType(FilledButton)).dy;
    expect(874 - 26 - buttonBottom, greaterThanOrEqualTo(26));
  });

  testWidgets('Sign In and Get Started invoke their respective actions', (
    tester,
  ) async {
    var signInCount = 0;
    var getStartedCount = 0;
    await tester.pumpWidget(
      _buildApp(
        theme: AppTheme.light,
        home: OnboardingScreen(
          onSignIn: () => signInCount++,
          onGetStarted: () => getStartedCount++,
        ),
      ),
    );

    await tester.tap(find.text('Sign In'));
    expect(signInCount, 1);
    expect(getStartedCount, 0);
    await tester.tap(find.text('Get Started'));
    expect(signInCount, 1);
    expect(getStartedCount, 1);
  });

  for (final size in [const Size(402, 874), const Size(320, 568)]) {
    testWidgets(
      'actions remain tappable on a $size screen with enlarged text',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var signInPressed = false;
        var getStartedPressed = false;
        await tester.pumpWidget(
          _buildApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: const EdgeInsets.only(top: 44, bottom: 34),
                textScaler: const TextScaler.linear(2),
              ),
              child: child!,
            ),
            home: OnboardingScreen(
              onSignIn: () => signInPressed = true,
              onGetStarted: () => getStartedPressed = true,
            ),
          ),
        );

        await tester.tap(find.text('Sign In'));
        await tester.tap(find.text('Get Started'));
        expect(signInPressed, isTrue);
        expect(getStartedPressed, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Widget _buildApp({
  ThemeData? theme,
  TransitionBuilder? builder,
  required Widget home,
}) {
  return ScreenUtilInit(
    designSize: const Size(402, 874),
    minTextAdapt: true,
    splitScreenMode: true,
    builder: (context, child) =>
        MaterialApp(theme: theme, builder: builder, home: home),
  );
}
