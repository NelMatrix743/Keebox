import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:keebox/features/authentication/models/authenticated_user.dart';
import 'package:keebox/features/authentication/models/authentication_json.dart';
import 'package:keebox/features/authentication/models/authentication_session.dart';
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
  static String _userKey(String id) => 'keebox.auth.user.v1.$id';

  final FlutterSecureStorage storage;
  Future<void> _pending = Future<void>.value();

  Future<void> save(AuthenticationSession session) => _serialize(() async {
    final user = session.user;
    final existing = await storage.read(key: _userKey(user.id));
    if (existing != null) {
      final storedUser = AuthenticatedUser.fromJson(jsonDecode(existing));
      if (storedUser.id != user.id || storedUser.kbkey != user.kbkey) {
        throw StateError('The stored user encryption key cannot be replaced.');
      }
    }
    await storage.write(
      key: _userKey(user.id),
      value: jsonEncode({
        'user_id': user.id,
        'first_name': user.firstName,
        'last_name': user.lastName,
        'email': user.email,
        'kbkey': user.kbkey,
      }),
    );
    await storage.write(
      key: _sessionKey,
      value: jsonEncode({
        'user_id': user.id,
        'access_token': session.accessToken,
        'refresh_token': session.refreshToken,
      }),
    );
  });

  Future<AuthenticationSession?> read() => _serialize(() async {
    final raw = await storage.read(key: _sessionKey);
    if (raw == null) {
      return null;
    }
    try {
      final json = authenticationJson(jsonDecode(raw));
      final userId = authenticationString(json, 'user_id');
      final rawUser = await storage.read(key: _userKey(userId));
      if (rawUser == null) {
        throw const FormatException('Missing stored authentication user.');
      }
      final user = AuthenticatedUser.fromJson(jsonDecode(rawUser));
      if (user.id != userId) {
        throw const FormatException(
          'Stored authentication user does not match.',
        );
      }
      return AuthenticationSession(
        user: user,
        accessToken: authenticationString(json, 'access_token'),
        refreshToken: authenticationString(json, 'refresh_token'),
        message: '',
      );
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
