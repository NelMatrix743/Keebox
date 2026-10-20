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
import 'package:keebox/features/authentication/models/recovery_type.dart';
import 'package:keebox/features/authentication/screens/recovery_email_screen.dart';
import 'package:keebox/features/authentication/recovery_api.dart';
import 'package:keebox/features/authentication/models/recovery_start_request.dart';
import 'package:keebox/features/authentication/models/recovery_challenge.dart';
import 'package:keebox/network/api_client.dart';

void main() {
  for (final (route, type) in [
    (AppRoutes.forgotPasswordName, RecoveryType.password),
    (AppRoutes.recoverPinName, RecoveryType.pin),
  ]) {
    testWidgets(
      '$route opens recovery and retains its challenge through OTP navigation',
      (tester) async {
        FlutterSecureStorage.setMockInitialValues({});
        tester.view.physicalSize = const Size(402, 874);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = _API();
        addTearDown(api.client.close);
        final container = ProviderContainer(
          overrides: [recoveryApiProvider.overrideWithValue(api)],
        );
        addTearDown(container.dispose);
        final router = container.read(appRouterProvider);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: ScreenUtilInit(
              designSize: const Size(402, 874),
              minTextAdapt: true,
              builder: (context, child) => MaterialApp.router(
                routerConfig: router,
                theme: AppTheme.light,
              ),
            ),
          ),
        );
        router.pushNamed(route);
        await tester.pumpAndSettle();
        final screen = tester.widget<RecoveryEmailScreen>(
          find.byType(RecoveryEmailScreen),
        );
        expect(screen.type, type);
        await tester.enterText(find.byType(TextFormField), 'ada@example.com');
        await tester.tap(find.text(AppTexts.continueLabel));
        await tester.pumpAndSettle();
        expect(find.text(AppTexts.recoveryOtpPlaceholder), findsOneWidget);
        expect(
          find.text('If an account exists, a code has been sent.'),
          findsOneWidget,
        );
        await tester.tap(find.byTooltip(AppTexts.back));
        await tester.pumpAndSettle();
        expect(find.text(AppTexts.recoveryEmailTitle), findsOneWidget);
        await tester.tap(find.byTooltip(AppTexts.back));
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, AppRoutes.root);
      },
    );
  }
}

class _API extends RecoveryAPI {
  _API() : super(client: APIClient());
  @override
  Future<RecoveryChallenge> start(
    RecoveryType type,
    RecoveryStartRequest request, {
    CancelToken? cancelToken,
  }) async => RecoveryChallenge(
    resetId: '12345678-1234-1234-1234-123456789abc',
    otpExpiresAt: DateTime.now().add(const Duration(minutes: 5)),
    resendAvailableAt: DateTime.now().add(const Duration(seconds: 60)),
    message: 'If an account exists, a code has been sent.',
  );
}
