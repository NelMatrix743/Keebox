import 'package:keebox/features/authentication/models/recovery_json.dart';

/// Shared response for recovery initiation and OTP resending.
class RecoveryChallenge {
  const RecoveryChallenge({
    required this.resetId,
    required this.otpExpiresAt,
    required this.resendAvailableAt,
    required this.message,
  });
  final String resetId;
  final DateTime otpExpiresAt;
  final DateTime resendAvailableAt;
  final String message;
  factory RecoveryChallenge.fromJson(Object? data) {
    final json = recoveryJson(data, 'otp_pending');
    return RecoveryChallenge(
      resetId: requireResetId(recoveryString(json, 'reset_id')),
      otpExpiresAt: recoveryTimestamp(json, 'otp_expires_at'),
      resendAvailableAt: recoveryTimestamp(json, 'resend_available_at'),
      message: recoveryString(json, 'message'),
    );
  }
}
