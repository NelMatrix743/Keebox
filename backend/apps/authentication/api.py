from typing import Any

from django.http import HttpRequest
from ninja import Router

from apps.authentication.exceptions import (
    ConsumedOTPError,
    ExpiredOTPError,
    InvalidOTPError,
    InvalidRegistrationStateError,
    LockedOTPError,
    OTPResendCooldownError,
    OTPResendLimitError,
    RegistrationEmailConflictError,
)
from apps.authentication.models import OTPVerification, RegistrationChallenge
from apps.authentication.registration_services import RegistrationService
from apps.authentication.schemas import (
    RegistrationOTPResendRequest,
    RegistrationOTPResentResponse,
    RegistrationOTPVerifiedResponse,
    RegistrationRequest,
    RegistrationStartedResponse,
    RegistrationVerificationRequest,
)
from apps.core.constants import OTP_MAX_RESENDS, OTP_RESEND_COOLDOWN, OTP_TTL
from apps.core.email import EmailDeliveryService
from apps.core.exceptions import EmailDeliveryError
from apps.core.response import ErrorData, ErrorResponse, APIResponse, SuccessResponse



router: Router = Router(tags=["Authentication"])

@router.post(
    "/register",
    response={
        201: SuccessResponse[RegistrationStartedResponse],
        Ellipsis: ErrorResponse[ErrorData],
    },
)
def register(
    request: HttpRequest,
    payload: RegistrationRequest,
) -> tuple[int, dict[str, Any]]:
    """
    Begin registration and deliver its initial OTP email.

    Args:
        request: HTTP request that initiated registration.
        payload: Validated account registration data.

    Returns:
        HTTP status and the standard registration response envelope.

    Raises:
        None: Expected service and delivery failures are mapped to API responses.
    """
    try:
        registration_challenge: RegistrationChallenge
        otp_verification: OTPVerification
        raw_code: str
        registration_challenge, otp_verification, raw_code = (
            RegistrationService.start_registration(
                first_name=payload.first_name,
                last_name=payload.last_name,
                email=str(payload.email),
                raw_password=payload.password,
            )
        )
        EmailDeliveryService().send_otp_email(
            recipient_email=registration_challenge.email,
            recipient_full_name=(
                f"{registration_challenge.first_name} "
                f"{registration_challenge.last_name}"
            ),
            otp_code=raw_code,
            expiration_minutes=int(OTP_TTL.total_seconds() // 60),
        )
    except RegistrationEmailConflictError:
        return 409, APIResponse.error(
            ErrorData(
                code="registration_email_conflict",
                message="A user with this email address already exists.",
            ).model_dump(),
        )
    except InvalidRegistrationStateError:
        return 409, APIResponse.error(
            ErrorData(
                code="invalid_registration_state",
                message="The registration could not be started.",
            ).model_dump(),
        )
    except ValueError:
        return 400, APIResponse.error(
            ErrorData(
                code="invalid_registration_data",
                message="The registration information is invalid.",
            ).model_dump(),
        )
    except EmailDeliveryError:
        return 503, APIResponse.error(
            ErrorData(
                code="email_delivery_failed",
                message="The verification email could not be sent.",
            ).model_dump(),
        )

    response_data: RegistrationStartedResponse = (
        RegistrationStartedResponse.model_validate(
            {
                "registration_id": registration_challenge.id,
                "status": registration_challenge.status,
                "expires_at": registration_challenge.expires_at,
                "otp_expires_at": otp_verification.expires_at,
                "resend_available_at": (
                    otp_verification.last_sent_at + OTP_RESEND_COOLDOWN
                ),
                "message": (
                    "Registration started. Check your email for the verification "
                    "code."
                ),
            },
        )
    )
    return 201, APIResponse.success(response_data.model_dump())


@router.post(
    "/register/verify-otp",
    response={
        200: SuccessResponse[RegistrationOTPVerifiedResponse],
        Ellipsis: ErrorResponse[ErrorData],
    },
)
def verify_registration_otp(
    request: HttpRequest,
    payload: RegistrationVerificationRequest,
) -> tuple[int, dict[str, Any]]:
    """
    Verify the current OTP for a pending registration challenge.

    Args:
        request: HTTP request that initiated OTP verification.
        payload: Validated registration identifier and OTP code.

    Returns:
        HTTP status and the standard OTP verification response envelope.

    Raises:
        None: Expected registration and OTP failures are mapped to API responses.
    """
    try:
        RegistrationService.verify_registration_otp(
            registration_challenge_id=payload.registration_id,
            raw_code=payload.otp_code,
        )
    except InvalidOTPError:
        return 400, APIResponse.error(
            ErrorData(
                code="invalid_otp",
                message="The OTP code is invalid.",
            ).model_dump(),
        )
    except ExpiredOTPError:
        return 410, APIResponse.error(
            ErrorData(
                code="expired_otp",
                message="The OTP code has expired.",
            ).model_dump(),
        )
    except LockedOTPError:
        return 423, APIResponse.error(
            ErrorData(
                code="locked_otp",
                message="The OTP code is locked.",
            ).model_dump(),
        )
    except ConsumedOTPError:
        return 409, APIResponse.error(
            ErrorData(
                code="consumed_otp",
                message="The OTP code has already been used.",
            ).model_dump(),
        )
    except InvalidRegistrationStateError:
        return 409, APIResponse.error(
            ErrorData(
                code="invalid_registration_state",
                message="The registration cannot verify an OTP.",
            ).model_dump(),
        )

    response_data: RegistrationOTPVerifiedResponse = (
        RegistrationOTPVerifiedResponse.model_validate(
            {
                "registration_id": payload.registration_id,
                "status": "otp_verified",
                "message": (
                    "Email verified. Create your lock PIN to complete registration."
                ),
            },
        )
    )
    return 200, APIResponse.success(response_data.model_dump())


@router.post(
    "/register/resend-otp",
    response={
        200: SuccessResponse[RegistrationOTPResentResponse],
        Ellipsis: ErrorResponse[ErrorData],
    },
)
def resend_registration_otp(
    request: HttpRequest,
    payload: RegistrationOTPResendRequest,
) -> tuple[int, dict[str, Any]]:
    """
    Replace and deliver the current OTP for a pending registration.

    Args:
        request: HTTP request that initiated the OTP resend.
        payload: Validated registration identifier for the resend.

    Returns:
        HTTP status and the standard OTP resend response envelope.

    Raises:
        None: Expected resend and delivery failures are mapped to API responses.
    """
    try:
        replacement_otp: OTPVerification
        raw_code: str
        replacement_otp, raw_code = RegistrationService.resend_registration_otp(
            registration_challenge_id=payload.registration_id,
        )
        registration_challenge: RegistrationChallenge = (
            replacement_otp.registration_challenge
        )
        EmailDeliveryService().send_otp_email(
            recipient_email=registration_challenge.email,
            recipient_full_name=(
                f"{registration_challenge.first_name} "
                f"{registration_challenge.last_name}"
            ),
            otp_code=raw_code,
            expiration_minutes=int(OTP_TTL.total_seconds() // 60),
        )
    except OTPResendCooldownError:
        return 429, APIResponse.error(
            ErrorData(
                code="otp_resend_cooldown",
                message="A new OTP cannot be requested yet.",
            ).model_dump(),
        )
    except OTPResendLimitError:
        return 429, APIResponse.error(
            ErrorData(
                code="otp_resend_limit_reached",
                message=(
                    "The OTP resend limit has been reached. Start a new "
                    "registration."
                ),
            ).model_dump(),
        )
    except InvalidRegistrationStateError:
        return 409, APIResponse.error(
            ErrorData(
                code="invalid_registration_state",
                message="The registration cannot resend an OTP.",
            ).model_dump(),
        )
    except EmailDeliveryError:
        return 503, APIResponse.error(
            ErrorData(
                code="email_delivery_failed",
                message="The verification email could not be sent.",
            ).model_dump(),
        )

    response_data: RegistrationOTPResentResponse = (
        RegistrationOTPResentResponse.model_validate(
            {
                "registration_id": registration_challenge.id,
                "status": registration_challenge.status,
                "otp_expires_at": replacement_otp.expires_at,
                "resend_available_at": (
                    replacement_otp.last_sent_at + OTP_RESEND_COOLDOWN
                ),
                "resends_remaining": (
                    OTP_MAX_RESENDS - registration_challenge.resend_count
                ),
                "message": "A new verification code has been sent.",
            },
        )
    )

    return 200, APIResponse.success(response_data.model_dump())
