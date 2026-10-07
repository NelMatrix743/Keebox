import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keebox/features/authentication/models/authenticated_user.dart';
import 'package:keebox/features/authentication/storage/authenticated_user_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secureStorage = FlutterSecureStorage();
  const users = AuthenticatedUserStorage(storage: secureStorage);

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('unknown account has no stored user', () async {
    expect(await users.read('unknown'), isNull);
  });

  test('persists profile and KBKey across storage instances', () async {
    await users.save(_user());
    final restored = await const AuthenticatedUserStorage(
      storage: secureStorage,
    ).read('user-1');
    expect(restored!.id, 'user-1');
    expect(restored.firstName, 'Ada');
    expect(restored.lastName, 'Lovelace');
    expect(restored.email, 'ada@example.com');
    expect(restored.kbkey, 'permanent-key');
  });

  test('updates profile data with the same permanent key', () async {
    await users.save(_user());
    await users.save(_user(email: 'new@example.com'));
    final restored = await users.read('user-1');
    expect(restored!.email, 'new@example.com');
    expect(restored.kbkey, 'permanent-key');
  });

  test('keeps different account profiles and keys separate', () async {
    await users.save(_user());
    await users.save(_user(id: 'user-2', kbkey: 'other-key'));
    expect((await users.read('user-1'))!.kbkey, 'permanent-key');
    expect((await users.read('user-2'))!.kbkey, 'other-key');
  });

  test('reports corrupt profile without deleting retained key data', () async {
    await users.save(_user());
    final key = (await secureStorage.readAll()).keys.single;
    await secureStorage.write(key: key, value: 'invalid-json');
    await expectLater(users.read('user-1'), throwsFormatException);
    expect(await secureStorage.read(key: key), 'invalid-json');
  });
}

AuthenticatedUser _user({
  String id = 'user-1',
  String email = 'ada@example.com',
  String kbkey = 'permanent-key',
}) => AuthenticatedUser(
  id: id,
  firstName: 'Ada',
  lastName: 'Lovelace',
  email: email,
  kbkey: kbkey,
);
