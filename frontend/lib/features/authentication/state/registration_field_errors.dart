import 'package:keebox/features/authentication/state/registration_state.dart';

String? registrationFieldError(RegistrationState state, String field) {
  if (field == 'email' && state.errorCode == 'registration_email_conflict') {
    return state.errorMessage;
  }
  if (state.errorCode != 'validation_error' || state.errorDetails is! List) {
    return null;
  }
  final messages = <String>[];
  for (final detail in state.errorDetails! as List) {
    if (detail is! Map) continue;
    final location = detail['location'];
    final message = detail['message'];
    if (location is List &&
        location.isNotEmpty &&
        location.last == field &&
        message is String &&
        message.trim().isNotEmpty) {
      messages.add(message);
    }
  }
  return messages.isEmpty ? null : messages.join('\n');
}
