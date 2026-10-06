import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:keebox/app/theme/app_colors.dart';
import 'package:keebox/app/theme/app_fonts.dart';
import 'package:keebox/assets/app_assets.dart';

class OnboardingSignInButton extends StatelessWidget {
  const OnboardingSignInButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10.r),
    );
    final labelStyle = TextStyle(
      fontFamily: AppFonts.inter,
      fontSize: 16.sp,
      fontWeight: FontWeight.w600,
    );

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        minimumSize: Size.fromHeight(math.max(48, 50.h)),
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
        side: BorderSide(color: AppColors.border, width: 2.r),
        shape: shape,
        textStyle: labelStyle,
      ),
      child: const Text('Sign In'),
    );
  }
}

class OnboardingGetStartedButton extends StatelessWidget {
  const OnboardingGetStartedButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10.r),
    );
    final labelStyle = TextStyle(
      fontFamily: AppFonts.inter,
      fontSize: 16.sp,
      fontWeight: FontWeight.w600,
    );

    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.brand,
        foregroundColor: AppColors.background,
        minimumSize: Size.fromHeight(math.max(48, 50.h)),
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
        shape: shape,
        textStyle: labelStyle,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Flexible(
            child: Text('Get Started', textAlign: TextAlign.center),
          ),
          SizedBox(width: 8.w),
          Image.asset(
            AppAssets.getStarted,
            width: 24.r,
            height: 24.r,
            excludeFromSemantics: true,
          ),
        ],
      ),
    );
  }
}
