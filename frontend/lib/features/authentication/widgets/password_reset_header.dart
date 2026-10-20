import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/app/theme/app_colors.dart';
import 'package:keebox/app/theme/app_fonts.dart';
import 'package:keebox/assets/app_assets.dart';

class PasswordResetHeader extends StatelessWidget {
  const PasswordResetHeader({super.key});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Transform.translate(
        offset: Offset(5.w, 0),
        child: Image.asset(
          AppAssets.passwordReset,
          width: 120.r,
          height: 120.r,
          excludeFromSemantics: true,
        ),
      ),
      SizedBox(height: 11.h),
      Text(
        AppTexts.resetPasswordTitle,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppFonts.poppins,
          fontSize: 24.sp,
          fontWeight: FontWeight.w600,
          color: Colors.black,
          height: 1.5,
        ),
      ),
      Text(
        AppTexts.resetPasswordSubtitle,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppFonts.inter,
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
          color: AppColors.mutedText,
          height: 1.22,
        ),
      ),
    ],
  );
}
