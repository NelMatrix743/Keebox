import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/app/theme/app_colors.dart';
import 'package:keebox/app/theme/app_fonts.dart';
import 'package:keebox/assets/app_assets.dart';

class RecoveryEmailField extends StatelessWidget {
  const RecoveryEmailField({
    required this.controller,
    required this.onSubmitted,
    this.enabled = true,
    super.key,
  });
  final TextEditingController controller;
  final VoidCallback onSubmitted;
  final bool enabled;

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
      fontSize: 16.sp,
      fontWeight: FontWeight.w500,
      color: AppColors.mutedText,
    );
    return TextFormField(
      controller: controller,
      enabled: enabled,
      style: style,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.email],
      autocorrect: false,
      textCapitalization: TextCapitalization.none,
      onFieldSubmitted: (_) => onSubmitted(),
      decoration: InputDecoration(
        hintText: AppTexts.recoveryEmailHint,
        hintStyle: style,
        filled: true,
        fillColor: AppColors.border,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        prefixIconConstraints: BoxConstraints(
          minWidth: 44.w,
          minHeight: math.max(55.h, 48),
        ),
        prefixIcon: Padding(
          padding: EdgeInsets.only(left: 11.w, right: 9.w),
          child: Image.asset(
            AppAssets.email,
            width: 24.r,
            height: 24.r,
            excludeFromSemantics: true,
          ),
        ),
        border: border,
        enabledBorder: border,
        disabledBorder: border,
        focusedBorder: focused,
        errorBorder: border,
        focusedErrorBorder: focused,
        errorMaxLines: 3,
      ),
      validator: (value) {
        final email = value?.trim() ?? '';
        if (email.isEmpty) return AppTexts.recoveryEmailRequired;
        if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
          return AppTexts.recoveryEmailInvalid;
        }
        return null;
      },
    );
  }
}
