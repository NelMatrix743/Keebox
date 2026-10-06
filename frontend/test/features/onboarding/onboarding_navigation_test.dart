import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keebox/main.dart';

void main() {
  testWidgets(
    'onboarding opens sign in and registration with back navigation',
    (tester) async {
      await tester.pumpWidget(const ProviderScope(child: KeeboxApp()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome Back!'), findsOneWidget);
      await tester.ensureVisible(find.text('Forgot your password?'));
      await tester.tap(find.text('Forgot your password?'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Reset Password'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Register'));
      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Create Account'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Create Account'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Get Started'), findsOneWidget);
    },
  );
}
