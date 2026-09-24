from datetime import timedelta
from typing import Self

from django.test import TestCase, override_settings
from django.utils import timezone

from apps.authentication.exceptions import (
    ExpiredLoginChallengeError,
    InvalidLoginPINError,
    LoginPINAttemptLimitError,
)
from apps.authentication.services.login_services import LoginService
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

    def test_verify_pin_completes_challenge_and_returns_user_key(
        self: Self,
    ) -> None:
        """
        Verify a correct PIN completes the challenge and recovers the KBKey.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when successful PIN verification is incomplete.
        """
        challenge: LoginChallenge = self._create_login_challenge()

        user: User
        kbkey: str
        user, kbkey = LoginService.verify_pin(challenge.id, "123456")

        challenge.refresh_from_db()
        user.refresh_from_db()
        self.assertEqual(user.email, "nelson@example.com")
        self.assertTrue(kbkey.startswith("KBK-"))
        self.assertEqual(challenge.status, LoginStatus.COMPLETED)
        self.assertIsNotNone(challenge.completed_at)
        self.assertEqual(user.pin_failed_attempts, 0)
        self.assertIsNone(user.pin_locked_until)
        self.assertEqual(user.token_version, 1)

    def test_verify_pin_records_an_invalid_pin_attempt(self: Self) -> None:
        """
        Verify an incorrect PIN increments challenge and account counters.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an invalid PIN is not recorded.
        """
        challenge: LoginChallenge = self._create_login_challenge()

        with self.assertRaises(InvalidLoginPINError):
            LoginService.verify_pin(challenge.id, "654321")

        challenge.refresh_from_db()
        user: User = User.objects.get(pk=challenge.user_id)
        self.assertEqual(challenge.status, LoginStatus.PASSWORD_VERIFIED)
        self.assertEqual(challenge.failed_pin_attempts, 1)
        self.assertEqual(user.pin_failed_attempts, 1)

    def test_verify_pin_locks_account_after_fifth_failed_attempt(
        self: Self,
    ) -> None:
        """
        Verify the fifth invalid PIN locks the account for twenty-four hours.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when the PIN attempt limit does not lock the account.
        """
        challenge: LoginChallenge = self._create_login_challenge()

        for _ in range(4):
            with self.assertRaises(InvalidLoginPINError):
                LoginService.verify_pin(challenge.id, "654321")

        with self.assertRaises(LoginPINAttemptLimitError):
            LoginService.verify_pin(challenge.id, "654321")

        challenge.refresh_from_db()
        user: User = User.objects.get(pk=challenge.user_id)
        self.assertEqual(challenge.failed_pin_attempts, 5)
        self.assertEqual(challenge.status, LoginStatus.LOCKED)
        self.assertEqual(user.pin_failed_attempts, 5)
        self.assertIsNotNone(user.pin_locked_until)
        self.assertGreater(
            user.pin_locked_until,
            timezone.now() + timedelta(hours=23, minutes=59),
        )

    def test_verify_pin_rejects_an_expired_challenge(self: Self) -> None:
        """
        Verify an expired challenge cannot be used for PIN authentication.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an expired challenge is accepted.
        """
        challenge: LoginChallenge = self._create_login_challenge()
        challenge.expires_at = timezone.now() - timedelta(microseconds=1)
        challenge.save(update_fields=["expires_at", "updated_at"])

        with self.assertRaises(ExpiredLoginChallengeError):
            LoginService.verify_pin(challenge.id, "123456")

        challenge.refresh_from_db()
        self.assertEqual(challenge.status, LoginStatus.EXPIRED)
