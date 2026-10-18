class RecoveryStartRequest {
  const RecoveryStartRequest({required this.email});
  final String email;
  Map<String, dynamic> toJson() {
    final value = email.trim();
    if (value.isEmpty) {
      throw const FormatException('Recovery email is required.');
    }
    return {'email': value};
  }
}
