import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:keebox/app/theme/app_colors.dart';
import 'package:keebox/app/theme/app_fonts.dart';
import 'package:keebox/app/theme/app_theme.dart';
import 'package:keebox/assets/app_assets.dart';

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
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10.r),
    );
    final labelStyle = TextStyle(
      fontFamily: AppFonts.inter,
      fontSize: 16.sp,
      fontWeight: FontWeight.w600,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.systemUiOverlayStyle,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = math.min(379.w, constraints.maxWidth);
                    return Align(
                      alignment: const Alignment(0, -0.1),
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        child: Image.asset(
                          AppAssets.onboarding,
                          width: width,
                          height: width * 505 / 379,
                          fit: BoxFit.contain,
                          semanticLabel:
                              'Keebox. Your thoughts and access secured. '
                              'Secure notes, credentials, private by design, '
                              'and data backup.',
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(18.w, 0, 18.w, 26.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton(
                      onPressed: onSignIn,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.text,
                        minimumSize: Size.fromHeight(math.max(48, 50.h)),
                        padding: EdgeInsets.symmetric(
                          horizontal: 24.w,
                          vertical: 12.h,
                        ),
                        side: BorderSide(color: AppColors.border, width: 2.r),
                        shape: shape,
                        textStyle: labelStyle,
                      ),
                      child: const Text('Sign In'),
                    ),
                    SizedBox(height: 16.h),
                    FilledButton(
                      onPressed: onGetStarted,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: AppColors.background,
                        minimumSize: Size.fromHeight(math.max(48, 50.h)),
                        padding: EdgeInsets.symmetric(
                          horizontal: 24.w,
                          vertical: 12.h,
                        ),
                        shape: shape,
                        textStyle: labelStyle,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Flexible(
                            child: Text(
                              'Get Started',
                              textAlign: TextAlign.center,
                            ),
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
