import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/app/theme/app_colors.dart';
import 'package:keebox/app/theme/app_fonts.dart';

class RecoverySuccessMessage extends StatelessWidget {
  const RecoverySuccessMessage({
    this.message = AppTexts.recoveryCompletedMessage,
    super.key,
  });
  final String message;

  @override
  Widget build(BuildContext context) => Text(
    message,
    textAlign: TextAlign.center,
    style: TextStyle(
      fontFamily: AppFonts.inter,
      fontWeight: FontWeight.w500,
      fontSize: 15.sp,
      height: 1.2,
      color: AppColors.text,
    ),
  );
}
