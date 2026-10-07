import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:keebox/features/authentication/models/authenticated_user.dart';
import 'package:keebox/storage/secure_storage.dart';

final authenticatedUserStorageProvider = Provider<AuthenticatedUserStorage>((
  ref,
) {
  return AuthenticatedUserStorage(storage: ref.watch(secureStorageProvider));
});

class AuthenticatedUserStorage {
  const AuthenticatedUserStorage({required this.storage});

  final FlutterSecureStorage storage;

  static String _userKey(String id) => 'keebox.auth.user.v1.$id';

  Future<void> save(AuthenticatedUser user) => storage.write(
    key: _userKey(user.id),
    value: jsonEncode({
      'user_id': user.id,
      'first_name': user.firstName,
      'last_name': user.lastName,
      'email': user.email,
      'kbkey': user.kbkey,
    }),
  );

  Future<AuthenticatedUser?> read(String userId) async {
    final raw = await storage.read(key: _userKey(userId));
    if (raw == null) {
      return null;
    }
    final user = AuthenticatedUser.fromJson(jsonDecode(raw));
    if (user.id != userId) {
      throw const FormatException(
        'Stored user does not match the requested account.',
      );
    }
    return user;
  }
}
