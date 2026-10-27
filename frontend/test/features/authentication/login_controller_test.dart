import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keebox/app/app_texts.dart';
import 'package:keebox/features/authentication/authentication_api.dart';
import 'package:keebox/features/authentication/models/login_response.dart';
import 'package:keebox/features/authentication/models/login_requests.dart';
import 'package:keebox/features/authentication/state/authentication_controller.dart';
import 'package:keebox/features/authentication/state/authentication_state.dart';
import 'package:keebox/features/authentication/state/login_controller.dart';
import 'package:keebox/features/authentication/storage/auth_session_storage.dart';
import 'package:keebox/network/api_client.dart';
import 'package:keebox/network/api_exception.dart';
import 'package:keebox/network/api_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late _LoginAPI api;
  final identity = Object();
  final provider = loginControllerProvider(identity);

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    api = _LoginAPI();
    container = ProviderContainer(
      overrides: [authenticationApiProvider.overrideWithValue(api)],
    );
    container.listen(provider, (_, _) {});
  });
  tearDown(() {
    container.dispose();
    api.client.close();
  });

  test(
    'password login stores a pending challenge without creating a session',
    () async {
      await container
          .read(provider.notifier)
          .submit(' user@example.com ', ' secret ');
      expect(api.request!.email, 'user@example.com');
      expect(api.request!.password, ' secret ');
      expect(container.read(provider).challenge, same(_challenge));
      expect(container.read(provider).isSubmitting, isFalse);
      final auth = container
          .read(authenticationControllerProvider)
          .requireValue;
      expect(auth, isA<AwaitingPin>());
      expect((auth as AwaitingPin).challenge, same(_challenge));
      expect(container.read(apiSessionProvider).accessToken, isNull);
      expect(
        await container.read(authenticationSessionStorageProvider).read(),
        isNull,
      );
    },
  );

  test('a pending login ignores duplicate submissions', () async {
    api.pending = Completer<LoginChallenge>();
    final controller = container.read(provider.notifier);
    final first = controller.submit('user@example.com', 'secret');
    expect(container.read(provider).isSubmitting, isTrue);
    await controller.submit('other@example.com', 'other');
    expect(api.calls, 1);
    api.pending!.complete(_challenge);
    await first;
    expect(container.read(provider).isSubmitting, isFalse);
  });

  test(
    'backend login failures can be retried and preserve their message',
    () async {
      api.failure = const APIException(
        kind: APIErrorKind.api,
        code: 'invalid_login_credentials',
        message: 'Invalid email address or password.',
      );
      final controller = container.read(provider.notifier);
      await controller.submit('user@example.com', 'incorrect');
      expect(container.read(provider).errorMessage, api.failure!.message);
      expect(container.read(provider).isSubmitting, isFalse);
      expect(container.read(provider).challenge, isNull);
      api.failure = null;
      await controller.submit('user@example.com', 'correct');
      expect(api.calls, 2);
      expect(container.read(provider).errorMessage, isNull);
      expect(container.read(provider).challenge, same(_challenge));
    },
  );

  test(
    'unexpected failures use a generic message rather than exception details',
    () async {
      api.unexpectedFailure = StateError('sensitive internal detail');
      await container
          .read(provider.notifier)
          .submit('user@example.com', 'secret');
      expect(container.read(provider).errorMessage, AppTexts.loginFailed);
    },
  );

  test(
    'disposing a login cancels its request and ignores a late response',
    () async {
      api.pending = Completer<LoginChallenge>();
      await container.read(authenticationControllerProvider.future);
      final operation = container
          .read(provider.notifier)
          .submit('user@example.com', 'secret');
      container.invalidate(provider);
      expect(api.cancelToken!.isCancelled, isTrue);
      api.pending!.complete(_challenge);
      await operation;
      expect(
        container.read(authenticationControllerProvider).requireValue,
        isA<Unauthenticated>(),
      );
      expect(container.read(provider).challenge, isNull);
    },
  );
}

final _challenge = LoginChallenge(
  loginChallengeId: 'challenge-id',
  expiresAt: DateTime.utc(2030),
  message: 'Enter your lock PIN.',
);

class _LoginAPI extends AuthenticationAPI {
  _LoginAPI() : super(client: APIClient());

  LoginRequest? request;
  CancelToken? cancelToken;
  Completer<LoginChallenge>? pending;
  APIException? failure;
  Object? unexpectedFailure;
  int calls = 0;

  @override
  Future<LoginChallenge> login(
    LoginRequest request, {
    CancelToken? cancelToken,
  }) async {
    calls++;
    this.request = request;
    this.cancelToken = cancelToken;
    if (failure != null) throw failure!;
    if (unexpectedFailure != null) throw unexpectedFailure!;
    return pending == null ? _challenge : pending!.future;
  }
}
