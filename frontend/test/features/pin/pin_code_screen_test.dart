import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/app/theme/app_theme.dart';
import 'package:keebox/features/pin/screens/pin_code_screen.dart';
import 'package:keebox/features/pin/widgets/pin_indicator_row.dart';

void main() {
  testWidgets('five digits notify the caller once without revealing the PIN', (
    tester,
  ) async {
    final pins = <String>[];
    await _pump(tester, PinCodeScreen(onPinEntered: pins.add));
    expect(_count(tester), 0);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    await _enter(tester, '0123');
    expect(pins, isEmpty);
    expect(_count(tester), 4);
    await _enter(tester, '4');
    expect(pins, ['01234']);
    expect(_count(tester), 5);
    expect(find.text('01234'), findsNothing);
    await _enter(tester, '9');
    expect(pins, ['01234']);
    expect(_count(tester), 5);
  });

  testWidgets(
    'delete clears indicators in reverse order and permits correction',
    (tester) async {
      final pins = <String>[];
      await _pump(tester, PinCodeScreen(onPinEntered: pins.add));
      expect(_delete(tester).onPressed, isNull);
      await _enter(tester, '01234');
      await tester.tap(find.byKey(const ValueKey('pin-delete')));
      await tester.pump();
      expect(_count(tester), 4);
      await _enter(tester, '9');
      expect(pins, ['01234', '01239']);
      for (var index = 0; index < 5; index++) {
        await tester.tap(find.byKey(const ValueKey('pin-delete')));
        await tester.pump();
      }
      expect(_count(tester), 0);
      expect(_delete(tester).onPressed, isNull);
    },
  );

  testWidgets('fingerprint and Reset use their independent callbacks', (
    tester,
  ) async {
    var fingerprints = 0;
    var resets = 0;
    await _pump(
      tester,
      PinCodeScreen(
        onFingerprintPressed: () => fingerprints++,
        onResetPin: () => resets++,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('pin-fingerprint')));
    await tester.pump();
    await tester.tap(find.text(AppTexts.reset));
    await tester.pump();
    expect(fingerprints, 1);
    expect(resets, 1);
    expect(_count(tester), 0);
  });

  for (final (size, textScale) in [
    (const Size(402, 874), 1.0),
    (const Size(320, 568), 2.0),
    (const Size(874, 402), 2.0),
  ]) {
    testWidgets(
      'all controls fit without scrolling at $size, text scale $textScale',
      (tester) async {
        var resets = 0;
        final pins = <String>[];
        await _pump(
          tester,
          PinCodeScreen(onPinEntered: pins.add, onResetPin: () => resets++),
          size: size,
          textScale: textScale,
        );
        expect(find.byType(Scrollable), findsNothing);
        for (final key in [
          for (var digit = 0; digit < 10; digit++) ValueKey('pin-key-$digit'),
          const ValueKey('pin-delete'),
          const ValueKey('pin-fingerprint'),
        ]) {
          final bounds = tester.getRect(find.byKey(key));
          expect(bounds.top, greaterThanOrEqualTo(24));
          expect(bounds.bottom, lessThanOrEqualTo(size.height - 34));
          expect(bounds.left, greaterThanOrEqualTo(0));
          expect(bounds.right, lessThanOrEqualTo(size.width));
        }
        await _enter(tester, '01234');
        await tester.tap(find.text(AppTexts.reset));
        await tester.pump();
        expect(pins, ['01234']);
        expect(resets, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('leaving the lock screen discards its partial PIN', (
    tester,
  ) async {
    await _pump(tester, const PinCodeScreen());
    await _enter(tester, '12');
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await _pump(tester, const PinCodeScreen());
    expect(_count(tester), 0);
  });
}

int _count(WidgetTester tester) =>
    tester.widget<PinIndicatorRow>(find.byType(PinIndicatorRow)).filledCount;

OutlinedButton _delete(WidgetTester tester) => tester.widget<OutlinedButton>(
  find.descendant(
    of: find.byKey(const ValueKey('pin-delete')),
    matching: find.byType(OutlinedButton),
  ),
);

Future<void> _enter(WidgetTester tester, String pin) async {
  for (final digit in pin.split('')) {
    await tester.tap(find.byKey(ValueKey('pin-key-$digit')));
    await tester.pump();
  }
}

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  Size size = const Size(402, 874),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      child: ScreenUtilInit(
        designSize: const Size(402, 874),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) => MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 24, bottom: 34),
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
          home: screen,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
