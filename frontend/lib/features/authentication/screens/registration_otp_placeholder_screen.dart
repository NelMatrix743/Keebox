import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/features/authentication/state/registration_controller.dart';
import 'package:keebox/features/authentication/widgets/recovery_app_bar.dart';

class RegistrationOtpPlaceholderScreen extends ConsumerWidget {
  const RegistrationOtpPlaceholderScreen({
    required this.scope,
    required this.onBack,
    super.key,
  });
  final Object scope;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(registrationControllerProvider(scope));
    return Scaffold(
      appBar: RecoveryAppBar(onBack: onBack),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppTexts.registrationOtpPlaceholder,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  AppTexts.registrationOtpPlaceholderMessage,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(state.email, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
