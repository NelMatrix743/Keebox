from datetime import timedelta
from typing import Self

from django.test import TestCase
from django.utils import timezone

from apps.authentication.models import LoginChallenge, User
from apps.core.choices import LoginStatus
from apps.core.constants import AUTH_LOGIN_CHALLENGE_TTL, AUTH_PIN_MAX_ATTEMPTS



class LoginChallengeModelTests(TestCase):
    def _create_user(self: Self) -> User:
        """
        Create a permanent user for login challenge tests.

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

    def test_login_challenge_defines_database_metadata(self: Self) -> None:
        """
        Verify login challenge storage metadata and attempt constraints.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when login challenge metadata is incorrect.
        """
        self.assertEqual(LoginChallenge._meta.db_table, "auth_login_challenge")
        self.assertEqual(LoginChallenge._meta.ordering, ["-created_at"])
        self.assertEqual(
            {
                index.name
                for index in LoginChallenge._meta.indexes
            },
            {
                "login_challenge_user_idx",
                "login_challenge_expiry_idx",
            },
        )
        self.assertEqual(
            {
                constraint.name
                for constraint in LoginChallenge._meta.constraints
            },
            {"login_challenge_attempts_within_limit"},
        )

    def test_login_challenge_persists_password_verified_defaults(
        self: Self,
    ) -> None:
        """
        Verify a new login challenge starts after password verification.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when login challenge defaults are incorrect.
        """
        user: User = self._create_user()

        challenge: LoginChallenge = LoginChallenge.objects.create(user=user)

        self.assertEqual(challenge.user, user)
        self.assertEqual(challenge.status, LoginStatus.PASSWORD_VERIFIED)
        self.assertEqual(challenge.failed_pin_attempts, 0)
        self.assertIsNone(challenge.completed_at)
        self.assertAlmostEqual(
            challenge.expires_at.timestamp(),
            (timezone.now() + AUTH_LOGIN_CHALLENGE_TTL).timestamp(),
            delta=2,
        )

    def test_login_challenge_tracks_attempts_and_completion(self: Self) -> None:
        """
        Verify failed PIN attempts and completed state persist correctly.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when challenge state is not persisted.
        """
        user: User = self._create_user()
        challenge: LoginChallenge = LoginChallenge.objects.create(
            user=user,
            failed_pin_attempts=AUTH_PIN_MAX_ATTEMPTS,
            status=LoginStatus.COMPLETED,
            completed_at=timezone.now(),
        )

        challenge.refresh_from_db()

        self.assertEqual(challenge.failed_pin_attempts, AUTH_PIN_MAX_ATTEMPTS)
        self.assertEqual(challenge.status, LoginStatus.COMPLETED)
        self.assertIsNotNone(challenge.completed_at)
