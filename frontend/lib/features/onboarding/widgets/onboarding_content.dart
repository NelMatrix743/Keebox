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

  TextStyle get _titleStyle => TextStyle(
    fontFamily: AppFonts.inter,
    fontWeight: FontWeight.w700,
    fontSize: 20.sp,
    letterSpacing: 0,
    height: 1.2,
    color: Colors.black,
  );

  TextStyle get _descriptionStyle => TextStyle(
    fontFamily: AppFonts.poppins,
    fontWeight: FontWeight.w400,
    fontSize: 15.sp,
    letterSpacing: 0,
    height: 1.5,
    color: Colors.black,
  );

  /// Reserves room for wrapped, accessibility-scaled text before sizing artwork.
  double measureHeight(BuildContext context, double width) {
    double height(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: width);
      final result = painter.height;
      painter.dispose();
      return result;
    }

    return height(step.title, _titleStyle) +
        (step == OnboardingStep.welcome ? 0 : 6.h) +
        height(step.description, _descriptionStyle);
  }

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
          child: Text(step.title, textAlign: alignment, style: _titleStyle),
        ),
        if (!welcome) SizedBox(height: 6.h),
        Text(step.description, textAlign: alignment, style: _descriptionStyle),
      ],
    );
  }
}
