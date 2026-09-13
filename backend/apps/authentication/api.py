from typing import Any

from django.http import HttpRequest
from ninja import Router

from apps.authentication.exceptions import (
    InvalidRegistrationStateError,
    RegistrationEmailConflictError,
)
from apps.authentication.models import OTPVerification, RegistrationChallenge
from apps.authentication.registration_services import RegistrationService
from apps.authentication.schemas import (
    RegistrationRequest,
    RegistrationStartedResponse,
)
from apps.core.constants import OTP_RESEND_COOLDOWN, OTP_TTL
from apps.core.email import EmailDeliveryService
from apps.core.exceptions import EmailDeliveryError
from apps.core.response import ErrorData, ErrorResponse, APIResponse, SuccessResponse



router: Router = Router(tags=["Authentication"])

@router.post(
    "/register",
    response={
        201: SuccessResponse[RegistrationStartedResponse],
        400: ErrorResponse[ErrorData],
        409: ErrorResponse[ErrorData],
        422: ErrorResponse[ErrorData],
        503: ErrorResponse[ErrorData],
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
