from datetime import timedelta
from typing import Any, Self
from uuid import uuid4

from django.test import TestCase
from django.utils import timezone

from apps.authentication.models import OTPVerification, RegistrationChallenge, User
from apps.core.choices import OTPStatus, RegistrationStatus



class RegistrationVerificationAPITests(TestCase):
    def _create_registration_with_otp(
        self: Self,
    ) -> tuple[RegistrationChallenge, OTPVerification]:
        """
        Create a pending registration with an active OTP.

        Args:
            self: Current test case instance.

        Returns:
            The persisted registration challenge and OTP verification.

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
        )
        otp_verification.hash_and_set_otp_code("482913")
        otp_verification.save()
        return registration_challenge, otp_verification

    def _verification_payload(
        self: Self,
        registration_challenge: RegistrationChallenge,
    ) -> dict[str, str]:
        """
        Build valid input for the registration OTP verification endpoint.

        Args:
            self: Current test case instance.
            registration_challenge: Registration challenge being verified.

        Returns:
            Valid registration OTP verification request data.

        Raises:
            None.
        """
        return {
            "registration_id": str(registration_challenge.id),
            "otp_code": "482913",
        }

    def test_verify_otp_advances_registration_without_creating_user(
        self: Self,
    ) -> None:
        """
        Verify a valid OTP advances registration to the PIN setup stage.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when successful verification is incomplete.
        """
        registration_challenge, otp_verification = (
            self._create_registration_with_otp()
        )

        response: Any = self.client.post(
            "/api/auth/register/verify-otp",
            data=self._verification_payload(registration_challenge),
            content_type="application/json",
        )
        response_body: dict[str, Any] = response.json()

        registration_challenge.refresh_from_db()
        otp_verification.refresh_from_db()
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response_body["success"])
        self.assertEqual(
            response_body["data"],
            {
                "registration_id": str(registration_challenge.id),
                "status": "otp_verified",
                "message": (
                    "Email verified. Create your lock PIN to complete registration."
                ),
            },
        )
        self.assertIsNone(response_body["error"])
        self.assertIsNone(response_body["meta"])
        self.assertEqual(
            registration_challenge.status,
            RegistrationStatus.OTP_VERIFIED,
        )
        self.assertEqual(otp_verification.status, OTPStatus.CONSUMED)
        self.assertIsNotNone(otp_verification.consumed_at)
        self.assertFalse(User.objects.exists())

    def test_verify_otp_rejects_an_invalid_code(self: Self) -> None:
        """
        Verify an invalid OTP returns a safe error and records the attempt.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when invalid OTP handling is incorrect.
        """
        registration_challenge, otp_verification = (
            self._create_registration_with_otp()
        )
        payload: dict[str, str] = self._verification_payload(
            registration_challenge,
        )
        payload["otp_code"] = "123456"

        response: Any = self.client.post(
            "/api/auth/register/verify-otp",
            data=payload,
            content_type="application/json",
        )
        response_body: dict[str, Any] = response.json()

        registration_challenge.refresh_from_db()
        otp_verification.refresh_from_db()
        self.assertEqual(response.status_code, 400)
        self.assertFalse(response_body["success"])
        self.assertIsNone(response_body["data"])
        self.assertEqual(response_body["error"]["code"], "invalid_otp")
        self.assertEqual(otp_verification.attempt_count, 1)
        self.assertEqual(otp_verification.status, OTPStatus.PENDING)
        self.assertEqual(
            registration_challenge.status,
            RegistrationStatus.OTP_PENDING,
        )

    def test_verify_otp_rejects_an_expired_code(self: Self) -> None:
        """
        Verify an expired OTP returns a gone response and is persisted as expired.

        Args:
            self: Current test case instance.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when expired OTP handling is incorrect.
        """
        registration_challenge, otp_verification = (
            self._create_registration_with_otp()
        )
        otp_verification.expires_at = timezone.now() - timedelta(microseconds=1)
        otp_verification.save(update_fields=["expires_at", "updated_at"])

        response: Any = self.client.post(
            "/api/auth/register/verify-otp",
            data=self._verification_payload(registration_challenge),
            content_type="application/json",
        )
        response_body: dict[str, Any] = response.json()

        otp_verification.refresh_from_db()
        self.assertEqual(response.status_code, 410)
        self.assertEqual(response_body["error"]["code"], "expired_otp")
        self.assertEqual(otp_verification.status, OTPStatus.EXPIRED)
