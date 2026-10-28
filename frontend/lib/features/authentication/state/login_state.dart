import 'package:keebox/features/authentication/models/login_response.dart';

class LoginState {
  const LoginState({
    this.isSubmitting = false,
    this.challenge,
    this.errorMessage,
  });

  final bool isSubmitting;
  final LoginChallenge? challenge;
  final String? errorMessage;
}

class LoginPinState {
  const LoginPinState({
    this.isSubmitting = false,
    this.isAuthenticated = false,
    this.requiresLogin = false,
    this.errorMessage,
  });

  final bool isSubmitting;
  final bool isAuthenticated;
  final bool requiresLogin;
  final String? errorMessage;
}
