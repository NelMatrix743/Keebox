import 'package:keebox/features/authentication/models/recovery_type.dart';
import 'package:keebox/features/authentication/models/recovery_response.dart';

enum RecoveryStage {
  email,
  otp,
  credential,
  completed,
  restartRequired,
  completionUncertain,
}

enum RecoveryOperation { start, resend, verify, complete }

class RecoveryState {
  const RecoveryState({
    required this.type,
    this.stage = RecoveryStage.email,
    this.email = '',
    this.challenge,
    this.verified,
    this.completed,
    this.operation,
    this.errorMessage,
    this.errorCode,
    this.errorDetails,
    this.feedbackRevision = 0,
  });

  final RecoveryType type;
  final RecoveryStage stage;
  final String email;
  final RecoveryChallenge? challenge;
  final RecoveryVerified? verified;
  final RecoveryCompleted? completed;
  final RecoveryOperation? operation;
  final String? errorMessage;
  final String? errorCode;
  final Object? errorDetails;
  final int feedbackRevision;

  bool get isSubmitting => operation != null;
  String? get resetId => challenge?.resetId;
}
