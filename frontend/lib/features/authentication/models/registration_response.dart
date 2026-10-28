import 'package:keebox/features/authentication/models/authentication_json.dart';
import 'package:keebox/features/authentication/models/registration_json.dart';

class RegistrationChallenge {
  const RegistrationChallenge({
    required this.registrationId,
    required this.expiresAt,
    required this.otpExpiresAt,
    required this.resendAvailableAt,
    required this.message,
  });

  final String registrationId;
  final DateTime expiresAt;
  final DateTime otpExpiresAt;
  final DateTime resendAvailableAt;
  final String message;

  factory RegistrationChallenge.fromJson(Object? data) {
    final json = registrationJson(data, 'otp_pending');
    return RegistrationChallenge(
      registrationId: requireRegistrationId(
        authenticationString(json, 'registration_id'),
      ),
      expiresAt: registrationTimestamp(json, 'expires_at'),
      otpExpiresAt: registrationTimestamp(json, 'otp_expires_at'),
      resendAvailableAt: registrationTimestamp(json, 'resend_available_at'),
      message: authenticationString(json, 'message'),
    );
  }
}

class RegistrationVerified {
  const RegistrationVerified({
    required this.registrationId,
    required this.message,
  });

  final String registrationId;
  final String message;

  factory RegistrationVerified.fromJson(Object? data) {
    final json = registrationJson(data, 'otp_verified');
    return RegistrationVerified(
      registrationId: requireRegistrationId(
        authenticationString(json, 'registration_id'),
      ),
      message: authenticationString(json, 'message'),
    );
  }
}

/// Updated OTP timing only; the original registration deadline still applies.
class RegistrationOtpResent {
  const RegistrationOtpResent({
    required this.registrationId,
    required this.otpExpiresAt,
    required this.resendAvailableAt,
    required this.resendsRemaining,
    required this.message,
  });

  final String registrationId;
  final DateTime otpExpiresAt;
  final DateTime resendAvailableAt;
  final int resendsRemaining;
  final String message;

  factory RegistrationOtpResent.fromJson(Object? data) {
    final json = registrationJson(data, 'otp_pending');
    final remaining = json['resends_remaining'];
    if (remaining is! int || remaining < 0) {
      throw const FormatException('Invalid registration resend allowance.');
    }
    return RegistrationOtpResent(
      registrationId: requireRegistrationId(
        authenticationString(json, 'registration_id'),
      ),
      otpExpiresAt: registrationTimestamp(json, 'otp_expires_at'),
      resendAvailableAt: registrationTimestamp(json, 'resend_available_at'),
      resendsRemaining: remaining,
      message: authenticationString(json, 'message'),
    );
  }
}
