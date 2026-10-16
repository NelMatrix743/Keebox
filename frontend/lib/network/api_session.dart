import 'package:flutter_riverpod/flutter_riverpod.dart';

final apiSessionProvider = Provider<APISession>((ref) => APISession());

class APISession {
  String? _accessToken;
  Future<void> Function()? _onInvalidSession;
  Future<String?> Function()? _onRefresh;
  Future<String?>? _refreshing;
  int _generation = 0;
  String? _previousToken;

  String? get accessToken => _accessToken;

  void set(
    String token, {
    required Future<void> Function() onInvalidSession,
    Future<String?> Function()? onRefresh,
    String? previousToken,
  }) {
    _previousToken = previousToken;
    _generation++;
    _refreshing = null;
    _accessToken = token;
    _onInvalidSession = onInvalidSession;
    _onRefresh = onRefresh;
  }

  void clear() {
    _previousToken = null;
    _generation++;
    _refreshing = null;
    _accessToken = null;
    _onInvalidSession = null;
    _onRefresh = null;
  }

  Future<String?> refresh(String rejectedToken) async {
    if (_accessToken == null) return null;
    if (_accessToken != rejectedToken) {
      return _previousToken == rejectedToken ? _accessToken : null;
    }
    final callback = _onRefresh;
    if (callback == null) {
      await invalidate(rejectedToken);
      return null;
    }
    final generation = _generation;
    final pending = _refreshing ??= callback();
    try {
      final token = await pending;
      return token != null && _accessToken == token ? token : null;
    } finally {
      if (_generation == generation && identical(_refreshing, pending)) {
        _refreshing = null;
      }
    }
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
