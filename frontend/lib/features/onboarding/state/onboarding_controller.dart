import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:keebox/app/app_texts.dart';
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
      return OnboardingState(isCompleted: completed);
    } catch (_) {
      return const OnboardingState(errorMessage: AppTexts.onboardingLoadFailed);
    }
  }

  Future<bool> complete() async {
    final current = state.asData?.value;
    if (current == null || current.isSaving) return false;
    if (current.isCompleted) return true;
    state = const AsyncData(OnboardingState(isSaving: true));
    try {
      await ref.read(onboardingStorageProvider).markCompleted();
      if (!ref.mounted) return false;
      state = const AsyncData(OnboardingState(isCompleted: true));
      return true;
    } catch (_) {
      if (!ref.mounted) return false;
      state = const AsyncData(
        OnboardingState(errorMessage: AppTexts.onboardingSaveFailed),
      );
      return false;
    }
  }
}
