import secrets
from uuid import UUID

from django.db import transaction

from apps.authentication.exceptions import InvalidRegistrationStateError
from apps.authentication.models import OTPVerification, RegistrationChallenge
from apps.core.choices import OTPStatus, RegistrationStatus
from apps.core.constants import OTP_CODE_LENGTH



def generate_otp_code() -> str:
    """
    Generate a cryptographically secure numeric OTP code.

    Args:
        None.

    Returns:
        A zero-padded numeric OTP code with the configured length.

    Raises:
        None.
    """
    upper_bound: int = 10**OTP_CODE_LENGTH
    random_value: int = secrets.randbelow(upper_bound)
    return f"{random_value:0{OTP_CODE_LENGTH}d}"


@transaction.atomic
def issue_registration_otp(registration_challenge_id: UUID) -> tuple[OTPVerification, str]:
    """
    Create a protected OTP verification for a pending registration.

    Args:
        registration_challenge_id: Identifier of the owning registration challenge.

    Returns:
        The persisted OTP verification and raw code for immediate delivery.

    Raises:
        InvalidRegistrationStateError: Raised when the registration cannot issue 
        OTPs.
    """
    try:
        registration_challenge: RegistrationChallenge = (
            RegistrationChallenge.objects.select_for_update().get(
                pk=registration_challenge_id,
            )
        )
    except RegistrationChallenge.DoesNotExist as exception:
        raise InvalidRegistrationStateError(
            "The registration challenge is unavailable.",
        ) from exception

    if (
        registration_challenge.status != RegistrationStatus.OTP_PENDING
        or registration_challenge.is_expired()
    ):
        raise InvalidRegistrationStateError(
            "The registration challenge cannot issue an OTP.",
        )

    OTPVerification.objects.filter(
        registration_challenge=registration_challenge,
        status=OTPStatus.PENDING,
    ).update(status=OTPStatus.EXPIRED)

    raw_code: str = generate_otp_code()
    otp_verification: OTPVerification = OTPVerification(
        registration_challenge=registration_challenge,
        email=registration_challenge.email,
    )
    otp_verification.hash_and_set_otp_code(raw_code)
    otp_verification.save()
    return otp_verification, raw_code
