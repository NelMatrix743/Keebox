import 'package:flutter_test/flutter_test.dart';
import 'package:keebox/features/authentication/models/authentication_session.dart';
import 'package:keebox/features/authentication/models/login_challenge.dart';
import 'package:keebox/features/authentication/models/login_request.dart';
import 'package:keebox/features/authentication/models/login_pin_request.dart';
import 'package:keebox/features/authentication/models/logout_response.dart';

void main() {
  test('login request trims email while preserving password whitespace', () {
    expect(
      const LoginRequest(
        email: ' user@example.com ',
        password: ' secret ',
      ).toJson(),
      {'email': 'user@example.com', 'password': ' secret '},
    );
  });

  test('PIN request preserves leading zeroes', () {
    expect(
      const LoginPinRequest(
        loginChallengeId: 'challenge-id',
        pin: '0012',
      ).toJson(),
      {'login_challenge_id': 'challenge-id', 'pin': '0012'},
    );
  });

  test(
    'password verification decodes challenge and timezone-aware expiration',
    () {
      final challenge = LoginChallenge.fromJson(_challenge());
      expect(challenge.loginChallengeId, 'challenge-id');
      expect(challenge.expiresAt, DateTime.utc(2026, 10, 7, 12));
      expect(challenge.message, 'Enter your lock PIN.');
    },
  );

  test('challenge rejects unexpected status and malformed expiration', () {
    expect(
      () => LoginChallenge.fromJson({..._challenge(), 'status': 'completed'}),
      throwsFormatException,
    );
    expect(
      () => LoginChallenge.fromJson({..._challenge(), 'expires_at': 'invalid'}),
      throwsFormatException,
    );
  });

  test('completed authentication decodes user and session credentials', () {
    final session = AuthenticationSession.fromJson(_session());
    expect(session.user.id, 'user-id');
    expect(session.user.firstName, 'Ada');
    expect(session.user.lastName, 'Lovelace');
    expect(session.user.email, 'ada@example.com');
    expect(session.accessToken, 'access-secret');
    expect(session.refreshToken, 'refresh-secret');
    expect(session.user.kbkey, 'key-secret');
    expect(session.message, 'Login completed successfully.');
  });

  test('password-verified payload cannot become an authenticated session', () {
    expect(
      () => AuthenticationSession.fromJson(_challenge()),
      throwsFormatException,
    );
  });

  test('session rejects missing or incorrectly typed required fields', () {
    for (final key in _session().keys) {
      final missing = _session()..remove(key);
      expect(
        () => AuthenticationSession.fromJson(missing),
        throwsFormatException,
      );
      expect(
        () => AuthenticationSession.fromJson({..._session(), key: 123}),
        throwsFormatException,
      );
    }
  });

  test('logout decodes confirmation and rejects unexpected status', () {
    final response = LogoutResponse.fromJson({
      'status': 'logged_out',
      'message': 'Logged out.',
    });
    expect(response.message, 'Logged out.');
    expect(
      () =>
          LogoutResponse.fromJson({'status': 'completed', 'message': 'Done.'}),
      throwsFormatException,
    );
  });
}

Map<String, dynamic> _challenge() => {
  'login_challenge_id': 'challenge-id',
  'status': 'password_verified',
  'expires_at': '2026-10-07T14:00:00+02:00',
  'message': 'Enter your lock PIN.',
};

Map<String, dynamic> _session() => {
  'user_id': 'user-id',
  'first_name': 'Ada',
  'last_name': 'Lovelace',
  'email': 'ada@example.com',
  'kbkey': 'key-secret',
  'access_token': 'access-secret',
  'refresh_token': 'refresh-secret',
  'status': 'completed',
  'message': 'Login completed successfully.',
};
