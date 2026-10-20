import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/features/authentication/models/recovery_type.dart';
import 'package:keebox/features/authentication/state/recovery_controller.dart';
import 'package:keebox/features/authentication/widgets/recovery_app_bar.dart';

class RecoveryResetPlaceholderScreen extends ConsumerWidget {
  const RecoveryResetPlaceholderScreen({required this.scope, super.key});
  final RecoveryScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(recoveryControllerProvider(scope));
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
                  scope.type == RecoveryType.password
                      ? AppTexts.resetPasswordTitle
                      : AppTexts.resetPinTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  AppTexts.recoveryResetPlaceholder,
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
