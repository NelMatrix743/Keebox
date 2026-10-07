import 'package:keebox/features/authentication/models/authenticated_user.dart';
import 'package:keebox/features/authentication/models/authentication_credentials.dart';
import 'package:keebox/features/authentication/models/authentication_json.dart';

class AuthenticationResult {
  const AuthenticationResult({
    required this.user,
    required this.session,
    required this.message,
  });

  final AuthenticatedUser user;
  final AuthenticationCredentials session;
  final String message;

  factory AuthenticationResult.fromJson(Object? data) {
    final json = authenticationJson(data);
    requireAuthenticationStatus(json, 'completed');
    return AuthenticationResult(
      user: AuthenticatedUser.fromJson(json),
      session: AuthenticationCredentials.fromJson(json),
      message: authenticationString(json, 'message'),
    );
  }
}
