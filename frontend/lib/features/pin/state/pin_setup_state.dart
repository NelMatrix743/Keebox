enum PinSetupStage { entry, complete }

class PinSetupState {
  const PinSetupState({
    this.digits = '',
    this.stage = PinSetupStage.entry,
    this.isSubmitting = false,
    this.submissionFailed = false,
  });

  static const length = 5;

  final String digits;
  final PinSetupStage stage;
  final bool isSubmitting;
  final bool submissionFailed;

  bool get canEdit => !isSubmitting && stage != PinSetupStage.complete;
  bool get canConfirm => canEdit && digits.length == length;
}
