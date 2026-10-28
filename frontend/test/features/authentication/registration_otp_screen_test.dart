import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/app/theme/app_theme.dart';
import 'package:keebox/features/authentication/models/registration_requests.dart';
import 'package:keebox/features/authentication/models/registration_response.dart';
import 'package:keebox/features/authentication/registration_api.dart';
import 'package:keebox/features/authentication/screens/otp_verification_screen.dart';
import 'package:keebox/features/authentication/state/otp_verification_flow.dart';
import 'package:keebox/features/authentication/state/registration_clock.dart';
import 'package:keebox/features/authentication/state/registration_controller.dart';
import 'package:keebox/features/authentication/state/registration_state.dart';
import 'package:keebox/network/api_client.dart';
import 'package:keebox/network/api_exception.dart';

void main() {
  late DateTime now;
  late _API api;
  late ProviderContainer container;
  late Object scope;
  late int verified;
  late int restarted;
  setUp(() async {
    now = DateTime.utc(2030);
    api = _API(() => now);
    verified = restarted = 0;
    scope = Object();
    container = ProviderContainer(
      overrides: [
        registrationApiProvider.overrideWithValue(api),
        registrationClockProvider.overrideWithValue(() => now),
      ],
    );
    container.listen(registrationControllerProvider(scope), (_, _) {});
    await container
        .read(registrationControllerProvider(scope).notifier)
        .start(
          const RegistrationRequest(
            firstName: 'Ada',
            lastName: 'Lovelace',
            email: 'ada@example.com',
            password: 'password',
          ),
        );
  });
  tearDown(() {
    container.dispose();
    api.client.close();
  });
  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ScreenUtilInit(
          designSize: const Size(402, 874),
          minTextAdapt: true,
          builder: (_, child) => MaterialApp(
            theme: AppTheme.light,
            home: OtpVerificationScreen(
              flow: OtpVerificationFlow.registration(scope),
              onVerified: () => verified++,
              onRestart: () => restarted++,
              onBack: () {
                container
                    .read(registrationControllerProvider(scope).notifier)
                    .restart();
                restarted++;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).first, '001234');
    await tester.pump();
    await tester.ensureVisible(find.text(AppTexts.continueLabel));
    await tester.tap(find.text(AppTexts.continueLabel));
  }

  testWidgets(
    'registration uses the six-digit shared screen and advances its own challenge',
    (tester) async {
      await pump(tester);
      expect(find.byType(TextField), findsNWidgets(6));
      expect(find.text('01:00'), findsOneWidget);
      await submit(tester);
      await tester.pumpAndSettle();
      expect(api.verifiedCodes, ['001234']);
      expect(
        container.read(registrationControllerProvider(scope)).stage,
        RegistrationStage.pin,
      );
      expect(verified, 1);
    },
  );
  testWidgets('wrong OTP stays editable with red error feedback', (
    tester,
  ) async {
    api.failure = const APIException(
      kind: APIErrorKind.api,
      code: 'invalid_otp',
      message: 'Incorrect code.',
      statusCode: 400,
    );
    await pump(tester);
    await submit(tester);
    await tester.pumpAndSettle();
    expect(verified, 0);
    expect(find.text('Incorrect code.'), findsWidgets);
    expect(
      tester.widget<SnackBar>(find.byType(SnackBar)).backgroundColor,
      Colors.red,
    );
    api.failure = null;
    await tester.tap(find.text(AppTexts.continueLabel));
    await tester.pumpAndSettle();
    expect(verified, 1);
  });
  testWidgets(
    'resend clears old digits and refreshes countdown without changing registration expiry',
    (tester) async {
      await pump(tester);
      final expiry = container
          .read(registrationControllerProvider(scope))
          .challenge!
          .expiresAt;
      await tester.enterText(find.byType(TextField).first, '001234');
      now = now.add(const Duration(seconds: 60));
      await tester.pump(const Duration(seconds: 1));
      await tester.ensureVisible(find.text(AppTexts.resendCode));
      await tester.tap(find.text(AppTexts.resendCode));
      await tester.pumpAndSettle();
      expect(api.resends, 1);
      expect(find.text('01:00'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        isEmpty,
      );
      expect(
        container
            .read(registrationControllerProvider(scope))
            .challenge!
            .expiresAt,
        expiry,
      );
    },
  );
  testWidgets(
    'last resend disables resend while allowing the latest code to be verified',
    (tester) async {
      api.remaining = 0;
      await pump(tester);
      now = now.add(const Duration(seconds: 60));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text(AppTexts.resendCode));
      await tester.pumpAndSettle();
      now = now.add(const Duration(seconds: 60));
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, AppTexts.resendCode),
            )
            .onPressed,
        isNull,
      );
      await submit(tester);
      await tester.pumpAndSettle();
      expect(verified, 1);
    },
  );
  testWidgets(
    'expired registration OTP permits resend rather than ending registration',
    (tester) async {
      await pump(tester);
      now = now.add(const Duration(minutes: 5));
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(find.text(AppTexts.restartRecovery), findsNothing);
      await tester.tap(find.text(AppTexts.resendCode));
      await tester.pumpAndSettle();
      await submit(tester);
      await tester.pumpAndSettle();
      expect(verified, 1);
    },
  );
  testWidgets(
    'registration deadline requires restarting and clears the challenge',
    (tester) async {
      await pump(tester);
      now = now.add(const Duration(minutes: 30));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text(AppTexts.restartRecovery), findsOneWidget);
      await tester.tap(find.text(AppTexts.restartRecovery));
      await tester.pumpAndSettle();
      expect(restarted, 1);
      expect(
        container.read(registrationControllerProvider(scope)).registrationId,
        isNull,
      );
    },
  );
  testWidgets('verification spinner blocks duplicate actions', (tester) async {
    api.gate = Completer<RegistrationVerified>();
    await pump(tester);
    await submit(tester);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).first).enabled,
      isFalse,
    );
    api.gate!.complete(api.verified());
    await tester.pumpAndSettle();
    expect(verified, 1);
  });
  testWidgets('Back uses the registration callback', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip(AppTexts.back));
    await tester.pumpAndSettle();
    expect(restarted, 1);
    expect(
      container.read(registrationControllerProvider(scope)).registrationId,
      isNull,
    );
  });
}

