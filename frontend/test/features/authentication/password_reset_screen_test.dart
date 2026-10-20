import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/app/theme/app_theme.dart';
import 'package:keebox/assets/app_assets.dart';
import 'package:keebox/features/authentication/models/password_reset_request.dart';
import 'package:keebox/features/authentication/models/recovery_challenge.dart';
import 'package:keebox/features/authentication/models/recovery_completed.dart';
import 'package:keebox/features/authentication/models/recovery_start_request.dart';
import 'package:keebox/features/authentication/models/recovery_type.dart';
import 'package:keebox/features/authentication/models/recovery_verified.dart';
import 'package:keebox/features/authentication/models/recovery_verify_request.dart';
import 'package:keebox/features/authentication/recovery_api.dart';
import 'package:keebox/features/authentication/screens/password_reset_screen.dart';
import 'package:keebox/features/authentication/state/recovery_controller.dart';
import 'package:keebox/network/api_client.dart';
import 'package:keebox/network/api_exception.dart';

void main() {
  late _API api;
  late ProviderContainer container;
  late RecoveryScope scope;
  late DateTime now;
  late int completed;
  late int restarted;
  late int loginRequired;
  setUp(() {
    now = DateTime.utc(2030);
    api = _API(() => now);
    scope = (identity: Object(), type: RecoveryType.password);
    completed = restarted = loginRequired = 0;
    container = ProviderContainer(
      overrides: [
        recoveryApiProvider.overrideWithValue(api),
        recoveryClockProvider.overrideWithValue(() => now),
      ],
    );
    container.listen(recoveryControllerProvider(scope), (_, _) {});
  });
  tearDown(() {
    container.dispose();
    api.client.close();
  });
  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(402, 874),
    double textScale = 1,
    double keyboard = 0,
    bool navigable = false,
  }) async {
    final controller = container.read(
      recoveryControllerProvider(scope).notifier,
    );
    await controller.start('ada@example.com');
    await controller.verifyOtp('001234');
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final screen = PasswordResetScreen(
      scope: scope,
      onCompleted: (_) => completed++,
      onRestart: () => restarted++,
      onLoginRequired: () => loginRequired++,
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ScreenUtilInit(
          designSize: const Size(402, 874),
          minTextAdapt: true,
          builder: (_, child) => MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                viewInsets: EdgeInsets.only(bottom: keyboard),
                textScaler: TextScaler.linear(textScale),
              ),
              child: child!,
            ),
            home: navigable
                ? Builder(
                    builder: (context) => Scaffold(
                      body: TextButton(
                        key: const ValueKey('open-reset'),
                        onPressed: () => Navigator.of(
                          context,
                        ).push(MaterialPageRoute<void>(builder: (_) => screen)),
                        child: const Text('Open'),
                      ),
                    ),
                  )
                : screen,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (navigable) {
      await tester.tap(find.byKey(const ValueKey('open-reset')));
      await tester.pumpAndSettle();
    }
  }

  Future<void> fill(
    WidgetTester tester, [
    String password = ' strong password 7349 ',
  ]) async {
    await tester.enterText(find.byType(TextFormField).first, password);
    await tester.enterText(find.byType(TextFormField).last, password);
    await tester.pump();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
  }

  testWidgets(
    'required fields and mismatched confirmation never call the API',
    (tester) async {
      await pump(tester);
      await submit(tester);
      await tester.pumpAndSettle();
      expect(find.text(AppTexts.recoveryPasswordRequired), findsOneWidget);
      expect(find.text(AppTexts.confirmPasswordRequired), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).first,
        'a strong password',
      );
      await tester.enterText(
        find.byType(TextFormField).last,
        'different password',
      );
      await submit(tester);
      await tester.pumpAndSettle();
      expect(find.text(AppTexts.passwordsDoNotMatch), findsOneWidget);
      expect(api.requests, isEmpty);
    },
  );

  testWidgets(
    'visibility is independent and uses supplied assets without changing text',
    (tester) async {
      await pump(tester);
      await fill(tester);
      await tester.tap(find.byTooltip(AppTexts.showPassword).first);
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).obscureText,
        isFalse,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).last).obscureText,
        isTrue,
      );
      final icon = tester.widget<Image>(
        find.descendant(
          of: find.byTooltip(AppTexts.hidePassword),
          matching: find.byType(Image),
        ),
      );
      expect((icon.image as AssetImage).assetName, AppAssets.passwordVisible);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        ' strong password 7349 ',
      );
    },
  );

  testWidgets(
    'submission preserves password whitespace, disables controls and completes once',
    (tester) async {
      await pump(tester);
      await fill(tester);
      api.pending = Completer<RecoveryCompleted>();
      await submit(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester
            .widgetList<TextFormField>(find.byType(TextFormField))
            .every((field) => !field.enabled),
        isTrue,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(api.requests.single.newPassword, ' strong password 7349 ');
      api.pending!.complete(api.completed());
      await tester.pumpAndSettle();
      expect(completed, 1);
      expect(
        tester
            .widgetList<TextField>(find.byType(TextField))
            .every((field) => field.controller!.text.isEmpty),
        isTrue,
      );
    },
  );

  testWidgets(
    'backend policy errors stay inline and show a red snackbar until corrected',
    (tester) async {
      await pump(tester);
      await fill(tester);
      api.failure = const APIException(
        kind: APIErrorKind.api,
        code: 'validation_error',
        message: 'Invalid data.',
        statusCode: 422,
        details: [
          {
            'location': ['body', 'payload', 'new_password'],
            'message': 'This password is too common.',
          },
        ],
      );
      await submit(tester);
      await tester.pumpAndSettle();
      expect(find.text('This password is too common.'), findsOneWidget);
      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).backgroundColor,
        Colors.red,
      );
      api.failure = null;
      await fill(tester, 'different strong password');
      await submit(tester);
      await tester.pumpAndSettle();
      expect(completed, 1);
      expect(api.requests, hasLength(2));
    },
  );

  testWidgets('uncertain completion blocks resubmission and offers login', (
    tester,
  ) async {
    await pump(tester);
    await fill(tester);
    api.failure = const APIException(
      kind: APIErrorKind.timeout,
      message: 'Timeout',
    );
    await submit(tester);
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(find.text(AppTexts.recoveryCompletionUncertain), findsNWidgets(2));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(AppTexts.backToLogin));
    await tester.tap(find.text(AppTexts.backToLogin));
    await tester.pumpAndSettle();
    expect(loginRequired, 1);
    expect(api.requests, hasLength(1));
  });

  testWidgets(
    'expired completion window offers restart and blocks submission',
    (tester) async {
      await pump(tester);
      now = now.add(const Duration(minutes: 10));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text(AppTexts.restartRecovery), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.tap(find.text(AppTexts.restartRecovery));
      await tester.pumpAndSettle();
      expect(restarted, 1);
      expect(api.requests, isEmpty);
    },
  );

  testWidgets(
    'back navigation cancels submission and ignores its late result',
    (tester) async {
      await pump(tester, navigable: true);
      await fill(tester);
      api.pending = Completer<RecoveryCompleted>();
      await submit(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(api.token!.isCancelled, isTrue);
      api.pending!.complete(api.completed());
      await tester.pumpAndSettle();
      expect(completed, 0);
    },
  );

  testWidgets('small viewport with keyboard and large text remains usable', (
    tester,
  ) async {
    await pump(tester, size: const Size(320, 568), keyboard: 220, textScale: 2);
    await fill(tester);
    await submit(tester);
    await tester.pumpAndSettle();
    expect(completed, 1);
    expect(tester.takeException(), isNull);
  });
}

