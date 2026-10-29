import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/app/theme/app_colors.dart';
import 'package:keebox/app/theme/app_theme.dart';
import 'package:keebox/features/onboarding/models/onboarding_step.dart';
import 'package:keebox/features/onboarding/widgets/onboarding_buttons.dart';
import 'package:keebox/features/onboarding/widgets/onboarding_decoration.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Poppins')..addFont(
          rootBundle.load('assets/fonts/poppins/Poppins-SemiBold.ttf'),
        ))
        .load();
    await (FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/inter/Inter-Variable.ttf')))
        .load();
  });

  testWidgets(
    'Skip and forward invoke distinct callbacks and can be disabled',
    (tester) async {
      var skips = 0;
      var forwards = 0;
      Widget controls(bool enabled) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          OnboardingSkipButton(onPressed: enabled ? () => skips++ : null),
          OnboardingNextButton(onPressed: enabled ? () => forwards++ : null),
        ],
      );
      await _pump(tester, controls(true));
      await tester.tap(find.text(AppTexts.onboardingSkip));
      await tester.tap(find.byTooltip(AppTexts.onboardingNext));
      expect(skips, 1);
      expect(forwards, 1);
      await _pump(tester, controls(false));
      await tester.tap(find.text(AppTexts.onboardingSkip));
      await tester.tap(find.byTooltip(AppTexts.onboardingNext));
      expect(skips, 1);
      expect(forwards, 1);
    },
  );

  testWidgets(
    'progress identifies the current introduction visually and accessibly',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        for (final step in OnboardingStep.values.take(4)) {
          await _pump(tester, OnboardingProgressIndicators(step: step));
          expect(
            find.bySemanticsLabel(
              AppTexts.onboardingProgress(step.index + 1, 4),
            ),
            findsOneWidget,
          );
          final bars = tester
              .widgetList<DecoratedBox>(
                find.descendant(
                  of: find.byType(OnboardingProgressIndicators),
                  matching: find.byType(DecoratedBox),
                ),
              )
              .toList();
          expect(bars, hasLength(4));
          for (var i = 0; i < bars.length; i++) {
            expect(
              (bars[i].decoration as BoxDecoration).color,
              i == step.index ? AppColors.brand : AppColors.brandLight,
            );
          }
        }
      } finally {
        semantics.dispose();
      }
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'welcome actions remain side by side and tappable at text scale $scale',
      (tester) async {
        var signIns = 0;
        var registrations = 0;
        await _pump(
          tester,
          SizedBox(
            width: 292,
            child: OnboardingWelcomeActions(
              onSignIn: () => signIns++,
              onGetStarted: () => registrations++,
            ),
          ),
          textScale: scale,
        );
        final signIn = find.text(AppTexts.signIn);
        final getStarted = find.text(AppTexts.getStarted);
        expect(
          tester.getTopLeft(signIn).dx,
          lessThan(tester.getTopLeft(getStarted).dx),
        );
        expect(
          tester.getRect(find.byType(OutlinedButton)).top,
          tester.getRect(find.byType(FilledButton)).top,
        );
        await tester.tap(signIn);
        await tester.tap(getStarted);
        expect(signIns, 1);
        expect(registrations, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('disabled welcome actions cannot navigate', (tester) async {
    await _pump(
      tester,
      const OnboardingWelcomeActions(onSignIn: null, onGetStarted: null),
    );
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(402, 874),
      builder: (_, ignored) => MaterialApp(
        theme: AppTheme.light,
        builder: (context, content) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: content!,
        ),
        home: Scaffold(body: Center(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
