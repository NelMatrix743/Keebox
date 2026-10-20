import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/features/authentication/state/recovery_controller.dart';
import 'package:keebox/features/authentication/widgets/recovery_app_bar.dart';

class RecoveryOtpPlaceholderScreen extends ConsumerWidget {
  const RecoveryOtpPlaceholderScreen({required this.scope, super.key});
  final RecoveryScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recoveryControllerProvider(scope));
    return Scaffold(
      appBar: const RecoveryAppBar(),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppTexts.recoveryOtpTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  state.challenge?.message ?? AppTexts.recoveryResponseInvalid,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  AppTexts.recoveryOtpPlaceholder,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
