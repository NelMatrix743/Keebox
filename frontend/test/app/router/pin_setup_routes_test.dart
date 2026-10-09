import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:keebox/app/router/app_router.dart';
import 'package:keebox/app/router/app_routes.dart';
import 'package:keebox/app/theme/app_theme.dart';
import 'package:keebox/features/pin/widgets/pin_digit_cell.dart';

void main() {
  for (final (route, title) in [
    (AppRoutes.createPinName, 'Create a PIN Code'),
    (AppRoutes.resetPinName, 'Reset Your PIN Code'),
  ]) {
    testWidgets('$route returns the confirmed PIN to its caller', (
      tester,
    ) async {
      final router = await _pumpRouter(tester);
      final result = router.pushNamed<String>(route);
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
      for (var pass = 0; pass < 2; pass++) {
        for (final digit in [0, 1, 2, 3, 4]) {
          final key = find.byKey(ValueKey('pin-key-$digit'));
          await tester.ensureVisible(key);
          await tester.tap(key);
          await tester.pump();
        }
        await tester.ensureVisible(find.text('Confirm'));
        await tester.tap(find.text('Confirm'));
        await tester.pumpAndSettle();
      }
      expect(await result, '01234');
      expect(router.routeInformationProvider.value.uri.path, AppRoutes.root);
    });
  }

  testWidgets('leaving PIN setup discards partial entry before reopening', (
    tester,
  ) async {
    final router = await _pumpRouter(tester);
    final cancelled = router.pushNamed<String>(AppRoutes.createPinName);
    await tester.pumpAndSettle();
    final key = find.byKey(const ValueKey('pin-key-1'));
    await tester.ensureVisible(key);
    await tester.tap(key);
    await tester.pump();
    router.pop();
    await tester.pumpAndSettle();
    expect(await cancelled, isNull);
    router.pushNamed<String>(AppRoutes.createPinName);
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<PinDigitCell>(find.byType(PinDigitCell))
          .every((cell) => cell.digit == null),
      isTrue,
    );
    expect(find.byKey(const ValueKey('pin-delete')), findsNothing);
  });
}

Future<GoRouter> _pumpRouter(WidgetTester tester) async {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final router = container.read(appRouterProvider);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: ScreenUtilInit(
        designSize: const Size(402, 874),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) =>
            MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}
