import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keebox/app/bootstrap.dart';
import 'package:keebox/app/keebox_app.dart';
import 'package:keebox/app/theme/app_colors.dart';

void main() {
  testWidgets('bootstrap launches the app within Riverpod', (tester) async {
    await bootstrap();
    await tester.pumpAndSettle();
    expect(find.byType(ProviderScope), findsOneWidget);
    expect(find.byType(KeeboxApp), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('app starts with router navigation and the Keebox theme', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: KeeboxApp()));
    await tester.pumpAndSettle();
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'Keebox');
    expect(app.routerConfig, isNotNull);
    expect(app.debugShowCheckedModeBanner, isFalse);
    expect(app.themeMode, ThemeMode.light);
    expect(find.byType(Scaffold), findsOneWidget);
    final context = tester.element(find.byType(Scaffold));
    expect(Theme.of(context).colorScheme.primary, AppColors.brand);
    expect(Theme.of(context).textTheme.bodyMedium!.fontFamily, 'Inter');
    expect(find.byType(FloatingActionButton), findsNothing);
  });
}
