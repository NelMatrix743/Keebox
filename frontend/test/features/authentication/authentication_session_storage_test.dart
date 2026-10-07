import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keebox/features/authentication/models/authenticated_user.dart';
import 'package:keebox/features/authentication/models/authentication_credentials.dart';
import 'package:keebox/features/authentication/storage/user_storage.dart';
import 'package:keebox/features/authentication/storage/auth_session_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secureStorage = FlutterSecureStorage();
  late AuthenticationSessionStorage storage;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    storage = AuthenticationSessionStorage(storage: secureStorage);
  });

  test('returns no credentials before authentication', () async {
    expect(await storage.read(), isNull);
  });

  test('restores tokens and user ID without requiring user storage', () async {
    await storage.save(_credentials());
    final restored = await AuthenticationSessionStorage(storage: secureStorage)
        .read();
    expect(restored!.userId, 'user-1');
    expect(restored.accessToken, 'access-1');
    expect(restored.refreshToken, 'refresh-1');
  });

  test(
    'clearing session retains independently stored user and KBKey',
    () async {
      const users = AuthenticatedUserStorage(storage: secureStorage);
      await users.save(
        const AuthenticatedUser(
          id: 'user-1',
          firstName: 'Ada',
          lastName: 'Lovelace',
          email: 'ada@example.com',
          kbkey: 'permanent-key',
        ),
      );
      await storage.save(_credentials());
      await storage.clear();
      expect(await storage.read(), isNull);
      expect((await users.read('user-1'))!.kbkey, 'permanent-key');
    },
  );

  test('updates session credentials', () async {
    await storage.save(_credentials());
    await storage.save(_credentials(accessToken: 'access-2'));
    expect((await storage.read())!.accessToken, 'access-2');
  });

  test('clears corrupt credentials', () async {
    await storage.save(_credentials());
    final key = (await secureStorage.readAll()).keys.single;
    await secureStorage.write(key: key, value: 'invalid-json');
    expect(await storage.read(), isNull);
    expect(await secureStorage.read(key: key), isNull);
  });

  test('save followed by clear cannot leave a session behind', () async {
    final save = storage.save(_credentials());
    final clear = storage.clear();
    await Future.wait([save, clear]);
    expect(await storage.read(), isNull);
  });
}

AuthenticationCredentials _credentials({String accessToken = 'access-1'}) =>
    AuthenticationCredentials(
      userId: 'user-1',
      accessToken: accessToken,
      refreshToken: 'refresh-1',
    );
