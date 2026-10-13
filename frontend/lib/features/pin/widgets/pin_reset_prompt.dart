import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/app/theme/app_colors.dart';
import 'package:keebox/app/theme/app_fonts.dart';

class PinResetPrompt extends StatelessWidget {
  const PinResetPrompt({required this.onReset, super.key});

  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: AppFonts.inter,
      fontSize: 14.sp,
      fontWeight: FontWeight.w500,
      color: Colors.black,
    );
    return SizedBox(
      height: 48.w,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppTexts.forgotPin, style: style),
            TextButton(
              onPressed: onReset,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.brand,
                disabledForegroundColor: AppColors.brand,
                textStyle: style,
                padding: EdgeInsets.symmetric(horizontal: 8.w),
              ),
              child: const Text(AppTexts.reset),
            ),
          ],
        ),
      ),
    );
  }
}
