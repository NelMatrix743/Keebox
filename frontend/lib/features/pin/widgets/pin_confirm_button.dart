import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/app/theme/app_colors.dart';
import 'package:keebox/app/theme/app_fonts.dart';
import 'package:keebox/assets/app_assets.dart';

class PinConfirmButton extends StatelessWidget {
  const PinConfirmButton({
    required this.onPressed,
    this.isComplete = false,
    super.key,
  });

  final VoidCallback? onPressed;
  final bool isComplete;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 334.w,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: Size.fromHeight(math.max(48, 50.h)),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.brand.withValues(alpha: 0.4),
        disabledForegroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
        textStyle: TextStyle(
          fontFamily: AppFonts.poppins,
          fontSize: 16.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(isComplete ? AppTexts.confirmed : AppTexts.confirm),
          ),
          SizedBox(width: 8.w),
          Image.asset(
            AppAssets.pinConfirm,
            width: 24.r,
            height: 24.r,
            excludeFromSemantics: true,
          ),
        ],
      ),
    ),
  );
}
