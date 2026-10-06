import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:keebox/app/router/app_routes.dart';
import 'package:keebox/features/onboarding/onboarding_screen.dart';

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
        builder: (context, state) =>
            Scaffold(appBar: AppBar(title: const Text('Sign In'))),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: AppRoutes.registerName,
        builder: (context, state) =>
            Scaffold(appBar: AppBar(title: const Text('Create Account'))),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
