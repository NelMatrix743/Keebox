import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/app/theme/app_colors.dart';
import 'package:keebox/features/onboarding/models/onboarding_step.dart';

class OnboardingDecorativeStrip extends StatelessWidget {
  const OnboardingDecorativeStrip({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: 209.w,
      height: 55.h,
      decoration: const BoxDecoration(
        color: AppColors.brandLight,
        borderRadius: BorderRadius.horizontal(right: Radius.circular(999)),
      ),
    ),
  );
}

class OnboardingProgressIndicators extends StatelessWidget {
  const OnboardingProgressIndicators({required this.step, super.key})
    : assert(step != OnboardingStep.welcome);

  final OnboardingStep step;

  @override
  Widget build(BuildContext context) {
    final count = OnboardingStep.welcome.index;
    return Semantics(
      label: AppTexts.onboardingProgress(step.index + 1, count),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < count; index++) ...[
            if (index > 0) SizedBox(width: 7.w),
            SizedBox(
              width: 30.w,
              height: 7.h,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: index == step.index
                      ? AppColors.brand
                      : AppColors.brandLight,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
