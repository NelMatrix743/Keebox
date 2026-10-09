import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keebox/features/pin/state/pin_setup_state.dart';

// Each screen supplies its own identity so overlapping routes never share a PIN.
final pinSetupControllerProvider = NotifierProvider.autoDispose
    .family<PinSetupController, PinSetupState, Object>(
      (_) => PinSetupController(),
    );

class PinSetupController extends Notifier<PinSetupState> {
  String? _firstPin;

  @override
  PinSetupState build() {
    ref.onDispose(() => _firstPin = null);
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

  Future<void> confirm(FutureOr<void> Function(String pin) onConfirmed) async {
    if (!state.canConfirm) return;
    if (state.stage == PinSetupStage.entry) {
      _firstPin = state.digits;
      state = const PinSetupState(stage: PinSetupStage.confirmation);
      return;
    }
    if (state.digits != _firstPin) {
      state = const PinSetupState(
        stage: PinSetupStage.confirmation,
        error: PinSetupError.mismatch,
      );
      return;
    }
    final pin = state.digits;
    state = PinSetupState(
      digits: pin,
      stage: PinSetupStage.confirmation,
      isSubmitting: true,
    );
    try {
      await onConfirmed(pin);
      if (!ref.mounted) return;
      _firstPin = null;
      state = const PinSetupState(stage: PinSetupStage.complete);
    } catch (_) {
      if (!ref.mounted) return;
      state = const PinSetupState(
        stage: PinSetupStage.confirmation,
        error: PinSetupError.submission,
      );
    }
  }
}
