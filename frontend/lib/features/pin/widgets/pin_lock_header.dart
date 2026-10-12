import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/app/theme/app_colors.dart';
import 'package:keebox/app/theme/app_fonts.dart';
import 'package:keebox/assets/app_assets.dart';

class PinLockHeader extends StatelessWidget {
  const PinLockHeader({super.key});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Image.asset(
        AppAssets.pinLock,
        width: 86.r,
        height: 86.r,
        color: AppColors.brand,
        excludeFromSemantics: true,
      ),
      SizedBox(height: 24.w),
      Text(
        AppTexts.enterPinToProceed,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppFonts.poppins,
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
          height: 1.5,
          color: AppColors.mutedText,
        ),
      ),
    ],
  );
}
