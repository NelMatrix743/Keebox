import 'package:keebox/features/authentication/models/recovery_json.dart';

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
