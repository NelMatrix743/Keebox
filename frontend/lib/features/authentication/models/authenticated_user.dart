import 'package:keebox/features/authentication/models/authentication_json.dart';

class AuthenticatedUser {
  const AuthenticatedUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.kbkey,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String kbkey;

  factory AuthenticatedUser.fromJson(Object? data) {
    final json = authenticationJson(data);
    return AuthenticatedUser(
      id: authenticationString(json, 'user_id'),
      firstName: authenticationString(json, 'first_name'),
      lastName: authenticationString(json, 'last_name'),
      email: authenticationString(json, 'email'),
      kbkey: authenticationString(json, 'kbkey'),
    );
  }
}
