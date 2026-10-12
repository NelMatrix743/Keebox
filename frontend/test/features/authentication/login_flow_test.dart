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
import 'package:keebox/features/authentication/storage/auth_session_storage.dart';
import 'package:keebox/features/authentication/authentication_api.dart';
import 'package:keebox/features/authentication/state/authentication_controller.dart';
import 'package:keebox/features/authentication/state/authentication_state.dart';
import 'package:keebox/network/api_client.dart';
import 'package:keebox/network/api_endpoints.dart';
import 'package:keebox/network/api_session.dart';

void main() {
  testWidgets(
    'valid login posts credentials once and opens the PIN lock screen',
    (tester) async {
      final adapter = _LoginAdapter();
      final container = await _pumpLogin(tester, adapter);
      await _enterCredentials(
        tester,
        email: ' user@example.com ',
        password: ' secret ',
      );
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(adapter.requests, hasLength(1));
      final request = adapter.requests.single;
      expect(request.uri.toString(), APIEndpoints.login);
      expect(request.method, 'POST');
      expect(request.data, {
        'email': 'user@example.com',
        'password': ' secret ',
      });
      expect(request.headers['Authorization'], isNull);
      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        AppRoutes.homeLock,
      );
      expect(find.text(AppTexts.enterPinToProceed), findsOneWidget);
      final pending =
          container.read(authenticationControllerProvider).requireValue
              as AwaitingPin;
      expect(pending.challenge.loginChallengeId, 'challenge-id');
      expect(container.read(apiSessionProvider).accessToken, isNull);
      expect(
        await container.read(authenticationSessionStorageProvider).read(),
        isNull,
      );
      expect(adapter.requests, hasLength(1));
      container.read(appRouterProvider).goNamed(AppRoutes.signInName);
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).last)
            .controller!
            .text,
        isEmpty,
      );
    },
  );

  testWidgets(
    'invalid form values keep inline errors and never send a request',
    (tester) async {
      final adapter = _LoginAdapter();
      await _pumpLogin(tester, adapter);
      await tester.enterText(find.byType(TextFormField).first, 'invalid-email');
      await tester.ensureVisible(find.text(AppTexts.login));
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);
      expect(adapter.requests, isEmpty);
    },
  );

  testWidgets(
    'backend error stays on login with a red bottom snackbar and allows retry',
    (tester) async {
      final adapter = _LoginAdapter()..rejectCredentials = true;
      final container = await _pumpLogin(tester, adapter);
      await _enterCredentials(tester);
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        AppRoutes.signIn,
      );
      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(bar.backgroundColor, Colors.red);
      expect(bar.behavior, SnackBarBehavior.fixed);
      expect(
        tester
            .widget<Text>(find.text('Invalid email address or password.'))
            .style!
            .color,
        Colors.white,
      );
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).last)
            .controller!
            .text,
        'secret',
      );
      adapter.rejectCredentials = false;
      await tester.ensureVisible(find.text(AppTexts.login));
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(adapter.requests, hasLength(2));
      expect(find.text(AppTexts.enterPinToProceed), findsOneWidget);
      expect(find.text('Invalid email address or password.'), findsNothing);
    },
  );

  testWidgets(
    'connection failures restore login controls and show network feedback',
    (tester) async {
      final adapter = _LoginAdapter()..connectionFailure = true;
      await _pumpLogin(tester, adapter);
      await _enterCredentials(tester);
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text('Unable to connect to the server.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('the PIN lock screen cannot open without a login challenge', (
    tester,
  ) async {
    final container = await _pumpLogin(tester, _LoginAdapter());
    container.read(appRouterProvider).goNamed(AppRoutes.homeLockName);
    await tester.pumpAndSettle();
    expect(
      container.read(appRouterProvider).routeInformationProvider.value.uri.path,
      AppRoutes.signIn,
    );
  });

}

Future<ProviderContainer> _pumpLogin(
  WidgetTester tester,
  _LoginAdapter adapter,
) async {
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
  final router = container.read(appRouterProvider);
  router.goNamed(AppRoutes.signInName);
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
  return container;
}

Future<void> _enterCredentials(
  WidgetTester tester, {
  String email = 'user@example.com',
  String password = 'secret',
}) async {
  await tester.enterText(find.byType(TextFormField).first, email);
  await tester.enterText(find.byType(TextFormField).last, password);
  await tester.ensureVisible(find.text(AppTexts.login));
}

class _LoginAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  bool rejectCredentials = false;
  bool connectionFailure = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (connectionFailure) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    }
    return ResponseBody.fromString(
      jsonEncode({
        'success': !rejectCredentials,
        'data': rejectCredentials
            ? null
            : {
                'login_challenge_id': 'challenge-id',
                'status': 'password_verified',
                'expires_at': '2030-01-01T00:00:00Z',
                'message': 'Enter your lock PIN.',
              },
        'error': rejectCredentials
            ? {
                'code': 'invalid_login_credentials',
                'message': 'Invalid email address or password.',
                'details': null,
              }
            : null,
        'meta': null,
      }),
      rejectCredentials ? 401 : 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
