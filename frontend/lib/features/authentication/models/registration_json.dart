import 'package:keebox/features/authentication/models/authentication_json.dart';

Map<String, dynamic> registrationJson(Object? data, String status) {
  final json = authenticationJson(data);
  requireAuthenticationStatus(json, status);
  return json;
}

String requireRegistrationId(String value) {
  if (value.length != 36 ||
      !RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(value)) {
    throw const FormatException('Invalid registration challenge ID.');
  }
  return value;
}

DateTime registrationTimestamp(Map<String, dynamic> json, String field) {
  final value = authenticationString(json, field);
  final date = DateTime.tryParse(value);
  if (date == null || !RegExp(r'(Z|[+-][0-9]{2}:[0-9]{2})$').hasMatch(value)) {
    throw FormatException('Invalid registration timestamp for $field.');
  }
  return date.toUtc();
}
