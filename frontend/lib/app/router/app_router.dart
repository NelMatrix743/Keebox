import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:keebox/app/router/app_routes.dart';
import 'package:keebox/features/onboarding/screens/onboarding_screen.dart';
import 'package:keebox/features/authentication/screens/login_screen.dart';
import 'package:keebox/features/authentication/screens/pin_verification_screen.dart';
import 'package:keebox/features/authentication/screens/authenticated_placeholder_screen.dart';
import 'package:keebox/features/authentication/state/authentication_controller.dart';
import 'package:keebox/features/authentication/state/authentication_state.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.root,
    redirect: (context, state) {
      final authentication = ref.read(authenticationControllerProvider);
      final current = authentication.asData?.value;
      final path = state.uri.path;
      if (current is Authenticated) {
        return path == AppRoutes.home ? null : AppRoutes.home;
      }
      if (current is AwaitingPin && path != AppRoutes.verifyPin) {
        return AppRoutes.verifyPin;
      }
      if (current is Unauthenticated &&
          (path == AppRoutes.home || path == AppRoutes.verifyPin)) {
        return AppRoutes.signIn;
      }
      if (current is! Authenticated && path == AppRoutes.home) {
        return AppRoutes.root;
      }
      if (current is! AwaitingPin && path == AppRoutes.verifyPin) {
        return AppRoutes.signIn;
      }
      return null;
    },
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
          onRegister: () => context.pushNamed(AppRoutes.registerName),
          onForgotPassword: () =>
              context.pushNamed(AppRoutes.forgotPasswordName),
        ),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        name: AppRoutes.forgotPasswordName,
        builder: (context, state) =>
            Scaffold(appBar: AppBar(title: const Text('Reset Password'))),
      ),
      GoRoute(
        path: AppRoutes.verifyPin,
        name: AppRoutes.verifyPinName,
        builder: (context, state) => const PinVerificationScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: AppRoutes.homeName,
        builder: (context, state) => const AuthenticatedPlaceholderScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: AppRoutes.registerName,
        builder: (context, state) =>
            Scaffold(appBar: AppBar(title: const Text('Create Account'))),
      ),
    ],
  );
  ref.listen(
    authenticationControllerProvider,
    (previous, next) => router.refresh(),
  );
  ref.onDispose(router.dispose);
  return router;
});
