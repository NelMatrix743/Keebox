from datetime import timedelta
from typing import Any, Self
from unittest.mock import Mock, patch
from uuid import uuid4

from django.http import HttpResponse
from django.test import TestCase
from django.utils import timezone

from apps.authentication.models import OTPVerification, ResetChallenge, User
from apps.authentication.routes import Routes
from apps.authentication.services.reset_services import ResetService, ResetStartResult
from apps.core.choices import OTPStatus, ResetStatus, ResetType
from apps.core.constants import OTP_MAX_RESENDS, OTP_RESEND_COOLDOWN



class ResetOTPResendAPITests(TestCase):
    def setUp(self: Self) -> None:
        """
        Create an account and isolate reset OTP email delivery.

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
        self.email_delivery_service: Mock = email_patcher.start()
        self.addCleanup(email_patcher.stop)

    def _start_reset(self: Self, reset_type: ResetType) -> tuple[ResetChallenge, OTPVerification]:
        """
        Start a password or PIN reset with one pending OTP.

        Args:
            self: Current test case instance.
            reset_type: Credential being recovered.

        Returns:
            The pending reset challenge and its current OTP.

        Raises:
            ValueError: Raised if the reset cannot be initialized.
        """
        started: ResetStartResult = ResetService.start_reset(
            self.user.email,
            reset_type,
        )
        challenge: ResetChallenge = ResetChallenge.objects.get(pk=started.reset_id)
        otp: OTPVerification = OTPVerification.objects.get(reset_challenge=challenge)
        return challenge, otp

    def _post_resend(self: Self, reset_id: str) -> HttpResponse:
        """
        Submit a reset OTP resend request through the public API.

        Args:
            self: Current test case instance.
            reset_id: Reset identifier sent by the client.

        Returns:
            HTTP response from the reset resend endpoint.

        Raises:
            None.
        """
        return self.client.post(
            f"/api/auth{Routes.Reset.RESEND_OTP}",
            data={"reset_id": reset_id},
            content_type="application/json",
        )

    def test_password_and_pin_resends_keep_the_challenge_and_replace_otp(
        self: Self,
    ) -> None:
        """
        Verify both reset types issue a fresh OTP without changing reset ID.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when resend state or response is incorrect.
        """
        for reset_type in (ResetType.PASSWORD, ResetType.PIN):
            with self.subTest(reset_type=reset_type):
                challenge, previous_otp = self._start_reset(reset_type)
                previous_otp.last_sent_at = (
                    timezone.now() - OTP_RESEND_COOLDOWN - timedelta(seconds=1)
                )
                previous_otp.save(update_fields=["last_sent_at"])

                response: HttpResponse = self._post_resend(str(challenge.id))
                body: dict[str, Any] = response.json()
                challenge.refresh_from_db()
                previous_otp.refresh_from_db()
                replacement: OTPVerification = OTPVerification.objects.get(
                    reset_challenge=challenge,
                    status=OTPStatus.PENDING,
                )

                self.assertEqual(response.status_code, 200)
                self.assertTrue(body["success"])
                self.assertIsNone(body["error"])
                self.assertEqual(body["data"]["reset_id"], str(challenge.id))
                self.assertEqual(body["data"]["status"], ResetStatus.OTP_PENDING)
                self.assertIn("otp_expires_at", body["data"])
                self.assertIn("resend_available_at", body["data"])
                self.assertEqual(challenge.resend_count, 1)
                self.assertEqual(previous_otp.status, OTPStatus.EXPIRED)
                self.assertNotEqual(replacement.pk, previous_otp.pk)
                self.assertEqual(
                    self.email_delivery_service.return_value.send_otp_email.call_count,
                    ResetChallenge.objects.count() * 2,
                )

    def test_resend_during_cooldown_returns_error_without_replacing_otp(
        self: Self,
    ) -> None:
        """
        Verify the cooldown rejects an early replacement request.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when cooldown enforcement fails.
        """
        challenge, otp = self._start_reset(ResetType.PASSWORD)

        response: HttpResponse = self._post_resend(str(challenge.id))
        body: dict[str, Any] = response.json()
        challenge.refresh_from_db()
        otp.refresh_from_db()

        self.assertEqual(response.status_code, 429)
        self.assertFalse(body["success"])
        self.assertIsNone(body["data"])
        self.assertEqual(body["error"]["code"], "otp_resend_cooldown")
        self.assertEqual(challenge.resend_count, 0)
        self.assertEqual(otp.status, OTPStatus.PENDING)
        self.assertEqual(OTPVerification.objects.count(), 1)

    def test_expired_otp_cancels_the_reset(self: Self) -> None:
        """
        Verify an expired code cannot be replaced through the API.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an expired reset stays usable.
        """
        challenge, otp = self._start_reset(ResetType.PIN)
        otp.expires_at = timezone.now() - timedelta(seconds=1)
        otp.save(update_fields=["expires_at"])

        response: HttpResponse = self._post_resend(str(challenge.id))
        challenge.refresh_from_db()
        otp.refresh_from_db()

        self.assertEqual(response.status_code, 410)
        self.assertEqual(response.json()["error"]["code"], "expired_otp")
        self.assertEqual(challenge.status, ResetStatus.CANCELLED)
        self.assertEqual(otp.status, OTPStatus.EXPIRED)

    def test_resend_limit_cancels_the_reset(self: Self) -> None:
        """
        Verify the final permitted resend cannot be exceeded.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when a limited challenge remains usable.
        """
        challenge, otp = self._start_reset(ResetType.PASSWORD)
        challenge.resend_count = OTP_MAX_RESENDS
        challenge.save(update_fields=["resend_count"])
        otp.last_sent_at = timezone.now() - OTP_RESEND_COOLDOWN - timedelta(seconds=1)
        otp.save(update_fields=["last_sent_at"])

        response: HttpResponse = self._post_resend(str(challenge.id))
        challenge.refresh_from_db()
        otp.refresh_from_db()

        self.assertEqual(response.status_code, 429)
        self.assertEqual(response.json()["error"]["code"], "otp_resend_limit_reached")
        self.assertEqual(challenge.status, ResetStatus.CANCELLED)
        self.assertEqual(otp.status, OTPStatus.EXPIRED)

    def test_unknown_reset_id_returns_an_error(self: Self) -> None:
        """
        Verify a missing challenge cannot trigger OTP delivery.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an unknown reset is accepted.
        """
        response: HttpResponse = self._post_resend(str(uuid4()))

        self.assertEqual(response.status_code, 409)
        self.assertEqual(response.json()["error"]["code"], "invalid_reset_challenge")
        self.email_delivery_service.assert_not_called()

    def test_malformed_reset_id_is_rejected(self: Self) -> None:
        """
        Verify invalid reset identifiers fail request validation.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when malformed input is accepted.
        """
        response: HttpResponse = self._post_resend("not-a-uuid")

        self.assertEqual(response.status_code, 422)
        self.assertFalse(ResetChallenge.objects.exists())
