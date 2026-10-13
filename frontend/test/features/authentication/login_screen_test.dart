import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keebox/app/theme/app_theme.dart';
import 'package:keebox/features/authentication/authentication_api.dart';
import 'package:keebox/features/authentication/models/login_challenge.dart';
import 'package:keebox/features/authentication/models/login_request.dart';
import 'package:keebox/features/authentication/screens/login_screen.dart';
import 'package:keebox/network/api_client.dart';

void main() {
  late _LoginAPI api;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    api = _LoginAPI();
  });
  tearDown(() => api.client.close());
  testWidgets('login requires an email and password before submitting', (
    tester,
  ) async {
    _usePhoneViewport(tester);
    var submitted = false;
    await tester.pumpWidget(
      _app(LoginScreen(onLoginVerified: (_) => submitted = true), api: api),
    );
    await tester.tap(find.text('Login'));
    await tester.pump();
    expect(find.text('Enter your email address'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
    expect(submitted, isFalse);
    expect(api.request, isNull);
  });

  testWidgets(
    'visibility toggle preserves the password and login submits inputs',
    (tester) async {
      _usePhoneViewport(tester);
      var verified = false;
      await tester.pumpWidget(
        _app(LoginScreen(onLoginVerified: (_) => verified = true), api: api),
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
      await tester.pumpAndSettle();
      expect(api.request!.email, 'user@example.com');
      expect(api.request!.password, 'private-password');
      expect(verified, isTrue);
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
        _app(
          LoginScreen(onRegister: () => registered = true),
          api: api,
          keyboard: true,
        ),
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'password');
      await tester.ensureVisible(find.text('Register'));
      await tester.tap(find.text('Register'));
      expect(registered, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _app(Widget screen, {required _LoginAPI api, bool keyboard = false}) {
  return ProviderScope(
    overrides: [authenticationApiProvider.overrideWithValue(api)],
    child: ScreenUtilInit(
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
        home: screen,
      ),
    ),
  );
}

class _LoginAPI extends AuthenticationAPI {
  _LoginAPI() : super(client: APIClient());
  LoginRequest? request;

  @override
  Future<LoginChallenge> login(
    LoginRequest request, {
    CancelToken? cancelToken,
  }) async {
    this.request = request;
    return LoginChallenge(
      loginChallengeId: 'challenge-id',
      expiresAt: DateTime.utc(2030),
      message: 'Enter your PIN.',
    );
  }
}

void _usePhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
