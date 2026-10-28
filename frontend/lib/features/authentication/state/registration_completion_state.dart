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
