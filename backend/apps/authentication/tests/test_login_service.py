from datetime import timedelta
from typing import Self

from django.test import TestCase
from django.utils import timezone

from apps.authentication.exceptions import (
    InvalidLoginCredentialsError,
    LoginAccountLockedError,
)
from apps.authentication.models import LoginChallenge, OTPVerification, User
from apps.authentication.login_services import LoginService
from apps.core.choices import LoginStatus



class LoginServiceTests(TestCase):
    def _create_user(self: Self) -> User:
        """
        Create a permanent user for login service tests.

        Args:
            self: Current test case instance.

        Returns:
            The persisted test user.

        Raises:
            ValueError: Raised when the test credentials are invalid.
        """
        return User.objects.create_user(
            email="nelson@example.com",
            password="correct horse battery staple",
            first_name="Nelson",
            last_name="Ubochiegbu",
        )

    def test_start_login_creates_a_password_verified_challenge(
        self: Self,
    ) -> None:
        """
        Verify valid credentials create a login challenge without JWTs or OTPs.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when login initiation is incomplete.
        """
        user: User = self._create_user()

        challenge: LoginChallenge = LoginService.start_login(
            email=" Nelson@EXAMPLE.com ",
            password="correct horse battery staple",
        )

        self.assertEqual(challenge.user, user)
        self.assertEqual(challenge.status, LoginStatus.PASSWORD_VERIFIED)
        self.assertEqual(challenge.failed_pin_attempts, 0)
        self.assertIsNone(challenge.completed_at)
        self.assertEqual(LoginChallenge.objects.count(), 1)
        self.assertFalse(OTPVerification.objects.exists())

    def test_start_login_rejects_an_incorrect_password(self: Self) -> None:
        """
        Verify an incorrect password cannot create a login challenge.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when invalid credentials are accepted.
        """
        self._create_user()

        with self.assertRaises(InvalidLoginCredentialsError):
            LoginService.start_login(
                email="nelson@example.com",
                password="incorrect password",
            )

        self.assertFalse(LoginChallenge.objects.exists())

    def test_start_login_rejects_an_unknown_email(self: Self) -> None:
        """
        Verify an unknown email returns the same invalid-credentials failure.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an unknown account creates a challenge.
        """
        with self.assertRaises(InvalidLoginCredentialsError):
            LoginService.start_login(
                email="unknown@example.com",
                password="correct horse battery staple",
            )

        self.assertFalse(LoginChallenge.objects.exists())

    def test_start_login_rejects_an_account_with_an_active_pin_lock(
        self: Self,
    ) -> None:
        """
        Verify an active PIN lock prevents a new login challenge.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when a locked account can start login.
        """
        user: User = self._create_user()
        user.pin_failed_attempts = 5
        user.pin_locked_until = timezone.now() + timedelta(hours=24)
        user.save(update_fields=["pin_failed_attempts", "pin_locked_until"])

        with self.assertRaises(LoginAccountLockedError):
            LoginService.start_login(
                email="nelson@example.com",
                password="correct horse battery staple",
            )

        self.assertFalse(LoginChallenge.objects.exists())
