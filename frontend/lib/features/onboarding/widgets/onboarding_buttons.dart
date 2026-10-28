import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:keebox/app/app_texts.dart';
import 'package:keebox/app/theme/app_colors.dart';
import 'package:keebox/app/theme/app_fonts.dart';

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
