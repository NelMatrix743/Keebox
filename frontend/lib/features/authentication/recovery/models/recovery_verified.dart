import 'package:keebox/features/authentication/recovery/models/recovery_json.dart';

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
