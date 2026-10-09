import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:keebox/app/theme/app_colors.dart';
import 'package:keebox/app/theme/app_fonts.dart';
import 'package:keebox/assets/app_assets.dart';

class LoginHeader extends StatelessWidget {
  const LoginHeader({super.key});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Image.asset(
        AppAssets.logoBrand,
        width: 74.w,
        height: 118.w,
        fit: BoxFit.contain,
        color: AppColors.brand,
        excludeFromSemantics: true,
      ),
      SizedBox(height: 10.h),
      Text(
        'Welcome Back!',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppFonts.poppins,
          fontSize: 24.sp,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
      SizedBox(height: 4.h),
      Text(
        'Log into your account',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppFonts.inter,
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
          color: AppColors.mutedText,
        ),
      ),
    ],
  );
}
