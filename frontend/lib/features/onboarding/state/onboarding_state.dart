class OnboardingState {
  const OnboardingState({
    this.isCompleted = false,
    this.isSaving = false,
    this.errorMessage,
  });

  final bool isCompleted;
  final bool isSaving;
  final String? errorMessage;
}
