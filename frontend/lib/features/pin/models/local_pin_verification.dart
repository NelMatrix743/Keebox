import 'package:keebox/features/pin/local_pin_policy.dart';

enum LocalPinStatus {
  matched,
  incorrect,
  invalidInput,
  requiresReauthentication,
  unavailable,
}

class LocalPinVerification {
  const LocalPinVerification(this.status, {this.failedAttempts = 0});

  final LocalPinStatus status;
  final int failedAttempts;
  int get remainingAttempts => LocalPinPolicy.maxAttempts - failedAttempts;
}
