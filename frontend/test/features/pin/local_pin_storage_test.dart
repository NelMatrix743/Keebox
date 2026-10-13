import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keebox/features/pin/models/local_pin_record.dart';
import 'package:keebox/features/pin/storage/local_pin_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secure = FlutterSecureStorage();
  const storage = LocalPinStorage(storage: secure);
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('missing credentials cannot supply a local verifier', () async {
    expect(await storage.read('first'), isNull);
  });

  test(
    'account-specific retry restrictions survive storage recreation',
    () async {
      await storage.save(_record('first', 5));
      await storage.save(_record('second', 1));
      final restored = await const LocalPinStorage(storage: secure)
          .read('first');
      expect(restored!.requiresReauthentication, isTrue);
      expect(restored.failedAttempts, 5);
      expect((await storage.read('second'))!.requiresReauthentication, isFalse);
      expect((await storage.read('second'))!.failedAttempts, 1);
    },
  );

  test('invalid or cross-account records fail closed without deleting retained data', () async {
    final valid = _record('first', 0).toJson();
    for (final changes in [
      {'user_id': 'another-account'},
      {'version': 99},
      {'algorithm': 'sha256'},
      {'memory_kib': 1},
      {'iterations': 0},
      {'parallelism': 8},
      {'salt': 'bad'},
      {'verifier': 'bad'},
      {'failed_attempts': -1},
      {'failed_attempts': 6},
      {'failed_attempts': 5, 'requires_reauthentication': false},
    ]) {
      final raw = jsonEncode({...valid, ...changes});
      await secure.write(key: 'keebox.pin.local.v1.first', value: raw);
      await expectLater(storage.read('first'), throwsFormatException);
      expect(await secure.read(key: 'keebox.pin.local.v1.first'), raw);
    }
  });

  test(
    'malformed JSON is rejected instead of treated as an unlocked account',
    () async {
      await secure.write(key: 'keebox.pin.local.v1.first', value: '{broken');
      await expectLater(storage.read('first'), throwsFormatException);
    },
  );
}

LocalPinRecord _record(String userId, int attempts) => LocalPinRecord(
  userId: userId,
  salt: List.filled(16, 1),
  verifier: List.filled(32, 2),
  failedAttempts: attempts,
);
