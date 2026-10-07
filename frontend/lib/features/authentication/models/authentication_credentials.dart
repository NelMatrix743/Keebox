import 'package:keebox/features/authentication/models/authentication_json.dart';

class AuthenticationCredentials {
  const AuthenticationCredentials({
    required this.userId,
    required this.accessToken,
    required this.refreshToken,
  });

  final String userId;
  final String accessToken;
  final String refreshToken;

  factory AuthenticationCredentials.fromJson(Object? data) {
    final json = authenticationJson(data);
    return AuthenticationCredentials(
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
