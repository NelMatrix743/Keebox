Map<String, dynamic> authenticationJson(Object? data) {
  if (data is! Map<String, dynamic>) {
    throw const FormatException('Expected an authentication response object.');
  }
  return data;
}

String authenticationString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is! String) {
    throw FormatException('Expected a string for $field.');
  }
  return value;
}

void requireAuthenticationStatus(Map<String, dynamic> json, String expected) {
  if (authenticationString(json, 'status') != expected) {
    throw const FormatException('Unexpected authentication response status.');
  }
}
