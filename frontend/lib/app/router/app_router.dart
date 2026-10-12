import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:keebox/app/router/app_routes.dart';
import 'package:keebox/features/onboarding/screens/onboarding_screen.dart';
import 'package:keebox/features/authentication/screens/login_screen.dart';
import 'package:keebox/features/authentication/screens/login_pin_screen.dart';
import 'package:keebox/features/authentication/state/authentication_controller.dart';
import 'package:keebox/features/authentication/state/authentication_state.dart';
import 'package:keebox/features/pin/models/pin_setup_mode.dart';
import 'package:keebox/features/pin/screens/pin_setup_screen.dart';
import 'package:keebox/features/home/screens/home_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.root,
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
            ref.read(authenticationControllerProvider).asData?.value
                is AwaitingPin
            ? null
            : AppRoutes.signIn,
        builder: (context, state) => LoginPinScreen(
          onAuthenticated: () => context.goNamed(AppRoutes.homeName),
          onLoginRequired: () => context.goNamed(AppRoutes.signInName),
          onResetPin: () => context.pushNamed(AppRoutes.resetPinName),
        ),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: AppRoutes.homeName,
        redirect: (context, state) =>
            ref.read(authenticationControllerProvider).asData?.value
                is Authenticated
            ? null
            : AppRoutes.signIn,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        name: AppRoutes.forgotPasswordName,
        builder: (context, state) =>
            Scaffold(appBar: AppBar(title: const Text('Reset Password'))),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: AppRoutes.registerName,
        builder: (context, state) =>
            Scaffold(appBar: AppBar(title: const Text('Create Account'))),
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
  ref.listen(authenticationControllerProvider, (_, next) {
    if (router.routeInformationProvider.value.uri.path == AppRoutes.home) {
      router.refresh();
    }
  });
  ref.onDispose(router.dispose);
  return router;
});
