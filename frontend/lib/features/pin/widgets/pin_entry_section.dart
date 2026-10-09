import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/app/theme/app_colors.dart';
import 'package:keebox/app/theme/app_fonts.dart';
import 'package:keebox/features/pin/state/pin_setup_state.dart';
import 'package:keebox/features/pin/widgets/pin_digit_row.dart';

class PinEntrySection extends StatelessWidget {
  const PinEntrySection({required this.state, super.key});

  final PinSetupState state;

  @override
  Widget build(BuildContext context) {
    final message = switch (state.error) {
      PinSetupError.mismatch => AppTexts.pinMismatchMessage,
      PinSetupError.submission || null =>
        state.isSubmitting
            ? AppTexts.confirmingPin
            : state.stage == PinSetupStage.confirmation
            ? AppTexts.confirmPinInstruction
            : null,
    };
    return Column(
      children: [
        SizedBox(
          height: 50.h,
          child: Center(
            child: state.isSubmitting
                ? SizedBox.square(
                    dimension: 32.r,
                    child: const CircularProgressIndicator(
                      color: AppColors.brand,
                      strokeWidth: 3,
                      semanticsLabel: AppTexts.confirmingPin,
                    ),
                  )
                : PinDigitRow(
                    digits: state.digits,
                    hasError: state.error == PinSetupError.mismatch,
                  ),
          ),
        ),
        SizedBox(height: 8.h),
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: 28.h),
          child: Semantics(
            liveRegion: true,
            child: message == null
                ? const SizedBox.shrink()
                : Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.inter,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                      color: state.error == PinSetupError.mismatch
                          ? Colors.red
                          : AppColors.mutedText,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
