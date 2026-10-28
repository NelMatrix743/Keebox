import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/app/theme/app_theme.dart';
import 'package:keebox/assets/app_assets.dart';
import 'package:keebox/features/authentication/models/recovery_type.dart';
import 'package:keebox/features/authentication/screens/recovery_success_screen.dart';
import 'package:keebox/features/authentication/state/recovery_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await AssetLottie(AppAssets.successCheck).load();
  });
  late ProviderContainer container;
  late RecoveryScope scope;
  late Future<void> Function() cleanup;
  late int continued;
  setUp(() {
    continued = 0;
    cleanup = () async {};
    scope = (identity: Object(), type: RecoveryType.password);
    container = ProviderContainer(
      overrides: [
        recoveryCompletionProvider(scope).overrideWith((ref) => cleanup()),
      ],
    );
  });
  tearDown(() => container.dispose());
  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(402, 874),
    double textScale = 1,
    bool reducedMotion = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ScreenUtilInit(
          designSize: const Size(402, 874),
          minTextAdapt: true,
          builder: (_, child) => MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: reducedMotion,
                textScaler: TextScaler.linear(textScale),
              ),
              child: child!,
            ),
            home: RecoverySuccessScreen(
              scope: scope,
              onContinue: () => continued++,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('Lottie plays once and Continue waits for session cleanup', (
    tester,
  ) async {
    final pending = Completer<void>();
    cleanup = () => pending.future;
    await pump(tester);
    final animation = tester.widget<LottieBuilder>(find.byType(LottieBuilder));
    expect((animation.lottie as AssetLottie).assetName, AppAssets.successCheck);
    expect(animation.repeat, isFalse);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text(AppTexts.recoveryCompletedMessage), findsOneWidget);
    await tester.tap(find.text(AppTexts.continueLabel));
    expect(continued, 1);
  });

  testWidgets(
    'cleanup failure shows red feedback and retries cleanup before allowing login',
    (tester) async {
      var attempts = 0;
      cleanup = () async {
        if (++attempts == 1) throw StateError('Unavailable');
      };
      await pump(tester);
      await tester.pumpAndSettle();
      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).backgroundColor,
        Colors.red,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.tap(find.text(AppTexts.retry));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('reduced motion shows the final frame without animating', (
    tester,
  ) async {
    await pump(tester, reducedMotion: true);
    await tester.pumpAndSettle();
    final animation = tester.widget<LottieBuilder>(find.byType(LottieBuilder));
    expect(animation.animate, isFalse);
    expect(animation.controller!.value, 1);
  });

  testWidgets('Back waits for cleanup then follows the same login action', (
    tester,
  ) async {
    final pending = Completer<void>();
    cleanup = () => pending.future;
    await pump(tester);
    await tester.binding.handlePopRoute();
    expect(continued, 0);
    pending.complete();
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    expect(continued, 1);
  });

  testWidgets('small screen with enlarged text keeps Continue reachable', (
    tester,
  ) async {
    await pump(tester, size: const Size(320, 568), textScale: 2);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    expect(continued, 1);
    expect(tester.takeException(), isNull);
  });
}
