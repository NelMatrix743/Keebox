import 'package:keebox/features/authentication/models/authenticated_user.dart';
import 'package:keebox/features/authentication/models/authentication_json.dart';

class AuthenticationSession {
  const AuthenticationSession({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
    required this.kbkey,
    required this.message,
  });

  final AuthenticatedUser user;
  final String accessToken;
  final String refreshToken;
  final String kbkey;
  final String message;

  factory AuthenticationSession.fromJson(Object? data) {
    final json = authenticationJson(data);
    requireAuthenticationStatus(json, 'completed');
    return AuthenticationSession(
      user: AuthenticatedUser.fromJson(json),
      accessToken: authenticationString(json, 'access_token'),
      refreshToken: authenticationString(json, 'refresh_token'),
      kbkey: authenticationString(json, 'kbkey'),
      message: authenticationString(json, 'message'),
    );
  }
}
