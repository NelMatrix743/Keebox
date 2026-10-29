import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keebox/shared/widgets/app_snackbar.dart';
import 'package:keebox/assets/app_assets.dart';

void main() {
  for (final (type, background, asset) in [
    (AppSnackBarType.success, Colors.green, AppAssets.snackbarSuccess),
    (AppSnackBarType.info, Colors.blue, AppAssets.snackbarInfo),
    (
      AppSnackBarType.warning,
      const Color(0xFFFAD83B),
      AppAssets.snackbarWarning,
    ),
    (AppSnackBarType.error, Colors.red, AppAssets.snackbarError),
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
      expect(bar.behavior, SnackBarBehavior.floating);
      expect(
        tester.widget<Text>(find.text('Feedback')).style!.color,
        Colors.white,
      );
      final icon = tester.widget<Image>(find.byType(Image));
      expect((icon.image as AssetImage).assetName, asset);
      expect(icon.color, Colors.white);
      expect(icon.excludeFromSemantics, isTrue);
      expect(tester.getSize(find.byType(Image)), const Size(24, 24));
      expect(
        tester.getTopLeft(find.text('Feedback')).dx,
        greaterThan(tester.getTopRight(find.byType(Image)).dx),
      );
      expect(
        tester.getBottomRight(find.byType(SnackBar)).dy,
        lessThanOrEqualTo(
          tester.view.physicalSize.height / tester.view.devicePixelRatio,
        ),
      );
    });
  }

  testWidgets('long feedback wraps beside the icon with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Builder(
          builder: (value) {
            context = value;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );
    const message = 'Please check your connection and try your request again.';
    AppSnackBar.show(context, message: message, type: AppSnackBarType.error);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.text(message)).height, greaterThan(48));
    expect(
      tester.getBottomRight(find.text(message)).dx,
      lessThan(tester.view.physicalSize.width),
    );
  });

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
