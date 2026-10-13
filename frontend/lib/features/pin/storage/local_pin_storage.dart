import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:keebox/features/pin/models/local_pin_record.dart';
import 'package:keebox/storage/secure_storage.dart';

final localPinStorageProvider = Provider<LocalPinStorage>((ref) {
  return LocalPinStorage(storage: ref.watch(secureStorageProvider));
});

class LocalPinStorage {
  const LocalPinStorage({required this.storage});

  final FlutterSecureStorage storage;

  static String _key(String userId) => 'keebox.pin.local.v1.$userId';

  Future<LocalPinRecord?> read(String userId) async {
    final raw = await storage.read(key: _key(userId));
    if (raw == null) return null;
    final record = LocalPinRecord.fromJson(jsonDecode(raw));
    if (record.userId != userId) {
      throw const FormatException(
        'Local PIN record belongs to another account.',
      );
    }
    return record;
  }

  Future<void> save(LocalPinRecord record) => storage.write(
    key: _key(record.userId),
    value: jsonEncode(record.toJson()),
  );
}
