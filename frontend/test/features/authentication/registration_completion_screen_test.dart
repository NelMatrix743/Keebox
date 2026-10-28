import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/app/router/app_router.dart';
import 'package:keebox/app/router/app_routes.dart';
import 'package:keebox/app/startup/startup_coordinator.dart';
import 'package:keebox/app/theme/app_theme.dart';
import 'package:keebox/assets/app_assets.dart';
import 'package:keebox/features/authentication/authentication_api.dart';
import 'package:keebox/features/authentication/registration_api.dart';
import 'package:keebox/features/authentication/screens/registration_screen.dart';
import 'package:keebox/features/authentication/screens/registration_pin_screen.dart';
import 'package:keebox/features/authentication/state/registration_clock.dart';
import 'package:keebox/features/authentication/storage/auth_session_storage.dart';
import 'package:keebox/features/pin/services/local_pin_hasher.dart';
import 'package:keebox/network/api_exception.dart';

import 'support/registration_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await AssetLottie(AppAssets.successCheck).load();
    await (FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/inter/Inter-Variable.ttf')))
        .load();
    await (FontLoader('Poppins')..addFont(
          rootBundle.load('assets/fonts/poppins/Poppins-SemiBold.ttf'),
        ))
        .load();
  });
  late TestRegistrationAPI api;
  late TestProfileAPI profile;
  late TestPinHasher hasher;
  late TestSessionStorage storage;
  late ProviderContainer container;
  late int completed;
  late int signIns;
  late DateTime now;
  setUp(() {
    now = DateTime.utc(2030);
    FlutterSecureStorage.setMockInitialValues({});
    api = TestRegistrationAPI();
    profile = TestProfileAPI();
    hasher = TestPinHasher();
    completed = signIns = 0;
  });
  tearDown(() {
    container.dispose();
    api.client.close();
    profile.client.close();
  });
  Future<void> pump(WidgetTester tester, {bool router = false}) async {
    storage = TestSessionStorage();
    container = ProviderContainer(
      overrides: [
        registrationApiProvider.overrideWithValue(api),
        authenticationApiProvider.overrideWithValue(profile),
        localPinHasherProvider.overrideWithValue(hasher),
        authenticationSessionStorageProvider.overrideWithValue(storage),
        registrationClockProvider.overrideWithValue(() => now),
        initialRouteProvider.overrideWithValue(AppRoutes.register),
      ],
    );
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ScreenUtilInit(
          designSize: const Size(402, 874),
          minTextAdapt: true,
          builder: (_, child) => router
              ? MaterialApp.router(
                  theme: AppTheme.light,
                  routerConfig: container.read(appRouterProvider),
                )
              : MaterialApp(
                  theme: AppTheme.light,
                  home: RegistrationScreen(
                    onSignIn: () => signIns++,
                    onRegistered: () => completed++,
                  ),
                ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Ada');
    await tester.enterText(find.byType(TextFormField).at(1), 'Lovelace');
    await tester.enterText(find.byType(TextFormField).at(2), 'ada@example.com');
    await tester.tap(find.text(AppTexts.next));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'strong password');
    await tester.enterText(find.byType(TextFormField).last, 'strong password');
    await tester.tap(find.text(AppTexts.continueLabel));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '001234');
    await tester.pump();
    await tester.tap(find.text(AppTexts.continueLabel));
    await tester.pumpAndSettle();
    for (final digit in '00123'.split('')) {
      await tester.ensureVisible(find.byKey(ValueKey('pin-key-$digit')));
      await tester.tap(find.byKey(ValueKey('pin-key-$digit')));
      await tester.pump();
    }
    await tester.ensureVisible(find.text(AppTexts.confirm));
  }

  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(find.text(AppTexts.confirm));
    await tester.pump();
  }

  testWidgets(
    'Confirm stays busy through backend completion and local hashing',
    (tester) async {
      api.gate = Completer();
      hasher.gate = Completer<void>();
      await pump(tester);
      await confirm(tester);
      expect(api.pins, ['00123']);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(RegistrationPinScreen), findsOneWidget);
      api.gate!.complete(registeredResult);
      await tester.pump();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      hasher.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text(AppTexts.registrationCompletedMessage), findsOneWidget);
      await tester.tap(find.text(AppTexts.continueLabel));
      expect(completed, 1);
    },
  );
  testWidgets(
    'backend PIN failure stays on setup with red feedback and permits a retry',
    (tester) async {
      await pump(tester);
      api.failure = const APIException(
        kind: APIErrorKind.api,
        code: 'validation_error',
        statusCode: 422,
        message: 'Invalid PIN.',
      );
      await confirm(tester);
      await tester.pumpAndSettle();
      expect(find.byType(RegistrationPinScreen), findsOneWidget);
      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).backgroundColor,
        Colors.red,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      api.failure = null;
      await confirm(tester);
      await tester.pumpAndSettle();
      expect(api.pins, hasLength(2));
      expect(find.text(AppTexts.registrationCompletedMessage), findsOneWidget);
    },
  );
  testWidgets('timeout prevents another confirmation and offers fresh login', (
    tester,
  ) async {
    await pump(tester);
    api.failure = const APIException(
      kind: APIErrorKind.timeout,
      message: 'Timeout',
    );
    await confirm(tester);
    await tester.pumpAndSettle();
    expect(find.text(AppTexts.registrationCompletionUncertain), findsWidgets);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(AppTexts.backToLogin));
    await tester.tap(find.text(AppTexts.backToLogin));
    expect(signIns, 1);
    expect(api.pins, hasLength(1));
  });
  testWidgets(
    'local storage retry saves the session without calling completion again',
    (tester) async {
      await pump(tester);
      storage.failures = 1;
      await confirm(tester);
      await tester.pumpAndSettle();
      expect(find.text(AppTexts.registrationSessionSaveFailed), findsWidgets);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(AppTexts.retry));
      await tester.tap(find.text(AppTexts.retry));
      await tester.pumpAndSettle();
      expect(api.pins, ['00123']);
      expect(find.text(AppTexts.registrationCompletedMessage), findsOneWidget);
    },
  );
  testWidgets(
    'success Continue enters protected Home and removes registration history',
    (tester) async {
      await pump(tester, router: true);
      await confirm(tester);
      await tester.pumpAndSettle();
      expect(find.text(AppTexts.registrationCompletedMessage), findsOneWidget);
      final router = container.read(appRouterProvider);
      await tester.tap(find.text(AppTexts.continueLabel));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, AppRoutes.home);
      expect(router.canPop(), isFalse);
      expect(find.text('ada@example.com'), findsOneWidget);
      expect(profile.fetches, 1);
    },
  );
  testWidgets('expiry after OTP verification disables PIN confirmation', (
    tester,
  ) async {
    await pump(tester);
    now = DateTime.utc(2030, 1, 1, 0, 30);
    await confirm(tester);
    await tester.pumpAndSettle();
    expect(api.pins, isEmpty);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(find.text(AppTexts.restartRecovery), findsOneWidget);
  });
  testWidgets(
    'Back from success continues once instead of restarting registration',
    (tester) async {
      await pump(tester);
      await confirm(tester);
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(completed, 1);
      expect(api.pins, ['00123']);
    },
  );
}
