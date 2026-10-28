import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keebox/app/startup/startup_coordinator.dart';

import 'package:keebox/app/router/app_routes.dart';
import 'package:keebox/features/onboarding/screens/onboarding_screen.dart';
import 'package:keebox/features/authentication/screens/login_screen.dart';
import 'package:keebox/features/authentication/screens/registration_screen.dart';
import 'package:keebox/features/authentication/models/recovery_type.dart';
import 'package:keebox/features/authentication/screens/recovery_email_screen.dart';
import 'package:keebox/features/authentication/screens/otp_verification_screen.dart';
import 'package:keebox/features/authentication/state/otp_verification_flow.dart';
import 'package:keebox/features/authentication/screens/pin_reset_screen.dart';
import 'package:keebox/features/authentication/screens/password_reset_screen.dart';
import 'package:keebox/features/authentication/screens/recovery_success_screen.dart';
import 'package:keebox/features/authentication/state/recovery_state.dart';
import 'package:keebox/features/authentication/state/recovery_controller.dart';
import 'package:keebox/features/authentication/screens/login_pin_screen.dart';
import 'package:keebox/features/authentication/state/authentication_controller.dart';
import 'package:keebox/features/authentication/state/authentication_state.dart';
import 'package:keebox/features/pin/models/pin_setup_mode.dart';
import 'package:keebox/features/pin/screens/pin_setup_screen.dart';
import 'package:keebox/features/pin/screens/local_unlock_screen.dart';
import 'package:keebox/features/home/screens/home_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  String? returnLocation;
  String? returnUserId;
  String unlockDestination() {
    final auth = ref.read(authenticationControllerProvider).asData?.value;
    final saved = returnLocation;
    final permitted =
        auth is AuthenticatedUnlocked &&
        auth.user.id == returnUserId &&
        saved != null &&
        Uri.tryParse(saved)?.path == AppRoutes.home;
    return permitted ? saved : AppRoutes.home;
  }

  final router = GoRouter(
    initialLocation: ref.read(initialRouteProvider),
    routes: [
      GoRoute(
        path: AppRoutes.root,
        name: AppRoutes.rootName,
        builder: (context, state) => OnboardingScreen(
          onSignIn: () => context.pushNamed(AppRoutes.signInName),
          onGetStarted: () => context.pushNamed(AppRoutes.registerName),
        ),
      ),
      GoRoute(
        path: AppRoutes.signIn,
        name: AppRoutes.signInName,
        builder: (context, state) => LoginScreen(
          onLoginVerified: (_) => context.goNamed(AppRoutes.homeLockName),
          onRegister: () => context.pushNamed(AppRoutes.registerName),
          onForgotPassword: () =>
              context.pushNamed(AppRoutes.forgotPasswordName),
        ),
      ),
      GoRoute(
        path: AppRoutes.homeLock,
        name: AppRoutes.homeLockName,
        redirect: (context, state) =>
            switch (ref.read(authenticationControllerProvider).asData?.value) {
              AwaitingPin() || AuthenticatedLocked() => null,
              AuthenticatedUnlocked() => unlockDestination(),
              _ => AppRoutes.signIn,
            },
        builder: (context, state) =>
            ref.read(authenticationControllerProvider).asData?.value
                is AuthenticatedLocked
            ? LocalUnlockScreen(
                onUnlocked: () => context.go(unlockDestination()),
                onLoginRequired: () => context.goNamed(AppRoutes.signInName),
                onResetPin: () => context.pushNamed(AppRoutes.recoverPinName),
              )
            : LoginPinScreen(
                onAuthenticated: () => context.goNamed(AppRoutes.homeName),
                onLoginRequired: () => context.goNamed(AppRoutes.signInName),
                onResetPin: () => context.pushNamed(AppRoutes.recoverPinName),
              ),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: AppRoutes.homeName,
        redirect: (context, state) =>
            switch (ref.read(authenticationControllerProvider).asData?.value) {
              AuthenticatedUnlocked() => null,
              AuthenticatedLocked() => AppRoutes.homeLock,
              _ => AppRoutes.signIn,
            },
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        name: AppRoutes.forgotPasswordName,
        builder: (context, state) => RecoveryEmailScreen(
          type: RecoveryType.password,
          onStarted: (scope) =>
              context.pushNamed(AppRoutes.recoveryOtpName, extra: scope),
        ),
      ),
      GoRoute(
        path: AppRoutes.recoverPin,
        name: AppRoutes.recoverPinName,
        builder: (context, state) => RecoveryEmailScreen(
          type: RecoveryType.pin,
          onStarted: (scope) =>
              context.pushNamed(AppRoutes.recoveryOtpName, extra: scope),
        ),
      ),
      GoRoute(
        path: AppRoutes.recoveryOtp,
        name: AppRoutes.recoveryOtpName,
        redirect: (context, state) =>
            state.extra is RecoveryScope ? null : AppRoutes.forgotPassword,
        builder: (context, state) => OtpVerificationScreen(
          flow: OtpVerificationFlow.recovery(state.extra! as RecoveryScope),
          onVerified: () => context.pushReplacementNamed(
            AppRoutes.recoveryResetName,
            extra: state.extra! as RecoveryScope,
          ),
          onRestart: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.goNamed(
                (state.extra! as RecoveryScope).type == RecoveryType.pin
                    ? AppRoutes.recoverPinName
                    : AppRoutes.forgotPasswordName,
              );
            }
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.recoveryReset,
        name: AppRoutes.recoveryResetName,
        redirect: (context, state) =>
            state.extra is RecoveryScope ? null : AppRoutes.forgotPassword,
        builder: (context, state) {
          final scope = state.extra! as RecoveryScope;
          if (scope.type == RecoveryType.pin) {
            return PinResetScreen(
              scope: scope,
              onCompleted: (scope) => context.goNamed(
                AppRoutes.recoveryCompletedName,
                extra: scope,
              ),
              onRestart: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.goNamed(AppRoutes.recoverPinName);
                }
              },
              onLoginRequired: () => context.goNamed(AppRoutes.signInName),
            );
          }
          return PasswordResetScreen(
            scope: scope,
            onCompleted: (scope) =>
                context.goNamed(AppRoutes.recoveryCompletedName, extra: scope),
            onRestart: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.goNamed(AppRoutes.forgotPasswordName);
              }
            },
            onLoginRequired: () => context.goNamed(AppRoutes.signInName),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.recoveryCompleted,
        name: AppRoutes.recoveryCompletedName,
        redirect: (context, state) {
          final extra = state.extra;
          if (extra is! RecoveryScope) return AppRoutes.signIn;
          final recovery = ref.read(recoveryControllerProvider(extra));
          return recovery.stage == RecoveryStage.completed &&
                  recovery.completed != null
              ? null
              : AppRoutes.signIn;
        },
        builder: (context, state) => RecoverySuccessScreen(
          scope: state.extra! as RecoveryScope,
          onContinue: () => context.goNamed(AppRoutes.signInName),
        ),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: AppRoutes.registerName,
        builder: (context, state) => RegistrationScreen(
          onSignIn: () => context.goNamed(AppRoutes.signInName),
        ),
      ),
      GoRoute(
        path: AppRoutes.createPin,
        name: AppRoutes.createPinName,
        builder: (context, state) => PinSetupScreen(
          mode: PinSetupMode.create,
          onPinConfirmed: (pin) {
            if (context.canPop()) context.pop(pin);
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.resetPin,
        name: AppRoutes.resetPinName,
        builder: (context, state) => PinSetupScreen(
          mode: PinSetupMode.reset,
          onPinConfirmed: (pin) {
            if (context.canPop()) context.pop(pin);
          },
        ),
      ),
    ],
  );
  ref.listen(authenticationControllerProvider, (previous, next) {
    final path = router.routeInformationProvider.value.uri.path;
    final before = previous?.asData?.value;
    final after = next.asData?.value;
    if (before is AuthenticatedUnlocked &&
        after is AuthenticatedLocked &&
        path == AppRoutes.home) {
      returnLocation = router.routeInformationProvider.value.uri.toString();
      returnUserId = after.user.id;
    } else if (after is Unauthenticated || after is AwaitingPin) {
      returnLocation = null;
      returnUserId = null;
    }
    if (path == AppRoutes.home || path == AppRoutes.homeLock) {
      router.refresh();
    }
  });
  ref.onDispose(router.dispose);
  return router;
});
