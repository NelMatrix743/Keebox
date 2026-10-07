import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keebox/features/authentication/authentication_api.dart';
import 'package:keebox/features/authentication/models/login_challenge.dart';
import 'package:keebox/features/authentication/models/login_request.dart';
import 'package:keebox/features/authentication/state/authentication_controller.dart';
import 'package:keebox/features/authentication/state/authentication_state.dart';
import 'package:keebox/features/authentication/state/login_controller.dart';
import 'package:keebox/network/api_client.dart';
import 'package:keebox/network/api_exception.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late _API api;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    api = _API();
    container = ProviderContainer(
      overrides: [authenticationApiProvider.overrideWithValue(api)],
    );
    container.listen(loginControllerProvider, (_, next) {});
    await container.read(authenticationControllerProvider.future);
  });
  tearDown(() {
    container.dispose();
    api.client.close();
  });

  test('submission reports loading and prevents duplicate requests', () async {
    final controller = container.read(loginControllerProvider.notifier);
    final first = controller.submit(_request);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(loginControllerProvider).isLoading, isTrue);
    await controller.submit(_request);
    expect(api.calls, 1);
    api.response.complete(_challenge());
    await first;
    expect(
      container.read(authenticationControllerProvider).requireValue,
      isA<AwaitingPin>(),
    );
    expect(container.read(loginControllerProvider).hasError, isFalse);
  });

  test('credential error stays unauthenticated and allows retry', () async {
    final controller = container.read(loginControllerProvider.notifier);
    final first = controller.submit(_request);
    await Future<void>.delayed(Duration.zero);
    api.response.completeError(
      const APIException(
        kind: APIErrorKind.api,
        code: 'invalid_login_credentials',
        message: 'Invalid credentials.',
      ),
    );
    await first;
    expect(container.read(loginControllerProvider).hasError, isTrue);
    expect(
      container.read(authenticationControllerProvider).requireValue,
      isA<Unauthenticated>(),
    );
    api.response = Completer<LoginChallenge>();
    final retry = controller.submit(_request);
    await Future<void>.delayed(Duration.zero);
    api.response.complete(_challenge());
    await retry;
    expect(api.calls, 2);
    expect(
      container.read(authenticationControllerProvider).requireValue,
      isA<AwaitingPin>(),
    );
  });
}

const _request = LoginRequest(email: 'user@example.com', password: ' secret ');
LoginChallenge _challenge() => LoginChallenge(
  loginChallengeId: 'challenge-id',
  expiresAt: DateTime.now().add(const Duration(minutes: 10)),
  message: 'Enter PIN.',
);

class _API extends AuthenticationAPI {
  _API() : super(client: APIClient());
  int calls = 0;
  Completer<LoginChallenge> response = Completer<LoginChallenge>();

  @override
  Future<LoginChallenge> login(
    LoginRequest request, {
    CancelToken? cancelToken,
  }) {
    calls++;
    return response.future;
  }
}
