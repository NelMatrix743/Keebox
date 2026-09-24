from datetime import datetime, timedelta
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
from apps.core.constants import OTP_MAX_ATTEMPTS, RESET_CHALLENGE_COMPLETION_TTL



class ResetOTPVerificationAPITests(TestCase):
    def setUp(self: Self) -> None:
        """
        Create an account and isolate OTP generation and email delivery.

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

    def _start_reset(self: Self, reset_type: ResetType) -> ResetChallenge:
        """
        Start a reset challenge for the chosen credential type.

        Args:
            self: Current test case instance.
            reset_type: Password or PIN recovery purpose.

        Returns:
            The pending reset challenge.

        Raises:
            ValueError: Raised when the reset request is invalid.
        """
        started: ResetStartResult = ResetService.start_reset(
            self.user.email,
            reset_type,
        )
        return ResetChallenge.objects.get(pk=started.reset_id)

    def _post_verification(self: Self, reset_id: str, otp_code: str) -> HttpResponse:
        """
        Submit one reset OTP verification request through the API.

        Args:
            self: Current test case instance.
            reset_id: Reset challenge identifier sent by the client.
            otp_code: Six-digit verification code sent by the client.

        Returns:
            HTTP response from the verification endpoint.

        Raises:
            None.
        """
        return self.client.post(
            f"/api/auth{Routes.Reset.VERIFY_OTP}",
            data={"reset_id": reset_id, "otp_code": otp_code},
            content_type="application/json",
        )

    def test_valid_code_verifies_password_and_pin_resets(self: Self) -> None:
        """
        Verify either reset type consumes its OTP and opens completion.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when OTP or response state is incorrect.
        """
        for reset_type in (ResetType.PASSWORD, ResetType.PIN):
            with self.subTest(reset_type=reset_type):
                challenge: ResetChallenge = self._start_reset(reset_type)

                response: HttpResponse = self._post_verification(
                    str(challenge.id),
                    "048291",
                )
                body: dict[str, Any] = response.json()
                challenge.refresh_from_db()
                otp: OTPVerification = OTPVerification.objects.get(
                    reset_challenge=challenge,
                )

                self.assertEqual(response.status_code, 200)
                self.assertTrue(body["success"])
                self.assertIsNone(body["error"])
                self.assertIsNone(body["meta"])
                self.assertEqual(body["data"]["reset_id"], str(challenge.id))
                self.assertEqual(body["data"]["status"], ResetStatus.OTP_VERIFIED)
                self.assertLess(
                    abs(
                        datetime.fromisoformat(
                            body["data"]["completion_expires_at"],
                        ) - challenge.completion_expires_at,
                    ),
                    timedelta(milliseconds=1),
                )
                self.assertEqual(challenge.status, ResetStatus.OTP_VERIFIED)
                self.assertEqual(
                    challenge.completion_expires_at,
                    challenge.verified_at + RESET_CHALLENGE_COMPLETION_TTL,
                )
                self.assertEqual(otp.status, OTPStatus.CONSUMED)
                self.assertNotIn("048291", str(body))

    def test_wrong_code_returns_an_error_and_records_an_attempt(self: Self) -> None:
        """
        Verify an incorrect OTP cannot advance a PIN reset.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when a wrong code changes reset state.
        """
        challenge: ResetChallenge = self._start_reset(ResetType.PIN)

        response: HttpResponse = self._post_verification(str(challenge.id), "999999")
        challenge.refresh_from_db()
        otp: OTPVerification = OTPVerification.objects.get(reset_challenge=challenge)

        self.assertEqual(response.status_code, 400)
        self.assertFalse(response.json()["success"])
        self.assertEqual(response.json()["error"]["code"], "invalid_otp")
        self.assertEqual(challenge.status, ResetStatus.OTP_PENDING)
        self.assertEqual(otp.attempt_count, 1)
