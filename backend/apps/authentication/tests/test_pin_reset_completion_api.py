from datetime import timedelta
from typing import Any, Self
from unittest.mock import Mock, patch
from uuid import uuid4

from django.http import HttpRequest, HttpResponse
from django.test import TestCase, override_settings
from django.utils import timezone
from ninja_jwt.exceptions import InvalidToken

from apps.authentication.auth import VersionedJWTAuth
from apps.authentication.models import ResetChallenge, User
from apps.authentication.routes import Routes
from apps.authentication.services.reset_services import ResetService, ResetStartResult
from apps.authentication.services.token_services import TokenService
from apps.core.choices import ResetStatus, ResetType
from apps.core.pin import encrypt_lock_pin, verify_lock_pin



@override_settings(KEEBOX_PIN_PEPPER="test-pin-pepper")
class PINResetCompletionAPITests(TestCase):
    def setUp(self: Self) -> None:
        """
        Create a locked account and isolate reset OTP delivery.

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

    def _verified_challenge(self: Self, reset_type: ResetType) -> ResetChallenge:
        """
        Prepare an OTP-verified reset for the selected credential type.

        Args:
            self: Current test case instance.
            reset_type: Password or PIN recovery purpose.

        Returns:
            The verified reset challenge.

        Raises:
            InvalidResetChallengeError: Raised if OTP verification fails.
        """
        started: ResetStartResult = ResetService.start_reset(
            self.user.email,
            reset_type,
        )
        return ResetService.verify_reset_otp(started.reset_id, "048291")

    def _post_completion(self: Self, reset_id: str, pin: str) -> HttpResponse:
        """
        Submit a lock-PIN reset completion request through the API.

        Args:
            self: Current test case instance.
            reset_id: Reset challenge identifier sent by the client.
            pin: New lock PIN sent by the client.

        Returns:
            HTTP response from the completion endpoint.

        Raises:
            None.
        """
        return self.client.post(
            f"/api/auth{Routes.Reset.PIN_COMPLETE}",
            data={"reset_id": reset_id, "new_pin": pin},
            content_type="application/json",
        )

    def test_verified_pin_reset_unlocks_account_and_revokes_old_tokens(
        self: Self,
    ) -> None:
        """
        Verify PIN completion replaces the secret without signing in the user.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when PIN or session state is incorrect.
        """
        old_access: str
        old_refresh: str
        old_access, old_refresh = TokenService.issue_tokens(self.user)
        challenge: ResetChallenge = self._verified_challenge(ResetType.PIN)

        response: HttpResponse = self._post_completion(str(challenge.id), "654321")
        body: dict[str, Any] = response.json()
        challenge.refresh_from_db()
        self.user.refresh_from_db()

        self.assertEqual(response.status_code, 200)
        self.assertTrue(body["success"])
        self.assertIsNone(body["error"])
        self.assertEqual(body["data"]["reset_id"], str(challenge.id))
        self.assertEqual(body["data"]["status"], ResetStatus.COMPLETED)
        self.assertIn("Sign in again", body["data"]["message"])
        self.assertNotIn("access_token", body["data"])
        self.assertNotIn("refresh_token", body["data"])
        self.assertEqual(challenge.status, ResetStatus.COMPLETED)
        self.assertIsNotNone(challenge.completed_at)
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

    def test_pending_or_password_reset_cannot_change_the_pin(self: Self) -> None:
        """
        Verify PIN completion requires an OTP-verified PIN reset.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an invalid challenge changes the PIN.
        """
        pending: ResetStartResult = ResetService.start_reset(
            self.user.email,
            ResetType.PIN,
        )
        wrong_type: ResetChallenge = self._verified_challenge(ResetType.PASSWORD)

        for reset_id in (pending.reset_id, wrong_type.id):
            response: HttpResponse = self._post_completion(str(reset_id), "654321")
            self.assertEqual(response.status_code, 409)
            self.assertEqual(
                response.json()["error"]["code"],
                "invalid_reset_challenge",
            )

        self.user.refresh_from_db()
        self.assertTrue(verify_lock_pin("123456", self.user.pin_hash))
        self.assertEqual(self.user.pin_version, 2)
        self.assertEqual(self.user.token_version, 0)

    def test_expired_completion_window_does_not_replace_the_pin(self: Self) -> None:
        """
        Verify a late PIN reset marks the challenge expired.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an expired reset changes the PIN.
        """
        challenge: ResetChallenge = self._verified_challenge(ResetType.PIN)
        challenge.completion_expires_at = timezone.now() - timedelta(seconds=1)
        challenge.save(update_fields=["completion_expires_at"])

        response: HttpResponse = self._post_completion(str(challenge.id), "654321")
        challenge.refresh_from_db()
        self.user.refresh_from_db()

        self.assertEqual(response.status_code, 410)
        self.assertEqual(
            response.json()["error"]["code"],
            "expired_reset_challenge",
        )
        self.assertEqual(challenge.status, ResetStatus.EXPIRED)
        self.assertTrue(verify_lock_pin("123456", self.user.pin_hash))
        self.assertEqual(self.user.pin_failed_attempts, 5)
        self.assertIsNotNone(self.user.pin_locked_until)

    def test_completed_or_unknown_reset_cannot_be_reused(self: Self) -> None:
        """
        Verify a reset identifier authorizes at most one PIN replacement.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an unusable reset changes the PIN.
        """
        missing: HttpResponse = self._post_completion(str(uuid4()), "654321")
        challenge: ResetChallenge = self._verified_challenge(ResetType.PIN)
        self._post_completion(str(challenge.id), "654321")
        replay: HttpResponse = self._post_completion(str(challenge.id), "987654")

        self.assertEqual(missing.status_code, 409)
        self.assertEqual(replay.status_code, 409)
        self.assertEqual(replay.json()["error"]["code"], "invalid_reset_challenge")
        self.user.refresh_from_db()
        self.assertTrue(verify_lock_pin("654321", self.user.pin_hash))
        self.assertEqual(self.user.pin_version, 3)
        self.assertEqual(self.user.token_version, 1)
