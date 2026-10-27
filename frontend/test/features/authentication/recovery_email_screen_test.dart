import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/app/theme/app_colors.dart';
import 'package:keebox/app/theme/app_theme.dart';
import 'package:keebox/features/authentication/models/recovery_response.dart';
import 'package:keebox/features/authentication/models/recovery_requests.dart';
import 'package:keebox/features/authentication/models/recovery_type.dart';
import 'package:keebox/features/authentication/recovery_api.dart';
import 'package:keebox/features/authentication/screens/recovery_email_screen.dart';
import 'package:keebox/features/authentication/state/recovery_controller.dart';
import 'package:keebox/network/api_client.dart';
import 'package:keebox/network/api_exception.dart';

void main() {
  late _API api;
  setUp(() => api = _API());
  tearDown(() => api.client.close());

  Future<void> pump(
    WidgetTester tester, {
    RecoveryType type = RecoveryType.password,
    ValueChanged<RecoveryScope>? onStarted,
    Size size = const Size(402, 874),
    double keyboard = 0,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [recoveryApiProvider.overrideWithValue(api)],
        child: ScreenUtilInit(
          designSize: const Size(402, 874),
          minTextAdapt: true,
          builder: (context, child) => MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                viewInsets: EdgeInsets.only(bottom: keyboard),
                textScaler: TextScaler.linear(textScale),
              ),
              child: child!,
            ),
            home: RecoveryEmailScreen(
              type: type,
              onStarted: onStarted ?? (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('invalid email stays inline and never calls the API', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text(AppTexts.continueLabel));
    await tester.pumpAndSettle();
    expect(find.text(AppTexts.recoveryEmailRequired), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'invalid');
    await tester.tap(find.text(AppTexts.continueLabel));
    await tester.pumpAndSettle();
    expect(find.text(AppTexts.recoveryEmailInvalid), findsOneWidget);
    expect(api.calls, 0);
  });

  for (final type in RecoveryType.values) {
    testWidgets('$type submits once and hands off its recovery scope', (
      tester,
    ) async {
      RecoveryScope? scope;
      await pump(tester, type: type, onStarted: (value) => scope = value);
      api.pending = Completer<RecoveryChallenge>();
      await tester.enterText(find.byType(TextFormField), ' ada@example.com ');
      await tester.tap(find.text(AppTexts.continueLabel));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField)).enabled,
        isFalse,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(api.email, 'ada@example.com');
      expect(api.type, type);
      api.pending!.complete(api.challenge());
      await tester.pumpAndSettle();
      expect(scope?.type, type);
      expect(api.calls, 1);
    });
  }

  testWidgets('failure uses red snackbar, preserves email and allows retry', (
    tester,
  ) async {
    await pump(tester);
    api.failure = const APIException(
      kind: APIErrorKind.connection,
      message: 'Offline',
    );
    await tester.enterText(find.byType(TextFormField), 'ada@example.com');
    await tester.tap(find.text(AppTexts.continueLabel));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SnackBar>(find.byType(SnackBar)).backgroundColor,
      Colors.red,
    );
    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('ada@example.com'), findsOneWidget);
    api.failure = null;
    await tester.tap(find.text(AppTexts.continueLabel));
    await tester.pumpAndSettle();
    expect(api.calls, 2);
  });

  testWidgets('field geometry and focused border follow the design', (
    tester,
  ) async {
    await pump(tester);
    final field = find.byType(TextFormField);
    expect(tester.getSize(field).width, closeTo(349, 1));
    expect(tester.getSize(field).height, closeTo(55, 1));
    final decoration = tester
        .widget<TextField>(find.byType(TextField))
        .decoration!;
    expect(decoration.fillColor, AppColors.border);
    expect(
      (decoration.enabledBorder! as OutlineInputBorder).borderSide,
      BorderSide.none,
    );
    expect(
      (decoration.focusedBorder! as OutlineInputBorder).borderSide.color,
      AppColors.brand,
    );
    expect(
      (decoration.focusedBorder! as OutlineInputBorder).borderSide.width,
      2,
    );
  });

  testWidgets('small viewport with keyboard and large text remains usable', (
    tester,
  ) async {
    await pump(tester, size: const Size(320, 568), keyboard: 220, textScale: 2);
    await tester.enterText(find.byType(TextFormField), 'ada@example.com');
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(api.calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'leaving screen cancels pending work and prevents a late handoff',
    (tester) async {
      var handedOff = false;
      await pump(tester, onStarted: (_) => handedOff = true);
      api.pending = Completer<RecoveryChallenge>();
      await tester.enterText(find.byType(TextFormField), 'ada@example.com');
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(api.token!.isCancelled, isTrue);
      api.pending!.complete(api.challenge());
      await tester.pump();
      expect(handedOff, isFalse);
    },
  );
}

class _API extends RecoveryAPI {
  _API() : super(client: APIClient());
  int calls = 0;
  String? email;
  RecoveryType? type;
  APIException? failure;
  CancelToken? token;
  Completer<RecoveryChallenge>? pending;
  RecoveryChallenge challenge() => RecoveryChallenge(
    resetId: '12345678-1234-1234-1234-123456789abc',
    otpExpiresAt: DateTime.now().add(const Duration(minutes: 5)),
    resendAvailableAt: DateTime.now().add(const Duration(minutes: 1)),
    message: 'If an account exists, a code has been sent.',
  );
  @override
  Future<RecoveryChallenge> start(
    RecoveryType type,
    RecoveryStartRequest request, {
    CancelToken? cancelToken,
  }) async {
    calls++;
    email = request.email;
    this.type = type;
    token = cancelToken;
    if (failure != null) throw failure!;
    return pending == null ? challenge() : await pending!.future;
  }
}
