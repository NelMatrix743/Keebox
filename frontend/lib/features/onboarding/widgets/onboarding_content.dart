import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:keebox/app/theme/app_fonts.dart';
import 'package:keebox/features/onboarding/models/onboarding_step.dart';

class OnboardingArtwork extends StatelessWidget {
  const OnboardingArtwork({required this.step, super.key});

  final OnboardingStep step;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 352 / 440,
    child: Image.asset(
      step.illustration,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
    ),
  );
}

class OnboardingMessage extends StatelessWidget {
  const OnboardingMessage({required this.step, super.key});

  final OnboardingStep step;

  @override
  Widget build(BuildContext context) {
    final welcome = step == OnboardingStep.welcome;
    final alignment = welcome ? TextAlign.center : TextAlign.left;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: welcome
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            step.title,
            textAlign: alignment,
            style: TextStyle(
              fontFamily: AppFonts.inter,
              fontWeight: FontWeight.w700,
              fontSize: 20.sp,
              height: 1.2,
              color: Colors.black,
            ),
          ),
        ),
        if (!welcome) SizedBox(height: 6.h),
        Text(
          step.description,
          textAlign: alignment,
          style: TextStyle(
            fontFamily: AppFonts.poppins,
            fontWeight: FontWeight.w400,
            fontSize: 15.sp,
            height: 1.5,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}
