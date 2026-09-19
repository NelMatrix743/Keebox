from datetime import timedelta
from typing import Self

from django.test import TestCase, override_settings
from django.utils import timezone

from apps.authentication.exceptions import (
    ExpiredLoginChallengeError,
    InvalidLoginPINError,
    LoginPINAttemptLimitError,
)
from apps.authentication.login_services import LoginService
from apps.authentication.models import LoginChallenge, User
from apps.core.choices import LoginStatus
from apps.core.key_utils import encrypt_kbkey, generate_kbkey
from apps.core.pin import encrypt_lock_pin



@override_settings(
    KEEBOX_MASTER_KEY="KMK-ICEiIyQlJicoKSorLC0uLz-AxMjM0NTY3ODk6Ozw9Pj8",
    KEEBOX_PIN_PEPPER="test-pin-pepper",
)
class LoginPINServiceTests(TestCase):
    def _create_user(self: Self) -> User:
        """
        Create a persisted user with protected PIN and KBKey material.

        Args:
            self: Current test case instance.

        Returns:
            The persisted user prepared for PIN verification.

        Raises:
            ValueError: Raised when test key material cannot be protected.
        """
        kbkey: str = generate_kbkey()
        encrypted_kbkey: bytes
        kbkey_nonce: bytes
        kbkey_encryption_version: int
        (
            encrypted_kbkey,
            kbkey_nonce,
            kbkey_encryption_version,
        ) = encrypt_kbkey(
            kbkey,
            "KMK-ICEiIyQlJicoKSorLC0uLz-AxMjM0NTY3ODk6Ozw9Pj8",
        )
        return User.objects.create_user(
            email="nelson@example.com",
            password="correct horse battery staple",
            first_name="Nelson",
            last_name="Ubochiegbu",
            pin_hash=encrypt_lock_pin("123456"),
            encrypted_kbkey=encrypted_kbkey,
            kbkey_nonce=kbkey_nonce,
            kbkey_encryption_version=kbkey_encryption_version,
        )

    def _create_login_challenge(self: Self) -> LoginChallenge:
        """
        Create a password-verified login challenge for a test user.

        Args:
            self: Current test case instance.

        Returns:
            The persisted login challenge awaiting PIN verification.

        Raises:
            InvalidLoginCredentialsError: Raised when test credentials are invalid.
        """
        self._create_user()
        return LoginService.start_login(
            email="nelson@example.com",
            password="correct horse battery staple",
        )

 