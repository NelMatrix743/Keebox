import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:keebox/app/theme/app_colors.dart';
import 'package:keebox/app/theme/app_theme.dart';
import 'package:keebox/features/onboarding/state/onboarding_controller.dart';
import 'package:keebox/features/onboarding/widgets/onboarding_buttons.dart';
import 'package:keebox/features/onboarding/widgets/onboarding_illustration.dart';
import 'package:keebox/shared/widgets/app_snackbar.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({
    required this.onSignIn,
    required this.onGetStarted,
    super.key,
  });

  final VoidCallback onSignIn;
  final VoidCallback onGetStarted;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  Future<void> _complete(VoidCallback navigate) async {
    AppSnackBar.dismiss(context);
    final completed = await ref
        .read(onboardingControllerProvider.notifier)
        .complete();
    if (mounted && completed) navigate();
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(onboardingControllerProvider);
    final busy = progress.isLoading || progress.asData?.value.isSaving == true;
    ref.listen(onboardingControllerProvider, (previous, next) {
      final message = next.asData?.value.errorMessage;
      if (message != null && message != previous?.asData?.value.errorMessage) {
        AppSnackBar.show(
          context,
          message: message,
          type: AppSnackBarType.error,
        );
      }
    });
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.systemUiOverlayStyle,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              const Expanded(child: OnboardingIllustration()),
              Padding(
                padding: EdgeInsets.fromLTRB(18.w, 0, 18.w, 26.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OnboardingSignInButton(
                      onPressed: busy ? null : () => _complete(widget.onSignIn),
                    ),
                    SizedBox(height: 16.h),
                    OnboardingGetStartedButton(
                      onPressed: busy
                          ? null
                          : () => _complete(widget.onGetStarted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
