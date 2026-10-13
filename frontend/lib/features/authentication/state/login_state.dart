import 'package:keebox/features/authentication/models/login_challenge.dart';

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
