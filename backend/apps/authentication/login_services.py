from __future__ import annotations

from datetime import datetime

from django.db import transaction
from django.utils import timezone

from apps.authentication.exceptions import (
    InvalidLoginCredentialsError,
    LoginAccountLockedError,
)
from apps.authentication.models import LoginChallenge, User



class LoginService:
    """Provide application services for the Keebox login workflow."""

    @staticmethod
    @transaction.atomic
    def start_login(email: str, password: str) -> LoginChallenge:
        """
        Authenticate account credentials and create a PIN-verification challenge.

        Args:
            email: Email address submitted as the account identifier.
            password: Raw account password submitted for authentication.

        Returns:
            A new login challenge in the password-verified state.

        Raises:
            InvalidLoginCredentialsError: Raised when the email, password, or
                account status is invalid.
            LoginAccountLockedError: Raised when the account is currently
                locked after too many failed PIN attempts.
        """
        if not email.strip() or not password:
            raise InvalidLoginCredentialsError(
                "The email or password is invalid.",
            )

        normalized_email: str = User.objects.normalize_email(email.strip()).casefold()

        try:
            user: User = User.objects.select_for_update().get(
                email=normalized_email,
            )
        except User.DoesNotExist as exception:
            raise InvalidLoginCredentialsError(
                "The email or password is invalid.",
            ) from exception

        if not user.is_active or not user.check_password(password):
            raise InvalidLoginCredentialsError(
                "The email or password is invalid.",
            )

        current_time: datetime = timezone.now()
        if user.pin_locked_until is not None:
            if user.pin_locked_until > current_time:
                raise LoginAccountLockedError(
                    "The account is temporarily locked. Try again later.",
                )

            user.pin_locked_until = None
            user.pin_failed_attempts = 0
            user.save(update_fields=["pin_locked_until", "pin_failed_attempts"])

        return LoginChallenge.objects.create(user=user)
