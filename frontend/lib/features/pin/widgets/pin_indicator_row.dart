import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/app/theme/app_colors.dart';
import 'package:keebox/features/pin/state/pin_code_controller.dart';

class PinIndicatorRow extends StatelessWidget {
  const PinIndicatorRow({required this.filledCount, super.key});

  final int filledCount;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < PinCodeController.length; index++) ...[
          if (index > 0) SizedBox(width: 12.r),
          Semantics(
            label: AppTexts.pinIndicatorLabel(index + 1, index < filledCount),
            child: Container(
              width: 22.r,
              height: 22.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index < filledCount
                    ? AppColors.brand
                    : AppColors.pinIndicator,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}
