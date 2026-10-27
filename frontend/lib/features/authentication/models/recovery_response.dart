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

class RecoveryVerified {
  const RecoveryVerified({
    required this.resetId,
    required this.completionExpiresAt,
    required this.message,
  });
  final String resetId;
  final DateTime completionExpiresAt;
  final String message;
  factory RecoveryVerified.fromJson(Object? data) {
    final json = recoveryJson(data, 'otp_verified');
    return RecoveryVerified(
      resetId: requireResetId(recoveryString(json, 'reset_id')),
      completionExpiresAt: recoveryTimestamp(json, 'completion_expires_at'),
      message: recoveryString(json, 'message'),
    );
  }
}

/// Confirms recovery completion without creating an authenticated session.
class RecoveryCompleted {
  const RecoveryCompleted({required this.resetId, required this.message});
  final String resetId;
  final String message;
  factory RecoveryCompleted.fromJson(Object? data) {
    final json = recoveryJson(data, 'completed');
    return RecoveryCompleted(
      resetId: requireResetId(recoveryString(json, 'reset_id')),
      message: recoveryString(json, 'message'),
    );
  }
}
