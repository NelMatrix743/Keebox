import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:keebox/app/app_texts.dart';
import 'package:keebox/features/pin/models/pin_setup_mode.dart';
import 'package:keebox/features/pin/state/pin_setup_controller.dart';
import 'package:keebox/features/pin/state/pin_setup_state.dart';
import 'package:keebox/features/pin/widgets/pin_confirm_button.dart';
import 'package:keebox/features/pin/widgets/pin_entry_section.dart';
import 'package:keebox/features/pin/widgets/pin_numpad.dart';
import 'package:keebox/features/pin/widgets/pin_setup_header.dart';
import 'package:keebox/shared/widgets/app_snackbar.dart';

class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({
    required this.mode,
    this.onPinConfirmed,
    this.enabled = true,
    this.showSubmissionError = true,
    this.footer,
    super.key,
  });

  final PinSetupMode mode;
  final bool enabled;
  final bool showSubmissionError;
  final Widget? footer;

  /// Invoked when a complete five-digit PIN is confirmed. API and storage work
  /// belongs to the caller; the screen awaits it and allows retry on failure.
  final FutureOr<void> Function(String pin)? onPinConfirmed;

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  final _screenIdentity = Object();

  @override
  Widget build(BuildContext context) {
    final provider = pinSetupControllerProvider(_screenIdentity);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    ref.listen(provider, (previous, next) {
      if (!widget.showSubmissionError ||
          !next.submissionFailed ||
          previous?.submissionFailed == true) {
        return;
      }
      AppSnackBar.show(
        context,
        message: AppTexts.pinConfirmationFailed,
        type: AppSnackBarType.error,
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
                    PinEntrySection(digits: state.digits),
                    PinNumpad(
                      onDigit: controller.enterDigit,
                      onDelete: controller.deleteDigit,
                      showDelete: state.digits.isNotEmpty,
                      enabled: state.canEdit && widget.enabled,
                    ),
                    SizedBox(height: 40.h),
                    const Spacer(),
                    PinConfirmButton(
                      onPressed: state.canConfirm && widget.enabled
                          ? () {
                              AppSnackBar.dismiss(context);
                              unawaited(
                                controller.confirm(
                                  (pin) async {
                                    if (!mounted) return;
                                    await widget.onPinConfirmed?.call(pin);
                                  },
                                  beforeSubmit: () =>
                                      WidgetsBinding.instance.endOfFrame,
                                ),
                              );
                            }
                          : null,
                      isComplete: state.stage == PinSetupStage.complete,
                      isSubmitting: state.isSubmitting,
                    ),
                    if (widget.footer != null) ...[
                      SizedBox(height: 8.h),
                      widget.footer!,
                    ],
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
