import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keebox/app/theme/app_theme.dart';
import 'package:keebox/features/authentication/screens/login_screen.dart';

void main() {
  testWidgets('login requires an email and password before submitting', (
    tester,
  ) async {
    _usePhoneViewport(tester);
    var submitted = false;
    await tester.pumpWidget(
      _app(LoginScreen(onLogin: (email, password) => submitted = true)),
    );
    await tester.tap(find.text('Login'));
    await tester.pump();
    expect(find.text('Enter your email address'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
    expect(submitted, isFalse);
  });

  testWidgets(
    'visibility toggle preserves the password and login submits inputs',
    (tester) async {
      _usePhoneViewport(tester);
      String? submittedEmail;
      String? submittedPassword;
      await tester.pumpWidget(
        _app(
          LoginScreen(
            onLogin: (email, password) {
              submittedEmail = email;
              submittedPassword = password;
            },
          ),
        ),
      );
      await tester.enterText(
        find.byType(TextFormField).at(0),
        ' user@example.com ',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'private-password',
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).obscureText,
        isTrue,
      );
      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).obscureText,
        isFalse,
      );
      await tester.ensureVisible(find.text('Login'));
      await tester.tap(find.text('Login'));
      expect(submittedEmail, 'user@example.com');
      expect(submittedPassword, 'private-password');
    },
  );

  testWidgets(
    'form remains usable on a small screen with keyboard and enlarged text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var registered = false;
      await tester.pumpWidget(
        _app(LoginScreen(onRegister: () => registered = true), keyboard: true),
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'password');
      await tester.ensureVisible(find.text('Register'));
      await tester.tap(find.text('Register'));
      expect(registered, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _app(Widget screen, {bool keyboard = false}) {
  return ScreenUtilInit(
    designSize: const Size(402, 874),
    minTextAdapt: true,
    splitScreenMode: true,
    builder: (context, child) => MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(keyboard ? 2 : 1),
          viewInsets: EdgeInsets.only(bottom: keyboard ? 220 : 0),
        ),
        child: child!,
      ),
      home: ProviderScope(child: screen),
    ),
  );
}

void _usePhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
