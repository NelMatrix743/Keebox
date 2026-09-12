from typing import Any, Self
from unittest.mock import Mock, patch

from django.http import HttpResponse
from django.test import TestCase

from apps.authentication.models import OTPVerification, RegistrationChallenge, User
from apps.core.exceptions import EmailDeliveryError



class RegistrationAPITests(TestCase):
    def _registration_payload(self: Self) -> dict[str, str]:
        """
        Build valid input for the registration endpoint.

        Args:
            self: Current test case instance.

        Returns:
            Valid registration request data.

        Raises:
            None.
        """
        return {
            "first_name": "Nelson",
            "last_name": "Ubochiegbu",
            "email": "nelson@example.com",
            "password": "correct horse battery staple",
        }

    @patch("apps.authentication.api.EmailDeliveryService")
    @patch(
        "apps.authentication.registration_services.generate_otp_code",
        return_value="482913",
    )
    def test_register_starts_registration_and_delivers_the_otp(
        self: Self,
        generate_otp: Mock,
        email_delivery_service: Mock,
    ) -> None:
        """
        Verify registration creates its challenge and emails the generated OTP.

        Args:
            self: Current test case instance.
            generate_otp: Mocked secure OTP generator.
            email_delivery_service: Mocked lowest-level email delivery service.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when registration initiation is incomplete.
        """
        email_delivery_service.return_value.send_otp_email.return_value = (
            "brevo-message-id"
        )

        response: HttpResponse = self.client.post(
            "/api/auth/register",
            data=self._registration_payload(),
            content_type="application/json",
        )
        response_body: dict[str, Any] = response.json()

        self.assertEqual(response.status_code, 201)
        self.assertTrue(response_body["success"])
        self.assertEqual(response_body["data"]["status"], "otp_pending")
        self.assertIsNone(response_body["error"])
        self.assertIsNone(response_body["meta"])
        self.assertEqual(RegistrationChallenge.objects.count(), 1)
        self.assertEqual(OTPVerification.objects.count(), 1)
        self.assertNotIn("password", response_body["data"])
        self.assertNotIn("482913", str(response_body))
        generate_otp.assert_called_once_with()
        email_delivery_service.return_value.send_otp_email.assert_called_once_with(
            recipient_email="nelson@example.com",
            recipient_full_name="Nelson Ubochiegbu",
            otp_code="482913",
            expiration_minutes=5,
        )

    @patch("apps.authentication.api.EmailDeliveryService")
    def test_register_rejects_an_existing_user_email(
        self: Self,
        email_delivery_service: Mock,
    ) -> None:
        """
        Verify registration returns a conflict for an existing account email.

        Args:
            self: Current test case instance.
            email_delivery_service: Mocked lowest-level email delivery service.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when a conflicting registration is accepted.
        """
        User.objects.create_user(
            email="nelson@example.com",
            password="correct horse battery staple",
            first_name="Nelson",
            last_name="Ubochiegbu",
        )

        response: HttpResponse = self.client.post(
            "/api/auth/register",
            data=self._registration_payload(),
            content_type="application/json",
        )
        response_body: dict[str, Any] = response.json()

        self.assertEqual(response.status_code, 409)
        self.assertFalse(response_body["success"])
        self.assertIsNone(response_body["data"])
        self.assertEqual(
            response_body["error"]["code"],
            "registration_email_conflict",
        )
        self.assertFalse(RegistrationChallenge.objects.exists())
        self.assertFalse(OTPVerification.objects.exists())
        email_delivery_service.assert_not_called()

    @patch("apps.authentication.api.EmailDeliveryService")
    def test_register_returns_a_safe_error_when_email_delivery_fails(
        self: Self,
        email_delivery_service: Mock,
    ) -> None:
        """
        Verify a delivery failure returns a safe service-unavailable response.

        Args:
            self: Current test case instance.
            email_delivery_service: Mocked failing email delivery service.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when delivery failures leak or appear successful.
        """
        email_delivery_service.return_value.send_otp_email.side_effect = (
            EmailDeliveryError("sensitive provider details")
        )

        response: HttpResponse = self.client.post(
            "/api/auth/register",
            data=self._registration_payload(),
            content_type="application/json",
        )
        response_body: dict[str, Any] = response.json()

        self.assertEqual(response.status_code, 503)
        self.assertFalse(response_body["success"])
        self.assertEqual(response_body["error"]["code"], "email_delivery_failed")
        self.assertNotIn("sensitive provider details", str(response_body))
        self.assertEqual(RegistrationChallenge.objects.count(), 1)
        self.assertEqual(OTPVerification.objects.count(), 1)

    def test_register_wraps_request_validation_errors(self: Self) -> None:
        """
        Verify invalid registration input uses the standard API error envelope.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when validation errors use another response shape.
        """
        invalid_payload: dict[str, str] = self._registration_payload()
        invalid_payload["email"] = "not-an-email"

        response: HttpResponse = self.client.post(
            "/api/auth/register",
            data=invalid_payload,
            content_type="application/json",
        )
        response_body: dict[str, Any] = response.json()

        self.assertEqual(response.status_code, 422)
        self.assertFalse(response_body["success"])
        self.assertIsNone(response_body["data"])
        self.assertEqual(response_body["error"]["code"], "validation_error")
        self.assertIsInstance(response_body["error"]["details"], list)