class _API extends RecoveryAPI {
  _API(this.now) : super(client: APIClient());
  final DateTime Function() now;
  final requests = <PasswordResetRequest>[];
  APIException? failure;
  Completer<RecoveryCompleted>? pending;
  CancelToken? token;
  static const id = '12345678-1234-1234-1234-123456789abc';
  RecoveryCompleted completed() => const RecoveryCompleted(
    resetId: id,
    message: 'Password reset completed. Sign in again.',
  );
  @override
  Future<RecoveryChallenge> start(
    RecoveryType type,
    RecoveryStartRequest request, {
    CancelToken? cancelToken,
  }) async => RecoveryChallenge(
    resetId: id,
    otpExpiresAt: now().add(const Duration(minutes: 5)),
    resendAvailableAt: now().add(const Duration(seconds: 60)),
    message: 'Code sent.',
  );
  @override
  Future<RecoveryVerified> verifyOtp(
    RecoveryVerifyRequest request, {
    CancelToken? cancelToken,
  }) async => RecoveryVerified(
    resetId: id,
    completionExpiresAt: now().add(const Duration(minutes: 10)),
    message: 'Email verified.',
  );
  @override
  Future<RecoveryCompleted> completePassword(
    PasswordResetRequest request, {
    CancelToken? cancelToken,
  }) async {
    token = cancelToken;
    requests.add(request);
    if (failure != null) throw failure!;
    return pending == null ? completed() : await pending!.future;
  }
}
