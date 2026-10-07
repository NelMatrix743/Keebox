import 'package:keebox/features/authentication/models/authenticated_user.dart';
import 'package:keebox/features/authentication/models/authentication_session.dart';
import 'package:keebox/features/authentication/models/login_challenge.dart';

sealed class AuthenticationState {
  const AuthenticationState();
}

class Unauthenticated extends AuthenticationState {
  const Unauthenticated();
}

class AwaitingPin extends AuthenticationState {
  const AwaitingPin(this.challenge);

  final LoginChallenge challenge;
}

class Authenticated extends AuthenticationState {
  const Authenticated({required this.user, required this.session});

  final AuthenticatedUser user;
  final AuthenticationSession session;
}
