import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/app/router/app_router.dart';
import 'package:keebox/app/router/app_routes.dart';
import 'package:keebox/app/theme/app_theme.dart';
import 'package:keebox/features/authentication/authentication_api.dart';
import 'package:keebox/features/authentication/state/authentication_controller.dart';
import 'package:keebox/features/authentication/state/authentication_state.dart';
import 'package:keebox/features/authentication/storage/auth_session_storage.dart';
import 'package:keebox/features/authentication/storage/user_storage.dart';
import 'package:keebox/features/pin/widgets/pin_indicator_row.dart';
import 'package:keebox/network/api_client.dart';
import 'package:keebox/network/api_endpoints.dart';
import 'package:keebox/network/api_session.dart';

void main() {
  testWidgets(
    'password and PIN login store the session and open protected Home',
    (tester) async {
      final adapter = _Adapter();
      final container = await _pump(tester, adapter);
      await _enterPin(tester, '01234');
      await tester.pumpAndSettle();
      final pinRequest = adapter.requests.last;
      expect(pinRequest.uri.toString(), APIEndpoints.loginVerifyPin);
      expect(pinRequest.method, 'POST');
      expect(pinRequest.data, {
        'login_challenge_id': 'challenge-id',
        'pin': '01234',
      });
      expect(pinRequest.headers['Authorization'], isNull);
      expect(adapter.requests, hasLength(2));
      expect(_path(container), AppRoutes.home);
      expect(find.text(AppTexts.homePlaceholder), findsOneWidget);
      expect(
        container.read(authenticationControllerProvider).requireValue,
        isA<Authenticated>(),
      );
      expect(container.read(apiSessionProvider).accessToken, 'access');
      expect(
        (await container.read(authenticationSessionStorageProvider).read())!
            .refreshToken,
        'refresh',
      );
      expect(
        (await container
                .read(authenticatedUserStorageProvider)
                .read('user-id'))!
            .kbkey,
        'permanent-key',
      );
    },
  );

  testWidgets(
    'wrong PIN clears indicators and shows an error before a successful retry',
    (tester) async {
      final adapter = _Adapter()..errorCode = 'invalid_login_pin';
      final container = await _pump(tester, adapter);
      await _enterPin(tester, '11111');
      await tester.pumpAndSettle();
      expect(_path(container), AppRoutes.homeLock);
      expect(
        tester
            .widget<PinIndicatorRow>(find.byType(PinIndicatorRow))
            .filledCount,
        0,
      );
      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(bar.backgroundColor, Colors.red);
      expect(bar.behavior, SnackBarBehavior.fixed);
      expect(
        tester.widget<Text>(find.text('PIN rejected.')).style!.color,
        Colors.white,
      );
      expect(container.read(apiSessionProvider).accessToken, isNull);
      adapter.errorCode = null;
      await _enterPin(tester, '01234');
      await tester.pumpAndSettle();
      expect(_path(container), AppRoutes.home);
      expect(find.text('PIN rejected.'), findsNothing);
    },
  );

  for (final code in ['expired_login_challenge', 'login_pin_attempt_limit']) {
    testWidgets('$code returns to password login with error feedback', (
      tester,
    ) async {
      final adapter = _Adapter()..errorCode = code;
      final container = await _pump(tester, adapter);
      await _enterPin(tester, '11111');
      await tester.pumpAndSettle();
      expect(_path(container), AppRoutes.signIn);
      expect(find.text('PIN rejected.'), findsOneWidget);
      expect(
        container.read(authenticationControllerProvider).requireValue,
        isA<Unauthenticated>(),
      );
      expect(
        await container.read(authenticationSessionStorageProvider).read(),
        isNull,
      );
    });
  }

  testWidgets(
    'verification disables input and cannot unlock Home before the response',
    (tester) async {
      final adapter = _Adapter()..gate = Completer<void>();
      final container = await _pump(tester, adapter);
      await _enterPin(tester, '01234');
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(_path(container), AppRoutes.homeLock);
      expect(
        await container.read(authenticationSessionStorageProvider).read(),
        isNull,
      );
      for (final button in tester.widgetList<OutlinedButton>(
        find.byType(OutlinedButton),
      )) {
        expect(button.onPressed, isNull);
      }
      adapter.gate!.complete();
      await tester.pumpAndSettle();
      expect(adapter.requests, hasLength(2));
      expect(_path(container), AppRoutes.home);
    },
  );

  testWidgets(
    'Home rejects a pending login and redirects after session invalidation',
    (tester) async {
      final container = await _pump(tester, _Adapter());
      container.read(appRouterProvider).goNamed(AppRoutes.homeName);
      await tester.pumpAndSettle();
      expect(_path(container), AppRoutes.signIn);
      container.read(appRouterProvider).goNamed(AppRoutes.homeLockName);
      await tester.pumpAndSettle();
      await _enterPin(tester, '01234');
      await tester.pumpAndSettle();
      expect(_path(container), AppRoutes.home);
      await container.read(apiSessionProvider).invalidate('access');
      await tester.pumpAndSettle();
      expect(_path(container), AppRoutes.signIn);
      container.read(appRouterProvider).goNamed(AppRoutes.homeName);
      await tester.pumpAndSettle();
      expect(_path(container), AppRoutes.signIn);
    },
  );

  testWidgets(
    'leaving during verification cannot save or navigate on a late response',
    (tester) async {
      final adapter = _Adapter()..gate = Completer<void>();
      final container = await _pump(tester, adapter);
      await _enterPin(tester, '01234');
      container.read(appRouterProvider).goNamed(AppRoutes.signInName);
      await tester.pumpAndSettle();
      adapter.gate!.complete();
      await tester.pumpAndSettle();
      expect(_path(container), AppRoutes.signIn);
      expect(container.read(apiSessionProvider).accessToken, isNull);
      expect(
        await container.read(authenticationSessionStorageProvider).read(),
        isNull,
      );
    },
  );
}

