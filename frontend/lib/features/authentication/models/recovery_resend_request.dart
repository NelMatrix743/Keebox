import 'package:keebox/features/authentication/models/recovery_json.dart';

class RecoveryResendRequest {
  const RecoveryResendRequest({required this.resetId});
  final String resetId;
  Map<String, dynamic> toJson() => {'reset_id': requireResetId(resetId)};
}
