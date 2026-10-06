import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:keebox/assets/app_assets.dart';

class OnboardingIllustration extends StatelessWidget {
  const OnboardingIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(379.w, constraints.maxWidth);
        return Align(
          alignment: const Alignment(0, -0.1),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            child: Image.asset(
              AppAssets.onboarding,
              width: width,
              height: width * 505 / 379,
              fit: BoxFit.contain,
              semanticLabel:
                  'Keebox. Your thoughts and access secured. '
                  'Secure notes, credentials, private by design, '
                  'and data backup.',
            ),
          ),
        );
      },
    );
  }
}
