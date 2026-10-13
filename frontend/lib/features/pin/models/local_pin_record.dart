import 'dart:convert';

import 'package:keebox/features/pin/local_pin_policy.dart';

class LocalPinRecord {
  factory LocalPinRecord({
    required String userId,
    required List<int> salt,
    required List<int> verifier,
    int failedAttempts = 0,
  }) {
    if (userId.isEmpty ||
        salt.length != LocalPinPolicy.saltLength ||
        verifier.length != LocalPinPolicy.verifierLength ||
        [...salt, ...verifier].any((byte) => byte < 0 || byte > 255) ||
        failedAttempts < 0 ||
        failedAttempts > LocalPinPolicy.maxAttempts) {
      throw const FormatException('Invalid local PIN record.');
    }
    return LocalPinRecord._(
      userId,
      List.unmodifiable(salt),
      List.unmodifiable(verifier),
      failedAttempts,
    );
  }

  const LocalPinRecord._(
    this.userId,
    this.salt,
    this.verifier,
    this.failedAttempts,
  );

  final String userId;
  final List<int> salt;
  final List<int> verifier;
  final int failedAttempts;
  bool get requiresReauthentication =>
      failedAttempts >= LocalPinPolicy.maxAttempts;

  LocalPinRecord withFailedAttempts(int attempts) => LocalPinRecord(
    userId: userId,
    salt: salt,
    verifier: verifier,
    failedAttempts: attempts,
  );

  Map<String, Object> toJson() => {
    'version': LocalPinPolicy.recordVersion,
    'algorithm': 'argon2id',
    'memory_kib': LocalPinPolicy.memoryKiB,
    'iterations': LocalPinPolicy.iterations,
    'parallelism': LocalPinPolicy.parallelism,
    'user_id': userId,
    'salt': base64Encode(salt),
    'verifier': base64Encode(verifier),
    'failed_attempts': failedAttempts,
    'requires_reauthentication': requiresReauthentication,
  };

  factory LocalPinRecord.fromJson(Object? data) {
    if (data is! Map<String, dynamic> ||
        data['version'] != LocalPinPolicy.recordVersion ||
        data['algorithm'] != 'argon2id' ||
        data['memory_kib'] != LocalPinPolicy.memoryKiB ||
        data['iterations'] != LocalPinPolicy.iterations ||
        data['parallelism'] != LocalPinPolicy.parallelism ||
        data['user_id'] is! String ||
        data['salt'] is! String ||
        data['verifier'] is! String ||
        data['failed_attempts'] is! int ||
        data['requires_reauthentication'] is! bool) {
      throw const FormatException('Unsupported or corrupt local PIN record.');
    }
    final record = LocalPinRecord(
      userId: data['user_id'] as String,
      salt: base64Decode(data['salt'] as String),
      verifier: base64Decode(data['verifier'] as String),
      failedAttempts: data['failed_attempts'] as int,
    );
    if (record.requiresReauthentication != data['requires_reauthentication']) {
      throw const FormatException('Inconsistent local PIN retry state.');
    }
    return record;
  }
}
