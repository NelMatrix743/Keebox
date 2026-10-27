import 'package:keebox/features/authentication/models/recovery_json.dart';

class RecoveryStartRequest {
  const RecoveryStartRequest({required this.email});
  final String email;
  Map<String, dynamic> toJson() {
    final value = email.trim();
    if (value.isEmpty) {
      throw const FormatException('Recovery email is required.');
    }
    return {'email': value};
  }
}

class RecoveryResendRequest {
  const RecoveryResendRequest({required this.resetId});
  final String resetId;
  Map<String, dynamic> toJson() => {'reset_id': requireResetId(resetId)};
}

class RecoveryVerifyRequest {
  const RecoveryVerifyRequest({required this.resetId, required this.otpCode});
  final String resetId;
  final String otpCode;
  Map<String, dynamic> toJson() {
    if (otpCode.length != 6 || !RegExp(r'^[0-9]{6}$').hasMatch(otpCode)) {
      throw const FormatException(
        'Recovery OTP must contain six ASCII digits.',
      );
    }
    return {'reset_id': requireResetId(resetId), 'otp_code': otpCode};
  }
}

class PasswordResetRequest {
  const PasswordResetRequest({
    required this.resetId,
    required this.newPassword,
  });
  final String resetId;
  final String newPassword;
  Map<String, dynamic> toJson() {
    if (newPassword.isEmpty) {
      throw const FormatException('New password is required.');
    }
    return {'reset_id': requireResetId(resetId), 'new_password': newPassword};
  }
}

class PinResetRequest {
  const PinResetRequest({required this.resetId, required this.newPin});
  final String resetId;
  final String newPin;
  Map<String, dynamic> toJson() {
    if (newPin.length != 5 || !RegExp(r'^[0-9]{5}$').hasMatch(newPin)) {
      throw const FormatException('New PIN must contain five ASCII digits.');
    }
    return {'reset_id': requireResetId(resetId), 'new_pin': newPin};
  }
}
