import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/app/theme/app_colors.dart';
import 'package:keebox/app/theme/app_fonts.dart';

class RegistrationSignInLink extends StatelessWidget {
  const RegistrationSignInLink({required this.onSignIn, super.key});
  final VoidCallback onSignIn;
  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: AppFonts.inter,
      fontWeight: FontWeight.w500,
      fontSize: 14.sp,
    );
    return SizedBox(
      height: 48.h,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              AppTexts.registrationHaveAccount,
              style: style.copyWith(color: Colors.black),
            ),
          ),
          SizedBox(width: 8.w),
          TextButton(
            onPressed: onSignIn,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              textStyle: style,
              foregroundColor: AppColors.brand,
            ),
            child: const Text(AppTexts.signIn),
          ),
        ],
      ),
    );
  }
}
