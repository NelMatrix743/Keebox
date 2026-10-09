import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:keebox/features/pin/widgets/pin_numpad_key.dart';

class PinNumpad extends StatelessWidget {
  const PinNumpad({
    required this.onDigit,
    required this.onDelete,
    required this.showDelete,
    this.enabled = true,
    super.key,
  });

  final ValueChanged<int> onDigit;
  final VoidCallback onDelete;
  final bool showDelete;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: SizedBox(
      width: math.max(3 * 48, 272.w),
      child: Column(
        children: [
          for (var row = 0; row < 4; row++) ...[
            if (row > 0) SizedBox(height: 14.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var column = 0; column < 3; column++)
                  if (row == 3 && (column == 0 || (column == 2 && !showDelete)))
                    SizedBox.square(dimension: math.max(48, 74.r))
                  else if (row == 3 && column == 2)
                    PinNumpadKey.delete(
                      key: const ValueKey('pin-delete'),
                      onPressed: enabled ? onDelete : null,
                    )
                  else
                    _digit(row == 3 ? 0 : row * 3 + column + 1),
              ],
            ),
          ],
        ],
      ),
    ),
  );

  Widget _digit(int digit) => PinNumpadKey(
    key: ValueKey('pin-key-$digit'),
    digit: digit,
    onPressed: enabled ? () => onDigit(digit) : null,
  );
}
