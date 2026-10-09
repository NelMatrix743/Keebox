import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keebox/app/theme/app_colors.dart';
import 'package:keebox/app/theme/app_fonts.dart';
import 'package:keebox/app/theme/app_theme.dart';
import 'package:keebox/features/pin/models/pin_setup_mode.dart';
import 'package:keebox/features/pin/screens/pin_code_screen.dart';
import 'package:keebox/features/pin/widgets/pin_digit_cell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final (family, asset) in [
      (AppFonts.poppins, 'assets/fonts/poppins/Poppins-SemiBold.ttf'),
      (
        AppFonts.jetBrainsMono,
        'assets/fonts/jetbrains_mono/JetBrainsMono-Medium.ttf',
      ),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
    }
  });

  testWidgets('filled cells retain their border until their digit is deleted', (
    tester,
  ) async {
    _viewport(tester);
    await tester.pumpWidget(
      _app(const PinCodeScreen(mode: PinSetupMode.create)),
    );
    expect(find.byKey(const ValueKey('pin-delete')), findsNothing);
    expect(_confirm(tester).onPressed, isNull);
    await _enter(tester, '01234');
    expect(_digits(tester), '01234');
    expect(_confirm(tester).onPressed, isNotNull);
    for (var i = 0; i < 5; i++) {
      expect(_border(tester, i), AppColors.brand);
    }
    await tester.tap(find.byKey(const ValueKey('pin-delete')));
    await tester.pump();
    expect(_digits(tester), '0123');
    expect(_border(tester, 3), AppColors.brand);
    expect(_border(tester, 4), AppColors.border);
    expect(_confirm(tester).onPressed, isNull);
    await _enter(tester, '9');
    expect(_digits(tester), '01239');
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byKey(const ValueKey('pin-delete')));
      await tester.pump();
    }
    expect(find.byKey(const ValueKey('pin-delete')), findsNothing);
  });

  for (final mode in PinSetupMode.values) {
    testWidgets('$mode requires two matching entries before completion', (
      tester,
    ) async {
      _viewport(tester);
      final pins = <String>[];
      await tester.pumpWidget(
        _app(PinCodeScreen(mode: mode, onPinConfirmed: pins.add)),
      );
      expect(
        find.text(
          mode == PinSetupMode.create
              ? 'Create a PIN Code'
              : 'Reset Your PIN Code',
        ),
        findsOneWidget,
      );
      final buttonPosition = tester.getTopLeft(find.byType(FilledButton));
      await _enter(tester, '01234');
      await tester.tap(find.text('Confirm'));
      await tester.pump();
      expect(pins, isEmpty);
      expect(_digits(tester), isEmpty);
      expect(find.text('Confirm Your PIN Code'), findsOneWidget);
      expect(_confirm(tester).onPressed, isNull);
      expect(tester.getTopLeft(find.byType(FilledButton)), buttonPosition);
      await _enter(tester, '01234');
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(pins, ['01234']);
      expect(find.text('PIN Code Confirmed'), findsOneWidget);
      expect(_digits(tester), isEmpty);
      expect(_confirm(tester).onPressed, isNull);
    });
  }

  testWidgets('mismatch shows a bottom error and allows confirmation retry', (
    tester,
  ) async {
    _viewport(tester);
    final pins = <String>[];
    await tester.pumpWidget(
      _app(PinCodeScreen(mode: PinSetupMode.create, onPinConfirmed: pins.add)),
    );
    await _enter(tester, '12345');
    await tester.tap(find.text('Confirm'));
    await tester.pump();
    await _enter(tester, '54321');
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(pins, isEmpty);
    expect(_digits(tester), isEmpty);
    final snackbar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackbar.backgroundColor, Colors.red);
    expect(snackbar.behavior, SnackBarBehavior.fixed);
    expect((snackbar.content as Text).style?.color, Colors.white);
    expect(
      find.text('PIN codes do not match. Please try again.'),
      findsOneWidget,
    );
    await _enter(tester, '12345');
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(pins, ['12345']);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('pending callback disables input and failure permits retry', (
    tester,
  ) async {
    _viewport(tester);
    var pending = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      _app(
        PinCodeScreen(
          mode: PinSetupMode.reset,
          onPinConfirmed: (_) {
            calls++;
            return pending.future;
          },
        ),
      ),
    );
    await _enter(tester, '12345');
    await tester.tap(find.text('Confirm'));
    await tester.pump();
    await _enter(tester, '12345');
    await tester.tap(find.text('Confirm'));
    await tester.pump();
    expect(calls, 1);
    expect(_confirm(tester).onPressed, isNull);
    expect(
      tester
          .widget<OutlinedButton>(
            find.descendant(
              of: find.byKey(const ValueKey('pin-key-1')),
              matching: find.byType(OutlinedButton),
            ),
          )
          .onPressed,
      isNull,
    );
    pending.completeError(StateError('Unavailable'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not confirm your PIN. Please try again.'),
      findsOneWidget,
    );
    expect(_digits(tester), isEmpty);
    pending = Completer<void>();
    await _enter(tester, '12345');
    await tester.tap(find.text('Confirm'));
    await tester.pump();
    expect(calls, 2);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Confirmed'), findsOneWidget);
  });

  testWidgets('small screens and enlarged text keep the whole flow usable', (
    tester,
  ) async {
    _viewport(tester, size: const Size(320, 568));
    String? confirmed;
    await tester.pumpWidget(
      _app(
        PinCodeScreen(
          mode: PinSetupMode.create,
          onPinConfirmed: (pin) => confirmed = pin,
        ),
        textScale: 2,
      ),
    );
    for (var pass = 0; pass < 2; pass++) {
      await _enter(tester, '12345');
      await tester.ensureVisible(find.text('Confirm'));
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
    }
    expect(confirmed, '12345');
    expect(tester.takeException(), isNull);
  });
}

Future<void> _enter(WidgetTester tester, String pin) async {
  for (final digit in pin.split('')) {
    final key = find.byKey(ValueKey('pin-key-$digit'));
    await tester.ensureVisible(key);
    await tester.tap(key);
    await tester.pump();
  }
}

String _digits(WidgetTester tester) => tester
    .widgetList<PinDigitCell>(find.byType(PinDigitCell))
    .map((cell) => cell.digit ?? '')
    .join();

Color _border(WidgetTester tester, int index) {
  final cell = find.byType(PinDigitCell).at(index);
  final box = tester.widget<Container>(
    find.descendant(of: cell, matching: find.byType(Container)),
  );
  return ((box.decoration as BoxDecoration).border! as Border).top.color;
}

FilledButton _confirm(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byType(FilledButton));

void _viewport(WidgetTester tester, {Size size = const Size(402, 874)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app(Widget screen, {double textScale = 1}) => ProviderScope(
  child: ScreenUtilInit(
    designSize: const Size(402, 874),
    minTextAdapt: true,
    splitScreenMode: true,
    builder: (context, child) => MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          padding: const EdgeInsets.only(top: 24, bottom: 34),
        ),
        child: child!,
      ),
      home: screen,
    ),
  ),
);