class _API extends RegistrationAPI {
  _API(this.now) : super(client: APIClient());
  final DateTime Function() now;
  final verifiedCodes = <String>[];
  int resends = 0;
  int remaining = 2;
  APIException? failure;
  Completer<RegistrationVerified>? gate;
  static const id = '12345678-1234-1234-1234-123456789abc';
  RegistrationVerified verified() =>
      const RegistrationVerified(registrationId: id, message: 'Verified.');
  @override
  Future<RegistrationChallenge> start(
    RegistrationRequest request, {
    CancelToken? cancelToken,
  }) async => RegistrationChallenge(
    registrationId: id,
    expiresAt: now().add(const Duration(minutes: 30)),
    otpExpiresAt: now().add(const Duration(minutes: 5)),
    resendAvailableAt: now().add(const Duration(seconds: 60)),
    message: 'Check email.',
  );
  @override
  Future<RegistrationVerified> verifyOtp(
    RegistrationVerifyRequest request, {
    CancelToken? cancelToken,
  }) async {
    verifiedCodes.add(request.otpCode);
    if (failure != null) throw failure!;
    return gate == null ? verified() : await gate!.future;
  }

  @override
  Future<RegistrationOtpResent> resendOtp(
    RegistrationResendRequest request, {
    CancelToken? cancelToken,
  }) async {
    resends++;
    return RegistrationOtpResent(
      registrationId: id,
      otpExpiresAt: now().add(const Duration(minutes: 5)),
      resendAvailableAt: now().add(const Duration(seconds: 60)),
      resendsRemaining: remaining,
      message: 'New code sent.',
    );
  }
}
