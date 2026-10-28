import 'package:keebox/features/onboarding/models/onboarding_step.dart';

class OnboardingState {
  const OnboardingState({
    this.step = OnboardingStep.notes,
    this.isCompleted = false,
    this.isSaving = false,
    this.errorMessage,
  });

  final OnboardingStep step;
  final bool isCompleted;
  final bool isSaving;
  final String? errorMessage;

  bool get isWelcome => step == OnboardingStep.welcome;
  bool get canGoBack => !isSaving && !isCompleted && step.index > 0;
  bool get canGoForward => !isSaving && !isCompleted && !isWelcome;
}
