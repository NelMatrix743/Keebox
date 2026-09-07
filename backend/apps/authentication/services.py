import secrets
from datetime import datetime
from uuid import UUID

from django.db import transaction
from django.utils import timezone

from apps.authentication.exceptions import (
    InvalidRegistrationStateError,
    OTPResendCooldownError,
    OTPResendLimitError,
)
from apps.authentication.models import OTPVerification, RegistrationChallenge
from apps.core.choices import OTPStatus, RegistrationStatus
from apps.core.constants import OTP_CODE_LENGTH, OTP_MAX_RESENDS, OTP_RESEND_COOLDOWN



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


def resend_registration_otp(
    registration_challenge_id: UUID,
) -> tuple[OTPVerification, str]:
    """
    Replace the current OTP for an active registration challenge.

    Args:
        registration_challenge_id: Identifier of the owning registration challenge.

    Returns:
        The persisted replacement OTP and raw code for immediate delivery.

    Raises:
        InvalidRegistrationStateError: Raised when the registration or OTP is
            unavailable for resending.
        OTPResendCooldownError: Raised when the resend cooldown has not elapsed.
        OTPResendLimitError: Raised after cancelling a registration that has used
            its resend allowance.
    """
    resend_limit_reached: bool = False
    replacement_otp: OTPVerification | None = None
    raw_code: str = ""

    with transaction.atomic():
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
                "The registration challenge cannot resend an OTP.",
            )

        current_otp: OTPVerification | None = (
            OTPVerification.objects.select_for_update()
            .filter(registration_challenge=registration_challenge)
            .order_by("-created_at")
            .first()
        )
        if current_otp is None:
            raise InvalidRegistrationStateError(
                "The registration challenge has no OTP to resend.",
            )

        if registration_challenge.resend_count >= OTP_MAX_RESENDS:
            registration_challenge.status = RegistrationStatus.CANCELLED
            registration_challenge.save(update_fields=["status", "updated_at"])
            OTPVerification.objects.filter(
                registration_challenge=registration_challenge,
                status=OTPStatus.PENDING,
            ).update(status=OTPStatus.EXPIRED)
            resend_limit_reached = True
        else:
            resend_available_at: datetime = (
                current_otp.last_sent_at + OTP_RESEND_COOLDOWN
            )
            if timezone.now() < resend_available_at:
                raise OTPResendCooldownError(
                    "The OTP resend cooldown has not elapsed.",
                )

            OTPVerification.objects.filter(
                registration_challenge=registration_challenge,
                status=OTPStatus.PENDING,
            ).update(status=OTPStatus.EXPIRED)
            registration_challenge.resend_count += 1
            registration_challenge.save(
                update_fields=["resend_count", "updated_at"],
            )

            raw_code: str = generate_otp_code()
            replacement_otp: OTPVerification = OTPVerification(
                registration_challenge=registration_challenge,
                email=registration_challenge.email,
            )
            replacement_otp.hash_and_set_otp_code(raw_code)
            replacement_otp.save()

    if resend_limit_reached:
        raise OTPResendLimitError(
            "The registration challenge reached its OTP resend limit.",
        )

    if replacement_otp is None:
        raise InvalidRegistrationStateError(
            "The replacement OTP could not be created.",
        )

    return replacement_otp, raw_code
