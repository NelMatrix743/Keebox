from datetime import datetime
from typing import Any, Literal, Self
from uuid import UUID

from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from ninja import Schema
from pydantic import ConfigDict, EmailStr, Field, field_validator



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

