import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/app/theme/app_colors.dart';
import 'package:keebox/app/theme/app_fonts.dart';
import 'package:keebox/assets/app_assets.dart';

class LoginButton extends StatelessWidget {
  const LoginButton({
    required this.onPressed,
    this.isLoading = false,
    super.key,
  });
  final VoidCallback? onPressed;
  final bool isLoading;
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: isLoading ? null : onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: AppColors.brand,
      foregroundColor: Colors.white,
      disabledBackgroundColor: AppColors.brand.withValues(alpha: 0.6),
      disabledForegroundColor: Colors.white,
      minimumSize: Size.fromHeight(math.max(48, 50.h)),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
      textStyle: TextStyle(
        fontFamily: AppFonts.poppins,
        fontSize: 16.sp,
        fontWeight: FontWeight.w600,
      ),
    ),
    child: isLoading
        ? SizedBox.square(
            dimension: 30.r,
            child: const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
              semanticsLabel: AppTexts.loggingIn,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Flexible(child: Text(AppTexts.login)),
              SizedBox(width: 4.w),
              Image.asset(
                AppAssets.arrowRight,
                width: 30.r,
                height: 30.r,
                excludeFromSemantics: true,
              ),
            ],
          ),
  );
}
