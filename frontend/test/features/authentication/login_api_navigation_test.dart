import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keebox/features/authentication/authentication_api.dart';
import 'package:keebox/features/authentication/models/authenticated_user.dart';
import 'package:keebox/features/authentication/models/authentication_result.dart';
import 'package:keebox/features/authentication/models/authentication_session.dart';
import 'package:keebox/features/authentication/models/login_challenge.dart';
import 'package:keebox/features/authentication/models/login_pin_request.dart';
import 'package:keebox/features/authentication/models/login_request.dart';
import 'package:keebox/features/authentication/storage/auth_session_storage.dart';
import 'package:keebox/features/authentication/storage/user_storage.dart';
import 'package:keebox/main.dart';
import 'package:keebox/network/api_client.dart';
import 'package:keebox/network/api_exception.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets(
    'login and PIN verification authenticate and persist both data groups',
    (tester) async {
      final api = _API();
      addTearDown(api.client.close);
      await _openLogin(tester, api);
      await _submitCredentials(tester);
      expect(find.text('Verify your PIN'), findsOneWidget);
      expect(api.loginRequest!.email, ' user@example.com ');
      expect(api.loginRequest!.password, ' secret ');
      await tester.enterText(find.byType(TextFormField), '0012');
      await tester.tap(find.text('Verify PIN'));
      await tester.pumpAndSettle();
      expect(api.pinRequest!.loginChallengeId, 'challenge-id');
      expect(api.pinRequest!.pin, '0012');
      expect(find.text('You are signed in.'), findsOneWidget);
      const secure = FlutterSecureStorage();
      expect(
        (await AuthenticationSessionStorage(
          storage: secure,
        ).read())!.accessToken,
        'access-token',
      );
      expect(
        (await const AuthenticatedUserStorage(storage: secure).read('user-id'))!
            .kbkey,
        'permanent-key',
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Welcome Back!'), findsNothing);
    },
  );

  testWidgets('login error is visible and the user can retry', (tester) async {
    final api = _API()..failLogin = true;
    addTearDown(api.client.close);
    await _openLogin(tester, api);
    await _submitCredentials(tester);
    expect(find.text('Invalid credentials.'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Verify your PIN'), findsNothing);
    api.failLogin = false;
    await tester.ensureVisible(find.text('Login'));
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();
    expect(find.text('Verify your PIN'), findsOneWidget);
  });

  testWidgets(
    'PIN error stays on verification and restarting returns to login',
    (tester) async {
      final api = _API()..failPin = true;
      addTearDown(api.client.close);
      await _openLogin(tester, api);
      await _submitCredentials(tester);
      await tester.enterText(find.byType(TextFormField), '0000');
      await tester.tap(find.text('Verify PIN'));
      await tester.pumpAndSettle();
      expect(find.text('Invalid PIN.'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('You are signed in.'), findsNothing);
      await tester.tap(find.text('Sign in again'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome Back!'), findsOneWidget);
    },
  );
}

Future<void> _openLogin(WidgetTester tester, _API api) async {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authenticationApiProvider.overrideWithValue(api)],
      child: const KeeboxApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Sign In'));
  await tester.pumpAndSettle();
}

Future<void> _submitCredentials(WidgetTester tester) async {
  await tester.enterText(
    find.byType(TextFormField).at(0),
    ' user@example.com ',
  );
  await tester.enterText(find.byType(TextFormField).at(1), ' secret ');
  await tester.ensureVisible(find.text('Login'));
  await tester.tap(find.text('Login'));
  await tester.pumpAndSettle();
}

class _API extends AuthenticationAPI {
  _API() : super(client: APIClient());
  LoginRequest? loginRequest;
  LoginPinRequest? pinRequest;
  bool failLogin = false;
  bool failPin = false;

  @override
  Future<LoginChallenge> login(
    LoginRequest request, {
    CancelToken? cancelToken,
  }) async {
    loginRequest = request;
    if (failLogin) {
      throw const APIException(
        kind: APIErrorKind.api,
        code: 'invalid_login_credentials',
        message: 'Invalid credentials.',
      );
    }
    return LoginChallenge(
      loginChallengeId: 'challenge-id',
      expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      message: 'Enter PIN.',
    );
  }

  @override
  Future<AuthenticationResult> verifyPin(
    LoginPinRequest request, {
    CancelToken? cancelToken,
  }) async {
    pinRequest = request;
    if (failPin) {
      throw const APIException(
        kind: APIErrorKind.api,
        code: 'invalid_login_pin',
        message: 'Invalid PIN.',
      );
    }
    return const AuthenticationResult(
      user: AuthenticatedUser(
        id: 'user-id',
        firstName: 'Ada',
        lastName: 'Lovelace',
        email: 'user@example.com',
        kbkey: 'permanent-key',
      ),
      session: AuthenticationSession(
        userId: 'user-id',
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
      ),
      message: 'Completed.',
    );
  }
}
