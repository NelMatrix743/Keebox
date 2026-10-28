import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/app/theme/app_theme.dart';
import 'package:keebox/features/authentication/models/recovery_response.dart';
import 'package:keebox/features/authentication/models/recovery_requests.dart';
import 'package:keebox/features/authentication/models/recovery_type.dart';
import 'package:keebox/features/authentication/recovery_api.dart';
import 'package:keebox/features/authentication/screens/otp_verification_screen.dart';
import 'package:keebox/features/authentication/state/recovery_controller.dart';
import 'package:keebox/features/authentication/state/recovery_state.dart';
import 'package:keebox/features/authentication/state/otp_verification_flow.dart';
import 'package:keebox/network/api_client.dart';
import 'package:keebox/network/api_exception.dart';

void main() {
  late DateTime now;
  late _API api;
  late ProviderContainer container;
  late RecoveryScope scope;
  late int verified;
  late int restarted;
  setUp(() {
    now = DateTime.utc(2030);
    api = _API(() => now);
    scope = (identity: Object(), type: RecoveryType.password);
    verified = restarted = 0;
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
    await container
        .read(recoveryControllerProvider(scope).notifier)
        .start('ada@example.com');
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
                        key: const ValueKey('open-otp'),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => OtpVerificationScreen(
                              flow: OtpVerificationFlow.recovery(scope),
                              onVerified: () => verified++,
                              onRestart: () => restarted++,
                            ),
                          ),
                        ),
                        child: const Text('Open'),
                      ),
                    ),
                  )
                : OtpVerificationScreen(
                    flow: OtpVerificationFlow.recovery(scope),
                    onVerified: () => verified++,
                    onRestart: () => restarted++,
                  ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (navigable) {
      await tester.tap(find.byKey(const ValueKey('open-otp')));
      await tester.pumpAndSettle();
    }
  }

  Future<void> enterCode(WidgetTester tester, [String code = '001234']) async {
    await tester.enterText(find.byType(TextField).first, code);
    await tester.pump();
  }

  testWidgets(
    'Continue enables only for six digits and submits leading zeros once',
    (tester) async {
      await pump(tester);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await enterCode(tester);
      api.pending = Completer<RecoveryVerified>();
      await tester.tap(find.text(AppTexts.continueLabel));
      await tester.pump();
      expect(api.codes, ['001234']);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester
            .widgetList<TextField>(find.byType(TextField))
            .every((field) => !field.enabled!),
        isTrue,
      );
      api.pending!.complete(api.verified());
      await tester.pumpAndSettle();
      expect(verified, 1);
      expect(
        container.read(recoveryControllerProvider(scope)).stage,
        RecoveryStage.credential,
      );
    },
  );

  testWidgets(
    'back navigation cancels pending verification and rejects a late result',
    (tester) async {
      await pump(tester, navigable: true);
      await enterCode(tester);
      api.pending = Completer<RecoveryVerified>();
      await tester.tap(find.text(AppTexts.continueLabel));
      await tester.pump();
      await tester.tap(find.byTooltip(AppTexts.back));
      await tester.pumpAndSettle();
      expect(api.token!.isCancelled, isTrue);
      expect(
        container.read(recoveryControllerProvider(scope)).stage,
        RecoveryStage.email,
      );
      api.pending!.complete(api.verified());
      await tester.pumpAndSettle();
      expect(verified, 0);
    },
  );

  testWidgets(
    'locked OTP requires restart instead of another verification attempt',
    (tester) async {
      await pump(tester);
      await enterCode(tester);
      api.failure = const APIException(
        kind: APIErrorKind.api,
        code: 'locked_otp',
        message: 'Start again.',
        statusCode: 423,
      );
      await tester.tap(find.text(AppTexts.continueLabel));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextButton, AppTexts.restartRecovery),
        findsOneWidget,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        tester
            .widgetList<TextField>(find.byType(TextField))
            .every((field) => !field.enabled!),
        isTrue,
      );
    },
  );

  testWidgets(
    'incorrect OTP stays inline with a red snackbar and permits correction',
    (tester) async {
      await pump(tester);
      await enterCode(tester);
      api.failure = const APIException(
        kind: APIErrorKind.api,
        code: 'invalid_otp',
        message: 'Incorrect code.',
        statusCode: 400,
      );
      await tester.tap(find.text(AppTexts.continueLabel));
      await tester.pumpAndSettle();
      expect(find.text('Incorrect code.'), findsNWidgets(2));
      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).backgroundColor,
        Colors.red,
      );
      api.failure = null;
      await tester.enterText(find.byType(TextField).last, '5');
      await tester.pump();
      expect(find.text('Incorrect code.'), findsOneWidget);
      await tester.tap(find.text(AppTexts.continueLabel));
      await tester.pumpAndSettle();
      expect(api.codes, ['001234', '001235']);
      expect(verified, 1);
    },
  );

  testWidgets(
    'server cooldown controls resend and successful resend clears old digits',
    (tester) async {
      await pump(tester);
      expect(find.text('01:00'), findsOneWidget);
      expect(find.text(AppTexts.resendCode), findsNothing);
      await enterCode(tester);
      now = now.add(const Duration(seconds: 60));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text(AppTexts.resendCode));
      await tester.pumpAndSettle();
      expect(api.resends, 1);
      expect(find.text('01:00'), findsOneWidget);
      expect(
        tester
            .widgetList<TextField>(find.byType(TextField))
            .every((field) => field.controller!.text.isEmpty),
        isTrue,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'resend failure keeps entered digits and allows an explicit retry',
    (tester) async {
      await pump(tester);
      await enterCode(tester);
      now = now.add(const Duration(seconds: 60));
      await tester.pump(const Duration(seconds: 1));
      api.failure = const APIException(
        kind: APIErrorKind.connection,
        message: 'Offline',
      );
      await tester.tap(find.text(AppTexts.resendCode));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        '4',
      );
      api.failure = null;
      await tester.tap(find.text(AppTexts.resendCode));
      await tester.pumpAndSettle();
      expect(api.resends, 2);
    },
  );

  testWidgets('expiry after resume disables input and offers restart', (
    tester,
  ) async {
    await pump(tester);
    now = now.add(const Duration(minutes: 5));
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
    expect(api.codes, isEmpty);
  });

  testWidgets(
    'small screen, keyboard and enlarged text keep controls reachable',
    (tester) async {
      await pump(
        tester,
        size: const Size(320, 568),
        keyboard: 220,
        textScale: 2,
      );
      await enterCode(tester);
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(verified, 1);
      expect(tester.takeException(), isNull);
    },
  );
}

