enum PinSetupStage { entry, confirmation, complete }

enum PinSetupError { mismatch, submission }

class PinSetupState {
  const PinSetupState({
    this.digits = '',
    this.stage = PinSetupStage.entry,
    this.isSubmitting = false,
    this.error,
  });

  static const length = 5;

  final String digits;
  final PinSetupStage stage;
  final bool isSubmitting;
  final PinSetupError? error;

  bool get canEdit => !isSubmitting && stage != PinSetupStage.complete;
  bool get canConfirm => canEdit && digits.length == length;
}
