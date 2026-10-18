import 'package:keebox/features/authentication/recovery/models/recovery_json.dart';

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
