import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/features/authentication/widgets/recovery_continue_button.dart';
import 'package:keebox/features/authentication/widgets/recovery_success_animation.dart';
import 'package:keebox/features/authentication/widgets/recovery_success_message.dart';

class AuthenticationSuccessScreen extends StatelessWidget {
  const AuthenticationSuccessScreen({
    required this.message,
    required this.semanticsLabel,
    required this.onContinue,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
    this.loadingLabel = AppTexts.finishingRecovery,
    super.key,
  });
  final String message;
  final String semanticsLabel;
  final VoidCallback? onContinue;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final String loadingLabel;
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && !isLoading) onContinue?.call();
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
                      RecoverySuccessAnimation(semanticsLabel: semanticsLabel),
                      SizedBox(height: 22.h),
                      RecoverySuccessMessage(message: message),
                      if (errorMessage != null) ...[
                        SizedBox(height: 16.h),
                        Text(
                          errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        if (onRetry != null)
                          TextButton(
                            onPressed: onRetry,
                            child: const Text(AppTexts.retry),
                          ),
                      ],
                      const Spacer(flex: 248),
                      RecoveryContinueButton(
                        onPressed: onContinue,
                        isLoading: isLoading,
                        loadingLabel: loadingLabel,
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
