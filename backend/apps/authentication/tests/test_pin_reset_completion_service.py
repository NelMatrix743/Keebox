from datetime import timedelta
from typing import Any, Self
from unittest.mock import Mock, patch
from uuid import uuid4

from django.http import HttpRequest
from django.test import TestCase, override_settings
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
from apps.core.pin import encrypt_lock_pin, verify_lock_pin



@override_settings(KEEBOX_PIN_PEPPER="test-pin-pepper")
class PINResetCompletionServiceTests(TestCase):
    def setUp(self: Self) -> None:
        """
        Create a locked account and isolate email OTP delivery.

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
            pin_hash=encrypt_lock_pin("123456"),
            pin_version=2,
            pin_failed_attempts=5,
            pin_locked_until=timezone.now() + timedelta(hours=24),
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
        Prepare an OTP-verified reset challenge for one credential type.

        Args:
            self: Current test case instance.
            reset_type: Password or PIN reset type to prepare.

        Returns:
            The verified reset challenge ready for completion.

        Raises:
            InvalidResetChallengeError: Raised if the prepared reset fails.
        """
        started: ResetStartResult = ResetService.start_reset(
            email=self.user.email,
            reset_type=reset_type,
        )
        return ResetService.verify_reset_otp(started.reset_id, "048291")

    def test_verified_pin_reset_replaces_pin_unlocks_account_and_revokes_tokens(
        self: Self,
    ) -> None:
        """
        Verify OTP-only PIN recovery updates security state atomically.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when PIN replacement or revocation fails.
        """
        old_access: str
        old_refresh: str
        old_access, old_refresh = TokenService.issue_tokens(self.user)
        challenge: ResetChallenge = self._start_and_verify(ResetType.PIN)

        completed: ResetChallenge = ResetService.complete_pin_reset(
            reset_id=challenge.id,
            raw_pin="654321",
        )
        self.user.refresh_from_db()

        self.assertEqual(completed.status, ResetStatus.COMPLETED)
        self.assertIsNotNone(completed.completed_at)
        self.assertTrue(verify_lock_pin("654321", self.user.pin_hash))
        self.assertFalse(verify_lock_pin("123456", self.user.pin_hash))
        self.assertEqual(self.user.pin_version, 3)
        self.assertEqual(self.user.pin_failed_attempts, 0)
        self.assertIsNone(self.user.pin_locked_until)
        self.assertEqual(self.user.token_version, 1)
        self.assertTrue(self.user.check_password("original strong password 5821"))
        with self.assertRaises(InvalidToken):
            VersionedJWTAuth().authenticate(HttpRequest(), old_access)
        with self.assertRaises(InvalidToken):
            TokenService.refresh_access_token(old_refresh)
