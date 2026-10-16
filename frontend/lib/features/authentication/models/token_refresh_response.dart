import 'package:keebox/features/authentication/models/authentication_json.dart';

class TokenRefreshResponse {
  const TokenRefreshResponse({required this.accessToken});

  final String accessToken;

  factory TokenRefreshResponse.fromJson(Object? data) => TokenRefreshResponse(
    accessToken: authenticationString(authenticationJson(data), 'access_token'),
  );
}
