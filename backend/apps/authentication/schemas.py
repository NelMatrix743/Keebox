from datetime import datetime
from typing import Any, Literal, Self
from uuid import UUID

from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from ninja import Schema
from pydantic import ConfigDict, EmailStr, Field, field_validator



class AuthenticationSuccessResponse(Schema):
    """Represent the shared payload returned after complete authentication."""

    model_config = ConfigDict(extra="forbid")

    user_id: UUID
    first_name: str
    last_name: str
    email: EmailStr
    kbkey: str
    access_token: str
    refresh_token: str
    status: Literal["completed"]
    message: str


class RegistrationRequest(Schema):
    """Validate data submitted to begin a Keebox registration."""

    model_config = ConfigDict(extra="forbid")

    first_name: str = Field(min_length=1, max_length=150)
    last_name: str = Field(min_length=1, max_length=150)
    email: EmailStr = Field(max_length=254)
    password: str = Field(min_length=1)

    @field_validator("first_name", "last_name", "email", mode="before")
    @classmethod
    def strip_registration_text(cls: type[Self], value: Any) -> Any:
        """
        Remove surrounding whitespace from textual registration fields.

        Args:
            cls: Registration request schema class.
            value: Unvalidated field value submitted by the client.

        Returns:
            The stripped string or the original non-string value.

        Raises:
            None.
        """
        if isinstance(value, str):
            return value.strip()
        return value

    @field_validator("password")
    @classmethod
    def validate_registration_password(
        cls: type[Self],
        value: str,
    ) -> str:
        """
        Validate a registration password using Django's configured policy.

        Args:
            cls: Registration request schema class.
            value: Raw password submitted by the client.

        Returns:
            The password after successful policy validation.

        Raises:
            ValueError: Raised when the password violates the configured policy.
        """
        try:
            validate_password(value)
        except DjangoValidationError as exception:
            raise ValueError(" ".join(exception.messages)) from exception
        return value


class RegistrationStartedResponse(Schema):
    """Represent safe response data for a newly started registration."""

    model_config = ConfigDict(extra="forbid")

    registration_id: UUID
    status: Literal["otp_pending"]
    expires_at: datetime
    otp_expires_at: datetime
    resend_available_at: datetime
    message: str


class RegistrationVerificationRequest(Schema):
    """Validate data submitted to verify a registration OTP."""

    model_config = ConfigDict(extra="forbid")

    registration_id: UUID
    otp_code: str = Field(pattern=r"^[0-9]{6}$", strict=True)


class RegistrationOTPVerifiedResponse(Schema):
    """Represent safe response data after registration OTP verification."""

    model_config = ConfigDict(extra="forbid")

    registration_id: UUID
    status: Literal["otp_verified"]
    message: str


class RegistrationOTPResendRequest(Schema):
    """Validate data submitted to resend a registration OTP."""

    model_config = ConfigDict(extra="forbid")

    registration_id: UUID


class RegistrationOTPResentResponse(Schema):
    """Represent safe response data for a replacement registration OTP."""

    model_config = ConfigDict(extra="forbid")

    registration_id: UUID
    status: Literal["otp_pending"]
    otp_expires_at: datetime
    resend_available_at: datetime
    resends_remaining: int = Field(ge=0)
    message: str


class RegistrationCompletionRequest(Schema):
    """Validate lock PIN data submitted to complete registration."""

    model_config = ConfigDict(extra="forbid")

    registration_id: UUID
    pin: str = Field(min_length=1, strict=True)


class RegistrationCompletedResponse(AuthenticationSuccessResponse):
    """Represent safe response data for a completed registration."""


class LoginRequest(Schema):
    """Validate credentials submitted to begin a Keebox login."""

    model_config = ConfigDict(extra="forbid")

    email: EmailStr = Field(max_length=254)
    password: str = Field(min_length=1, strict=True)

    @field_validator("email", mode="before")
    @classmethod
    def strip_login_email(cls: type[Self], value: Any) -> Any:
        """
        Remove surrounding whitespace from the submitted login email address.

        Args:
            cls: Login request schema class.
            value: Unvalidated email value submitted by the client.

        Returns:
            The stripped email string or the original non-string value.

        Raises:
            None.
        """
        if isinstance(value, str):
            return value.strip()
        return value


class LoginStartedResponse(Schema):
    """Represent safe response data for a password-verified login challenge."""

    model_config = ConfigDict(extra="forbid")

    login_challenge_id: UUID
    status: Literal["password_verified"]
    expires_at: datetime
    message: str


class LoginPINVerificationRequest(Schema):
    """Validate lock PIN data submitted to complete a Keebox login."""

    model_config = ConfigDict(extra="forbid")

    login_challenge_id: UUID
    pin: str = Field(min_length=1, strict=True)


class LoginCompletedResponse(AuthenticationSuccessResponse):
    """Represent safe response data for a completed login."""


class ResetStartRequest(Schema):
    """Validate an email submitted to begin password or PIN recovery."""

    model_config = ConfigDict(extra="forbid")

    email: EmailStr = Field(max_length=254)

    @field_validator("email", mode="before")
    @classmethod
    def strip_reset_email(cls: type[Self], value: Any) -> Any:
        """
        Remove surrounding whitespace from a submitted reset email address.

        Args:
            cls: Reset start request schema class.
            value: Unvalidated email value submitted by the client.

        Returns:
            The stripped email string or the original non-string value.

        Raises:
            None.
        """
        if isinstance(value, str):
            return value.strip()
        return value


class ResetStartedResponse(Schema):
    """Represent generic response data after a reset request is submitted."""

    model_config = ConfigDict(extra="forbid")

    reset_id: UUID
    status: Literal["otp_pending"]
    otp_expires_at: datetime
    resend_available_at: datetime
    message: str


class ResetOTPResendRequest(Schema):
    """Validate the reset identifier submitted to request another OTP."""

    model_config = ConfigDict(extra="forbid")

    reset_id: UUID

