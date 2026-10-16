import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/app/startup/startup_coordinator.dart';
import 'package:keebox/app/theme/app_theme.dart';
import 'package:keebox/features/authentication/state/authentication_controller.dart';

class StartupGate extends ConsumerWidget {
  const StartupGate({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startup = ref.watch(startupCoordinatorProvider);
    if (!startup.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => FlutterNativeSplash.remove(),
      );
    }
    return startup.when(
      data: (_) => child,
      loading: () => const SizedBox.shrink(),
      error: (_, _) => MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      AppTexts.startupFailed,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  FilledButton(
                    onPressed: () {
                      ref.invalidate(authenticationControllerProvider);
                      ref.invalidate(startupCoordinatorProvider);
                    },
                    child: const Text(AppTexts.retry),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
