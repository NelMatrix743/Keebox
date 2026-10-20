import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/app/theme/app_colors.dart';
import 'package:keebox/app/theme/app_fonts.dart';
import 'package:keebox/assets/app_assets.dart';

class RecoveryEmailHeader extends StatelessWidget {
  const RecoveryEmailHeader({super.key});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: 112.h,
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minHeight: 120.r,
          maxHeight: 120.r,
          child: Image.asset(
            AppAssets.recoveryEmail,
            width: 120.r,
            height: 120.r,
            excludeFromSemantics: true,
          ),
        ),
      ),
      Text(
        AppTexts.recoveryEmailTitle,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppFonts.poppins,
          fontWeight: FontWeight.w600,
          fontSize: 24.sp,
          height: 1.5,
          color: Colors.black,
        ),
      ),
      Text(
        AppTexts.recoveryEmailSubtitle,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppFonts.inter,
          fontWeight: FontWeight.w500,
          fontSize: 14.sp,
          height: 1.22,
          color: AppColors.mutedText,
        ),
      ),
    ],
  );
}
