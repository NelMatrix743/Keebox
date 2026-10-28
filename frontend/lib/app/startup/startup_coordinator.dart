import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keebox/app/router/app_routes.dart';
import 'package:keebox/features/authentication/state/authentication_controller.dart';
import 'package:keebox/features/onboarding/storage/onboarding_storage.dart';
import 'package:keebox/features/pin/storage/local_pin_storage.dart';

final initialRouteProvider = Provider<String>((ref) => AppRoutes.root);

final startupCoordinatorProvider = FutureProvider<String>((ref) async {
  final auth = await ref.read(authenticationControllerProvider.future);
  if (auth is Authenticated) {
    ref.read(authenticationControllerProvider.notifier).lock();
    final pin = await ref.read(localPinStorageProvider).read(auth.user.id);
    if (pin != null && !pin.requiresReauthentication) return AppRoutes.homeLock;
    await ref.read(authenticationControllerProvider.notifier).clearSession();
    return AppRoutes.signIn;
  }
  final completed = await ref.read(onboardingStorageProvider).isCompleted();
  return completed ? AppRoutes.signIn : AppRoutes.root;
});
