import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:keebox/app/theme/app_colors.dart';
import 'package:keebox/app/theme/app_fonts.dart';
import 'package:keebox/assets/app_assets.dart';

class LoginButton extends StatelessWidget {
  const LoginButton({required this.onPressed, super.key});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: AppColors.brand,
      foregroundColor: Colors.white,
      minimumSize: Size.fromHeight(math.max(48, 50.h)),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
      textStyle: TextStyle(
        fontFamily: AppFonts.poppins,
        fontSize: 16.sp,
        fontWeight: FontWeight.w600,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Flexible(child: Text('Login')),
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
