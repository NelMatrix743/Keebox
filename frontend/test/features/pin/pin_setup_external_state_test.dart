import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keebox/app/theme/app_theme.dart';
import 'package:keebox/features/pin/models/pin_setup_mode.dart';
import 'package:keebox/features/pin/screens/pin_setup_screen.dart';
import 'package:keebox/features/pin/widgets/pin_digit_cell.dart';

void main() {
  testWidgets('external submission renders a spinner and prevents PIN entry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: ScreenUtilInit(
          designSize: const Size(402, 874),
          builder: (_, child) => MaterialApp(
            home: const PinSetupScreen(
              mode: PinSetupMode.create,
              isSubmitting: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pin-key-1')));
    await tester.pump();
    expect(
      tester
          .widgetList<PinDigitCell>(find.byType(PinDigitCell))
          .every((cell) => cell.digit == null),
      isTrue,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });
  Future<void> pump(WidgetTester tester, PinSetupScreen screen) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: ScreenUtilInit(
          designSize: const Size(402, 874),
          minTextAdapt: true,
          builder: (_, child) =>
              MaterialApp(theme: AppTheme.light, home: screen),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'external disabling blocks digits and confirmation while keeping the footer visible',
    (tester) async {
      await pump(
        tester,
        const PinSetupScreen(
          mode: PinSetupMode.reset,
          enabled: false,
          footer: Text('Recovery expired'),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('pin-key-1')));
      await tester.pump();
      expect(
        tester
            .widgetList<PinDigitCell>(find.byType(PinDigitCell))
            .every((cell) => cell.digit == null),
        isTrue,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(find.text('Recovery expired'), findsOneWidget);
    },
  );

  testWidgets(
    'caller can handle submission errors without a duplicate generic snackbar',
    (tester) async {
      await pump(
        tester,
        PinSetupScreen(
          mode: PinSetupMode.reset,
          showSubmissionError: false,
          onPinConfirmed: (_) => throw StateError('Handled by caller'),
        ),
      );
      for (final digit in '01234'.split('')) {
        await tester.tap(find.byKey(ValueKey('pin-key-$digit')));
        await tester.pump();
      }
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
    },
  );
}
