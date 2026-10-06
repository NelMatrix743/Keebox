import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:keebox/app/theme/app_colors.dart';
import 'package:keebox/app/theme/app_fonts.dart';

class RegistrationFooter extends StatelessWidget {
  const RegistrationFooter({required this.onPressed, super.key});
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: AppFonts.inter,
      fontSize: 14.sp,
      fontWeight: FontWeight.w500,
      color: Colors.black,
    );
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('Don’t have an account?', style: style),
        TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.brand,
            textStyle: style,
          ),
          child: const Text('Register'),
        ),
      ],
    );
  }
}
