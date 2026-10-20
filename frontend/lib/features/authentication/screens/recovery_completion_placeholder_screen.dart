import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/features/authentication/state/recovery_controller.dart';

class RecoveryCompletionPlaceholderScreen extends ConsumerWidget {
  const RecoveryCompletionPlaceholderScreen({
    required this.scope,
    required this.onLogin,
    super.key,
  });
  final RecoveryScope scope;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recoveryControllerProvider(scope));
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppTexts.recoveryCompletedTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  state.completed?.message ?? AppTexts.recoveryResponseInvalid,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: onLogin,
                  child: const Text(AppTexts.backToLogin),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
