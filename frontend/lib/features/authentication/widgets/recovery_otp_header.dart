import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/app/theme/app_colors.dart';
import 'package:keebox/app/theme/app_fonts.dart';
import 'package:keebox/assets/app_assets.dart';

class RecoveryOtpHeader extends StatelessWidget {
  const RecoveryOtpHeader({super.key});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Image.asset(
        AppAssets.recoveryOtp,
        width: 120.r,
        height: 120.r,
        excludeFromSemantics: true,
      ),
      SizedBox(height: 10.h),
      Text(
        AppTexts.recoveryOtpSent,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppFonts.inter,
          fontSize: 15.sp,
          height: 1.2,
          fontWeight: FontWeight.w500,
          color: AppColors.text,
        ),
      ),
      SizedBox(height: 9.h),
      Text(
        AppTexts.recoveryOtpInstruction,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppFonts.inter,
          fontSize: 14.sp,
          height: 1.22,
          fontWeight: FontWeight.w500,
          color: AppColors.mutedText,
        ),
      ),
    ],
  );
}
