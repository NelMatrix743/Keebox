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
import 'package:keebox/features/authentication/storage/auth_session_storage.dart';
import 'package:keebox/network/api_client.dart';
import 'package:keebox/network/api_exception.dart';
import 'package:keebox/network/api_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late _Adapter adapter;
  late APIClient client;
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
  Future<void> read() => client.get<void>(
    'https://example.com/private',
    authenticated: true,
    decode: (_) {},
  );

  for (final locked in [false, true]) {
    test('refresh persists credentials and preserves locked=$locked', () async {
      if (locked) {
        container.read(authenticationControllerProvider.notifier).lock();
      }
      await read();
      final state =
          container.read(authenticationControllerProvider).requireValue
              as Authenticated;
      expect(state is AuthenticatedLocked, locked);
      expect(state.session.accessToken, 'new');
      expect(state.session.refreshToken, 'refresh');
      expect(state.user.kbkey, 'permanent-key');
      expect(
        (await container.read(authenticationSessionStorageProvider).read())!
            .accessToken,
        'new',
      );
      expect(adapter.refreshes, 1);
    });
  }
  test(
    'locking during refresh preserves locked state and completes renewal',
    () async {
      adapter.gate = Completer<void>();
      final pending = read();
      await adapter.started.future;
      container.read(authenticationControllerProvider.notifier).lock();
      adapter.gate!.complete();
      await pending;
      final state = container
          .read(authenticationControllerProvider)
          .requireValue;
      expect(state, isA<AuthenticatedLocked>());
      expect((state as AuthenticatedLocked).session.accessToken, 'new');
    },
  );

  test('concurrent rejected requests share a refresh', () async {
    adapter.gate = Completer<void>();
    final first = read();
    final second = read();
    await adapter.started.future;
    await Future<void>.delayed(Duration.zero);
    adapter.gate!.complete();
    await Future.wait([first, second]);
    expect(adapter.refreshes, 1);
  });
  test('temporary refresh failure retains the session', () async {
    adapter.refreshStatus = 503;
    await expectLater(read(), throwsA(isA<APIException>()));
    expect(container.read(apiSessionProvider).accessToken, 'old');
    expect(
      await container.read(authenticationSessionStorageProvider).read(),
      isNotNull,
    );
  });
  test('invalid refresh clears authentication', () async {
    adapter.refreshStatus = 401;
    await expectLater(read(), throwsA(isA<APIException>()));
    expect(
      container.read(authenticationControllerProvider).requireValue,
      isA<Unauthenticated>(),
    );
    expect(
      await container.read(authenticationSessionStorageProvider).read(),
      isNull,
    );
  });
  test('late refresh cannot restore a cleared session', () async {
    adapter.gate = Completer<void>();
    final pending = expectLater(read(), throwsA(isA<APIException>()));
    await adapter.started.future;
    await container
        .read(authenticationControllerProvider.notifier)
        .clearSession();
    adapter.gate!.complete();
    await pending;
    expect(
      container.read(authenticationControllerProvider).requireValue,
      isA<Unauthenticated>(),
    );
    expect(
      await container.read(authenticationSessionStorageProvider).read(),
      isNull,
    );
  });
  test('mutating requests are never automatically replayed', () async {
    await expectLater(
      client.post<void>(
        'https://example.com/private',
        authenticated: true,
        data: {'value': 1},
        decode: (_) {},
      ),
      throwsA(isA<APIException>()),
    );
    expect(adapter.privateCalls, 1);
    expect(adapter.refreshes, 1);
  });
  test('a rejected retry invalidates without refreshing twice', () async {
    adapter.rejectRenewed = true;
    await expectLater(read(), throwsA(isA<APIException>()));
    expect(adapter.refreshes, 1);
    expect(adapter.privateCalls, 2);
    expect(container.read(apiSessionProvider).accessToken, isNull);
  });
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
    accessToken: 'old',
    refreshToken: 'refresh',
  ),
  message: 'Completed.',
);

class _Adapter implements HttpClientAdapter {
  int refreshes = 0;
  int privateCalls = 0;
  int refreshStatus = 200;
  bool rejectRenewed = false;
  Completer<void>? gate;
  final started = Completer<void>();
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final refresh = options.path.endsWith('/refresh');
    if (refresh) {
      refreshes++;
      expect(options.data, {'refresh_token': 'refresh'});
      expect(options.headers['Authorization'], isNull);
      if (!started.isCompleted) started.complete();
      if (gate != null) await gate!.future;
    } else {
      privateCalls++;
    }
    final status = refresh
        ? refreshStatus
        : options.headers['Authorization'] == 'Bearer new' && !rejectRenewed
        ? 200
        : 401;
    return ResponseBody.fromString(
      jsonEncode({
        'success': status == 200,
        'data': status == 200 ? (refresh ? {'access_token': 'new'} : {}) : null,
        'error': status == 200
            ? null
            : {
                'code': refresh ? 'invalid_refresh_token' : 'invalid_session',
                'message': 'Rejected.',
              },
        'meta': null,
      }),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
