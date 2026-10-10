import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keebox/features/pin/state/pin_setup_state.dart';

// Each screen supplies its own identity so overlapping routes never share a PIN.
final pinSetupControllerProvider = NotifierProvider.autoDispose
    .family<PinSetupController, PinSetupState, Object>(
      (_) => PinSetupController(),
    );

class PinSetupController extends Notifier<PinSetupState> {
  int _generation = 0;

  @override
  PinSetupState build() {
    _generation++;
    return const PinSetupState();
  }

  void enterDigit(int digit) {
    if (!state.canEdit ||
        state.digits.length == PinSetupState.length ||
        digit < 0 ||
        digit > 9) {
      return;
    }
    state = PinSetupState(digits: '${state.digits}$digit', stage: state.stage);
  }

  void deleteDigit() {
    if (!state.canEdit || state.digits.isEmpty) return;
    state = PinSetupState(
      digits: state.digits.substring(0, state.digits.length - 1),
      stage: state.stage,
    );
  }

  Future<void> confirm(
    FutureOr<void> Function(String pin) onConfirmed, {
    Future<void> Function()? beforeSubmit,
  }) async {
    if (!state.canConfirm) return;
    final pin = state.digits;
    final generation = _generation;
    state = PinSetupState(digits: pin, isSubmitting: true);
    try {
      // Let the button render its busy state before starting the callback.
      await beforeSubmit?.call();
      if (!ref.mounted || generation != _generation) return;
      await onConfirmed(pin);
      if (!ref.mounted || generation != _generation) return;
      state = const PinSetupState(stage: PinSetupStage.complete);
    } catch (_) {
      if (!ref.mounted || generation != _generation) return;
      state = PinSetupState(digits: pin, submissionFailed: true);
    }
  }
}
