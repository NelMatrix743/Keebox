import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:keebox/features/authentication/models/authentication_credentials.dart';
import 'package:keebox/storage/secure_storage.dart';

final authenticationSessionStorageProvider =
    Provider<AuthenticationSessionStorage>((ref) {
      return AuthenticationSessionStorage(
        storage: ref.watch(secureStorageProvider),
      );
    });

class AuthenticationSessionStorage {
  AuthenticationSessionStorage({required this.storage});

  static const _sessionKey = 'keebox.auth.session.v1';

  final FlutterSecureStorage storage;
  Future<void> _pending = Future<void>.value();

  Future<void> save(AuthenticationCredentials credentials) =>
      _serialize(() async {
        await storage.write(
          key: _sessionKey,
          value: jsonEncode(credentials.toJson()),
        );
      });

  Future<AuthenticationCredentials?> read() => _serialize(() async {
    final raw = await storage.read(key: _sessionKey);
    if (raw == null) {
      return null;
    }
    try {
      return AuthenticationCredentials.fromJson(jsonDecode(raw));
    } on FormatException {
      await storage.delete(key: _sessionKey);
      return null;
    }
  });

  Future<void> clear() => _serialize(() => storage.delete(key: _sessionKey));

  Future<T> _serialize<T>(Future<T> Function() action) {
    final operation = _pending.then((_) => action());
    _pending = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return operation;
  }
}
