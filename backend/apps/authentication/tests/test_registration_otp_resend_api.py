from typing import Any, Self, cast
from unittest.mock import Mock, patch
from uuid import uuid4

from django.test import TestCase
from django.utils import timezone

from apps.authentication.models import OTPVerification, RegistrationChallenge, User
from apps.core.choices import OTPStatus, RegistrationStatus
from apps.core.constants import OTP_MAX_RESENDS, OTP_RESEND_COOLDOWN
from apps.core.exceptions import EmailDeliveryError



class RegistrationOTPResendAPITests(TestCase):
    def _create_registration_with_otp(
        self: Self,
    ) -> tuple[RegistrationChallenge, OTPVerification]:
        """
        Create a pending registration with an OTP eligible for replacement.

        Args:
            self: Current test case instance.

        Returns:
            The persisted registration challenge and its active OTP.

        Raises:
            ValueError: Raised when the test password or OTP is invalid.
        """
        registration_challenge: RegistrationChallenge = RegistrationChallenge(
            first_name="Nelson",
            last_name="Ubochiegbu",
            email="nelson@example.com",
        )
        registration_challenge.set_password("correct horse battery staple")
        registration_challenge.save()
        otp_verification: OTPVerification = OTPVerification(
            registration_challenge=registration_challenge,
            email=registration_challenge.email,
            last_sent_at=timezone.now() - OTP_RESEND_COOLDOWN,
        )
        otp_verification.hash_and_set_otp_code("111111")
        otp_verification.save()
        return registration_challenge, otp_verification

    @patch("apps.authentication.api.EmailDeliveryService")
    @patch(
        "apps.authentication.services.registration_services.generate_otp_code",
        return_value="482913",
    )
    def test_resend_otp_replaces_and_delivers_the_current_code(
        self: Self,
        generate_otp: Mock,
        email_delivery_service: Mock,
    ) -> None:
        """
        Verify a successful resend replaces and emails the current OTP.

        Args:
            self: Current test case instance.
            generate_otp: Mocked secure OTP generator.
            email_delivery_service: Mocked lowest-level email delivery service.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when successful resend behavior is incomplete.
        """
        registration_challenge, previous_otp = (
            self._create_registration_with_otp()
        )
        email_delivery_service.return_value.send_otp_email.return_value = (
            "brevo-message-id"
        )

        response: Any = self.client.post(
            "/api/auth/register/resend-otp",
            data={"registration_id": str(registration_challenge.id)},
            content_type="application/json",
        )
        response_body: dict[str, Any] = response.json()

        registration_challenge.refresh_from_db()
        previous_otp.refresh_from_db()
        replacement_otp: OTPVerification = cast(
            OTPVerification,
            registration_challenge.otp_verifications.order_by(
                "-created_at",
            ).first(),
        )
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response_body["success"])
        self.assertEqual(
            response_body["data"]["registration_id"],
            str(registration_challenge.id),
        )
        self.assertEqual(response_body["data"]["status"], "otp_pending")
        self.assertEqual(
            response_body["data"]["resends_remaining"],
            OTP_MAX_RESENDS - 1,
        )
        self.assertIsNone(response_body["error"])
        self.assertIsNone(response_body["meta"])
        self.assertNotIn("482913", str(response_body))
        self.assertEqual(
            registration_challenge.status,
            RegistrationStatus.OTP_PENDING,
        )
        self.assertEqual(registration_challenge.resend_count, 1)
        self.assertEqual(previous_otp.status, OTPStatus.EXPIRED)
        self.assertEqual(replacement_otp.status, OTPStatus.PENDING)
        self.assertTrue(replacement_otp.verify_otp_code("482913"))
        self.assertEqual(registration_challenge.otp_verifications.count(), 2)
        self.assertFalse(User.objects.exists())
        generate_otp.assert_called_once_with()
        email_delivery_service.return_value.send_otp_email.assert_called_once_with(
            recipient_email="nelson@example.com",
            recipient_full_name="Nelson Ubochiegbu",
            otp_code="482913",
            expiration_minutes=5,
        )

    @patch("apps.authentication.api.EmailDeliveryService")
    def test_resend_otp_rejects_requests_during_cooldown(
        self: Self,
        email_delivery_service: Mock,
    ) -> None:
        """
        Verify an early resend returns a retry error without changing state.

        Args:
            self: Current test case instance.
            email_delivery_service: Mocked lowest-level email delivery service.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when the resend cooldown is not enforced.
        """
        registration_challenge, current_otp = self._create_registration_with_otp()
        current_otp.last_sent_at = timezone.now()
        current_otp.save(update_fields=["last_sent_at", "updated_at"])

        response: Any = self.client.post(
            "/api/auth/register/resend-otp",
            data={"registration_id": str(registration_challenge.id)},
            content_type="application/json",
        )
        response_body: dict[str, Any] = response.json()

        registration_challenge.refresh_from_db()
        current_otp.refresh_from_db()
        self.assertEqual(response.status_code, 429)
        self.assertFalse(response_body["success"])
        self.assertIsNone(response_body["data"])
        self.assertEqual(
            response_body["error"]["code"],
            "otp_resend_cooldown",
        )
        self.assertEqual(registration_challenge.resend_count, 0)
        self.assertEqual(current_otp.status, OTPStatus.PENDING)
        self.assertEqual(registration_challenge.otp_verifications.count(), 1)
        email_delivery_service.assert_not_called()

    @patch("apps.authentication.api.EmailDeliveryService")
    def test_resend_otp_cancels_registration_at_the_resend_limit(
        self: Self,
        email_delivery_service: Mock,
    ) -> None:
        """
        Verify an exhausted resend allowance cancels the registration.

        Args:
            self: Current test case instance.
            email_delivery_service: Mocked lowest-level email delivery service.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when resend-limit cancellation is incomplete.
        """
        registration_challenge, current_otp = self._create_registration_with_otp()
        registration_challenge.resend_count = OTP_MAX_RESENDS
        registration_challenge.save(update_fields=["resend_count", "updated_at"])

        response: Any = self.client.post(
            "/api/auth/register/resend-otp",
            data={"registration_id": str(registration_challenge.id)},
            content_type="application/json",
        )
        response_body: dict[str, Any] = response.json()

        registration_challenge.refresh_from_db()
        current_otp.refresh_from_db()
        self.assertEqual(response.status_code, 429)
        self.assertEqual(
            response_body["error"]["code"],
            "otp_resend_limit_reached",
        )
        self.assertEqual(
            registration_challenge.status,
            RegistrationStatus.CANCELLED,
        )
        self.assertEqual(current_otp.status, OTPStatus.EXPIRED)
        self.assertEqual(registration_challenge.otp_verifications.count(), 1)
        email_delivery_service.assert_not_called()

    def test_resend_otp_rejects_an_unknown_registration(self: Self) -> None:
        """
        Verify an unknown registration identifier returns a conflict response.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when an unknown registration is accepted.
        """
        response: Any = self.client.post(
            "/api/auth/register/resend-otp",
            data={"registration_id": str(uuid4())},
            content_type="application/json",
        )
        response_body: dict[str, Any] = response.json()

        self.assertEqual(response.status_code, 409)
        self.assertEqual(
            response_body["error"]["code"],
            "invalid_registration_state",
        )

    @patch("apps.authentication.api.EmailDeliveryService")
    def test_resend_otp_returns_a_safe_error_when_delivery_fails(
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
            AssertionError: Raised when delivery failure details are exposed.
        """
        registration_challenge, _ = self._create_registration_with_otp()
        email_delivery_service.return_value.send_otp_email.side_effect = (
            EmailDeliveryError("sensitive provider details")
        )

        response: Any = self.client.post(
            "/api/auth/register/resend-otp",
            data={"registration_id": str(registration_challenge.id)},
            content_type="application/json",
        )
        response_body: dict[str, Any] = response.json()

        registration_challenge.refresh_from_db()
        self.assertEqual(response.status_code, 503)
        self.assertFalse(response_body["success"])
        self.assertEqual(response_body["error"]["code"], "email_delivery_failed")
        self.assertNotIn("sensitive provider details", str(response_body))
        self.assertEqual(registration_challenge.resend_count, 1)
        self.assertEqual(registration_challenge.otp_verifications.count(), 2)

    def test_resend_otp_wraps_request_validation_errors(self: Self) -> None:
        """
        Verify malformed resend input uses the standard API error envelope.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when validation uses another response shape.
        """
        response: Any = self.client.post(
            "/api/auth/register/resend-otp",
            data={"registration_id": "not-a-uuid"},
            content_type="application/json",
        )
        response_body: dict[str, Any] = response.json()

        self.assertEqual(response.status_code, 422)
        self.assertFalse(response_body["success"])
        self.assertIsNone(response_body["data"])
        self.assertEqual(response_body["error"]["code"], "validation_error")
