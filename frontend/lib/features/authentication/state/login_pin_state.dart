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
