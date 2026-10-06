import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:keebox/app/theme/app_colors.dart';
import 'package:keebox/app/theme/app_fonts.dart';

class ForgotPasswordLink extends StatelessWidget {
  const ForgotPasswordLink({required this.onPressed, super.key});
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.brand,
        textStyle: TextStyle(
          fontFamily: AppFonts.inter,
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
        ),
      ),
      child: const Text('Forgot your password?'),
    ),
  );
}
