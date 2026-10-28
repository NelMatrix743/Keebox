import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/app/theme/app_theme.dart';
import 'package:keebox/assets/app_assets.dart';
import 'package:keebox/features/authentication/models/registration_requests.dart';
import 'package:keebox/features/authentication/models/registration_response.dart';
import 'package:keebox/features/authentication/registration_api.dart';
import 'package:keebox/features/authentication/screens/registration_screen.dart';
import 'package:keebox/features/pin/screens/pin_setup_screen.dart';
import 'package:keebox/features/pin/models/pin_setup_mode.dart';
import 'package:keebox/network/api_client.dart';
import 'package:keebox/network/api_exception.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/inter/Inter-Variable.ttf')))
        .load();
    await (FontLoader('Poppins')..addFont(
          rootBundle.load('assets/fonts/poppins/Poppins-SemiBold.ttf'),
        ))
        .load();
  });
  late _API api;
  late int signIns;
  setUp(() {
    api = _API();
    signIns = 0;
  });
  tearDown(() => api.client.close());
  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(402, 874),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 32);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [registrationApiProvider.overrideWithValue(api)],
        child: ScreenUtilInit(
          designSize: const Size(402, 874),
          minTextAdapt: true,
          builder: (_, child) => MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: RegistrationScreen(onSignIn: () => signIns++),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> identity(WidgetTester tester) async {
    await tester.enterText(find.byType(TextFormField).at(0), ' Ada ');
    await tester.enterText(find.byType(TextFormField).at(1), ' Lovelace ');
    await tester.enterText(
      find.byType(TextFormField).at(2),
      ' ada@example.com ',
    );
    await tester.ensureVisible(find.text(AppTexts.next));
    await tester.tap(find.text(AppTexts.next));
    await tester.pumpAndSettle();
  }

  Future<void> passwords(
    WidgetTester tester, [
    String confirm = ' password ',
  ]) async {
    await tester.enterText(find.byType(TextFormField).first, ' password ');
    await tester.enterText(find.byType(TextFormField).last, confirm);
    await tester.ensureVisible(find.text(AppTexts.continueLabel));
    await tester.tap(find.text(AppTexts.continueLabel));
  }

  testWidgets(
    'Identity matches the design slots and Next makes no API request',
    (tester) async {
      await pump(tester);
      expect(find.text(AppTexts.registrationIdentityTitle), findsOneWidget);
      final image = find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName == AppAssets.registrationIdentity,
      );
      expect(tester.getSize(image), const Size(120, 120));
      expect(tester.getTopLeft(image).dy, closeTo(127, 1));
      expect(
        tester.getTopLeft(find.byType(TextFormField).first).dy,
        closeTo(357, 1),
      );
      expect(
        tester.getSize(find.byType(TextFormField).first).height,
        closeTo(55, 1),
      );
      await identity(tester);
      expect(find.text(AppTexts.registrationPasswordTitle), findsOneWidget);
      expect(api.requests, isEmpty);
    },
  );
  testWidgets('identity validates required names and email inline', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text(AppTexts.next));
    await tester.pumpAndSettle();
    expect(find.text(AppTexts.registrationFirstNameRequired), findsOneWidget);
    expect(find.text(AppTexts.registrationLastNameRequired), findsOneWidget);
    expect(find.text(AppTexts.recoveryEmailRequired), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).last, 'bad');
    await tester.tap(find.text(AppTexts.next));
    await tester.pumpAndSettle();
    expect(find.text(AppTexts.recoveryEmailInvalid), findsOneWidget);
    expect(api.requests, isEmpty);
  });
  testWidgets('password confirmation is required and must match exactly', (
    tester,
  ) async {
    await pump(tester);
    await identity(tester);
    await passwords(tester, 'different');
    await tester.pumpAndSettle();
    expect(find.text(AppTexts.passwordsDoNotMatch), findsOneWidget);
    expect(api.requests, isEmpty);
    await tester.enterText(find.byType(TextFormField).last, '');
    await tester.tap(find.text(AppTexts.continueLabel));
    await tester.pumpAndSettle();
    expect(
      find.text(AppTexts.registrationConfirmPasswordRequired),
      findsOneWidget,
    );
  });
  testWidgets('password visibility toggles independently', (tester) async {
    await pump(tester);
    await identity(tester);
    await tester.tap(find.byTooltip(AppTexts.showPassword).first);
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText).first).obscureText,
      isFalse,
    );
    expect(
      tester.widget<EditableText>(find.byType(EditableText).last).obscureText,
      isTrue,
    );
  });
  testWidgets(
    'valid submission passes all four fields and opens shared OTP verification',
    (tester) async {
      await pump(tester);
      await identity(tester);
      await passwords(tester);
      await tester.pumpAndSettle();
      expect(api.requests.single.toJson(), {
        'first_name': 'Ada',
        'last_name': 'Lovelace',
        'email': 'ada@example.com',
        'password': ' password ',
      });
      expect(find.text(AppTexts.recoveryOtpSent), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      await tester.tap(find.byTooltip(AppTexts.back));
      await tester.pumpAndSettle();
      expect(find.text(AppTexts.registrationIdentityTitle), findsOneWidget);
    },
  );
  testWidgets(
    'submission shows a spinner and disables fields and duplicate requests',
    (tester) async {
      api.gate = Completer<RegistrationChallenge>();
      await pump(tester);
      await identity(tester);
      await passwords(tester);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField).first).enabled,
        isFalse,
      );
      expect(api.requests, hasLength(1));
      api.gate!.complete(api.challenge());
      await tester.pumpAndSettle();
      expect(find.text(AppTexts.recoveryOtpSent), findsOneWidget);
    },
  );
  testWidgets(
    'Back cancels pending submission and retains identity without passwords',
    (tester) async {
      api.gate = Completer<RegistrationChallenge>();
      await pump(tester);
      await identity(tester);
      await passwords(tester);
      await tester.pump();
      final token = api.token!;
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(token.isCancelled, isTrue);
      expect(find.text('Ada'), findsOneWidget);
      api.gate!.complete(api.challenge());
      await tester.pumpAndSettle();
      expect(find.text(AppTexts.registrationIdentityTitle), findsOneWidget);
      await tester.tap(find.text(AppTexts.next));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        isEmpty,
      );
    },
  );
  testWidgets(
    'backend password validation remains inline alongside one red snackbar',
    (tester) async {
      api.failure = const APIException(
        kind: APIErrorKind.api,
        code: 'validation_error',
        message: 'Check your password.',
        statusCode: 422,
        details: [
          {
            'location': ['body', 'payload', 'password'],
            'message': 'Too common.',
          },
        ],
      );
      await pump(tester);
      await identity(tester);
      await passwords(tester);
      await tester.pumpAndSettle();
      expect(find.text('Too common.'), findsOneWidget);
      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).backgroundColor,
        Colors.red,
      );
      await tester.enterText(
        find.byType(TextFormField).first,
        'better password',
      );
      await tester.pump();
      expect(find.text('Too common.'), findsNothing);
    },
  );
  testWidgets('email conflict can be corrected on Identity and resubmitted', (
    tester,
  ) async {
    api.failure = const APIException(
      kind: APIErrorKind.api,
      code: 'registration_email_conflict',
      message: 'Already registered.',
      statusCode: 409,
    );
    await pump(tester);
    await identity(tester);
    await passwords(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(AppTexts.back));
    await tester.pumpAndSettle();
    expect(find.text('Already registered.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).last, 'new@example.com');
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppTexts.next));
    await tester.pumpAndSettle();
    api.failure = null;
    await passwords(tester);
    await tester.pumpAndSettle();
    expect(api.requests.last.email, 'new@example.com');
    expect(find.text(AppTexts.recoveryOtpSent), findsOneWidget);
  });
  testWidgets(
    'shared OTP verification advances registration to the pending PIN step',
    (tester) async {
      await pump(tester);
      await identity(tester);
      await passwords(tester);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '001234');
      await tester.pump();
      await tester.ensureVisible(find.text(AppTexts.continueLabel));
      await tester.tap(find.text(AppTexts.continueLabel));
      await tester.pumpAndSettle();
      expect(find.byType(PinSetupScreen), findsOneWidget);
      expect(
        tester.widget<PinSetupScreen>(find.byType(PinSetupScreen)).mode,
        PinSetupMode.create,
      );
      expect(
        tester.widget<PinSetupScreen>(find.byType(PinSetupScreen)).enabled,
        isTrue,
      );
      expect(find.text(AppTexts.createPinTitle), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    },
  );
  testWidgets('Sign In follows its callback', (tester) async {
    await pump(tester);
    await tester.tap(find.text(AppTexts.signIn));
    expect(signIns, 1);
  });
  testWidgets('small screen, large text and keyboard keep both forms usable', (
    tester,
  ) async {
    await pump(tester, size: const Size(320, 568), scale: 1.5);
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    await tester.pumpAndSettle();
    await identity(tester);
    await passwords(tester);
    await tester.pumpAndSettle();
    expect(find.text(AppTexts.recoveryOtpSent), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _API extends RegistrationAPI {
  _API() : super(client: APIClient());
  final requests = <RegistrationRequest>[];
  APIException? failure;
  CancelToken? token;
  Completer<RegistrationChallenge>? gate;
  RegistrationChallenge challenge() => RegistrationChallenge(
    registrationId: '12345678-1234-1234-1234-123456789abc',
    expiresAt: DateTime.now().add(const Duration(minutes: 30)),
    otpExpiresAt: DateTime.now().add(const Duration(minutes: 5)),
    resendAvailableAt: DateTime.now().add(const Duration(seconds: 60)),
    message: 'Check your email.',
  );
  @override
  Future<RegistrationVerified> verifyOtp(
    RegistrationVerifyRequest request, {
    CancelToken? cancelToken,
  }) async => RegistrationVerified(
    registrationId: request.registrationId,
    message: 'Verified.',
  );
  @override
  Future<RegistrationChallenge> start(
    RegistrationRequest request, {
    CancelToken? cancelToken,
  }) async {
    requests.add(request);
    token = cancelToken;
    if (failure != null) throw failure!;
    return gate == null ? challenge() : await gate!.future;
  }
}
