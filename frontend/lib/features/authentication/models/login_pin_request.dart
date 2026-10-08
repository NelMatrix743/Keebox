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
