import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:keebox/features/pin/models/pin_setup_mode.dart';
import 'package:keebox/features/pin/state/pin_setup_controller.dart';
import 'package:keebox/features/pin/state/pin_setup_state.dart';
import 'package:keebox/features/pin/widgets/pin_confirm_button.dart';
import 'package:keebox/features/pin/widgets/pin_digit_row.dart';
import 'package:keebox/features/pin/widgets/pin_numpad.dart';
import 'package:keebox/features/pin/widgets/pin_setup_header.dart';

class PinCodeScreen extends ConsumerStatefulWidget {
  const PinCodeScreen({required this.mode, this.onPinConfirmed, super.key});

  final PinSetupMode mode;

  /// Invoked only after both five-digit entries match. API and storage work
  /// belongs to the caller; the screen awaits it and allows retry on failure.
  final FutureOr<void> Function(String pin)? onPinConfirmed;

  @override
  ConsumerState<PinCodeScreen> createState() => _PinCodeScreenState();
}

class _PinCodeScreenState extends ConsumerState<PinCodeScreen> {
  final _screenIdentity = Object();

  @override
  Widget build(BuildContext context) {
    final provider = pinSetupControllerProvider(_screenIdentity);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    ref.listen(provider, (previous, next) {
      if (next.error == null || next.error == previous?.error) return;
      final message = switch (next.error!) {
        PinSetupError.mismatch => 'PIN codes do not match. Please try again.',
        PinSetupError.submission =>
          'Could not confirm your PIN. Please try again.',
      };
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message, style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.fixed,
          ),
        );
    });

    return Scaffold(
      body: SafeArea(
        minimum: EdgeInsets.fromLTRB(34.w, 80.h, 34.w, 79.h),
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    PinSetupHeader(mode: widget.mode, stage: state.stage),
                    SizedBox(height: 34.h),
                    PinDigitRow(digits: state.digits),
                    SizedBox(height: 36.h),
                    PinNumpad(
                      onDigit: controller.enterDigit,
                      onDelete: controller.deleteDigit,
                      showDelete: state.digits.isNotEmpty,
                      enabled: state.canEdit,
                    ),
                    SizedBox(height: 40.h),
                    const Spacer(),
                    PinConfirmButton(
                      onPressed: state.canConfirm
                          ? () {
                              ScaffoldMessenger.of(context)
                                  .removeCurrentSnackBar();
                              unawaited(
                                controller.confirm(
                                  (pin) => widget.onPinConfirmed?.call(pin),
                                ),
                              );
                            }
                          : null,
                      isSubmitting: state.isSubmitting,
                      isComplete: state.stage == PinSetupStage.complete,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
