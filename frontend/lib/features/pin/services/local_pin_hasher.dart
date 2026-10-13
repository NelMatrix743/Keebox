import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/helpers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:keebox/features/pin/local_pin_policy.dart';

final localPinHasherProvider = Provider<LocalPinHasher>(
  (ref) => const LocalPinHasher(),
);

class LocalPinHasher {
  const LocalPinHasher();

  List<int> newSalt() {
    final random = Random.secure();
    return List<int>.generate(
      LocalPinPolicy.saltLength,
      (_) => random.nextInt(256),
    );
  }

  Future<List<int>> derive(String pin, List<int> salt) async {
    if (!LocalPinPolicy.isValid(pin) ||
        salt.length != LocalPinPolicy.saltLength) {
      throw const FormatException('Invalid local PIN hashing input.');
    }
    return compute(_derive, (pin, salt));
  }

  Future<bool> verify(String pin, List<int> salt, List<int> expected) async {
    final actual = await derive(pin, salt);
    return constantTimeBytesEquality.equals(actual, expected);
  }
}

Future<List<int>> _derive((String, List<int>) input) async {
  final secret = SecretKeyData(utf8.encode(input.$1));
  try {
    final derived = await Argon2id(
      parallelism: LocalPinPolicy.parallelism,
      memory: LocalPinPolicy.memoryKiB,
      iterations: LocalPinPolicy.iterations,
      hashLength: LocalPinPolicy.verifierLength,
    ).deriveKey(secretKey: secret, nonce: input.$2);
    try {
      return List<int>.of(await derived.extractBytes());
    } finally {
      derived.destroy();
    }
  } finally {
    secret.destroy();
  }
}
