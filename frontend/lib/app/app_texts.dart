abstract final class AppTexts {
  static const appName = 'Keebox';

  static const createPinTitle = 'Create a PIN Code';
  static const createPinSubtitle =
      'Create a lock PIN to locally secure your data';
  static const resetPinTitle = 'Reset Your PIN Code';
  static const resetPinSubtitle = 'Enter a new pin code to reset';
  static const confirmPinTitle = 'Confirm Your PIN Code';
  static const confirmPinInstruction = 'Enter your PIN code again to confirm';
  static const pinConfirmedTitle = 'PIN Code Confirmed';
  static const pinConfirmedSubtitle = 'Your PIN entries match';
  static const pinMismatchMessage = 'PIN codes do not match. Please try again.';
  static const pinConfirmationFailed =
      'Could not confirm your PIN. Please try again.';
  static const confirm = 'Confirm';
  static const confirmed = 'Confirmed';
  static const confirmingPin = 'Confirming PIN';
  static const emptyPinDigit = 'Empty';
  static const deletePinDigit = 'Delete last digit';

  static String pinDigitLabel(int position) => 'PIN digit $position';
}
