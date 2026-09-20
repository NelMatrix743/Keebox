from datetime import datetime
from uuid import UUID

from django.conf import settings
from django.db import transaction
from django.utils import timezone

from apps.authentication.exceptions import (
    ExpiredLoginChallengeError,
    InvalidLoginChallengeError,
    InvalidLoginCredentialsError,
    InvalidLoginPINError,
    LoginAccountLockedError,
    LoginPINAttemptLimitError,
    LoginServiceError,
)
from apps.authentication.models import LoginChallenge, User
from apps.core.choices import LoginStatus
from apps.core.constants import AUTH_PIN_LOCKOUT_DURATION, AUTH_PIN_MAX_ATTEMPTS
from apps.core.key_utils import decrypt_kbkey
from apps.core.pin import verify_lock_pin



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

    @staticmethod
    def verify_pin(login_challenge_id: UUID, raw_pin: str) -> tuple[User, str]:
        """
        Verify a lock PIN and complete the pending login challenge.

        Args:
            login_challenge_id: Identifier of the password-verified challenge.
            raw_pin: Lock PIN submitted for the account.

        Returns:
            The authenticated user and their recovered plaintext KBKey.

        Raises:
            InvalidLoginChallengeError: Raised when the challenge is missing,
                invalid, or missing protected account key material.
            ExpiredLoginChallengeError: Raised when the challenge has expired.
            LoginAccountLockedError: Raised when the account is currently locked.
            InvalidLoginPINError: Raised when the submitted PIN is incorrect.
            LoginPINAttemptLimitError: Raised when the submitted PIN reaches
                the account's maximum failed-attempt limit.
            ValueError: Raised when the configured master key is invalid.
        """
        pending_error: LoginServiceError | None = None
        completed_login: tuple[User, str] | None = None

        with transaction.atomic():
            try:
                login_challenge: LoginChallenge = (
                    LoginChallenge.objects.select_for_update().get(
                        pk=login_challenge_id,
                    )
                )
            except LoginChallenge.DoesNotExist as exception:
                raise InvalidLoginChallengeError(
                    "The login challenge is unavailable.",
                ) from exception

            if login_challenge.status != LoginStatus.PASSWORD_VERIFIED:
                raise InvalidLoginChallengeError(
                    "The login challenge cannot verify a PIN.",
                )

            user: User = User.objects.select_for_update().get(
                pk=login_challenge.user_id,
            )
            current_time: datetime = timezone.now()

            if login_challenge.is_expired():
                login_challenge.status = LoginStatus.EXPIRED
                login_challenge.save(update_fields=["status", "updated_at"])
                pending_error = ExpiredLoginChallengeError(
                    "The login challenge has expired.",
                )
            elif user.pin_locked_until is not None and (
                user.pin_locked_until > current_time
            ):
                login_challenge.status = LoginStatus.LOCKED
                login_challenge.save(update_fields=["status", "updated_at"])
                pending_error = LoginAccountLockedError(
                    "The account is temporarily locked. Try again later.",
                )
            elif not user.pin_hash:
                raise InvalidLoginChallengeError(
                    "The account lock PIN is unavailable.",
                )
            elif verify_lock_pin(raw_pin, user.pin_hash):
                if user.encrypted_kbkey is None or user.kbkey_nonce is None:
                    raise InvalidLoginChallengeError(
                        "The account KBKey is unavailable.",
                    )

                kbkey: str = decrypt_kbkey(
                    user.encrypted_kbkey,
                    user.kbkey_nonce,
                    settings.KEEBOX_MASTER_KEY,
                    user.kbkey_encryption_version,
                )
                login_challenge.status = LoginStatus.COMPLETED
                login_challenge.completed_at = current_time
                login_challenge.save(
                    update_fields=["status", "completed_at", "updated_at"],
                )
                user.pin_failed_attempts = 0
                user.pin_locked_until = None
                user.save(update_fields=["pin_failed_attempts", "pin_locked_until"])
                completed_login = (user, kbkey)
            else:
                login_challenge.failed_pin_attempts += 1
                user.pin_failed_attempts += 1
                if user.pin_failed_attempts >= AUTH_PIN_MAX_ATTEMPTS:
                    user.pin_locked_until = current_time + AUTH_PIN_LOCKOUT_DURATION
                    login_challenge.status = LoginStatus.LOCKED
                    pending_error = LoginPINAttemptLimitError(
                        "The PIN attempt limit has been reached. Try again later.",
                    )
                else:
                    pending_error = InvalidLoginPINError(
                        "The lock PIN is invalid.",
                    )
                login_challenge.save(
                    update_fields=["failed_pin_attempts", "status", "updated_at"],
                )
                user.save(update_fields=["pin_failed_attempts", "pin_locked_until"])

        if pending_error is not None:
            raise pending_error
        if completed_login is None:
            raise InvalidLoginChallengeError(
                "The login challenge could not be completed.",
            )
        return completed_login