class _API extends RecoveryAPI {
  _API(this.now) : super(client: APIClient());
  final DateTime Function() now;
  final codes = <String>[];
  int resends = 0;
  APIException? failure;
  Completer<RecoveryVerified>? pending;
  CancelToken? token;
  RecoveryChallenge challenge() => RecoveryChallenge(
    resetId: '12345678-1234-1234-1234-123456789abc',
    otpExpiresAt: now().add(const Duration(minutes: 5)),
    resendAvailableAt: now().add(const Duration(seconds: 60)),
    message: 'If an account exists, a code has been sent.',
  );
  RecoveryVerified verified() => RecoveryVerified(
    resetId: challenge().resetId,
    completionExpiresAt: now().add(const Duration(minutes: 10)),
    message: 'Email verified.',
  );
  @override
  Future<RecoveryChallenge> start(
    RecoveryType type,
    RecoveryStartRequest request, {
    CancelToken? cancelToken,
  }) async => challenge();
  @override
  Future<RecoveryChallenge> resendOtp(
    RecoveryResendRequest request, {
    CancelToken? cancelToken,
  }) async {
    resends++;
    if (failure != null) throw failure!;
    return challenge();
  }

  @override
  Future<RecoveryVerified> verifyOtp(
    RecoveryVerifyRequest request, {
    CancelToken? cancelToken,
  }) async {
    token = cancelToken;
    codes.add(request.otpCode);
    if (failure != null) throw failure!;
    return pending == null ? verified() : await pending!.future;
  }
}
