import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:keebox/app/theme/app_colors.dart';
import 'package:keebox/app/theme/app_fonts.dart';

class RegistrationIdentityField extends StatelessWidget {
  const RegistrationIdentityField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.autofillHint,
    required this.validator,
    this.email = false,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
    super.key,
  });
  final TextEditingController controller;
  final String hint;
  final String icon;
  final String autofillHint;
  final FormFieldValidator<String> validator;
  final bool email;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.r),
      borderSide: BorderSide.none,
    );
    final focused = border.copyWith(
      borderSide: BorderSide(color: AppColors.brand, width: 2.r),
    );
    final style = TextStyle(
      fontFamily: AppFonts.inter,
      fontWeight: FontWeight.w500,
      fontSize: 16.sp,
      color: AppColors.mutedText,
      height: 1.2,
    );
    return TextFormField(
      controller: controller,
      validator: validator,
      forceErrorText: errorText,
      style: style,
      keyboardType: email ? TextInputType.emailAddress : TextInputType.name,
      textCapitalization: email
          ? TextCapitalization.none
          : TextCapitalization.words,
      textInputAction: email ? TextInputAction.done : TextInputAction.next,
      autofillHints: [autofillHint],
      autocorrect: false,
      onChanged: onChanged,
      onFieldSubmitted: (_) => onSubmitted?.call(),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: style,
        filled: true,
        fillColor: AppColors.border,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        prefixIconConstraints: BoxConstraints(
          minWidth: 40.w,
          minHeight: math.max(55.h, 48),
        ),
        prefixIcon: Padding(
          padding: EdgeInsets.only(left: 11.w, right: 5.w),
          child: Image.asset(
            icon,
            width: 24.r,
            height: 24.r,
            excludeFromSemantics: true,
          ),
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: focused,
        errorBorder: border,
        focusedErrorBorder: focused,
        errorMaxLines: 4,
      ),
    );
  }
}
