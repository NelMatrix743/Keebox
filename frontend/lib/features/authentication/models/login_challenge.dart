import 'package:keebox/features/authentication/models/authentication_json.dart';

class LoginChallenge {
  const LoginChallenge({
    required this.loginChallengeId,
    required this.expiresAt,
    required this.message,
  });

  final String loginChallengeId;
  final DateTime expiresAt;
  final String message;

  factory LoginChallenge.fromJson(Object? data) {
    final json = authenticationJson(data);
    requireAuthenticationStatus(json, 'password_verified');
    final expiration = DateTime.tryParse(
      authenticationString(json, 'expires_at'),
    );
    if (expiration == null) {
      throw const FormatException('Invalid login challenge expiration.');
    }
    return LoginChallenge(
      loginChallengeId: authenticationString(json, 'login_challenge_id'),
      expiresAt: expiration,
      message: authenticationString(json, 'message'),
    );
  }
}
