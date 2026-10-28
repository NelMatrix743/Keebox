import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/app/router/app_routes.dart';
import 'package:keebox/app/startup/startup_coordinator.dart';
import 'package:keebox/features/authentication/registration_api.dart';
import 'package:keebox/features/authentication/state/authentication_controller.dart';
import 'package:keebox/features/authentication/state/authentication_state.dart';
import 'package:keebox/features/authentication/state/registration_clock.dart';
import 'package:keebox/features/authentication/state/registration_controller.dart';
import 'package:keebox/features/authentication/state/registration_completion_controller.dart';
import 'package:keebox/features/authentication/storage/auth_session_storage.dart';
import 'package:keebox/features/authentication/storage/user_storage.dart';
import 'package:keebox/features/pin/models/local_pin_verification.dart';
import 'package:keebox/features/pin/services/local_pin_hasher.dart';
import 'package:keebox/features/pin/services/local_pin_service.dart';
import 'package:keebox/features/pin/storage/local_pin_storage.dart';
import 'package:keebox/network/api_exception.dart';
import 'package:keebox/network/api_session.dart';

import 'support/registration_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late TestRegistrationAPI api;
  late TestPinHasher hasher;
  late TestSessionStorage storage;
  late Object scope;
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    api = TestRegistrationAPI();
    hasher = TestPinHasher();
    storage = TestSessionStorage();
    scope = Object();
    container = ProviderContainer(
      overrides: [
        registrationApiProvider.overrideWithValue(api),
        registrationClockProvider.overrideWithValue(() => DateTime.utc(2030)),
        localPinHasherProvider.overrideWithValue(hasher),
        authenticationSessionStorageProvider.overrideWithValue(storage),
      ],
    );
    container.listen(registrationControllerProvider(scope), (_, _) {});
    container.listen(
      registrationCompletionControllerProvider(scope),
      (_, _) {},
    );
    await container.read(authenticationControllerProvider.future);
    final controller = container.read(
      registrationControllerProvider(scope).notifier,
    );
    await controller.start(registrationDetails);
    await controller.verifyOtp('001234');
  });
  tearDown(() {
    container.dispose();
    api.client.close();
  });
  RegistrationCompletionController completion() =>
      container.read(registrationCompletionControllerProvider(scope).notifier);

  test('backend-accepted PIN enrolls locally before authentication and survives restart', () async {
    hasher.gate = Completer<void>();
    final pending = completion().submit('00123');
    await hasher.started.future;
    expect(container.read(apiSessionProvider).accessToken, isNull);
    expect(await storage.read(), isNull);
    hasher.gate!.complete();
    expect(await pending, isTrue);
    expect(api.pins, ['00123']);
    expect(
      container.read(registrationCompletionControllerProvider(scope)).isReady,
      isTrue,
    );
    expect(
      container.read(authenticationControllerProvider).requireValue,
      isA<AuthenticatedUnlocked>(),
    );
    expect((await storage.read())!.refreshToken, 'new-refresh');
    expect(
      (await container
              .read(authenticatedUserStorageProvider)
              .read('registered-user'))!
          .kbkey,
      'permanent-key',
    );
    final record = (await container
        .read(localPinStorageProvider)
        .read('registered-user'))!;
    expect(jsonEncode(record.toJson()), isNot(contains('00123')));
    expect(
      (await container
              .read(localPinServiceProvider)
              .verify('registered-user', '00123'))
          .status,
      LocalPinStatus.matched,
    );
    container.invalidate(authenticationControllerProvider);
    expect(
      await container.read(authenticationControllerProvider.future),
      isA<AuthenticatedLocked>(),
    );
    expect(
      await container.read(startupCoordinatorProvider.future),
      AppRoutes.homeLock,
    );
  });
  for (final failure in ['hash', 'session']) {
    test(
      '$failure storage failure retries persistence without recreating the account',
      () async {
        if (failure == 'hash') {
          hasher.failures = 1;
        } else {
          storage.failures = 1;
        }
        expect(await completion().submit('00123'), isFalse);
        expect(
          container
              .read(registrationCompletionControllerProvider(scope))
              .errorMessage,
          AppTexts.registrationSessionSaveFailed,
        );
        expect(container.read(apiSessionProvider).accessToken, isNull);
        expect(await storage.read(), isNull);
        expect(await completion().retry(), isTrue);
        expect(api.pins, ['00123']);
        expect(
          container
              .read(registrationCompletionControllerProvider(scope))
              .isReady,
          isTrue,
        );
      },
    );
  }
  test('known backend validation failure permits correction without saving credentials', () async {
    api.failure = const APIException(
      kind: APIErrorKind.api,
      code: 'validation_error',
      statusCode: 422,
      message: 'Invalid PIN.',
    );
    expect(await completion().submit('00123'), isFalse);
    expect(hasher.pins, isEmpty);
    expect(await storage.read(), isNull);
    api.failure = null;
    expect(await completion().submit('00123'), isTrue);
    expect(api.pins, hasLength(2));
  });
  test(
    'uncertain backend completion cannot be submitted or persisted again',
    () async {
      api.failure = const APIException(
        kind: APIErrorKind.timeout,
        message: 'Timeout',
      );
      expect(await completion().submit('00123'), isFalse);
      expect(await completion().submit('00123'), isFalse);
      expect(await completion().retry(), isFalse);
      expect(api.pins, hasLength(1));
      expect(hasher.pins, isEmpty);
    },
  );
  test('duplicate completion and retry are ignored while hashing', () async {
    hasher.gate = Completer<void>();
    final pending = completion().submit('00123');
    await hasher.started.future;
    expect(await completion().submit('99999'), isFalse);
    expect(await completion().retry(), isFalse);
    hasher.gate!.complete();
    await pending;
    expect(api.pins, ['00123']);
  });
  test(
    'disposal during hashing cannot install a session or local verifier',
    () async {
      hasher.gate = Completer<void>();
      final pending = completion().submit('00123');
      await hasher.started.future;
      container.invalidate(registrationCompletionControllerProvider(scope));
      hasher.gate!.complete();
      expect(await pending, isFalse);
      expect(await storage.read(), isNull);
      expect(
        await container.read(localPinStorageProvider).read('registered-user'),
        isNull,
      );
      expect(container.read(apiSessionProvider).accessToken, isNull);
    },
  );
  test(
    'registration completed while backgrounded stays locally locked',
    () async {
      container
          .read(authenticationControllerProvider.notifier)
          .setApplicationActive(false);
      expect(await completion().submit('00123'), isTrue);
      expect(
        container.read(authenticationControllerProvider).requireValue,
        isA<AuthenticatedLocked>(),
      );
    },
  );
}
