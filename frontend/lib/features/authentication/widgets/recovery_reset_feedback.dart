import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:keebox/app/app_texts.dart';

class RecoveryResetFeedback extends StatelessWidget {
  const RecoveryResetFeedback({
    this.errorMessage,
    this.onRestart,
    this.onLoginRequired,
    super.key,
  });
  final String? errorMessage;
  final VoidCallback? onRestart;
  final VoidCallback? onLoginRequired;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (errorMessage != null)
        Text(
          errorMessage!,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.error,
            fontSize: 14.sp,
          ),
        ),
      if (onRestart != null)
        TextButton(
          onPressed: onRestart,
          child: const Text(AppTexts.restartRecovery),
        ),
      if (onLoginRequired != null)
        TextButton(
          onPressed: onLoginRequired,
          child: const Text(AppTexts.backToLogin),
        ),
    ],
  );
}
