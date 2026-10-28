import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keebox/app/app_texts.dart';
import 'package:keebox/features/authentication/state/registration_controller.dart';
import 'package:keebox/features/authentication/state/registration_completion_controller.dart';
import 'package:keebox/features/authentication/state/registration_state.dart';
import 'package:keebox/features/authentication/widgets/recovery_reset_feedback.dart';
import 'package:keebox/features/pin/models/pin_setup_mode.dart';
import 'package:keebox/features/pin/screens/pin_setup_screen.dart';
import 'package:keebox/shared/widgets/app_snackbar.dart';

class RegistrationPinScreen extends ConsumerStatefulWidget {
  const RegistrationPinScreen({
    required this.scope,
    required this.onRestart,
    required this.onSignIn,
    super.key,
  });
  final Object scope;
  final VoidCallback onRestart;
  final VoidCallback onSignIn;
  @override
  ConsumerState<RegistrationPinScreen> createState() =>
      _RegistrationPinScreenState();
}

class _RegistrationPinScreenState extends ConsumerState<RegistrationPinScreen>
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
        .read(registrationControllerProvider(widget.scope).notifier)
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

  void _error(String message) {
    if (ModalRoute.of(context)?.isCurrent != false) {
      AppSnackBar.show(context, message: message, type: AppSnackBarType.error);
    }
  }

  Future<void> _confirm(String pin) async {
    if (!await ref
        .read(registrationCompletionControllerProvider(widget.scope).notifier)
        .submit(pin)) {
      throw StateError(AppTexts.pinConfirmationFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final registration = ref.watch(
      registrationControllerProvider(widget.scope),
    );
    final completion = ref.watch(
      registrationCompletionControllerProvider(widget.scope),
    );
    ref.listen(registrationControllerProvider(widget.scope), (previous, next) {
      if (next.errorMessage != null &&
          previous?.feedbackRevision != next.feedbackRevision) {
        _error(next.errorMessage!);
      }
    });
    ref.listen(registrationCompletionControllerProvider(widget.scope), (
      previous,
      next,
    ) {
      if (next.errorMessage != null &&
          previous?.errorMessage != next.errorMessage) {
        _error(next.errorMessage!);
      }
    });
    final terminal = registration.stage == RegistrationStage.restartRequired;
    final uncertain =
        registration.stage == RegistrationStage.completionUncertain;
    final message = completion.errorMessage ?? registration.errorMessage;
    final showFeedback =
        message != null || terminal || uncertain || completion.canRetry;
    return PinSetupScreen(
      mode: PinSetupMode.create,
      enabled:
          registration.stage == RegistrationStage.pin &&
          !completion.isSubmitting,
      isSubmitting: completion.isSubmitting,
      showSubmissionError: false,
      onPinConfirmed: _confirm,
      footer: showFeedback
          ? RecoveryResetFeedback(
              errorMessage: message,
              onRestart: terminal ? widget.onRestart : null,
              onLoginRequired: uncertain || completion.canRetry
                  ? widget.onSignIn
                  : null,
              onRetry: completion.canRetry
                  ? () {
                      AppSnackBar.dismiss(context);
                      unawaited(
                        ref
                            .read(
                              registrationCompletionControllerProvider(
                                widget.scope,
                              ).notifier,
                            )
                            .retry(),
                      );
                    }
                  : null,
            )
          : null,
    );
  }
}
