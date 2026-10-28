import 'package:dio/dio.dart';
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
import 'package:keebox/features/authentication/state/authentication_controller.dart';
import 'package:keebox/features/authentication/state/authentication_state.dart';
import 'package:keebox/features/authentication/state/registration_controller.dart';
import 'package:keebox/features/authentication/storage/auth_session_storage.dart';
import 'package:keebox/features/authentication/storage/user_storage.dart';
import 'package:keebox/features/pin/services/local_pin_hasher.dart';
import 'package:keebox/features/pin/storage/local_pin_storage.dart';
import 'package:keebox/network/api_client.dart';
import 'package:keebox/network/api_endpoints.dart';
import 'package:keebox/network/api_session.dart';

import 'support/registration_fixture.dart';
import 'support/registration_http_adapter.dart';

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

  testWidgets(
    'registration HTTP journey resends OTP, saves credentials, opens Home and restores local unlock',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final server = RegistrationHttpAdapter();
      final container = _container(server, AppRoutes.signIn);
      var disposed = false;
      addTearDown(() {
        if (!disposed) container.dispose();
      });
      await _pumpApp(tester, container);
      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();
      await _submitDetails(tester);
      expect(server.requests.single.data, {
        'first_name': 'Ada',
        'last_name': 'Lovelace',
        'email': 'ada@example.com',
        'password': 'strong password',
      });
      expect(container.read(apiSessionProvider).accessToken, isNull);
      expect(
        await container.read(authenticationSessionStorageProvider).read(),
        isNull,
      );

      // Resend is driven by server deadlines and resets the shared OTP entry.
      await tester.enterText(find.byType(TextField).first, '001234');
      server.now = server.now.add(const Duration(seconds: 61));
      await tester.pump(const Duration(seconds: 1));
      await tester.ensureVisible(find.text(AppTexts.resendCode));
      await tester.tap(find.text(AppTexts.resendCode));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        isEmpty,
      );
      await tester.enterText(find.byType(TextField).first, '009876');
      await tester.pump();
      await tester.tap(find.text(AppTexts.continueLabel));
      await tester.pumpAndSettle();
      expect(
        await container.read(authenticationSessionStorageProvider).read(),
        isNull,
      );
      await _enterPin(tester);
      await tester.ensureVisible(find.text(AppTexts.confirm));
      await tester.tap(find.text(AppTexts.confirm));
      await tester.pumpAndSettle();
      expect(find.text(AppTexts.registrationCompletedMessage), findsOneWidget);
      expect(server.requests.map((r) => r.path), [
        APIEndpoints.register,
        APIEndpoints.registerResendOtp,
        APIEndpoints.registerVerifyOtp,
        APIEndpoints.registerCreatePin,
      ]);
      expect(
        server.requests.every(
          (r) => r.method == 'POST' && !r.headers.containsKey('Authorization'),
        ),
        isTrue,
      );
      expect(server.requests.last.data, {
        'registration_id': registrationId,
        'pin': '00123',
      });
      expect(
        (await container
                .read(authenticatedUserStorageProvider)
                .read(registeredUser.id))!
            .kbkey,
        registeredUser.kbkey,
      );
      expect(
        await container.read(localPinStorageProvider).read(registeredUser.id),
        isNotNull,
      );

      await tester.tap(find.text(AppTexts.continueLabel));
      await tester.pumpAndSettle();
      expect(_path(container), AppRoutes.home);
      expect(container.read(appRouterProvider).canPop(), isFalse);
      expect(find.text('Augusta Ada'), findsOneWidget);
      expect(server.requests.last.path, APIEndpoints.currentUser);
      expect(
        server.requests.last.headers['Authorization'],
        'Bearer new-access',
      );
      expect(
        (await container
                .read(authenticatedUserStorageProvider)
                .read(registeredUser.id))!
            .kbkey,
        registeredUser.kbkey,
      );
      final requestsBeforeRestart = server.requests.length;

      // A fresh provider graph restores from secure storage, without registering again.
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      disposed = true;
      final restored = _container(server, AppRoutes.homeLock);
      addTearDown(restored.dispose);
      // Native startup resolves the coordinator before the router is mounted.
      expect(
        await restored.read(startupCoordinatorProvider.future),
        AppRoutes.homeLock,
      );
      await _pumpApp(tester, restored);
      expect(
        restored.read(authenticationControllerProvider).requireValue,
        isA<AuthenticatedLocked>(),
      );
      expect(find.text(AppTexts.enterPinToProceed), findsOneWidget);
      await _enterPin(tester);
      await tester.pumpAndSettle();
      expect(_path(restored), AppRoutes.home);
      expect(find.text('Augusta Ada'), findsOneWidget);
      expect(server.requests, hasLength(requestsBeforeRestart));
    },
  );
}

ProviderContainer _container(RegistrationHttpAdapter server, String route) =>
    ProviderContainer(
      overrides: [
        apiClientProvider.overrideWith((ref) {
          final client = APIClient(
            dio: Dio()..httpClientAdapter = server,
            session: ref.watch(apiSessionProvider),
          );
          ref.onDispose(client.close);
          return client;
        }),
        localPinHasherProvider.overrideWithValue(TestPinHasher()),
        registrationClockProvider.overrideWithValue(() => server.now),
        initialRouteProvider.overrideWithValue(route),
      ],
    );

Future<void> _pumpApp(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: ScreenUtilInit(
        designSize: const Size(402, 874),
        minTextAdapt: true,
        builder: (_, child) => MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: container.read(appRouterProvider),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _submitDetails(WidgetTester tester) async {
  for (final entry in ['Ada', 'Lovelace', 'ada@example.com'].indexed) {
    await tester.enterText(find.byType(TextFormField).at(entry.$1), entry.$2);
  }
  await tester.tap(find.text(AppTexts.next));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).first, 'strong password');
  await tester.enterText(find.byType(TextFormField).last, 'strong password');
  await tester.tap(find.text(AppTexts.continueLabel));
  await tester.pumpAndSettle();
}

Future<void> _enterPin(WidgetTester tester) async {
  for (final digit in '00123'.split('')) {
    final key = find.byKey(ValueKey('pin-key-$digit'));
    await tester.ensureVisible(key);
    await tester.tap(key);
    await tester.pump();
  }
}

String _path(ProviderContainer container) =>
    container.read(appRouterProvider).routeInformationProvider.value.uri.path;
