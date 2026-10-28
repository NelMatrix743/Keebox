import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:keebox/app/app_texts.dart';
import 'package:keebox/features/onboarding/models/onboarding_step.dart';
import 'package:keebox/features/onboarding/state/onboarding_state.dart';
import 'package:keebox/features/onboarding/storage/onboarding_storage.dart';

final onboardingControllerProvider =
    AsyncNotifierProvider<OnboardingController, OnboardingState>(
      OnboardingController.new,
    );

class OnboardingController extends AsyncNotifier<OnboardingState> {
  @override
  Future<OnboardingState> build() async {
    try {
      final completed = await ref.read(onboardingStorageProvider).isCompleted();
      return OnboardingState(
        step: completed ? OnboardingStep.welcome : OnboardingStep.notes,
        isCompleted: completed,
      );
    } catch (_) {
      return const OnboardingState(errorMessage: AppTexts.onboardingLoadFailed);
    }
  }

  void next() {
    final current = state.asData?.value;
    if (current == null || !current.canGoForward) return;
    setPage(current.step.index + 1);
  }

  void previous() {
    final current = state.asData?.value;
    if (current == null || !current.canGoBack) return;
    setPage(current.step.index - 1);
  }

  void skip() => setPage(OnboardingStep.welcome.index);

  /// Accepts PageView selection changes as well as button navigation.
  void setPage(int index) {
    final current = state.asData?.value;
    if (current == null ||
        current.isSaving ||
        current.isCompleted ||
        index < 0 ||
        index >= OnboardingStep.values.length ||
        index == current.step.index) {
      return;
    }
    state = AsyncData(OnboardingState(step: OnboardingStep.values[index]));
  }

  Future<bool> complete() async {
    final current = state.asData?.value;
    if (current == null || current.isSaving) return false;
    if (current.isCompleted) return true;
    state = AsyncData(OnboardingState(step: current.step, isSaving: true));
    try {
      await ref.read(onboardingStorageProvider).markCompleted();
      if (!ref.mounted) return false;
      state = AsyncData(OnboardingState(step: current.step, isCompleted: true));
      return true;
    } catch (_) {
      if (!ref.mounted) return false;
      state = AsyncData(
        OnboardingState(
          step: current.step,
          errorMessage: AppTexts.onboardingSaveFailed,
        ),
      );
      return false;
    }
  }
}
