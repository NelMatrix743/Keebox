import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:keebox/features/pin/widgets/pin_digit_row.dart';

class PinEntrySection extends StatelessWidget {
  const PinEntrySection({required this.digits, super.key});

  final String digits;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: 36.h),
    child: PinDigitRow(digits: digits),
  );
}
