import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:keebox/app/theme/app_colors.dart';
import 'package:keebox/app/theme/app_fonts.dart';

class PinDigitCell extends StatelessWidget {
  const PinDigitCell({required this.position, this.digit, super.key});

  final int position;
  final String? digit;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'PIN digit ${position + 1}',
    value: digit ?? 'Empty',
    excludeSemantics: true,
    child: Container(
      width: 45.w,
      height: 50.h,
      decoration: BoxDecoration(
        border: Border.all(
          color: digit == null ? AppColors.border : AppColors.brand,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8.r),
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          digit ?? '',
          style: TextStyle(
            fontFamily: AppFonts.jetBrainsMono,
            fontWeight: FontWeight.w500,
            fontSize: 24.sp,
            color: Colors.black,
          ),
        ),
      ),
    ),
  );
}
