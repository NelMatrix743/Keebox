import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/app/theme/app_colors.dart';
import 'package:keebox/app/theme/app_fonts.dart';
import 'package:keebox/assets/app_assets.dart';
import 'package:keebox/features/pin/models/pin_setup_mode.dart';
import 'package:keebox/features/pin/state/pin_setup_state.dart';

class PinSetupHeader extends StatelessWidget {
  const PinSetupHeader({required this.mode, required this.stage, super.key});

  final PinSetupMode mode;
  final PinSetupStage stage;

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = switch (stage) {
      PinSetupStage.entry => switch (mode) {
        PinSetupMode.create => (
          AppTexts.createPinTitle,
          AppTexts.createPinSubtitle,
        ),
        PinSetupMode.reset => (
          AppTexts.resetPinTitle,
          AppTexts.resetPinSubtitle,
        ),
      },
      PinSetupStage.confirmation => (
        AppTexts.confirmPinTitle,
        AppTexts.confirmPinInstruction,
      ),
      PinSetupStage.complete => (
        AppTexts.pinConfirmedTitle,
        AppTexts.pinConfirmedSubtitle,
      ),
    };
    return Column(
      children: [
        Image.asset(
          AppAssets.pinLock,
          width: 86.r,
          height: 86.r,
          color: AppColors.brand,
          excludeFromSemantics: true,
        ),
        SizedBox(height: 18.h),
        Semantics(
          header: true,
          liveRegion: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.poppins,
              fontSize: 24.sp,
              fontWeight: FontWeight.w600,
              height: 1.5,
              color: Colors.black,
            ),
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.poppins,
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            height: 1.5,
            color: AppColors.mutedText,
          ),
        ),
      ],
    );
  }
}
