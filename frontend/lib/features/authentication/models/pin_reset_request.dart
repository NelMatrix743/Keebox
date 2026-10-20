import 'package:keebox/features/authentication/models/recovery_json.dart';

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
