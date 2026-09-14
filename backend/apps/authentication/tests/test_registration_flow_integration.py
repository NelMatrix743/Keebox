from typing import Any, Self
from unittest.mock import Mock, patch
from uuid import UUID

from django.contrib.auth.hashers import check_password
from django.test import TestCase, override_settings
from ninja_jwt.tokens import AccessToken, RefreshToken

from apps.authentication.models import OTPVerification, RegistrationChallenge, User
from apps.core.choices import OTPStatus, RegistrationStatus
from apps.core.key_utils import decrypt_kbkey, validate_kbkey



@override_settings(
    KEEBOX_MASTER_KEY="KMK-ICEiIyQlJicoKSorLC0uLz-AxMjM0NTY3ODk6Ozw9Pj8",
)
class RegistrationFlowIntegrationTests(TestCase):
    @patch("apps.authentication.api.EmailDeliveryService")
    @patch(
        "apps.authentication.registration_services.generate_otp_code",
        return_value="482913",
    )
    def test_registration_flow_creates_an_authenticated_keebox_user(
        self: Self,
        generate_otp: Mock,
        email_delivery_service: Mock,
    ) -> None:
        """
        Verify the complete registration API flow creates a secured user account.

        Args:
            self: Current test case instance.
            generate_otp: Mocked secure OTP generator with a known delivery code.
            email_delivery_service: Mocked external email delivery boundary.

        Returns:
            None: This test does not return a value.

        Raises:
            AssertionError: Raised when any registration stage is incomplete.
        """
        email_delivery_service.return_value.send_otp_email.return_value = (
            "brevo-message-id"
        )

        registration_response: Any = self.client.post(
            "/api/auth/register",
            data={
                "first_name": "Nelson",
                "last_name": "Ubochiegbu",
                "email": "nelson@example.com",
                "password": "correct horse battery staple",
            },
            content_type="application/json",
        )
        registration_body: dict[str, Any] = registration_response.json()
        registration_id: UUID = UUID(
            registration_body["data"]["registration_id"],
        )

        verification_response: Any = self.client.post(
            "/api/auth/register/verify-otp",
            data={
                "registration_id": str(registration_id),
                "otp_code": "482913",
            },
            content_type="application/json",
        )
        verification_body: dict[str, Any] = verification_response.json()

        completion_response: Any = self.client.post(
            "/api/auth/register/create-pin",
            data={
                "registration_id": str(registration_id),
                "pin": "123456",
            },
            content_type="application/json",
        )
        completion_body: dict[str, Any] = completion_response.json()
        completion_data: dict[str, Any] = completion_body["data"]

        registration_challenge: RegistrationChallenge = (
            RegistrationChallenge.objects.get(pk=registration_id)
        )
        otp_verification: OTPVerification = OTPVerification.objects.get(
            registration_challenge=registration_challenge,
        )
        user: User = User.objects.get(email="nelson@example.com")
        refresh_token: RefreshToken = RefreshToken(
            completion_data["refresh_token"],
        )
        access_token: AccessToken = AccessToken(
            completion_data["access_token"],
        )

        self.assertEqual(registration_response.status_code, 201)
        self.assertEqual(
            registration_body["data"]["status"],
            RegistrationStatus.OTP_PENDING,
        )
        self.assertEqual(verification_response.status_code, 200)
        self.assertEqual(
            verification_body["data"]["status"],
            RegistrationStatus.OTP_VERIFIED,
        )
        self.assertEqual(completion_response.status_code, 201)
        self.assertTrue(completion_body["success"])
        self.assertIsNone(completion_body["error"])
        self.assertEqual(completion_data["user_id"], str(user.id))
        self.assertEqual(completion_data["first_name"], "Nelson")
        self.assertEqual(completion_data["last_name"], "Ubochiegbu")
        self.assertEqual(completion_data["email"], "nelson@example.com")
        self.assertEqual(
            completion_data["status"],
            RegistrationStatus.COMPLETED,
        )
        self.assertTrue(validate_kbkey(completion_data["kbkey"]))
        self.assertEqual(
            decrypt_kbkey(
                user.encrypted_kbkey,
                user.kbkey_nonce,
                "KMK-ICEiIyQlJicoKSorLC0uLz-AxMjM0NTY3ODk6Ozw9Pj8",
                user.kbkey_encryption_version,
            ),
            completion_data["kbkey"],
        )
        self.assertTrue(user.check_password("correct horse battery staple"))
        self.assertTrue(check_password("123456", user.pin_hash))
        self.assertEqual(str(refresh_token["user_id"]), str(user.id))
        self.assertEqual(str(access_token["user_id"]), str(user.id))
        self.assertEqual(otp_verification.status, OTPStatus.CONSUMED)
        self.assertEqual(
            registration_challenge.status,
            RegistrationStatus.COMPLETED,
        )
        self.assertIsNotNone(registration_challenge.completed_at)
        self.assertEqual(User.objects.count(), 1)
        self.assertEqual(RegistrationChallenge.objects.count(), 1)
        self.assertEqual(OTPVerification.objects.count(), 1)
        generate_otp.assert_called_once_with()
        email_delivery_service.return_value.send_otp_email.assert_called_once_with(
            recipient_email="nelson@example.com",
            recipient_full_name="Nelson Ubochiegbu",
            otp_code="482913",
            expiration_minutes=5,
        )
