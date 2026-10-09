import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keebox/shared/widgets/app_snackbar.dart';

void main() {
  for (final (type, background, foreground) in [
    (AppSnackBarType.success, Colors.green, Colors.white),
    (AppSnackBarType.info, Colors.blue, Colors.white),
    (AppSnackBarType.warning, Colors.yellow, Colors.black),
    (AppSnackBarType.error, Colors.red, Colors.white),
  ]) {
    testWidgets('$type displays readable feedback at the bottom', (
      tester,
    ) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (value) {
              context = value;
              return const Scaffold(body: SizedBox.expand());
            },
          ),
        ),
      );
      AppSnackBar.show(context, message: 'Feedback', type: type);
      await tester.pumpAndSettle();
      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(bar.backgroundColor, background);
      expect(bar.behavior, SnackBarBehavior.fixed);
      expect(
        tester.widget<Text>(find.text('Feedback')).style!.color,
        foreground,
      );
      expect(
        tester.getBottomRight(find.byType(SnackBar)).dy,
        tester.view.physicalSize.height / tester.view.devicePixelRatio,
      );
    });
  }

  testWidgets('new feedback replaces an existing message without queuing it', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (value) {
            context = value;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );
    AppSnackBar.show(
      context,
      message: 'Old error',
      type: AppSnackBarType.error,
    );
    await tester.pumpAndSettle();
    AppSnackBar.show(
      context,
      message: 'Recovered',
      type: AppSnackBarType.success,
    );
    await tester.pumpAndSettle();
    expect(find.text('Old error'), findsNothing);
    expect(find.text('Recovered'), findsOneWidget);
    AppSnackBar.dismiss(context);
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });
}
