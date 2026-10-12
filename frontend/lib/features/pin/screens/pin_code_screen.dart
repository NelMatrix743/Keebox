import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:keebox/features/pin/state/pin_code_controller.dart';
import 'package:keebox/features/pin/widgets/pin_indicator_row.dart';
import 'package:keebox/features/pin/widgets/pin_lock_header.dart';
import 'package:keebox/features/pin/widgets/pin_numpad.dart';
import 'package:keebox/features/pin/widgets/pin_reset_prompt.dart';

class PinCodeScreen extends ConsumerStatefulWidget {
  const PinCodeScreen({
    this.onPinEntered,
    this.onFingerprintPressed,
    this.onResetPin,
    super.key,
  });

  final ValueChanged<String>? onPinEntered;
  final VoidCallback? onFingerprintPressed;
  final VoidCallback? onResetPin;

  @override
  ConsumerState<PinCodeScreen> createState() => _PinCodeScreenState();
}

class _PinCodeScreenState extends ConsumerState<PinCodeScreen> {
  final _screenIdentity = Object();

  @override
  Widget build(BuildContext context) {
    final provider = pinCodeControllerProvider(_screenIdentity);
    final digits = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: 402.w,
              height: 816.w,
              child: Column(
                children: [
                  SizedBox(height: 64.w),
                  const PinLockHeader(),
                  SizedBox(height: 60.w),
                  PinIndicatorRow(filledCount: digits.length),
                  const Spacer(flex: 2),
                  PinNumpad(
                    onDigit: (digit) {
                      final pin = controller.enterDigit(digit);
                      if (pin != null) widget.onPinEntered?.call(pin);
                    },
                    onDelete: controller.deleteDigit,
                    showDelete: true,
                    deleteEnabled: digits.isNotEmpty,
                    showFingerprint: true,
                    onFingerprint: widget.onFingerprintPressed,
                  ),
                  const Spacer(),
                  PinResetPrompt(onReset: widget.onResetPin),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
