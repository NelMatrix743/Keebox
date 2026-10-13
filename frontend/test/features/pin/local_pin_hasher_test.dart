import 'package:flutter_test/flutter_test.dart';

import 'package:keebox/features/pin/services/local_pin_hasher.dart';

void main() {
  const hasher = LocalPinHasher();

  test('leading-zero PIN matches an independent Argon2id reference', () async {
    final salt = List<int>.generate(16, (index) => index);
    final digest = await hasher.derive('01234', salt);
    expect(
      digest.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(),
      'f644e798c2399a5b16af901879b00371dd90d905d7c1c69c4ab0951e47b08db4',
    );
    expect(await hasher.verify('01234', salt, digest), isTrue);
    expect(await hasher.verify('01235', salt, digest), isFalse);
  });

  test('fresh salts produce distinct verifiers for the same PIN', () async {
    final first = hasher.newSalt();
    final second = hasher.newSalt();
    expect(
      await hasher.derive('12345', first),
      isNot(await hasher.derive('12345', second)),
    );
  });

  test('invalid PIN formats are rejected instead of normalized', () async {
    for (final pin in [
      '1234',
      '123456',
      '１２３４５',
      '12345\n',
      ' 12345',
      'abcde',
    ]) {
      await expectLater(
        hasher.derive(pin, List.filled(16, 0)),
        throwsFormatException,
      );
    }
  });
}
