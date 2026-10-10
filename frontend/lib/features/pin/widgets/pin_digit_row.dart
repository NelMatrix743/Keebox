import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:keebox/features/pin/state/pin_setup_state.dart';
import 'package:keebox/features/pin/widgets/pin_digit_cell.dart';

class PinDigitRow extends StatelessWidget {
  const PinDigitRow({required this.digits, super.key});

  final String digits;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: SizedBox(
      width: 253.w,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var index = 0; index < PinSetupState.length; index++)
            PinDigitCell(
              position: index,
              digit: index < digits.length ? digits[index] : null,
            ),
        ],
      ),
    ),
  );
}
