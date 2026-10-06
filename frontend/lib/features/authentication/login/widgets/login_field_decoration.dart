import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:keebox/app/theme/app_colors.dart';
import 'package:keebox/app/theme/app_fonts.dart';

InputDecoration loginFieldDecoration({
  required String hint,
  required String icon,
  Widget? suffix,
}) => InputDecoration(
  hintText: hint,
  hintStyle: TextStyle(
    fontFamily: AppFonts.inter,
    fontSize: 14.sp,
    fontWeight: FontWeight.w500,
    color: AppColors.mutedText,
  ),
  filled: true,
  fillColor: AppColors.inputBackground,
  contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
  prefixIcon: Padding(
    padding: EdgeInsets.all(10.r),
    child: Image.asset(
      icon,
      width: 24.r,
      height: 24.r,
      excludeFromSemantics: true,
    ),
  ),
  prefixIconConstraints: BoxConstraints(minWidth: 48, minHeight: 48),
  suffixIcon: suffix,
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10.r),
    borderSide: BorderSide(color: AppColors.border, width: 2.r),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10.r),
    borderSide: BorderSide(color: AppColors.brand, width: 2.r),
  ),
  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10.r),
    borderSide: BorderSide(color: Colors.red, width: 2.r),
  ),
  focusedErrorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10.r),
    borderSide: BorderSide(color: Colors.red, width: 2.r),
  ),
);

TextStyle get loginFieldLabelStyle => TextStyle(
  fontFamily: AppFonts.inter,
  fontSize: 15.sp,
  fontWeight: FontWeight.w500,
  color: Colors.black,
);
TextStyle get loginFieldTextStyle => TextStyle(
  fontFamily: AppFonts.inter,
  fontSize: 14.sp,
  fontWeight: FontWeight.w500,
  color: AppColors.mutedText,
);
