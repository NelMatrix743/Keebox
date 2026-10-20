import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/app/theme/app_colors.dart';
import 'package:keebox/app/theme/app_fonts.dart';

class RecoveryOtpResend extends StatelessWidget {
  const RecoveryOtpResend({
    required this.remaining,
    required this.onPressed,
    this.isLoading = false,
    super.key,
  });
  final Duration remaining;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: AppFonts.poppins,
      fontWeight: FontWeight.w500,
      fontSize: 14.sp,
      color: Colors.black,
    );
    if (remaining > Duration.zero && !isLoading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6.w,
          children: [
            Text(AppTexts.resendIn, style: style),
            Text(
              AppTexts.recoveryCountdown(remaining),
              style: style.copyWith(
                color: AppColors.brand,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    return TextButton(
      onPressed: isLoading ? null : onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.brand,
        textStyle: style,
      ),
      child: isLoading
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 16.r,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8.w),
                const Flexible(child: Text(AppTexts.resendingCode)),
              ],
            )
          : const Text(AppTexts.resendCode),
    );
  }
}
