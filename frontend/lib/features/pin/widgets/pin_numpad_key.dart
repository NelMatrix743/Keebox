import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:keebox/app/theme/app_colors.dart';
import 'package:keebox/app/theme/app_fonts.dart';
import 'package:keebox/assets/app_assets.dart';

class PinNumpadKey extends StatelessWidget {
  const PinNumpadKey({required this.digit, required this.onPressed, super.key});

  const PinNumpadKey.delete({required this.onPressed, super.key})
    : digit = null;

  final int? digit;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: ButtonStyle(
      fixedSize: WidgetStatePropertyAll(Size.square(math.max(48, 74.r))),
      minimumSize: const WidgetStatePropertyAll(Size.zero),
      padding: const WidgetStatePropertyAll(EdgeInsets.zero),
      shape: const WidgetStatePropertyAll(CircleBorder()),
      side: const WidgetStatePropertyAll(BorderSide(color: AppColors.border)),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.pressed)
            ? AppColors.brand
            : Colors.transparent,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.pressed) ? Colors.white : Colors.black,
      ),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      textStyle: WidgetStatePropertyAll(
        TextStyle(
          fontFamily: AppFonts.jetBrainsMono,
          fontSize: 30.sp,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    child: digit == null
        ? Semantics(
            label: 'Delete last digit',
            child: Builder(
              builder: (context) => Image.asset(
                AppAssets.pinDelete,
                width: 30.r,
                height: 30.r,
                color: DefaultTextStyle.of(context).style.color,
                excludeFromSemantics: true,
              ),
            ),
          )
        : FittedBox(fit: BoxFit.scaleDown, child: Text('$digit')),
  );
}
