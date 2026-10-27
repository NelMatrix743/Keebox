class LoginRequest {
  const LoginRequest({required this.email, required this.password});

  final String email;
  final String password;

  Map<String, dynamic> toJson() => {
    'email': email.trim(),
    'password': password,
  };
}

class LoginPinRequest {
  const LoginPinRequest({required this.loginChallengeId, required this.pin});

  final String loginChallengeId;
  final String pin;

  Map<String, dynamic> toJson() {
    if (pin.length != 5 || !RegExp(r'^[0-9]{5}$').hasMatch(pin)) {
      throw const FormatException(
        'The lock PIN must contain exactly 5 digits.',
      );
    }

    return {'login_challenge_id': loginChallengeId, 'pin': pin};
  }
}
