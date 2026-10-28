import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:keebox/app/theme/app_colors.dart';
import 'package:keebox/app/theme/app_fonts.dart';

class RegistrationHeader extends StatelessWidget {
  const RegistrationHeader({
    required this.image,
    required this.title,
    required this.subtitle,
    this.gap = 25,
    this.imageOffset = 0,
    super.key,
  });
  final String image;
  final String title;
  final String subtitle;
  final double gap;
  final double imageOffset;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Transform.translate(
        offset: Offset(imageOffset.w, 0),
        child: Image.asset(
          image,
          width: 120.r,
          height: 120.r,
          excludeFromSemantics: true,
        ),
      ),
      SizedBox(height: gap.h),
      Text(
        title,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppFonts.poppins,
          fontWeight: FontWeight.w600,
          fontSize: 24.sp,
          height: 1.5,
          color: Colors.black,
        ),
      ),
      Text(
        subtitle,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppFonts.inter,
          fontWeight: FontWeight.w500,
          fontSize: 14.sp,
          height: 1.22,
          color: AppColors.mutedText,
        ),
      ),
    ],
  );
}
