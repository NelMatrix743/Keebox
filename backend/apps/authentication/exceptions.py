class AuthenticationServiceError(Exception):
    """Represent a failure raised by a Keebox authentication service."""


class RegistrationServiceError(AuthenticationServiceError):
    """Represent a failure raised by the Keebox registration service."""


class InvalidRegistrationStateError(RegistrationServiceError):
    """Indicate that a registration cannot perform the requested operation."""


class RegistrationEmailConflictError(RegistrationServiceError):
    """Indicate that a registration email already belongs to a user."""


class LoginServiceError(AuthenticationServiceError):
    """Represent a failure raised by the Keebox login service."""


class InvalidLoginCredentialsError(LoginServiceError):
    """Indicate that submitted login credentials are invalid."""


class LoginAccountLockedError(LoginServiceError):
    """Indicate that PIN failures temporarily locked the user account."""


class InvalidLoginChallengeError(LoginServiceError):
    """Indicate that a login challenge cannot perform the requested operation."""


class ExpiredLoginChallengeError(LoginServiceError):
    """Indicate that a login challenge has expired."""


class InvalidLoginPINError(LoginServiceError):
    """Indicate that a submitted login PIN is invalid."""


class LoginPINAttemptLimitError(LoginServiceError):
    """Indicate that the login PIN failure limit has been reached."""


class OTPServiceError(AuthenticationServiceError):
    """Represent a failure raised by the Keebox OTP service."""


class InvalidOTPError(OTPServiceError):
    """Indicate that a submitted OTP code is invalid."""


class ExpiredOTPError(OTPServiceError):
    """Indicate that an OTP verification has expired."""


class ConsumedOTPError(OTPServiceError):
    """Indicate that an OTP verification has already been consumed."""


class LockedOTPError(OTPServiceError):
    """Indicate that an OTP verification is locked."""


class OTPResendCooldownError(OTPServiceError):
    """Indicate that an OTP resend was requested before its cooldown elapsed."""


class OTPResendLimitError(OTPServiceError):
    """Indicate that a registration challenge reached its OTP resend limit."""
