class LoginPinRequest {
  const LoginPinRequest({required this.loginChallengeId, required this.pin});

  final String loginChallengeId;
  final String pin;

  Map<String, dynamic> toJson() => {
    'login_challenge_id': loginChallengeId,
    'pin': pin,
  };
}
