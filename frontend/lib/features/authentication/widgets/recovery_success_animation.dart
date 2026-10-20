import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/assets/app_assets.dart';
import 'package:lottie/lottie.dart';

class RecoverySuccessAnimation extends StatelessWidget {
  const RecoverySuccessAnimation({super.key});

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      image: true,
      label: AppTexts.recoveryCompletedTitle,
      excludeSemantics: true,
      child: Lottie.asset(
        AppAssets.successCheck,
        width: 170.r,
        height: 170.r,
        fit: BoxFit.contain,
        repeat: false,
        animate: !reducedMotion,
        controller: reducedMotion
            ? const AlwaysStoppedAnimation<double>(1)
            : null,
      ),
    );
  }
}
