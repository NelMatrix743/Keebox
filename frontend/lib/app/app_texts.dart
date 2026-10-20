abstract final class AppTexts {
  static const appName = 'Keebox';
  static const recoveryFailed =
      'Unable to complete this recovery request. Please try again.';
  static const recoveryEmailRequired = 'Enter your email address.';
  static const recoveryOtpInvalid = 'Enter the six-digit verification code.';
  static const recoveryPasswordRequired = 'Enter your new password.';
  static const recoveryPinInvalid = 'Enter a five-digit PIN.';
  static const recoveryOtpExpired =
      'Your verification code has expired. Start a new recovery request.';
  static const recoveryCompletionExpired =
      'Your recovery session has expired. Start a new recovery request.';
  static const recoveryResendUnavailable =
      'Please wait before requesting another verification code.';
  static const recoveryResponseInvalid =
      'The server returned an unexpected recovery response. Start a new recovery request.';
  static const recoveryCompletionUncertain =
      'We could not confirm whether your credential was changed. Try signing in with the new credential, or restart recovery.';
  static const startupFailed =
      'Unable to read your saved settings. Please try again.';
  static const retry = 'Retry';
  static const logout = 'Log out';
  static const logoutLocalOnly =
      'Signed out on this device. The server could not be reached to end the remote session.';
  static const refreshProfile = 'Refresh profile';
  static const profileUnavailable =
      'Unable to load your profile. Please try again.';
  static const userId = 'User ID';
  static const firstName = 'First name';
  static const lastName = 'Last name';
  static const email = 'Email';

  static const onboardingLoadFailed =
      'Unable to load onboarding progress. Please try again.';
  static const onboardingSaveFailed =
      'Unable to save onboarding progress. Please try again.';

  static const login = 'Login';
  static const loggingIn = 'Verifying your account';
  static const loginFailed = 'Unable to log in. Please try again.';

  static const createPinTitle = 'Create a PIN Code';
  static const createPinSubtitle =
      'Create a lock PIN to locally secure your data';
  static const resetPinTitle = 'Reset Your PIN Code';
  static const resetPinSubtitle = 'Enter a new pin code to reset';
  static const pinConfirmedTitle = 'PIN Code Confirmed';
  static const pinConfirmedSubtitle = 'Your PIN code has been confirmed';
  static const pinConfirmationFailed =
      'Could not confirm your PIN. Please try again.';
  static const confirm = 'Confirm';
  static const confirmed = 'Confirmed';
  static const confirmingPin = 'Confirming PIN';
  static const emptyPinDigit = 'Empty';
  static const deletePinDigit = 'Delete last digit';
  static const authenticateWithFingerprint = 'Authenticate with fingerprint';
  static const enterPinToProceed = 'enter your pin code to proceed';
  static const forgotPin = 'Forgot your PIN code?';
  static const reset = 'Reset';
  static const verifyingPin = 'Verifying PIN';
  static const pinVerificationFailed =
      'Unable to verify your PIN. Please try again.';
  static const localPinLoginRequired =
      'For your security, please log in again to unlock the app.';
  static String localPinIncorrect(int remainingAttempts) =>
      'Incorrect PIN. $remainingAttempts ${remainingAttempts == 1 ? 'attempt' : 'attempts'} remaining.';
  static const loginChallengeExpired =
      'Your login has expired. Please log in again.';
  static const loginSessionSaveFailed =
      'Unable to save your session. Please log in again.';
  static const home = 'Home';
  static const homePlaceholder =
      'You are signed in. Your home screen is coming soon.';

  static String pinIndicatorLabel(int position, bool filled) =>
      'PIN digit $position: ${filled ? 'Entered' : emptyPinDigit}';

  static String pinDigitLabel(int position) => 'PIN digit $position';
}