String _path(ProviderContainer container) =>
    container.read(appRouterProvider).routeInformationProvider.value.uri.path;

Future<void> _enterPin(WidgetTester tester, String pin) async {
  for (final digit in pin.split('')) {
    await tester.tap(find.byKey(ValueKey('pin-key-$digit')));
    await tester.pump();
  }
}

Future<ProviderContainer> _pump(WidgetTester tester, _Adapter adapter) async {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  FlutterSecureStorage.setMockInitialValues({});
  final client = APIClient(dio: Dio()..httpClientAdapter = adapter);
  final container = ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue(client),
      authenticationApiProvider.overrideWithValue(
        AuthenticationAPI(client: client),
      ),
    ],
  );
  addTearDown(() {
    container.dispose();
    client.close();
  });
  final router = container.read(appRouterProvider)
    ..goNamed(AppRoutes.signInName);
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
  await tester.enterText(find.byType(TextFormField).first, 'ada@example.com');
  await tester.enterText(find.byType(TextFormField).last, 'secret');
  await tester.ensureVisible(find.text(AppTexts.login));
  await tester.tap(find.byType(FilledButton));
  await tester.pumpAndSettle();
  return container;
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  String? errorCode;
  Completer<void>? gate;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final isPin = options.uri.path.endsWith('/verify-pin');
    if (isPin && gate != null) await gate!.future;
    final code = isPin ? errorCode : null;
    final data = isPin
        ? {
            'user_id': 'user-id',
            'first_name': 'Ada',
            'last_name': 'Lovelace',
            'email': 'ada@example.com',
            'kbkey': 'permanent-key',
            'access_token': 'access',
            'refresh_token': 'refresh',
            'status': 'completed',
            'message': 'Login completed.',
          }
        : {
            'login_challenge_id': 'challenge-id',
            'expires_at': '2030-01-01T00:00:00Z',
            'status': 'password_verified',
            'message': 'Enter PIN.',
          };
    return ResponseBody.fromString(
      jsonEncode({
        'success': code == null,
        'data': code == null ? data : null,
        'error': code == null
            ? null
            : {'code': code, 'message': 'PIN rejected.', 'details': null},
        'meta': null,
      }),
      code == null
          ? 200
          : code == 'expired_login_challenge'
          ? 410
          : code == 'login_pin_attempt_limit'
          ? 423
          : 400,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
