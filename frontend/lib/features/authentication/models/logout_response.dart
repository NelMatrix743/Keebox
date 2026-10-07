import 'package:keebox/features/authentication/models/authentication_json.dart';

class LogoutResponse {
  const LogoutResponse({required this.message});

  final String message;

  factory LogoutResponse.fromJson(Object? data) {
    final json = authenticationJson(data);
    requireAuthenticationStatus(json, 'logged_out');
    return LogoutResponse(message: authenticationString(json, 'message'));
  }
}
