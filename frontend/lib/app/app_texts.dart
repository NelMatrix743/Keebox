abstract final class AppTexts {
  static const registrationCompletedTitle = 'Account setup completed';
  static const registrationCompletedMessage =
      'Account setup completed successfully!';
  static const registrationSessionSaveFailed =
      'Your account was created, but we could not save it on this device. Retry to finish, or sign in again.';
  static const registrationIdentityTitle = 'Identity';
  static const registrationIdentitySubtitle = 'Setup your account’s identity';
  static const registrationPasswordTitle = 'Password';
  static const registrationPasswordSubtitle = 'Setup your account’s password';
  static const registrationFirstNameHint = 'Your first name';
  static const registrationLastNameHint = 'Your last name';
  static const registrationFirstNameRequired = 'Enter your first name.';
  static const registrationLastNameRequired = 'Enter your last name.';
  static const registrationNameTooLong = 'Use no more than 150 characters.';
  static const registrationEmailTooLong = 'Use no more than 254 characters.';
  static const registrationPasswordRequired = 'Enter your password.';
  static const registrationConfirmPasswordRequired = 'Confirm your password.';
  static const registrationHaveAccount = 'Have an account?';
  static const signIn = 'Sign In';
  static const next = 'Next';
  static const registering = 'Creating your registration';
  static const registrationDetailsInvalid =
      'Enter your name, email address, and password correctly.';
  static const registrationOtpInvalid =
      'Enter the six-digit verification code.';
  static const registrationPinInvalid = 'Enter a five-digit PIN.';
  static const registrationFailed =
      'Unable to complete this registration request. Please try again.';
  static const registrationExpired =
      'Your registration has expired. Start again.';
  static const registrationOtpExpired =
      'Your verification code has expired. Request a new code.';
  static const registrationResendUnavailable =
      'Please wait before requesting another verification code.';
  static const registrationResendsExhausted =
      'No more codes can be requested. Use your latest valid code or start again.';
  static const registrationResponseInvalid =
      'The server returned an unexpected registration response. Start again.';
  static const registrationCompletionUncertain =
      'We could not confirm whether your account was created. Try signing in with your email, password, and selected PIN. If needed, use account recovery.';
  static const appName = 'Keebox';
  static const back = 'Back';
  static const recoveryEmailTitle = 'Enter your email';
  static const recoveryEmailSubtitle =
      'Enter the email address connected to your account';
  static const recoveryEmailHint = 'Your email address';
  static const recoveryEmailInvalid = 'Enter a valid email address.';
  static const continueLabel = 'Continue';
  static const requestingRecovery = 'Requesting a verification code';
  static const recoveryOtpSent = 'An OTP code has been sent to your email';
  static const recoveryOtpInstruction = 'Enter it below';
  static const verifyingOtp = 'Verifying your code';
  static const resendIn = 'Resend in:';
  static const resendCode = 'Resend code';
  static const resendingCode = 'Sending a new code';
  static const restartRecovery = 'Start again';
  static const resetPasswordTitle = 'Reset Password';
  static const resetPasswordSubtitle = 'Enter a new password to reset';
  static const newPasswordHint = 'Enter password';
  static const confirmPasswordHint = 'Confirm password';
  static const confirmPasswordRequired = 'Confirm your new password.';
  static const passwordsDoNotMatch = 'The passwords do not match.';
  static const showPassword = 'Show password';
  static const hidePassword = 'Hide password';
  static const resettingPassword = 'Resetting your password';
  static const backToLogin = 'Back to login';
  static const recoveryCompletedTitle = 'Reset completed';
  static const recoveryCompletedMessage = 'Reset completed successfully!';
  static const finishingRecovery = 'Finishing recovery';
  static const recoveryCleanupFailed =
      'Your reset succeeded, but we could not clear this device\'s previous session. Retry to finish.';
  static String otpDigitLabel(int position) =>
      'Verification code digit $position';
  static String recoveryCountdown(Duration remaining) {
    final seconds = remaining.inSeconds;
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

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
  static const onboardingNotesTitle = 'Secured Notes';
  static const onboardingNotesDescription =
      'Keep your private thoughts and sensitive information securely protected in one place.';
  static const onboardingCredentialsTitle = 'Secured Credentials';
  static const onboardingCredentialsDescription =
      'Safely store and manage passwords, API keys, security keys, and other credentials.';
  static const onboardingPrivacyTitle = 'Private By Design';
  static const onboardingPrivacyDescription =
      'Your sensitive data is encrypted and protected with privacy built into Keebox from the start.';
  static const onboardingBackupTitle = 'Data Backup';
  static const onboardingBackupDescription =
      'Keep encrypted backups of your KBoxes so your data can be restored when you need it.';
  static const onboardingWelcomeTitle = 'Welcome to Keebox!';
  static const onboardingWelcomeDescription =
      'Your Thoughts And Access Secured.';
  static const onboardingSkip = 'SKIP';
  static const onboardingNext = 'Next onboarding page';
  static const getStarted = 'Get Started';
  static String onboardingProgress(int position, int total) =>
      'Introduction $position of $total';

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
