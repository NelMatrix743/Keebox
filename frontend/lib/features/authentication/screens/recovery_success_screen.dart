import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/features/authentication/screens/authentication_success_screen.dart';
import 'package:keebox/features/authentication/state/recovery_completion.dart';
import 'package:keebox/features/authentication/state/recovery_controller.dart';
import 'package:keebox/shared/widgets/app_snackbar.dart';

class RecoverySuccessScreen extends ConsumerWidget {
  const RecoverySuccessScreen({
    required this.scope,
    required this.onContinue,
    super.key,
  });

  final RecoveryScope scope;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completion = ref.watch(recoveryCompletionProvider(scope));
    ref.listen(recoveryCompletionProvider(scope), (previous, next) {
      if (next.hasError && previous?.hasError != true) {
        AppSnackBar.show(
          context,
          message: AppTexts.recoveryCleanupFailed,
          type: AppSnackBarType.error,
        );
      }
    });
    final ready =
        completion.hasValue && !completion.isLoading && !completion.hasError;
    return AuthenticationSuccessScreen(
      message: AppTexts.recoveryCompletedMessage,
      semanticsLabel: AppTexts.recoveryCompletedTitle,
      onContinue: ready ? onContinue : null,
      isLoading: completion.isLoading,
      errorMessage: completion.hasError ? AppTexts.recoveryCleanupFailed : null,
      onRetry: () {
        AppSnackBar.dismiss(context);
        ref.invalidate(recoveryCompletionProvider(scope));
      },
    );
  }
}
