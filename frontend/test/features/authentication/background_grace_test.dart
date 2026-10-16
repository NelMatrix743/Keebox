import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keebox/app/background_lock_policy.dart';
import 'package:keebox/features/authentication/models/authenticated_user.dart';
import 'package:keebox/features/authentication/models/authentication_result.dart';
import 'package:keebox/features/authentication/models/authentication_session.dart';
import 'package:keebox/features/authentication/state/authentication_controller.dart';
import 'package:keebox/features/authentication/state/authentication_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final seconds in [19, 20, 21]) {
    test(
      'resume checks elapsed time even if the background timer did not run: $seconds',
      () async {
        FlutterSecureStorage.setMockInitialValues({});
        var elapsed = Duration.zero;
        final container = ProviderContainer(
          overrides: [
            backgroundElapsedProvider.overrideWithValue(() => elapsed),
          ],
        );
        addTearDown(container.dispose);
        final controller = container.read(
          authenticationControllerProvider.notifier,
        );
        await controller.completeAuthentication(_result);
        controller.setApplicationActive(false);
        elapsed = const Duration(seconds: 10);
        controller.setApplicationActive(false);
        elapsed = Duration(seconds: seconds);
        controller.setApplicationActive(true);
        final state = container
            .read(authenticationControllerProvider)
            .requireValue;
        expect(state is AuthenticatedLocked, seconds >= 20);
      },
    );
  }
  test(
    'background timer locks at the deadline and a short return cancels it',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final timers = <_Timer>[];
      final container = ProviderContainer(
        overrides: [
          backgroundTimerProvider.overrideWithValue((delay, callback) {
            expect(delay, const Duration(seconds: 20));
            final timer = _Timer(callback);
            timers.add(timer);
            return timer;
          }),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(
        authenticationControllerProvider.notifier,
      );
      await controller.completeAuthentication(_result);
      controller.setApplicationActive(false);
      expect(
        container.read(authenticationControllerProvider).requireValue,
        isA<AuthenticatedUnlocked>(),
      );
      controller.setApplicationActive(true);
      expect(timers.first.isActive, isFalse);
      expect(
        container.read(authenticationControllerProvider).requireValue,
        isA<AuthenticatedUnlocked>(),
      );
      controller.setApplicationActive(false);
      timers.last.fire();
      expect(
        container.read(authenticationControllerProvider).requireValue,
        isA<AuthenticatedLocked>(),
      );
    },
  );
}

class _Timer implements Timer {
  _Timer(this.callback);
  final void Function() callback;
  @override
  bool isActive = true;
  @override
  int get tick => 0;
  @override
  void cancel() => isActive = false;
  void fire() {
    if (isActive) callback();
  }
}

const _result = AuthenticationResult(
  user: AuthenticatedUser(
    id: 'user',
    firstName: 'Ada',
    lastName: 'Lovelace',
    email: 'ada@example.com',
    kbkey: 'key',
  ),
  session: AuthenticationSession(
    userId: 'user',
    accessToken: 'access',
    refreshToken: 'refresh',
  ),
  message: 'Done',
);
