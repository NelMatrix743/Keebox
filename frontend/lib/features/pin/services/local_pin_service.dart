import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:keebox/features/pin/local_pin_policy.dart';
import 'package:keebox/features/pin/models/local_pin_record.dart';
import 'package:keebox/features/pin/models/local_pin_verification.dart';
import 'package:keebox/features/pin/services/local_pin_hasher.dart';
import 'package:keebox/features/pin/storage/local_pin_storage.dart';

final localPinServiceProvider = Provider<LocalPinService>((ref) {
  return LocalPinService(
    storage: ref.watch(localPinStorageProvider),
    hasher: ref.watch(localPinHasherProvider),
  );
});

class LocalPinService {
  LocalPinService({required this.storage, required this.hasher});

  final LocalPinStorage storage;
  final LocalPinHasher hasher;
  Future<void> _pending = Future<void>.value();

  Future<bool> enrollVerifiedPin(
    String userId,
    String pin, {
    bool Function()? isActive,
  }) => _serialize(() async {
    if (userId.isEmpty || !LocalPinPolicy.isValid(pin)) {
      throw const FormatException('Invalid local PIN enrollment.');
    }
    if (isActive != null && !isActive()) return false;
    final salt = hasher.newSalt();
    final verifier = await hasher.derive(pin, salt);
    if (isActive != null && !isActive()) return false;
    await storage.save(
      LocalPinRecord(userId: userId, salt: salt, verifier: verifier),
    );
    return true;
  });

  Future<LocalPinVerification> verify(String userId, String pin) => _serialize(
    () async {
      LocalPinRecord? record;
      try {
        record = await storage.read(userId);
      } on FormatException {
        return const LocalPinVerification(
          LocalPinStatus.requiresReauthentication,
        );
      } catch (_) {
        return const LocalPinVerification(LocalPinStatus.unavailable);
      }
      if (record == null || record.requiresReauthentication) {
        return LocalPinVerification(
          LocalPinStatus.requiresReauthentication,
          failedAttempts: record?.failedAttempts ?? 0,
        );
      }
      if (!LocalPinPolicy.isValid(pin)) {
        return LocalPinVerification(
          LocalPinStatus.invalidInput,
          failedAttempts: record.failedAttempts,
        );
      }
      try {
        final matched = await hasher.verify(pin, record.salt, record.verifier);
        final attempts = matched ? 0 : record.failedAttempts + 1;
        final updated = record.withFailedAttempts(attempts);
        if (attempts != record.failedAttempts) await storage.save(updated);
        return LocalPinVerification(
          matched
              ? LocalPinStatus.matched
              : updated.requiresReauthentication
              ? LocalPinStatus.requiresReauthentication
              : LocalPinStatus.incorrect,
          failedAttempts: attempts,
        );
      } catch (_) {
        return LocalPinVerification(
          LocalPinStatus.unavailable,
          failedAttempts: record.failedAttempts,
        );
      }
    },
  );

  Future<T> _serialize<T>(Future<T> Function() action) {
    final operation = _pending.then((_) => action());
    _pending = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return operation;
  }
}
