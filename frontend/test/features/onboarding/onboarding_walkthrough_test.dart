import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/app/theme/app_theme.dart';
import 'package:keebox/features/onboarding/models/onboarding_step.dart';
import 'package:keebox/features/onboarding/screens/onboarding_screen.dart';
import 'package:keebox/features/onboarding/state/onboarding_controller.dart';
import 'package:keebox/features/onboarding/storage/onboarding_storage.dart';
import 'package:keebox/features/onboarding/widgets/onboarding_buttons.dart';
import 'package:keebox/features/onboarding/widgets/onboarding_decoration.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/inter/Inter-Variable.ttf')))
        .load();
    await (FontLoader(
          'Poppins',
        )..addFont(rootBundle.load('assets/fonts/poppins/Poppins-Regular.ttf')))
        .load();
  });
  late ProviderContainer container;
  late _Storage storage;
  setUp(() {
    storage = _Storage();
    container = ProviderContainer(
      overrides: [onboardingStorageProvider.overrideWithValue(storage)],
    );
  });
  tearDown(() => container.dispose());
  OnboardingStep current() =>
      container.read(onboardingControllerProvider).requireValue.step;

  testWidgets(
    'Forward visits each content state then reveals welcome actions',
    (tester) async {
      await _pump(tester, container);
      expect(current(), OnboardingStep.notes);
      for (final step in OnboardingStep.values.skip(1)) {
        await tester.tap(find.byTooltip(AppTexts.onboardingNext));
        await tester.pumpAndSettle();
        expect(current(), step);
        expect(find.text(step.title).hitTestable(), findsOneWidget);
      }
      expect(find.byType(OnboardingWelcomeActions), findsOneWidget);
      expect(find.byType(OnboardingSkipButton), findsNothing);
      expect(find.byType(OnboardingProgressIndicators), findsNothing);
      expect(find.byType(OnboardingDecorativeStrip), findsNothing);
      expect(storage.writes, 0);
    },
  );

  testWidgets('swipes, forward, Skip and Back share the same current state', (
    tester,
  ) async {
    await _pump(tester, container);
    final pager = find.byType(PageView);
    await tester.drag(pager, const Offset(-350, 0));
    await tester.pumpAndSettle();
    expect(current(), OnboardingStep.credentials);
    expect(
      tester
          .widget<OnboardingProgressIndicators>(
            find.byType(OnboardingProgressIndicators),
          )
          .step,
      OnboardingStep.credentials,
    );
    await tester.tap(find.byTooltip(AppTexts.onboardingNext));
    await tester.pumpAndSettle();
    expect(current(), OnboardingStep.privacy);
    await tester.tap(find.text(AppTexts.onboardingSkip));
    await tester.pumpAndSettle();
    expect(current(), OnboardingStep.welcome);
    await tester.drag(pager, const Offset(350, 0));
    await tester.pumpAndSettle();
    expect(current(), OnboardingStep.backup);
    for (final step in [
      OnboardingStep.privacy,
      OnboardingStep.credentials,
      OnboardingStep.notes,
    ]) {
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(current(), step);
    }
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(current(), OnboardingStep.notes);
    expect(storage.writes, 0);
  });

  testWidgets(
    'an external state change synchronizes the pager without losing its selection',
    (tester) async {
      await _pump(tester, container);
      container.read(onboardingControllerProvider.notifier).skip();
      await tester.pumpAndSettle();
      expect(
        find.text(AppTexts.onboardingWelcomeTitle).hitTestable(),
        findsOneWidget,
      );
      container.read(onboardingControllerProvider.notifier).setPage(1);
      await tester.pumpAndSettle();
      expect(
        find.text(AppTexts.onboardingCredentialsTitle).hitTestable(),
        findsOneWidget,
      );
      expect(current(), OnboardingStep.credentials);
    },
  );

  for (final size in [
    const Size(402, 874),
    const Size(320, 568),
    const Size(874, 402),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'all states fit without vertical scrolling at $size and text scale $scale',
        (tester) async {
          await _pump(tester, container, size: size, scale: scale);
          for (final step in OnboardingStep.values) {
            container
                .read(onboardingControllerProvider.notifier)
                .setPage(step.index);
            await tester.pumpAndSettle();
            expect(find.text(step.title).hitTestable(), findsOneWidget);
            expect(find.text(step.description).hitTestable(), findsOneWidget);
            final controls = step == OnboardingStep.welcome
                ? find.byType(OnboardingWelcomeActions)
                : find.byType(OnboardingNextButton);
            final rect = tester.getRect(controls);
            expect(rect.bottom, lessThanOrEqualTo(size.height - 26));
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(size.width));
            expect(find.byType(SingleChildScrollView), findsNothing);
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }
}

Future<void> _pump(
  WidgetTester tester,
  ProviderContainer container, {
  Size size = const Size(402, 874),
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: ScreenUtilInit(
        designSize: const Size(402, 874),
        minTextAdapt: true,
        builder: (_, child) => MaterialApp(
          theme: AppTheme.light,
          builder: (context, content) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 32, bottom: 26),
              viewPadding: const EdgeInsets.only(top: 32, bottom: 26),
              textScaler: TextScaler.linear(scale),
            ),
            child: content!,
          ),
          home: OnboardingScreen(onSignIn: () {}, onGetStarted: () {}),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _Storage implements OnboardingStorage {
  int writes = 0;
  @override
  Future<bool> isCompleted() async => false;
  @override
  Future<void> markCompleted() async {
    writes++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
