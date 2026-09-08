class AuthenticationServiceError(Exception):
    """Represent a failure raised by a Keebox authentication service."""


class RegistrationServiceError(AuthenticationServiceError):
    """Represent a failure raised by the Keebox registration service."""


class InvalidRegistrationStateError(RegistrationServiceError):
    """Indicate that a registration cannot perform the requested operation."""


class RegistrationEmailConflictError(RegistrationServiceError):
    """Indicate that a registration email already belongs to a user."""


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
