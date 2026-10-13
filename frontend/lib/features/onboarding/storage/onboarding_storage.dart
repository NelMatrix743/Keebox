import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:keebox/storage/shared_preferences.dart';

final onboardingStorageProvider = Provider<OnboardingStorage>((ref) {
  return OnboardingStorage(preferences: ref.watch(sharedPreferencesProvider));
});

class OnboardingStorage {
  const OnboardingStorage({required this.preferences});

  static const _completedKey = 'keebox.onboarding.completed.v1';
  final SharedPreferencesAsync preferences;

  Future<bool> isCompleted() async =>
      await preferences.getBool(_completedKey) ?? false;

  Future<void> markCompleted() => preferences.setBool(_completedKey, true);
}
