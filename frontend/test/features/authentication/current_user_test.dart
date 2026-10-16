import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keebox/features/authentication/authentication_api.dart';
import 'package:keebox/features/authentication/models/authenticated_user.dart';
import 'package:keebox/features/authentication/models/authentication_result.dart';
import 'package:keebox/features/authentication/models/authentication_session.dart';
import 'package:keebox/features/authentication/state/authentication_controller.dart';
import 'package:keebox/features/authentication/state/authentication_state.dart';
import 'package:keebox/features/authentication/storage/user_storage.dart';
import 'package:keebox/network/api_client.dart';
import 'package:keebox/network/api_exception.dart';
import 'package:keebox/network/api_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late APIClient client;
  late _Adapter adapter;
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    adapter = _Adapter();
    final session = APISession();
    client = APIClient(
      dio: Dio()..httpClientAdapter = adapter,
      session: session,
    );
    container = ProviderContainer(
      overrides: [
        apiSessionProvider.overrideWithValue(session),
        authenticationApiProvider.overrideWithValue(
          AuthenticationAPI(client: client),
        ),
      ],
    );
    await container
        .read(authenticationControllerProvider.notifier)
        .completeAuthentication(_result);
  });
  tearDown(() {
    container.dispose();
    client.close();
  });

  for (final locked in [false, true]) {
    test(
      'profile synchronization preserves KBKey and locked=$locked',
      () async {
        final controller = container.read(
          authenticationControllerProvider.notifier,
        );
        if (locked) {
          controller.lock();
        }
        expect(await controller.synchronizeUser(), isTrue);
        final current =
            container.read(authenticationControllerProvider).requireValue
                as Authenticated;
        expect(current is AuthenticatedLocked, locked);
        expect(current.user.firstName, 'Updated');
        expect(current.user.kbkey, 'permanent-key');
        expect(
          (await container.read(authenticatedUserStorageProvider).read('user'))!
              .firstName,
          'Updated',
        );
        expect(current.session.refreshToken, 'refresh');
      },
    );
  }
  test('expired access refreshes before retrying current user', () async {
    adapter.expired = true;
    expect(
      await container
          .read(authenticationControllerProvider.notifier)
          .synchronizeUser(),
      isTrue,
    );
    final current =
        container.read(authenticationControllerProvider).requireValue
            as Authenticated;
    expect(current.session.accessToken, 'renewed');
    expect(current.user.firstName, 'Updated');
    expect(adapter.calls, 2);
  });
  for (final failure in ['offline', 'malformed']) {
    test('$failure response preserves the cached user and session', () async {
      adapter.failure = failure;
      await expectLater(
        container
            .read(authenticationControllerProvider.notifier)
            .synchronizeUser(),
        throwsA(isA<APIException>()),
      );
      final current =
          container.read(authenticationControllerProvider).requireValue
              as Authenticated;
      expect(current.user.firstName, 'Ada');
      expect(current.user.kbkey, 'permanent-key');
      expect(container.read(apiSessionProvider).accessToken, 'access');
    });
  }
  test('mismatched account cannot overwrite local user data', () async {
    adapter.failure = 'mismatch';
    await expectLater(
      container
          .read(authenticationControllerProvider.notifier)
          .synchronizeUser(),
      throwsA(isA<APIException>()),
    );
    expect(
      container.read(authenticationControllerProvider).requireValue,
      isA<Unauthenticated>(),
    );
    expect(
      (await container.read(authenticatedUserStorageProvider).read('user'))!
          .firstName,
      'Ada',
    );
  });
  test(
    'late profile response after logout cannot restore or update user',
    () async {
      adapter.gate = Completer<void>();
      final controller = container.read(
        authenticationControllerProvider.notifier,
      );
      final operation = controller.synchronizeUser();
      await adapter.started.future;
      await controller.clearSession();
      adapter.gate!.complete();
      expect(await operation, isFalse);
      expect(
        container.read(authenticationControllerProvider).requireValue,
        isA<Unauthenticated>(),
      );
      expect(
        (await container.read(authenticatedUserStorageProvider).read('user'))!
            .firstName,
        'Ada',
      );
    },
  );
}

const _result = AuthenticationResult(
  user: AuthenticatedUser(
    id: 'user',
    firstName: 'Ada',
    lastName: 'Lovelace',
    email: 'ada@example.com',
    kbkey: 'permanent-key',
  ),
  session: AuthenticationSession(
    userId: 'user',
    accessToken: 'access',
    refreshToken: 'refresh',
  ),
  message: 'Completed.',
);

class _Adapter implements HttpClientAdapter {
  int calls = 0;
  bool expired = false;
  String? failure;
  Completer<void>? gate;
  final started = Completer<void>();
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final refresh = options.path.endsWith('/refresh');
    if (!refresh) {
      calls++;
      expect(options.uri.path, '/api/me');
      expect(options.headers['Authorization'], startsWith('Bearer '));
      if (!started.isCompleted) started.complete();
      if (gate != null) await gate!.future;
      if (failure == 'offline') {
        throw DioException.connectionError(
          requestOptions: options,
          reason: 'Offline',
        );
      }
    }
    final rejected =
        !refresh &&
        expired &&
        options.headers['Authorization'] == 'Bearer access';
    final data = refresh
        ? {'access_token': 'renewed'}
        : {
            'user_id': failure == 'mismatch' ? 'other' : 'user',
            'first_name': failure == 'malformed' ? 123 : 'Updated',
            'last_name': 'Lovelace',
            'email': 'updated@example.com',
            'kbkey': 'must-be-ignored',
          };
    return ResponseBody.fromString(
      jsonEncode({
        'success': !rejected,
        'data': rejected ? null : data,
        'error': rejected
            ? {'code': 'invalid_session', 'message': 'Expired'}
            : null,
        'meta': null,
      }),
      rejected ? 401 : 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
