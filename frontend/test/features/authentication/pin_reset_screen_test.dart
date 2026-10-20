import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/app/theme/app_theme.dart';
import 'package:keebox/features/authentication/models/pin_reset_request.dart';
import 'package:keebox/features/authentication/models/recovery_challenge.dart';
import 'package:keebox/features/authentication/models/recovery_completed.dart';
import 'package:keebox/features/authentication/models/recovery_start_request.dart';
import 'package:keebox/features/authentication/models/recovery_type.dart';
import 'package:keebox/features/authentication/models/recovery_verified.dart';
import 'package:keebox/features/authentication/models/recovery_verify_request.dart';
import 'package:keebox/features/authentication/recovery_api.dart';
import 'package:keebox/features/authentication/screens/pin_reset_screen.dart';
import 'package:keebox/features/authentication/state/recovery_controller.dart';
import 'package:keebox/features/authentication/state/recovery_state.dart';
import 'package:keebox/features/pin/widgets/pin_digit_cell.dart';
import 'package:keebox/features/pin/widgets/pin_digit_row.dart';
import 'package:keebox/network/api_client.dart';
import 'package:keebox/network/api_exception.dart';

void main() {
  late DateTime now;
  late _API api;
  late ProviderContainer container;
  late RecoveryScope scope;
  late int completed;
  late int restarted;
  late int loginRequired;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'existing-verifier': 'unchanged',
    });
    now = DateTime.utc(2030);
    api = _API(() => now);
    scope = (identity: Object(), type: RecoveryType.pin);
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
  Future<void> pump(WidgetTester tester, {bool navigable = false}) async {
    final controller = container.read(
      recoveryControllerProvider(scope).notifier,
    );
    await controller.start('ada@example.com');
    await controller.verifyOtp('001234');
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final screen = PinResetScreen(
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

  Future<void> fill(WidgetTester tester) async {
    for (final digit in '00123'.split('')) {
      final key = find.byKey(ValueKey('pin-key-$digit'));
      await tester.ensureVisible(key);
      await tester.tap(key);
      await tester.pump();
    }
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
  }

  String digits(WidgetTester tester) => tester
      .widgetList<PinDigitCell>(find.byType(PinDigitCell))
      .map((cell) => cell.digit ?? '')
      .join();

  testWidgets(
    'one five-digit entry submits leading zeros with a stationary row and button spinner',
    (tester) async {
      await pump(tester);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await fill(tester);
      final rowPosition = tester.getTopLeft(find.byType(PinDigitRow));
      api.pending = Completer<RecoveryCompleted>();
      await submit(tester);
      expect(api.requests.single.newPin, '00123');
      expect(await const FlutterSecureStorage().readAll(), {
        'existing-verifier': 'unchanged',
      });
      expect(digits(tester), '00123');
      expect(tester.getTopLeft(find.byType(PinDigitRow)), rowPosition);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      api.pending!.complete(api.completed());
      await tester.pumpAndSettle();
      expect(completed, 1);
      expect(api.requests, hasLength(1));
      expect(await const FlutterSecureStorage().readAll(), {
        'existing-verifier': 'unchanged',
      });
    },
  );

  testWidgets(
    'backend rejection preserves digits and shows its error without generic feedback',
    (tester) async {
      await pump(tester);
      await fill(tester);
      api.failure = const APIException(
        kind: APIErrorKind.api,
        code: 'validation_error',
        statusCode: 422,
        message: 'PIN rejected.',
      );
      await submit(tester);
      await tester.pumpAndSettle();
      expect(find.text('PIN rejected.'), findsNWidgets(2));
      expect(find.text(AppTexts.pinConfirmationFailed), findsNothing);
      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).backgroundColor,
        Colors.red,
      );
      expect(digits(tester), '00123');
      api.failure = null;
      await submit(tester);
      await tester.pumpAndSettle();
      expect(completed, 1);
      expect(api.requests, hasLength(2));
    },
  );

  testWidgets(
    'expired verified challenge blocks confirmation and permits restart',
    (tester) async {
      await pump(tester);
      await fill(tester);
      now = now.add(const Duration(minutes: 10));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.ensureVisible(find.text(AppTexts.restartRecovery));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppTexts.restartRecovery));
      await tester.pumpAndSettle();
      expect(restarted, 1);
      expect(api.requests, isEmpty);
    },
  );

  testWidgets('uncertain completion prevents retries and offers login', (
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
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(AppTexts.backToLogin));
    await tester.tap(find.text(AppTexts.backToLogin));
    await tester.pumpAndSettle();
    expect(loginRequired, 1);
    expect(api.requests, hasLength(1));
  });

  testWidgets('back cancels pending reset and ignores a late completion', (
    tester,
  ) async {
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
    expect(
      container.read(recoveryControllerProvider(scope)).stage,
      RecoveryStage.email,
    );
  });
}

class _API extends RecoveryAPI {
  _API(this.now) : super(client: APIClient());
  final DateTime Function() now;
  final requests = <PinResetRequest>[];
  APIException? failure;
  Completer<RecoveryCompleted>? pending;
  CancelToken? token;
  static const id = '12345678-1234-1234-1234-123456789abc';
  RecoveryCompleted completed() => const RecoveryCompleted(
    resetId: id,
    message: 'PIN reset completed. Sign in again.',
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
  Future<RecoveryCompleted> completePin(
    PinResetRequest request, {
    CancelToken? cancelToken,
  }) async {
    token = cancelToken;
    requests.add(request);
    if (failure != null) throw failure!;
    return pending == null ? completed() : await pending!.future;
  }
}
