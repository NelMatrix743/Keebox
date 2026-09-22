from typing import Any

from django.http import HttpRequest
from ninja import Router
from ninja_jwt.tokens import RefreshToken

from apps.authentication.exceptions import (
    ConsumedOTPError,
    ExpiredLoginChallengeError,
    ExpiredOTPError,
    InvalidLoginChallengeError,
    InvalidLoginCredentialsError,
    InvalidLoginPINError,
    InvalidOTPError,
    InvalidRegistrationStateError,
    LockedOTPError,
    LoginAccountLockedError,
    LoginPINAttemptLimitError,
    OTPResendCooldownError,
    OTPResendLimitError,
    RegistrationEmailConflictError,
)
from apps.authentication.models import (
    LoginChallenge,
    OTPVerification,
    RegistrationChallenge,
    User,
)
from apps.authentication.routes import Routes
from apps.authentication.services.login_services import LoginService
from apps.authentication.services.registration_services import RegistrationService
from apps.authentication.schemas import (
    LoginCompletedResponse,
    LoginPINVerificationRequest,
    LoginRequest,
    LoginStartedResponse,
    RegistrationCompletedResponse,
    RegistrationOTPResendRequest,
    RegistrationOTPResentResponse,
    RegistrationOTPVerifiedResponse,
    RegistrationCompletionRequest,
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
    Routes.Registration.BASE,
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
    Routes.Registration.VERIFY_OTP,
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
    Routes.Registration.RESEND_OTP,
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


@router.post(
    Routes.Registration.CREATE_PIN,
    response={
        201: SuccessResponse[RegistrationCompletedResponse],
        Ellipsis: ErrorResponse[ErrorData],
    },
)
def create_registration_pin(
    request: HttpRequest,
    payload: RegistrationCompletionRequest,
) -> tuple[int, dict[str, Any]]:
    """
    Create the lock PIN and complete an OTP-verified registration.

    Args:
        request: HTTP request that initiated registration completion.
        payload: Validated registration identifier and lock PIN.

    Returns:
        HTTP status and the completed registration response envelope.

    Raises:
        None: Expected registration failures are mapped to API responses.
    """
    try:
        user: User
        kbkey: str
        user, kbkey = RegistrationService.complete_registration(
            registration_challenge_id=payload.registration_id,
            raw_pin=payload.pin,
        )
    except InvalidRegistrationStateError:
        return 409, APIResponse.error(
            ErrorData(
                code="invalid_registration_state",
                message="The registration cannot create a lock PIN.",
            ).model_dump(),
        )

    refresh_token: RefreshToken = RefreshToken.for_user(user)
    response_data: RegistrationCompletedResponse = (
        RegistrationCompletedResponse.model_validate(
            {
                "user_id": user.id,
                "first_name": user.first_name,
                "last_name": user.last_name,
                "email": user.email,
                "kbkey": kbkey,
                "access_token": str(refresh_token.access_token),
                "refresh_token": str(refresh_token),
                "status": "completed",
                "message": "Registration completed successfully.",
            },
        )
    )
    return 201, APIResponse.success(response_data.model_dump())


@router.post(
    Routes.Login.BASE,
    response={
        200: SuccessResponse[LoginStartedResponse],
        Ellipsis: ErrorResponse[ErrorData],
    },
)
def login(
    request: HttpRequest,
    payload: LoginRequest,
) -> tuple[int, dict[str, Any]]:
    """
    Authenticate credentials and begin the lock-PIN login challenge.

    Args:
        request: HTTP request that initiated the login.
        payload: Validated email and password credentials.

    Returns:
        HTTP status and the standard login-challenge response envelope.

    Raises:
        None: Expected login failures are mapped to API responses.
    """
    try:
        login_challenge: LoginChallenge = LoginService.start_login(
            email=str(payload.email),
            password=payload.password,
        )
    except InvalidLoginCredentialsError:
        return 401, APIResponse.error(
            ErrorData(
                code="invalid_login_credentials",
                message="The email or password is invalid.",
            ).model_dump(),
        )
    except LoginAccountLockedError:
        return 423, APIResponse.error(
            ErrorData(
                code="login_account_locked",
                message="The account is temporarily locked. Try again later.",
            ).model_dump(),
        )

    response_data: LoginStartedResponse = LoginStartedResponse.model_validate(
        {
            "login_challenge_id": login_challenge.id,
            "status": login_challenge.status,
            "expires_at": login_challenge.expires_at,
            "message": "Password verified. Enter your lock PIN.",
        },
    )
    return 200, APIResponse.success(response_data.model_dump())


@router.post(
    Routes.Login.VERIFY_PIN,
    response={
        200: SuccessResponse[LoginCompletedResponse],
        Ellipsis: ErrorResponse[ErrorData],
    },
)
def verify_login_pin(
    request: HttpRequest,
    payload: LoginPINVerificationRequest,
) -> tuple[int, dict[str, Any]]:
    """
    Verify a login lock PIN and return the completed authentication payload.

    Args:
        request: HTTP request that submitted the login lock PIN.
        payload: Validated login challenge identifier and lock PIN.

    Returns:
        HTTP status and the standard completed-login response envelope.

    Raises:
        None: Expected login failures are mapped to API responses.
    """
    try:
        user: User
        kbkey: str
        user, kbkey = LoginService.verify_pin(
            login_challenge_id=payload.login_challenge_id,
            raw_pin=payload.pin,
        )
    except InvalidLoginChallengeError:
        return 409, APIResponse.error(
            ErrorData(
                code="invalid_login_challenge",
                message="The login challenge cannot verify a lock PIN.",
            ).model_dump(),
        )
    except ExpiredLoginChallengeError:
        return 410, APIResponse.error(
            ErrorData(
                code="expired_login_challenge",
                message="The login challenge has expired.",
            ).model_dump(),
        )
    except LoginAccountLockedError:
        return 423, APIResponse.error(
            ErrorData(
                code="login_account_locked",
                message="The account is temporarily locked. Try again later.",
            ).model_dump(),
        )
    except InvalidLoginPINError:
        return 400, APIResponse.error(
            ErrorData(
                code="invalid_login_pin",
                message="The lock PIN is invalid.",
            ).model_dump(),
        )
    except LoginPINAttemptLimitError:
        return 423, APIResponse.error(
            ErrorData(
                code="login_pin_attempt_limit",
                message="The PIN attempt limit has been reached. Try again later.",
            ).model_dump(),
        )

    refresh_token: RefreshToken = RefreshToken.for_user(user)
    response_data: LoginCompletedResponse = LoginCompletedResponse.model_validate(
        {
            "user_id": user.id,
            "first_name": user.first_name,
            "last_name": user.last_name,
            "email": user.email,
            "kbkey": kbkey,
            "access_token": str(refresh_token.access_token),
            "refresh_token": str(refresh_token),
            "status": "completed",
            "message": "Login completed successfully.",
        },
    )
    return 200, APIResponse.success(response_data.model_dump())
