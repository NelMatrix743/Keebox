import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/app/theme/app_colors.dart';
import 'package:keebox/app/theme/app_fonts.dart';
import 'package:keebox/assets/app_assets.dart';

class RecoveryPasswordField extends StatefulWidget {
  const RecoveryPasswordField({
    required this.controller,
    required this.hint,
    required this.validator,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction = TextInputAction.next,
    this.enabled = true,
    this.errorText,
    super.key,
  });
  final TextEditingController controller;
  final String hint;
  final FormFieldValidator<String> validator;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;
  final TextInputAction textInputAction;
  final bool enabled;
  final String? errorText;

  @override
  State<RecoveryPasswordField> createState() => _RecoveryPasswordFieldState();
}

class _RecoveryPasswordFieldState extends State<RecoveryPasswordField> {
  bool _obscure = true;

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
      height: 1.2,
    );
    return TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: _obscure,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.textInputAction,
      autofillHints: const [AutofillHints.newPassword],
      style: style,
      validator: widget.validator,
      forceErrorText: widget.errorText,
      onChanged: widget.onChanged,
      onFieldSubmitted: (_) => widget.onSubmitted?.call(),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: style,
        filled: true,
        fillColor: AppColors.border,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        prefixIconConstraints: BoxConstraints(
          minWidth: 45.w,
          minHeight: math.max(55.h, 48),
        ),
        prefixIcon: Padding(
          padding: EdgeInsets.only(left: 17.w, right: 4.w),
          child: SizedBox(
            width: 24.r,
            child: Center(
              child: Image.asset(
                AppAssets.password,
                width: 24.r,
                height: 24.r,
                excludeFromSemantics: true,
              ),
            ),
          ),
        ),
        suffixIcon: Padding(
          padding: EdgeInsetsDirectional.only(end: 8.w),
          child: IconButton(
            tooltip: _obscure ? AppTexts.showPassword : AppTexts.hidePassword,
            onPressed: widget.enabled
                ? () => setState(() => _obscure = !_obscure)
                : null,
            icon: Image.asset(
              _obscure ? AppAssets.passwordHidden : AppAssets.passwordVisible,
              width: 24.r,
              height: 24.r,
              excludeFromSemantics: true,
            ),
          ),
        ),
        border: border,
        enabledBorder: border,
        disabledBorder: border,
        focusedBorder: focused,
        errorBorder: border,
        focusedErrorBorder: focused,
        errorMaxLines: 6,
      ),
    );
  }
}
