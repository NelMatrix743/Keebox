import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
        ? SizedBox(
            width: 24.r,
            height: 24.r,
            child: const CircularProgressIndicator(
              strokeWidth: 2,
              semanticsLabel: 'Logging in',
            ),
          )
        : Row(
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
