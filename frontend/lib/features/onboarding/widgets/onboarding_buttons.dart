import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:keebox/app/app_texts.dart';
import 'package:keebox/app/theme/app_colors.dart';
import 'package:keebox/app/theme/app_fonts.dart';
import 'package:keebox/assets/app_assets.dart';

class OnboardingSignInButton extends StatelessWidget {
  const OnboardingSignInButton({required this.onPressed, super.key});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: _welcomeStyle(primary: false),
      child: const Text(AppTexts.signIn, textAlign: TextAlign.center),
    );
  }
}

class OnboardingGetStartedButton extends StatelessWidget {
  const OnboardingGetStartedButton({required this.onPressed, super.key});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: _welcomeStyle(primary: true),
      child: const Text(AppTexts.getStarted, textAlign: TextAlign.center),
    );
  }
}

ButtonStyle _welcomeStyle({required bool primary}) => ButtonStyle(
  minimumSize: WidgetStatePropertyAll(Size(0, math.max(48, 60.h))),
  padding: WidgetStatePropertyAll(
    EdgeInsets.symmetric(horizontal: 8.w, vertical: 12.h),
  ),
  backgroundColor: WidgetStateProperty.resolveWith((states) {
    final color = primary ? AppColors.brand : AppColors.brandLight;
    return states.contains(WidgetState.disabled)
        ? color.withValues(alpha: 0.38)
        : color;
  }),
  foregroundColor: WidgetStatePropertyAll(
    primary ? Colors.white : AppColors.brand,
  ),
  shape: WidgetStatePropertyAll(
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
  ),
  side: const WidgetStatePropertyAll(BorderSide.none),
  elevation: const WidgetStatePropertyAll(0),
  textStyle: WidgetStatePropertyAll(
    TextStyle(
      fontFamily: AppFonts.poppins,
      fontWeight: FontWeight.w600,
      fontSize: 16.sp,
    ),
  ),
);

class OnboardingWelcomeActions extends StatelessWidget {
  const OnboardingWelcomeActions({
    required this.onSignIn,
    required this.onGetStarted,
    super.key,
  });

  final VoidCallback? onSignIn;
  final VoidCallback? onGetStarted;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: OnboardingSignInButton(onPressed: onSignIn)),
        SizedBox(width: 19.w),
        Expanded(child: OnboardingGetStartedButton(onPressed: onGetStarted)),
      ],
    ),
  );
}

class OnboardingSkipButton extends StatelessWidget {
  const OnboardingSkipButton({required this.onPressed, super.key});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      backgroundColor: AppColors.brandLight,
      foregroundColor: Colors.black,
      minimumSize: Size(75.w, 35.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 9.h),
      shape: const StadiumBorder(),
      textStyle: TextStyle(
        fontFamily: AppFonts.inter,
        fontWeight: FontWeight.w600,
        fontSize: 14.sp,
        height: 17 / 14,
      ),
    ),
    child: const Text(AppTexts.onboardingSkip),
  );
}

class OnboardingNextButton extends StatelessWidget {
  const OnboardingNextButton({required this.onPressed, super.key});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: math.max(48, 70.r),
    child: IconButton(
      onPressed: onPressed,
      tooltip: AppTexts.onboardingNext,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.brand,
        disabledBackgroundColor: AppColors.brand.withValues(alpha: 0.38),
        padding: EdgeInsets.zero,
        shape: const CircleBorder(),
      ),
      icon: Image.asset(
        AppAssets.arrowRight,
        width: 30.r,
        height: 30.r,
        excludeFromSemantics: true,
      ),
    ),
  );
}
