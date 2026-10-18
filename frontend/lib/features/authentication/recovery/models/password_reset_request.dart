import 'package:keebox/features/authentication/recovery/models/recovery_json.dart';

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
