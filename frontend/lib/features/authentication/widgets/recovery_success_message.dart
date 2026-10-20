import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/app/theme/app_colors.dart';
import 'package:keebox/app/theme/app_fonts.dart';

class RecoverySuccessMessage extends StatelessWidget {
  const RecoverySuccessMessage({super.key});

  @override
  Widget build(BuildContext context) => Text(
    AppTexts.recoveryCompletedMessage,
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
