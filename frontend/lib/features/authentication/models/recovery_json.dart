Map<String, dynamic> recoveryJson(Object? data, String status) {
  if (data is! Map<String, dynamic> || data['status'] != status) {
    throw const FormatException('Unexpected recovery response or stage.');
  }
  return data;
}

String recoveryString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is! String) throw FormatException('Expected a string for $field.');
  return value;
}

String requireResetId(String value) {
  if (!RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(value) ||
      value.length != 36) {
    throw const FormatException('Invalid recovery challenge ID.');
  }
  return value;
}

DateTime recoveryTimestamp(Map<String, dynamic> json, String field) {
  final value = recoveryString(json, field);
  final date = DateTime.tryParse(value);
  if (date == null || !RegExp(r'(Z|[+-][0-9]{2}:[0-9]{2})$').hasMatch(value)) {
    throw FormatException('Invalid recovery timestamp for $field.');
  }
  return date.toUtc();
}
