from datetime import timedelta
from typing import Any, Self
from unittest.mock import Mock, patch
from uuid import uuid4

from django.http import HttpRequest
from django.test import TestCase
from django.utils import timezone
from ninja_jwt.exceptions import InvalidToken

from apps.authentication.auth import VersionedJWTAuth
from apps.authentication.exceptions import (
    ExpiredResetChallengeError,
    InvalidResetChallengeError,
)
from apps.authentication.models import ResetChallenge, User
from apps.authentication.services.reset_services import ResetService, ResetStartResult
from apps.authentication.services.token_services import TokenService
from apps.core.choices import ResetStatus, ResetType



class PasswordResetCompletionServiceTests(TestCase):
    def setUp(self: Self) -> None:
        """
        Create a user and isolate OTP generation and external email delivery.

        Args:
            self: Current test case instance.

        Returns:
            None: This setup method does not return a value.

        Raises:
            None.
        """
        self.user: User = User.objects.create_user(
            email="ada@example.com",
            password="original strong password 5821",
            first_name="Ada",
            last_name="Lovelace",
        )
        email_patcher: Any = patch(
            "apps.authentication.services.reset_services.EmailDeliveryService",
        )
        code_patcher: Any = patch(
            "apps.authentication.services.reset_services.generate_otp_code",
            return_value="048291",
        )
        self.email_delivery_service: Mock = email_patcher.start()
        self.generate_otp: Mock = code_patcher.start()
        self.addCleanup(email_patcher.stop)
        self.addCleanup(code_patcher.stop)

    def _start_and_verify(self: Self, reset_type: ResetType) -> ResetChallenge:
        """
        Start a reset and verify its emailed OTP for a selected credential.

        Args:
            self: Current test case instance.
            reset_type: Password or PIN reset type to prepare.

        Returns:
            The persisted OTP-verified reset challenge.

        Raises:
            InvalidResetChallengeError: Raised if the prepared challenge fails.
        """
        started: ResetStartResult = ResetService.start_reset(
            email=self.user.email,
            reset_type=reset_type,
        )
        return ResetService.verify_reset_otp(started.reset_id, "048291")

    def test_verified_password_reset_changes_password_and_revokes_old_tokens(
        self: Self,
    ) -> None:
        """
        Verify completion replaces the password and ends existing sessions.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when completion or revocation is incomplete.
        """
        old_access: str
        old_refresh: str
        old_access, old_refresh = TokenService.issue_tokens(self.user)
        challenge: ResetChallenge = self._start_and_verify(ResetType.PASSWORD)
        self.assertEqual(
            VersionedJWTAuth().authenticate(HttpRequest(), old_access),
            self.user,
        )

        completed: ResetChallenge = ResetService.complete_password_reset(
            reset_id=challenge.id,
            raw_password="replacement strong password 7349",
        )
        self.user.refresh_from_db()

        self.assertEqual(completed.status, ResetStatus.COMPLETED)
        self.assertIsNotNone(completed.completed_at)
        self.assertTrue(self.user.check_password("replacement strong password 7349"))
        self.assertFalse(self.user.check_password("original strong password 5821"))
        self.assertEqual(self.user.token_version, 1)
        with self.assertRaises(InvalidToken):
            VersionedJWTAuth().authenticate(HttpRequest(), old_access)
        with self.assertRaises(InvalidToken):
            TokenService.refresh_access_token(old_refresh)

    def test_pending_or_wrong_type_challenge_cannot_change_the_password(
        self: Self,
    ) -> None:
        """
        Verify password completion requires OTP verification of password reset.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when invalid reset state changes credentials.
        """
        pending: ResetStartResult = ResetService.start_reset(
            email=self.user.email,
            reset_type=ResetType.PASSWORD,
        )
        with self.assertRaises(InvalidResetChallengeError):
            ResetService.complete_password_reset(
                pending.reset_id,
                "replacement strong password 7349",
            )

        pin_challenge: ResetChallenge = self._start_and_verify(ResetType.PIN)
        with self.assertRaises(InvalidResetChallengeError):
            ResetService.complete_password_reset(
                pin_challenge.id,
                "replacement strong password 7349",
            )

        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password("original strong password 5821"))
        self.assertEqual(self.user.token_version, 0)

    def test_expired_completion_window_marks_the_challenge_expired(
        self: Self,
    ) -> None:
        """
        Verify the post-OTP deadline prevents a late password change.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an expired challenge remains usable.
        """
        challenge: ResetChallenge = self._start_and_verify(ResetType.PASSWORD)
        challenge.completion_expires_at = timezone.now() - timedelta(seconds=1)
        challenge.save(update_fields=["completion_expires_at"])

        with self.assertRaises(ExpiredResetChallengeError):
            ResetService.complete_password_reset(
                challenge.id,
                "replacement strong password 7349",
            )

        challenge.refresh_from_db()
        self.user.refresh_from_db()
        self.assertEqual(challenge.status, ResetStatus.EXPIRED)
        self.assertIsNone(challenge.completed_at)
        self.assertTrue(self.user.check_password("original strong password 5821"))
        self.assertEqual(self.user.token_version, 0)
