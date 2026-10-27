import 'package:keebox/features/authentication/models/registration_json.dart';

class RegistrationRequest {
  const RegistrationRequest({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.password,
  });

  final String firstName;
  final String lastName;
  final String email;
  final String password;

  Map<String, dynamic> toJson() {
    if (password.isEmpty) {
      throw const FormatException('Registration password is required.');
    }
    return {
      'first_name': _identityText(firstName, 'first_name', 150),
      'last_name': _identityText(lastName, 'last_name', 150),
      'email': _identityText(email, 'email', 254),
      'password': password,
    };
  }
}

class RegistrationVerifyRequest {
  const RegistrationVerifyRequest({
    required this.registrationId,
    required this.otpCode,
  });

  final String registrationId;
  final String otpCode;

  Map<String, dynamic> toJson() {
    if (otpCode.length != 6 || !RegExp(r'^[0-9]{6}$').hasMatch(otpCode)) {
      throw const FormatException(
        'Registration OTP must contain six ASCII digits.',
      );
    }
    return {
      'registration_id': requireRegistrationId(registrationId),
      'otp_code': otpCode,
    };
  }
}

class RegistrationResendRequest {
  const RegistrationResendRequest({required this.registrationId});

  final String registrationId;

  Map<String, dynamic> toJson() => {
    'registration_id': requireRegistrationId(registrationId),
  };
}

class RegistrationCompletionRequest {
  const RegistrationCompletionRequest({
    required this.registrationId,
    required this.pin,
  });

  final String registrationId;
  final String pin;

  Map<String, dynamic> toJson() {
    if (pin.length != 5 || !RegExp(r'^[0-9]{5}$').hasMatch(pin)) {
      throw const FormatException(
        'Registration PIN must contain five ASCII digits.',
      );
    }
    return {
      'registration_id': requireRegistrationId(registrationId),
      'pin': pin,
    };
  }
}

String _identityText(String value, String field, int maximumLength) {
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed.runes.length > maximumLength) {
    throw FormatException('Invalid registration $field.');
  }
  return trimmed;
}
