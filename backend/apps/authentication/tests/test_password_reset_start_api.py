from typing import Any, Self
from unittest.mock import Mock, patch

from django.http import HttpResponse
from django.test import TestCase

from apps.authentication.models import OTPVerification, ResetChallenge, User
from apps.authentication.routes import Routes
from apps.core.choices import ResetStatus, ResetType



class PasswordResetStartAPITests(TestCase):
    @patch("apps.authentication.services.reset_services.EmailDeliveryService")
    def test_known_email_starts_password_reset_and_sends_otp(
        self: Self,
        email_delivery_service: Mock,
    ) -> None:
        """
        Verify a known account receives an OTP-backed password reset.

        Args:
            self: Current test case instance.
            email_delivery_service: Mocked external email delivery service.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when reset creation or response is incorrect.
        """
        user: User = User.objects.create_user(
            email="ada@example.com",
            password="original strong password 5821",
            first_name="Ada",
            last_name="Lovelace",
        )

        response: HttpResponse = self.client.post(
            f"/api/auth{Routes.Reset.PASSWORD}",
            data={"email": " ADA@example.com "},
            content_type="application/json",
        )
        body: dict[str, Any] = response.json()

        self.assertEqual(response.status_code, 200)
        self.assertTrue(body["success"])
        self.assertIsNone(body["error"])
        self.assertIsNone(body["meta"])
        self.assertEqual(body["data"]["status"], ResetStatus.OTP_PENDING)
        self.assertIn("otp_expires_at", body["data"])
        self.assertIn("resend_available_at", body["data"])
        challenge: ResetChallenge = ResetChallenge.objects.get(
            pk=body["data"]["reset_id"],
        )
        self.assertEqual(challenge.user, user)
        self.assertEqual(challenge.reset_type, ResetType.PASSWORD)
        self.assertEqual(challenge.status, ResetStatus.OTP_PENDING)
        self.assertEqual(OTPVerification.objects.filter(reset_challenge=challenge).count(), 1)
        email_delivery_service.return_value.send_otp_email.assert_called_once()

    @patch("apps.authentication.services.reset_services.EmailDeliveryService")
    def test_unknown_email_receives_generic_success_without_reset(
        self: Self,
        email_delivery_service: Mock,
    ) -> None:
        """
        Verify an unknown email does not reveal whether an account exists.

        Args:
            self: Current test case instance.
            email_delivery_service: Mocked external email delivery service.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when the public response or state leaks.
        """
        response: HttpResponse = self.client.post(
            f"/api/auth{Routes.Reset.PASSWORD}",
            data={"email": "unknown@example.com"},
            content_type="application/json",
        )
        body: dict[str, Any] = response.json()

        self.assertEqual(response.status_code, 200)
        self.assertTrue(body["success"])
        self.assertEqual(body["data"]["status"], ResetStatus.OTP_PENDING)
        self.assertIn("reset_id", body["data"])
        self.assertIn("otp_expires_at", body["data"])
        self.assertIn("resend_available_at", body["data"])
        self.assertFalse(ResetChallenge.objects.exists())
        self.assertFalse(OTPVerification.objects.exists())
        email_delivery_service.assert_not_called()
