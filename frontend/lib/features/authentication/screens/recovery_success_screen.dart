import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/features/authentication/state/recovery_completion.dart';
import 'package:keebox/features/authentication/state/recovery_controller.dart';
import 'package:keebox/features/authentication/widgets/recovery_continue_button.dart';
import 'package:keebox/features/authentication/widgets/recovery_success_animation.dart';
import 'package:keebox/features/authentication/widgets/recovery_success_message.dart';
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && ready) onContinue();
      },
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(41.w, 0, 41.w, 81.h),
                    child: Column(
                      children: [
                        const Spacer(flex: 253),
                        const RecoverySuccessAnimation(),
                        SizedBox(height: 22.h),
                        const RecoverySuccessMessage(),
                        if (completion.hasError) ...[
                          SizedBox(height: 16.h),
                          const Text(
                            AppTexts.recoveryCleanupFailed,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.red),
                          ),
                          TextButton(
                            onPressed: () {
                              AppSnackBar.dismiss(context);
                              ref.invalidate(recoveryCompletionProvider(scope));
                            },
                            child: const Text(AppTexts.retry),
                          ),
                        ],
                        const Spacer(flex: 248),
                        RecoveryContinueButton(
                          onPressed: ready ? onContinue : null,
                          isLoading: completion.isLoading,
                          loadingLabel: AppTexts.finishingRecovery,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
