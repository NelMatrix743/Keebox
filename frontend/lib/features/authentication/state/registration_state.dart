import 'package:keebox/features/authentication/models/authentication_result.dart';
import 'package:keebox/features/authentication/models/registration_response.dart';

enum RegistrationStage {
  form,
  otp,
  pin,
  completed,
  restartRequired,
  completionUncertain,
}

enum RegistrationOperation { start, resend, verify, complete }

class RegistrationState {
  const RegistrationState({
    this.stage = RegistrationStage.form,
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.challenge,
    this.verified,
    this.completed,
    this.resendsRemaining,
    this.otpUnavailable = false,
    this.otpRevision = 0,
    this.operation,
    this.errorMessage,
    this.errorCode,
    this.errorDetails,
    this.feedbackRevision = 0,
  });

  final RegistrationStage stage;
  final String firstName;
  final String lastName;
  final String email;
  final RegistrationChallenge? challenge;
  final RegistrationVerified? verified;
  final AuthenticationResult? completed;

  /// Unknown until the resend endpoint returns the server's allowance.
  final int? resendsRemaining;
  final bool otpUnavailable;
  final int otpRevision;
  final RegistrationOperation? operation;
  final String? errorMessage;
  final String? errorCode;
  final Object? errorDetails;
  final int feedbackRevision;

  bool get isSubmitting => operation != null;
  String? get registrationId => challenge?.registrationId;
}

enum RegistrationCompletionPhase { idle, submitting, saveFailed, ready }

class RegistrationCompletionState {
  const RegistrationCompletionState({
    this.phase = RegistrationCompletionPhase.idle,
    this.errorMessage,
  });
  final RegistrationCompletionPhase phase;
  final String? errorMessage;
  bool get isSubmitting => phase == RegistrationCompletionPhase.submitting;
  bool get isReady => phase == RegistrationCompletionPhase.ready;
  bool get canRetry => phase == RegistrationCompletionPhase.saveFailed;
}
