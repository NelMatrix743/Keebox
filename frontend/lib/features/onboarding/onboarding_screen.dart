import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:keebox/app/theme/app_colors.dart';
import 'package:keebox/app/theme/app_theme.dart';
import 'package:keebox/features/onboarding/widgets/onboarding_buttons.dart';
import 'package:keebox/features/onboarding/widgets/onboarding_illustration.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({
    required this.onSignIn,
    required this.onGetStarted,
    super.key,
  });

  final VoidCallback onSignIn;
  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
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
                    OnboardingSignInButton(onPressed: onSignIn),
                    SizedBox(height: 16.h),
                    OnboardingGetStartedButton(onPressed: onGetStarted),
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
