import 'package:flutter_riverpod/flutter_riverpod.dart';

final apiSessionProvider = Provider<APISession>((ref) => APISession());

class APISession {
  String? _accessToken;
  Future<void> Function()? _onInvalidSession;

  String? get accessToken => _accessToken;

  void set(String token, {required Future<void> Function() onInvalidSession}) {
    _accessToken = token;
    _onInvalidSession = onInvalidSession;
  }

  void clear() {
    _accessToken = null;
    _onInvalidSession = null;
  }

  Future<void> invalidate(String token) async {
    if (_accessToken != token) {
      return;
    }
    final callback = _onInvalidSession;
    clear();
    await callback?.call();
  }
}
