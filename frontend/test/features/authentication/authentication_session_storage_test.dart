import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keebox/features/authentication/models/authenticated_user.dart';
import 'package:keebox/features/authentication/models/authentication_session.dart';
import 'package:keebox/features/authentication/storage/authentication_session_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secureStorage = FlutterSecureStorage();
  late AuthenticationSessionStorage storage;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    storage = AuthenticationSessionStorage(storage: secureStorage);
  });

  test('returns no session before authentication', () async {
    expect(await storage.read(), isNull);
  });

  test(
    'persists user and credentials and restores across storage instances',
    () async {
      await storage.save(_session());
      final restored = await AuthenticationSessionStorage(
        storage: secureStorage,
      ).read();
      expect(restored!.user.id, 'user-1');
      expect(restored.user.kbkey, 'permanent-key');
      expect(restored.user.email, 'ada@example.com');
      expect(restored.accessToken, 'access-1');
      expect(restored.refreshToken, 'refresh-1');
    },
  );

  test(
    'clearing session removes tokens and retains user encryption key',
    () async {
      await storage.save(_session());
      await storage.clear();
      expect(await storage.read(), isNull);
      final remaining = await secureStorage.readAll();
      expect(remaining.length, 1);
      expect(jsonDecode(remaining.values.single)['kbkey'], 'permanent-key');
    },
  );

  test('new session can update tokens without changing the user key', () async {
    await storage.save(_session());
    await storage.save(_session(accessToken: 'access-2'));
    final restored = await storage.read();
    expect(restored!.accessToken, 'access-2');
    expect(restored.user.kbkey, 'permanent-key');
  });

  test(
    'rejects a replacement KBKey for the same user and preserves session',
    () async {
      await storage.save(_session());
      await expectLater(
        storage.save(_session(kbkey: 'replacement')),
        throwsStateError,
      );
      final restored = await storage.read();
      expect(restored!.user.kbkey, 'permanent-key');
      expect(restored.accessToken, 'access-1');
    },
  );

  test('switching users keeps each account key separate', () async {
    await storage.save(_session());
    await storage.save(_session(userId: 'user-2', kbkey: 'other-key'));
    expect((await storage.read())!.user.id, 'user-2');
    await storage.save(_session());
    expect((await storage.read())!.user.kbkey, 'permanent-key');
  });

  test(
    'corrupt session is cleared without deleting retained user data',
    () async {
      await storage.save(_session());
      final values = await secureStorage.readAll();
      final sessionKey = values.entries
          .firstWhere(
            (entry) => jsonDecode(entry.value)['access_token'] != null,
          )
          .key;
      await secureStorage.write(key: sessionKey, value: 'invalid-json');
      expect(await storage.read(), isNull);
      expect(
        jsonDecode((await secureStorage.readAll()).values.single)['kbkey'],
        'permanent-key',
      );
    },
  );

  test('save followed by clear cannot leave a session behind', () async {
    final save = storage.save(_session());
    final clear = storage.clear();
    await Future.wait([save, clear]);
    expect(await storage.read(), isNull);
  });
}

AuthenticationSession _session({
  String userId = 'user-1',
  String kbkey = 'permanent-key',
  String accessToken = 'access-1',
}) => AuthenticationSession(
  user: AuthenticatedUser(
    id: userId,
    firstName: 'Ada',
    lastName: 'Lovelace',
    email: 'ada@example.com',
    kbkey: kbkey,
  ),
  accessToken: accessToken,
  refreshToken: 'refresh-1',
  message: 'Login completed.',
);
