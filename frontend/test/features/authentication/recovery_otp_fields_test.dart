import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keebox/app/theme/app_colors.dart';
import 'package:keebox/app/theme/app_theme.dart';
import 'package:keebox/features/authentication/widgets/recovery_otp_fields.dart';

void main() {
  Future<void> pump(WidgetTester tester, ValueChanged<String> changed) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(402, 874),
        builder: (_, child) => MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: RecoveryOtpFields(
                  onChanged: changed,
                  onSubmitted: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('six boxes preserve leading zeros and advance focus', (
    tester,
  ) async {
    var code = '';
    await pump(tester, (value) => code = value);
    expect(find.byType(TextField), findsNWidgets(6));
    expect(
      tester.getSize(find.byType(InputDecorator).first).height,
      closeTo(51, 1),
    );
    expect(
      InputDecorator.containerOf(
        tester.element(find.byType(EditableText).first),
      )!.size.height,
      closeTo(51, 1),
    );
    for (var index = 0; index < 6; index++) {
      await tester.enterText(find.byType(TextField).at(index), '$index');
      await tester.pump();
    }
    expect(code, '012345');
    final first = tester.widget<TextField>(find.byType(TextField).first);
    expect(
      (first.decoration!.enabledBorder! as OutlineInputBorder).borderSide.color,
      AppColors.brand,
    );
    expect(first.decoration!.fillColor, Colors.transparent);
    expect(
      tester.widget<TextField>(find.byType(TextField).last).focusNode!.hasFocus,
      isTrue,
    );
  });

  testWidgets('pasting or autofilling a full code distributes all six digits', (
    tester,
  ) async {
    var code = '';
    await pump(tester, (value) => code = value);
    await tester.enterText(find.byType(TextField).first, '001234');
    await tester.pump();
    expect(code, '001234');
    expect(
      tester
          .widgetList<TextField>(find.byType(TextField))
          .map((field) => field.controller!.text),
      ['0', '0', '1', '2', '3', '4'],
    );
  });

  testWidgets(
    'backspace on an empty cell clears the preceding digit and moves back',
    (tester) async {
      var code = '';
      await pump(tester, (value) => code = value);
      await tester.enterText(find.byType(TextField).first, '8');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      expect(code, '');
      expect(
        tester
            .widget<TextField>(find.byType(TextField).first)
            .focusNode!
            .hasFocus,
        isTrue,
      );
    },
  );

  testWidgets(
    'non-digits are rejected and editing a filled digit preserves the other cells',
    (tester) async {
      var code = '';
      await pump(tester, (value) => code = value);
      await tester.enterText(find.byType(TextField).first, 'a01b2345');
      await tester.pump();
      expect(code, '012345');
      await tester.enterText(find.byType(TextField).at(2), '9');
      await tester.pump();
      expect(code, '019345');
    },
  );
}
