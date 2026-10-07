import 'package:keebox/features/authentication/models/authentication_json.dart';

class AuthenticationSession {
  const AuthenticationSession({
    required this.userId,
    required this.accessToken,
    required this.refreshToken,
  });

  final String userId;
  final String accessToken;
  final String refreshToken;

  factory AuthenticationSession.fromJson(Object? data) {
    final json = authenticationJson(data);
    return AuthenticationSession(
      userId: authenticationString(json, 'user_id'),
      accessToken: authenticationString(json, 'access_token'),
      refreshToken: authenticationString(json, 'refresh_token'),
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'access_token': accessToken,
    'refresh_token': refreshToken,
  };
}
