import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/features/authentication/models/recovery_type.dart';
import 'package:keebox/features/authentication/state/recovery_controller.dart';
import 'package:keebox/features/authentication/state/recovery_state.dart';
import 'package:keebox/features/authentication/widgets/recovery_reset_feedback.dart';
import 'package:keebox/features/pin/models/pin_setup_mode.dart';
import 'package:keebox/features/pin/screens/pin_setup_screen.dart';
import 'package:keebox/shared/widgets/app_snackbar.dart';

class PinResetScreen extends ConsumerStatefulWidget {
  const PinResetScreen({
    required this.scope,
    required this.onCompleted,
    required this.onRestart,
    required this.onLoginRequired,
    super.key,
  });
  final RecoveryScope scope;
  final ValueChanged<RecoveryScope> onCompleted;
  final VoidCallback onRestart;
  final VoidCallback onLoginRequired;

  @override
  ConsumerState<PinResetScreen> createState() => _PinResetScreenState();
}

class _PinResetScreenState extends ConsumerState<PinResetScreen>
    with WidgetsBindingObserver {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _checkDeadline(),
    );
  }

  void _checkDeadline() {
    if (!mounted || ModalRoute.of(context)?.isCurrent == false) return;
    ref
        .read(recoveryControllerProvider(widget.scope).notifier)
        .checkDeadlines();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkDeadline();
  }

  @override
  void dispose() {
    _timer.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _confirm(String pin) async {
    final provider = recoveryControllerProvider(widget.scope);
    final state = ref.read(provider);
    if (widget.scope.type != RecoveryType.pin ||
        state.stage != RecoveryStage.credential ||
        state.isSubmitting) {
      throw StateError(AppTexts.pinConfirmationFailed);
    }
    await ref.read(provider.notifier).completePin(pin);
    if (!mounted || ref.read(provider).stage != RecoveryStage.completed) {
      throw StateError(AppTexts.pinConfirmationFailed);
    }
    widget.onCompleted(widget.scope);
  }

  @override
  Widget build(BuildContext context) {
    final provider = recoveryControllerProvider(widget.scope);
    final state = ref.watch(provider);
    ref.listen(provider, (previous, next) {
      if (next.errorMessage != null &&
          next.feedbackRevision != previous?.feedbackRevision &&
          ModalRoute.of(context)?.isCurrent != false) {
        AppSnackBar.show(
          context,
          message: next.errorMessage!,
          type: AppSnackBarType.error,
        );
      }
    });
    final active =
        widget.scope.type == RecoveryType.pin &&
        state.stage == RecoveryStage.credential;
    final terminal =
        state.stage == RecoveryStage.restartRequired ||
        state.stage == RecoveryStage.completionUncertain;
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && ref.read(provider).stage != RecoveryStage.completed) {
          ref.read(provider.notifier).restart();
        }
      },
      child: PinSetupScreen(
        mode: PinSetupMode.reset,
        enabled: active && !state.isSubmitting,
        showSubmissionError: false,
        onPinConfirmed: _confirm,
        footer: state.errorMessage == null && !terminal
            ? null
            : RecoveryResetFeedback(
                errorMessage: state.errorMessage,
                onRestart: terminal
                    ? () {
                        ref.read(provider.notifier).restart();
                        widget.onRestart();
                      }
                    : null,
                onLoginRequired:
                    state.stage == RecoveryStage.completionUncertain
                    ? widget.onLoginRequired
                    : null,
              ),
      ),
    );
  }
}
